package dev.openfeature.demo.java.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class Trial {

    @GetMapping("/")
    public String observeSubject() {
        // The lab is reading from a hard-coded label, not from the chart.
        // Wire OpenFeature in and resolve the "vision_state" flag from flags.json instead.
        return "untreated";
    }
}
