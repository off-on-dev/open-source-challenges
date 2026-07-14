import { createApp } from '@backstage/frontend-defaults';
import catalogPlugin from '@backstage/plugin-catalog/alpha';
// Roadie's Argo CD plugin (new frontend system entry point). It contributes the
// entity-card:argocd/overviewCard shown on each vessel's page, wired to Argo CD
// through the backend proxy (see app-config.yaml). Enabled in app-config's
// app.extensions.
import argocdPlugin from '@roadiehq/backstage-plugin-argo-cd/alpha';
import { navModule } from './modules/nav';
// Local module: a small custom card showing this vessel's Argo Workflows builds
// (there is no maintained Argo Workflows plugin for the new frontend system).
import { argoWorkflowsModule } from './modules/argo-workflows';

export default createApp({
  features: [catalogPlugin, argocdPlugin, navModule, argoWorkflowsModule],
});
