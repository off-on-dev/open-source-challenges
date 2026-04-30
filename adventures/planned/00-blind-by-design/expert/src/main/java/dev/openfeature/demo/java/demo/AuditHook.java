package dev.openfeature.demo.java.demo;

import dev.openfeature.sdk.EvaluationContext;
import dev.openfeature.sdk.FlagEvaluationDetails;
import dev.openfeature.sdk.Hook;
import dev.openfeature.sdk.HookContext;
import dev.openfeature.sdk.Value;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.Map;

/**
 * Audit-log hook carried over from the Intermediate level. Writes one line
 * per evaluation tagged {@code [AUDIT]}, with the cohort attributes the lab
 * director cares about. Variants of {@code clouded} log at {@code WARN} so
 * the safety officer can grep for improper-dosing follow-ups.
 *
 * <p>This is the durable, weeks-from-now archive view. The Phase 3 task adds
 * a {@code ContextSpanHook} for real-time correlation in Tempo — both hooks
 * stay registered, they just serve different downstreams.</p>
 */
public class AuditHook implements Hook {

    private static final Logger LOG = LoggerFactory.getLogger(AuditHook.class);

    /** Allowlist of context attributes safe to drop into the audit log. */
    private static final List<String> AUDITED = List.of("species", "country", "dose");

    @Override
    public void after(HookContext ctx, FlagEvaluationDetails details, Map hints) {
        StringBuilder ctxLine = new StringBuilder();
        EvaluationContext ec = ctx.getCtx();
        for (String key : AUDITED) {
            Value v = ec != null ? ec.getValue(key) : null;
            ctxLine.append(' ').append(key).append('=').append(v != null ? v.asString() : "(absent)");
        }
        String message = String.format("[AUDIT] flag=%s variant=%s reason=%s%s",
                ctx.getFlagKey(), details.getVariant(), details.getReason(), ctxLine);

        if ("clouded".equals(details.getVariant())) {
            LOG.warn("{} -- improper dosing or off-protocol cohort, follow-up required", message);
        } else {
            LOG.info("{}", message);
        }
    }

    @Override
    public void error(HookContext ctx, Exception err, Map hints) {
        LOG.warn("[AUDIT] flag evaluation error flag={} err={}", ctx.getFlagKey(), err.toString());
    }
}
