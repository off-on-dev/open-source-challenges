/*
 * Two bookkeeping actions that bracket a commission with a trace.
 *
 *   dr:trace-start  - opens the "commission <vessel>" root span and returns its
 *                     W3C traceparent, which the template writes into the code
 *                     repo's commit message so the delivery pipeline can continue
 *                     the same trace.
 *   dr:trace-finish - reads the task's step log, emits one span per work step
 *                     under the root, and closes the trace.
 *
 * The work steps in between stay ordinary scaffolder actions (fetch:template,
 * publish:gitea, catalog:register) — they are not wrapped or modified. Their
 * spans are reconstructed from the scaffolder's own log, so the template reads
 * exactly like any other, plus these two plumbing steps.
 */
import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import type { ScaffolderService } from '@backstage/plugin-scaffolder-node';
import { finishCommission, startCommission, timingsFromLogs } from './tracing';

export const createTraceStartAction = () =>
  createTemplateAction({
    id: 'dr:trace-start',
    description:
      'Opens the commission trace and returns its W3C traceparent so the delivery pipeline can continue it.',
    schema: {
      input: {
        vessel: z =>
          z.string({ description: 'The vessel being commissioned' }),
        // The cargo ordered on the form, recorded on the trace as
        // provisions.ordered.
        provisions: z =>
          z
            .string({ description: 'The cargo the vessel was commissioned to carry' })
            .optional(),
        // Browser-captured form-open time, so the trace can show the captain's
        // form-fill as its opening bar.
        enterStart: z =>
          z
            .string({ description: 'ISO 8601 time the commission form was opened' })
            .optional(),
      },
      output: {
        traceparent: z =>
          z.string({
            description: 'W3C traceparent for the commission trace',
          }),
      },
    },
    async handler(ctx) {
      const traceparent = startCommission(ctx.task.id, ctx.input.vessel, {
        provisions: ctx.input.provisions,
        enterStart: ctx.input.enterStart,
      });
      ctx.output('traceparent', traceparent);
      ctx.logger.info(`Opened commission trace ${traceparent}`);
    },
  });

export const createTraceFinishAction = (scaffolder: ScaffolderService) =>
  createTemplateAction({
    id: 'dr:trace-finish',
    description:
      'Emits a span per commission step from the task log and closes the trace.',
    async handler(ctx) {
      // Telemetry must never fail a commission: reconstruct spans best-effort.
      try {
        const credentials = await ctx.getInitiatorCredentials();
        const logs = await scaffolder.getLogs(
          { taskId: ctx.task.id },
          { credentials },
        );
        finishCommission(ctx.task.id, timingsFromLogs(logs));
      } catch (e) {
        ctx.logger.warn(`Could not finalise commission trace: ${e}`);
        finishCommission(ctx.task.id, []);
      }
      ctx.logger.info('Closed commission trace');
    },
  });
