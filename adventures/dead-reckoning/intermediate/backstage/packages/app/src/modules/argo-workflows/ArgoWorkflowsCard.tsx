import { useEffect, useState } from 'react';
import { IconButton } from '@material-ui/core';
import CachedIcon from '@material-ui/icons/Cached';
import {
  InfoCard,
  Progress,
  ResponseErrorPanel,
  Link,
  StatusOK,
  StatusError,
  StatusRunning,
  StatusPending,
  StatusAborted,
} from '@backstage/core-components';
import {
  useApi,
  discoveryApiRef,
  fetchApiRef,
  configApiRef,
} from '@backstage/core-plugin-api';
import { useEntity } from '@backstage/plugin-catalog-react';

// The namespace the delivery workflows run in (see platform/argo-workflows/).
const WORKFLOW_NS = 'argo-workflows';

type Workflow = {
  metadata: { name: string; creationTimestamp?: string };
  status?: { phase?: string; startedAt?: string; finishedAt?: string };
};

// Map an Argo Workflow phase onto one of Backstage's status dots.
function PhaseStatus({ phase }: { phase?: string }) {
  switch (phase) {
    case 'Succeeded':
      return <StatusOK>Succeeded</StatusOK>;
    case 'Failed':
    case 'Error':
      return <StatusError>{phase}</StatusError>;
    case 'Running':
      return <StatusRunning>Running</StatusRunning>;
    default:
      return <StatusPending>{phase || 'Pending'}</StatusPending>;
  }
}

// Shows the delivery workflows that built this vessel. The Sensor
// (platform/argo-events/sensor.yaml) stamps each Workflow with a "vessel" label
// equal to the repo name, which is also this component's catalog name, so we can
// list exactly this vessel's builds.
export function ArgoWorkflowsCard() {
  const { entity } = useEntity();
  const discoveryApi = useApi(discoveryApiRef);
  const { fetch } = useApi(fetchApiRef);
  const config = useApi(configApiRef);

  const vessel = entity.metadata.name;
  const uiBaseUrl = config.getOptionalString('argoWorkflows.baseUrl');

  const [workflows, setWorkflows] = useState<Workflow[]>();
  const [error, setError] = useState<Error>();
  // Bumped by the refresh button to re-run the fetch below.
  const [reload, setReload] = useState(0);

  useEffect(() => {
    let active = true;
    setWorkflows(undefined);
    setError(undefined);
    (async () => {
      try {
        const proxyUrl = await discoveryApi.getBaseUrl('proxy');
        const selector = encodeURIComponent(`vessel=${vessel}`);
        const res = await fetch(
          `${proxyUrl}/argo-workflows/workflows/${WORKFLOW_NS}?listOptions.labelSelector=${selector}`,
        );
        if (!res.ok) {
          throw new Error(`Argo Workflows API returned ${res.status}`);
        }
        const body = await res.json();
        if (active) {
          setWorkflows((body.items ?? []) as Workflow[]);
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
  }, [discoveryApi, fetch, vessel, reload]);

  let content;
  if (error) {
    content = <ResponseErrorPanel error={error} />;
  } else if (!workflows) {
    content = <Progress />;
  } else if (workflows.length === 0) {
    content = <StatusAborted>No delivery workflows found yet</StatusAborted>;
  } else {
    // Newest first.
    const sorted = [...workflows].sort((a, b) =>
      (b.status?.startedAt ?? '').localeCompare(a.status?.startedAt ?? ''),
    );
    content = (
      <ul style={{ listStyle: 'none', margin: 0, padding: 0 }}>
        {sorted.map(wf => (
          <li key={wf.metadata.name} style={{ marginBottom: 8 }}>
            <PhaseStatus phase={wf.status?.phase} />{' '}
            {uiBaseUrl ? (
              <Link
                to={`${uiBaseUrl}/workflows/${WORKFLOW_NS}/${wf.metadata.name}`}
              >
                {wf.metadata.name}
              </Link>
            ) : (
              wf.metadata.name
            )}
          </li>
        ))}
      </ul>
    );
  }

  return (
    <InfoCard
      title="Delivery workflows"
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
