package dev.openfeature.demo.java.demo;

import dev.openfeature.sdk.Client;
import dev.openfeature.sdk.ImmutableContext;
import dev.openfeature.sdk.OpenFeatureAPI;
import dev.openfeature.sdk.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Phase 3 lab. Reads the {@code vision_amplifier_v2} flag and, when the
 * fractional rollout puts the caller into the {@code on} bucket, executes the
 * deliberately bad new formulation: 200ms slower, 10% chance of a 5xx. The
 * baseline {@code vision_state} flag still drives the response body.
 *
 * <p>Each evaluation also passes a {@code dose} attribute as <em>invocation
 * context</em> — the fraction of clinical staff who under- or over-dose
 * subjects shows up here. Most subjects get {@code "standard"}, the rest get
 * {@code "underdose"} or {@code "overdose"}, both of which override the cohort
 * targeting and yield {@code clouded}.</p>
 */
@RestController
public class Trial {

    @GetMapping("/")
    public ResponseEntity<?> observeSubject(@RequestParam(required = false) String dose) {
        Client client = OpenFeatureAPI.getInstance().getClient();
        boolean newAlgo = client.getBooleanValue("vision_amplifier_v2", false);
        if (newAlgo) {
            try {
                Thread.sleep(200);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            if (ThreadLocalRandom.current().nextDouble() < 0.1) {
                return ResponseEntity.status(500).body("simulated failure in vision_amplifier_v2");
            }
        }

        String resolvedDose = (dose != null) ? dose : pickDose();
        HashMap<String, Value> invocationCtx = new HashMap<>();
        invocationCtx.put("dose", new Value(resolvedDose));

        return ResponseEntity.ok(
                client.getStringDetails("vision_state", "untreated", new ImmutableContext(invocationCtx)));
    }

    private static String pickDose() {
        double r = ThreadLocalRandom.current().nextDouble();
        if (r < 0.60) return "standard";
        if (r < 0.90) return "underdose";
        return "overdose";
    }
}
