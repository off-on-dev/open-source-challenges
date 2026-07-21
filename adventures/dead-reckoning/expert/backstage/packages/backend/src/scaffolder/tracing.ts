/*
 * The commission office's telemetry.
 *
 * Backstage emits one trace per vessel it commissions. This sets up the
 * OpenTelemetry SDK once, sending spans over OTLP/HTTP to the OpenTelemetry
 * Collector, which forwards them to Jaeger. The collector endpoint is read from
 * app-config (scaffolder.tracing.endpoint) so the wiring lives in configuration.
 *
 * A commission's trace is shaped like this:
 *
 *   commission <vessel>          (root, service=backstage)
 *   ├─ enter parameters          (the captain filling in the commission form)
 *   └─ scaffold repos            (parent of the per-step spans)
 *      ├─ <each scaffolder step> (one span per step)
 *
 * The "enter parameters" bar is the human's think-time at the commission desk:
 * the browser stamps the moment the form opened (the EnterParametersTimer field),
 * and the root span is back-dated to that moment so the trace opens with the
 * captain's own decision, not the scaffolder's first action.
 *
 * The per-step spans are reconstructed after the fact from the scaffolder's own
 * task log (each step logs "processing" when it starts and "completed" when it
 * finishes), so the template's work steps stay ordinary, untraced scaffolder
 * actions. The delivery pipeline (Argo Workflows, Argo CD) continues the same
 * trace off the root span, via the W3C traceparent carried in the commit message.
 */
import { Config } from '@backstage/config';
import { Span, SpanStatusCode, context, trace } from '@opentelemetry/api';
import {
  BatchSpanProcessor,
  NodeTracerProvider,
} from '@opentelemetry/sdk-trace-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { Resource } from '@opentelemetry/resources';

const TRACER_NAME = 'dead-reckoning-scaffolder';
const DEFAULT_ENDPOINT = 'http://localhost:30107';

// The bookkeeping steps that open and close the trace: excluded from the
// reconstructed per-step spans (they are plumbing, not commission work).
const BOOKKEEPING_STEP_IDS = new Set(['trace-start', 'trace-finish']);

let provider: NodeTracerProvider | undefined;

// Initialise the SDK once. Without a configured exporter endpoint the commission
// office stays dark and no spans reach Jaeger.
//
// Deliberately NOT registered as the global OpenTelemetry provider: we keep it
// local and read our tracer straight off it (see commissionTracer). Registering
// globally would route every span the rest of the Backstage backend emits (the
// scaffolder's own task-polling loop, etc.) through this exporter too, burying
// the commission trace under a stream of unrelated single-span traces in Jaeger.
export function initTracing(config: Config): void {
  if (provider) return;

  const endpoint =
    config.getOptionalString('scaffolder.tracing.endpoint') ?? DEFAULT_ENDPOINT;

  const exporter = new OTLPTraceExporter({
    url: `${endpoint.replace(/\/$/, '')}/v1/traces`,
  });

  provider = new NodeTracerProvider({
    resource: new Resource({ 'service.name': 'backstage' }),
    spanProcessors: [new BatchSpanProcessor(exporter)],
  });
}

// Our own provider's tracer, so ONLY the commission spans we create here are
// exported. Falls back to the global tracer if init was skipped (no endpoint),
// where it is a harmless no-op.
function commissionTracer() {
  return provider?.getTracer(TRACER_NAME) ?? trace.getTracer(TRACER_NAME);
}

// The root span of a commission, kept open across the scaffolder run and keyed
// by task id so trace-finish can close it and hang the per-step spans off it.
// enterStart is the browser-captured form-open time, held here so trace-finish
// can draw the "enter parameters" bar from it.
interface OpenCommission {
  root: Span;
  enterStart?: Date;
}
const roots = new Map<string, OpenCommission>();

// What the captain ordered at the commission desk, recorded on the trace.
export interface CommissionOrder {
  // The cargo selected on the form. Stamped onto the root as provisions.ordered
  // so the trace carries what was asked for, to sit beside the provisions.delivered
  // the delivery pipeline reads back off the running vessel.
  provisions?: string;
  // ISO 8601 time the form was opened (from the browser). Back-dates the root
  // span so the trace opens with the human's form-fill time.
  enterStart?: string;
}

