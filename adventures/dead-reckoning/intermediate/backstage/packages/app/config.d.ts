export interface Config {
  /** Settings for the custom Argo Workflows "Delivery workflows" card. */
  argoWorkflows?: {
    /**
     * Base URL of the Argo Workflows UI. Used only for deep links from the card
     * to a workflow, so it must be readable by the frontend.
     *
     * @visibility frontend
     */
    baseUrl?: string;
  };
}
