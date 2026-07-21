/*
 * Wires up commission tracing:
 *  - initialises the OpenTelemetry SDK from app-config, and
 *  - registers the dr:trace-start / dr:trace-finish bookkeeping actions.
 *
 * The template's work steps stay ordinary scaffolder actions; their spans are
 * reconstructed from the scaffolder's own task log by dr:trace-finish, which
 * reads it through the scaffolder client service.
 */
import {
  coreServices,
  createBackendModule,
} from '@backstage/backend-plugin-api';
import {
  scaffolderActionsExtensionPoint,
  scaffolderServiceRef,
} from '@backstage/plugin-scaffolder-node';
import { createTraceFinishAction, createTraceStartAction } from './actions';
import { initTracing } from './tracing';

export const scaffolderModuleTracing = createBackendModule({
  pluginId: 'scaffolder',
  moduleId: 'dead-reckoning-tracing',
  register(reg) {
    reg.registerInit({
      deps: {
        scaffolderActions: scaffolderActionsExtensionPoint,
        config: coreServices.rootConfig,
        scaffolder: scaffolderServiceRef,
      },
      async init({ scaffolderActions, config, scaffolder }) {
        initTracing(config);
        scaffolderActions.addActions(
          createTraceStartAction(),
          createTraceFinishAction(scaffolder),
        );
      },
    });
  },
});

export default scaffolderModuleTracing;