// Open the commission trace and return the W3C traceparent (built from the root
// span's real context) for the delivery pipeline to continue.
export function startCommission(
  taskId: string,
  vessel: string,
  order: CommissionOrder = {},
): string {
  const enterStart = order.enterStart ? new Date(order.enterStart) : undefined;
  const root = commissionTracer().startSpan(
    `commission ${vessel}`,
    // Back-date the root to form-open when we have it, so the whole journey
    // (form-fill included) hangs off a root that starts when the captain did.
    enterStart ? { startTime: enterStart } : undefined,
  );
  root.setAttribute('vessel.name', vessel);
  if (order.provisions) root.setAttribute('provisions.ordered', order.provisions);
  roots.set(taskId, { root, enterStart });

  const { traceId, spanId } = root.spanContext();
  return `00-${traceId}-${spanId}-01`;
}

// One scaffolder step, as reconstructed from the task log.
export interface StepTiming {
  name: string;
  start: Date;
  end: Date;
  failed: boolean;
}

// Emit a "scaffold repos" span with one child per step (plus the "enter
// parameters" bar when we captured a form-open time), then close the root.
// No-op if the commission has no open root (e.g. tracing was never started).
export function finishCommission(taskId: string, steps: StepTiming[]): void {
  const open = roots.get(taskId);
  if (!open) return;
  roots.delete(taskId);
  const { root, enterStart } = open;

  const tracer = commissionTracer();
  try {
    if (steps.length) {
      const rootCtx = trace.setSpan(context.active(), root);
      const scaffoldStart = steps[0].start;
      const scaffoldEnd = steps[steps.length - 1].end;

      // The human form-fill bar: form open -> scaffolder's first action. Drawn
      // only when the browser captured a form-open time.
      if (enterStart) {
        const enter = tracer.startSpan(
          'enter parameters',
          { startTime: enterStart },
          rootCtx,
        );
        enter.end(scaffoldStart);
      }

      const scaffold = tracer.startSpan(
        'scaffold repos',
        { startTime: scaffoldStart },
        rootCtx,
      );
      const scaffoldCtx = trace.setSpan(rootCtx, scaffold);

      for (const step of steps) {
        const span = tracer.startSpan(
          step.name,
          { startTime: step.start },
          scaffoldCtx,
        );
        span.setStatus({
          code: step.failed ? SpanStatusCode.ERROR : SpanStatusCode.OK,
        });
        span.end(step.end);
      }
      scaffold.end(scaffoldEnd);
    }
    root.setStatus({ code: SpanStatusCode.OK });
  } finally {
    root.end();
  }
}

// Reconstruct per-step timings from the scaffolder task log. Each step logs a
// "processing" event when it starts and a terminal event ("completed",
// "failed", "skipped", "cancelled") when it ends; both carry the step id and a
// timestamp. The step's display name is taken from the "Beginning step <name>"
// message, falling back to the step id.
export function timingsFromLogs(
  logs: Array<{
    createdAt: string;
    body: { message?: string; stepId?: string; status?: string };
  }>,
): StepTiming[] {
  const byStep = new Map<
    string,
    { name: string; start?: Date; end?: Date; failed: boolean }
  >();

  for (const log of logs) {
    const stepId = log.body.stepId;
    const status = log.body.status;
    if (!stepId || !status || BOOKKEEPING_STEP_IDS.has(stepId)) continue;

    const entry =
      byStep.get(stepId) ?? { name: stepId, start: undefined, end: undefined, failed: false };
    const when = new Date(log.createdAt);

    if (status === 'processing') {
      entry.start = when;
      const m = log.body.message?.match(/^Beginning step (.+)$/);
      if (m) entry.name = m[1];
    } else {
      // Terminal status: completed / failed / skipped / cancelled.
      entry.end = when;
      if (status === 'failed' || status === 'cancelled') entry.failed = true;
    }
    byStep.set(stepId, entry);
  }

  return [...byStep.values()]
    .filter((e): e is Required<Pick<typeof e, 'start' | 'end'>> & typeof e =>
      Boolean(e.start && e.end),
    )
    .map(e => ({ name: e.name, start: e.start, end: e.end, failed: e.failed }))
    .sort((a, b) => a.start.getTime() - b.start.getTime());
}
