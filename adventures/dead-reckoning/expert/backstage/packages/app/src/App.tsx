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
// Local module: a "Voyage log" card showing this vessel's commission trace from
// Jaeger, linking out to the full cross-service trace (the community Jaeger
// plugin has no new-frontend-system support).
import { jaegerModule } from './modules/jaeger';
// Local module: the EnterParametersTimer field the commission template uses to
// stamp the form-open time, so the trace opens with the captain's form-fill bar.
import { scaffolderFieldsModule } from './modules/scaffolder';

export default createApp({
  features: [
    catalogPlugin,
    argocdPlugin,
    navModule,
    argoWorkflowsModule,
    jaegerModule,
    scaffolderFieldsModule,
  ],
});
