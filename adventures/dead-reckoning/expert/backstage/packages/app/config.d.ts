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
  /** Settings for the custom Jaeger "Voyage log" card. */
  jaeger?: {
    /**
     * Base URL of the Jaeger UI. Used only for deep links from the card to a
     * trace, so it must be readable by the frontend.
     *
     * @visibility frontend
     */
    baseUrl?: string;
  };
}
