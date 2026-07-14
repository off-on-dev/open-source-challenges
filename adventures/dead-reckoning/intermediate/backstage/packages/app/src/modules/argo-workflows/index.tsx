import { createFrontendModule } from '@backstage/frontend-plugin-api';
import { EntityCardBlueprint } from '@backstage/plugin-catalog-react/alpha';

// A small custom entity card showing this vessel's delivery workflows. There is
// no maintained Argo Workflows plugin for the new frontend system, so rather
// than vendoring one we surface just what the cockpit needs: the build history
// for this vessel, fetched from Argo Workflows through the backend proxy.
const argoWorkflowsCard = EntityCardBlueprint.make({
  name: 'argo-workflows',
  params: {
    filter: 'kind:component',
    // A short status list; sits in the right rail next to the About card.
    type: 'info',
    loader: () =>
      import('./ArgoWorkflowsCard').then(m => <m.ArgoWorkflowsCard />),
  },
});

export const argoWorkflowsModule = createFrontendModule({
  pluginId: 'app',
  extensions: [argoWorkflowsCard],
});
