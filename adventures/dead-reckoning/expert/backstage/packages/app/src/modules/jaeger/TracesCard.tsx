import { useEffect, useState } from 'react';
import { IconButton } from '@material-ui/core';
import CachedIcon from '@material-ui/icons/Cached';
import {
  InfoCard,
  Progress,
  ResponseErrorPanel,
  Link,
  StatusAborted,
} from '@backstage/core-components';
import {
  useApi,
  discoveryApiRef,
  fetchApiRef,
  configApiRef,
} from '@backstage/core-plugin-api';
import { useEntity } from '@backstage/plugin-catalog-react';

// The commission office (Backstage) opens a root span named "commission <vessel>"
// on the service "backstage" (see packages/backend/src/scaffolder/tracing.ts).
// A vessel's catalog name IS its <vessel>, so we can ask Jaeger for exactly this
// vessel's commission trace(s) without needing any per-vessel annotation.
const TRACE_SERVICE = 'backstage';
// How far back to look for this vessel's voyages.
const LOOKBACK_MS = 7 * 24 * 60 * 60 * 1000;

type JaegerSpan = {
  operationName: string;
  startTime: number; // microseconds since epoch
  duration: number; // microseconds
};
type JaegerTrace = { traceID: string; spans: JaegerSpan[] };

// Jaeger reports times in microseconds; show something human at a glance.
function formatDuration(micros: number): string {
  const ms = micros / 1000;
  return ms >= 1000 ? `${(ms / 1000).toFixed(1)}s` : `${Math.round(ms)}ms`;
}

// Shows this vessel's commission trace(s): the single distributed trace that
// follows a vessel from the office (Backstage) through the shipyard (Argo
// Workflows) to open water (Argo CD). The list links out to the full trace in
// Jaeger, where all three services appear stitched together. Data comes through
// the backend proxy (see the "/jaeger/api" endpoint in app-config.yaml).
export function TracesCard() {
  const { entity } = useEntity();
  const discoveryApi = useApi(discoveryApiRef);
  const { fetch } = useApi(fetchApiRef);
  const config = useApi(configApiRef);

  const vessel = entity.metadata.name;
  const operation = `commission ${vessel}`;
  const uiBaseUrl = config.getOptionalString('jaeger.baseUrl');

  const [traces, setTraces] = useState<JaegerTrace[]>();
  const [error, setError] = useState<Error>();
  // Bumped by the refresh button to re-run the fetch below.
  const [reload, setReload] = useState(0);

  useEffect(() => {
    let active = true;
    setTraces(undefined);
    setError(undefined);
    (async () => {
      try {
        const proxyUrl = await discoveryApi.getBaseUrl('proxy');
        const end = Date.now() * 1000;
        const start = end - LOOKBACK_MS * 1000;
        const params = new URLSearchParams({
          service: TRACE_SERVICE,
          operation,
          start: String(start),
          end: String(end),
          limit: '20',
        });
        const res = await fetch(`${proxyUrl}/jaeger/api/traces?${params}`);
        if (!res.ok) {
          throw new Error(`Jaeger query API returned ${res.status}`);
        }
        const body = await res.json();
        if (active) {
          setTraces((body.data ?? []) as JaegerTrace[]);
        }
      } catch (e) {
        if (active) {
          setError(e as Error);
        }
      }
    })();
    return () => {
      active = false;
    };
  }, [discoveryApi, fetch, operation, reload]);

  let content;
  if (error) {
    content = <ResponseErrorPanel error={error} />;
  } else if (!traces) {
    content = <Progress />;
  } else if (traces.length === 0) {
    content = (
      <StatusAborted>
        No voyage logged yet — the trace may still be on its way to Jaeger.
      </StatusAborted>
    );
  } else {
    // The "commission <vessel>" root span closes when Backstage finishes, but
    // its pipeline children (build, rollout) run on afterwards and outlive it —
    // so the root's own duration is only the office's slice. Report the whole
    // voyage: earliest span start to latest span end across the trace. Newest
    // voyage first.
    const rows = traces
      .map(t => {
        const spans = t.spans ?? [];
        const start = spans.length
          ? Math.min(...spans.map(s => s.startTime))
          : 0;
        const end = spans.length
          ? Math.max(...spans.map(s => s.startTime + s.duration))
          : 0;
        return { traceID: t.traceID, start, duration: end - start };
      })
      .sort((a, b) => b.start - a.start);
    content = (
      <ul style={{ listStyle: 'none', margin: 0, padding: 0 }}>
        {rows.map(r => {
          const label = `${new Date(
            r.start / 1000,
          ).toLocaleString()} · ${formatDuration(r.duration)}`;
          return (
            <li key={r.traceID} style={{ marginBottom: 8 }}>
              {uiBaseUrl ? (
                <Link to={`${uiBaseUrl}/trace/${r.traceID}`}>{label}</Link>
              ) : (
                label
              )}
            </li>
          );
        })}
      </ul>
    );
  }

  return (
    <InfoCard
      title="Voyage log"
      subheader="This vessel's commission, traced from the office to open water"
      action={
        <IconButton
          aria-label="Refresh"
          title="Refresh"
          onClick={() => setReload(n => n + 1)}
        >
          <CachedIcon />
        </IconButton>
      }
    >
      {content}
    </InfoCard>
  );
}
