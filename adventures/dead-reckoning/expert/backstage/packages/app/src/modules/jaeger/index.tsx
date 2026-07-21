import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { EntityCardBlueprint } from '@backstage/plugin-catalog-react/alpha';

// A small custom entity card that surfaces this vessel's commission trace from
// Jaeger. The community Jaeger plugin has no new-frontend-system support, so —
// exactly as with the Argo Workflows card — we query Jaeger's API through the
// backend proxy and link out to the full cross-service trace (Backstage + Argo
// Workflows + Argo CD) in the Jaeger UI. type:content gives it the page's main
// column, since the trace is the headline of this level.
const jaegerTracesCard = EntityCardBlueprint.make({
  name: 'jaeger-traces',
  params: {
    filter: 'kind:component',
    type: 'content',
    loader: () => import('./TracesCard').then(m => <m.TracesCard />),
  },
});

export const jaegerModule = createFrontendModule({
  pluginId: 'app',
  extensions: [jaegerTracesCard],
});
