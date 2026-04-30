package dev.openfeature.demo.java.demo;

import io.opentelemetry.api.OpenTelemetry;
import io.opentelemetry.sdk.autoconfigure.AutoConfiguredOpenTelemetrySdk;
import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Half-wired OpenTelemetry SDK.
 *
 * <p>Traces ARE exported to the LGTM stack via OTLP/gRPC at
 * {@code http://localhost:4317}. The {@code TracesHook} registered in
 * {@link OpenFeatureConfig} attaches every flag evaluation as a span event
 * inside the active HTTP request span — open Grafana → Explore → Tempo and
 * search for service {@code fun-with-flags-java-spring} to see them.</p>
 *
 * <p>Metrics are NOT exported yet. The autoconfigure module is told
 * {@code otel.metrics.exporter=none}, which means the {@code SdkMeterProvider}
 * either is not created or has no exporter attached, so the Grafana
 * "Fun With Flags — Feature Flag Metrics" dashboard stays empty. To finish
 * Phase 3 the participant must:</p>
 *
 * <ol>
 *   <li>Switch {@code otel.metrics.exporter} to {@code otlp} and set a
 *       reasonable {@code otel.metric.export.interval} so Mimir receives
 *       evaluation metrics.</li>
 *   <li>Register the matching
 *       {@code dev.openfeature.contrib.hooks.otel.MetricsHook} on the
 *       OpenFeature API in {@link OpenFeatureConfig#initProvider()}.</li>
 * </ol>
 */
@Configuration
public class OpenTelemetryConfig {

    private AutoConfiguredOpenTelemetrySdk autoConfigured;

    @Bean
    public OpenTelemetry openTelemetry(
            @Value("${otel.service.name:fun-with-flags-java-spring}") String serviceName,
            @Value("${otel.exporter.otlp.endpoint:http://localhost:4317}") String otlpEndpoint,
            @Value("${otel.exporter.otlp.protocol:grpc}") String otlpProtocol,
            @Value("${otel.traces.exporter:otlp}") String tracesExporter,
            // Phase 3 TODO: flip this to "otlp" so the meter provider exports.
            @Value("${otel.metrics.exporter:none}") String metricsExporter,
            @Value("${otel.logs.exporter:none}") String logsExporter) {
        // Expose configured values via system properties so the SDK
        // autoconfigure module picks them up regardless of how the app
        // was launched.
        System.setProperty("otel.service.name", serviceName);
        System.setProperty("otel.exporter.otlp.endpoint", otlpEndpoint);
        System.setProperty("otel.exporter.otlp.protocol", otlpProtocol);
        System.setProperty("otel.traces.exporter", tracesExporter);
        System.setProperty("otel.metrics.exporter", metricsExporter);
        System.setProperty("otel.logs.exporter", logsExporter);
        // Phase 3 TODO: once metrics are flipped on, surface a sensible
        // export interval here, e.g. 10000 ms, so the dashboard updates
        // within ten seconds of new traffic.

        autoConfigured = AutoConfiguredOpenTelemetrySdk.builder()
                .setResultAsGlobal()
                .build();
        return autoConfigured.getOpenTelemetrySdk();
    }

    @PreDestroy
    public void shutdown() {
        if (autoConfigured != null) {
            autoConfigured.getOpenTelemetrySdk().close();
        }
    }
}
