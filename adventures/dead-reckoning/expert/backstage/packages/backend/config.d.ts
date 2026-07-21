export interface Config {
  scaffolder?: {
    /** Commission-office tracing (the dr:trace-start / dr:trace-finish actions). */
    tracing?: {
      /**
       * OTLP/HTTP endpoint of the OpenTelemetry Collector that commission traces
       * are exported to (spans are POSTed to `<endpoint>/v1/traces`).
       *
       * @visibility backend
       */
      endpoint?: string;
    };
  };
}
