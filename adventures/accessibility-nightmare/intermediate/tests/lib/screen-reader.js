// Drives the Guidepup Virtual Screen Reader inside the page under test.
//
// This is a *simulation*. It reads the accessibility tree the browser builds
// and reports what a screen reader would announce from it. It is not NVDA,
// JAWS or VoiceOver, and it will not reproduce the differences between them.
// Passing these assertions means the accessibility tree says the right thing,
// which is necessary but not sufficient. Test with a real screen reader on
// real work.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

const BUNDLE = path.join(
    path.dirname(require.resolve('@guidepup/virtual-screen-reader/package.json')),
    'lib/esm/index.browser.js',
);

// The published bundle is an ES module. Rewrite its export statement into
// window assignments so it can be injected as a classic script, which is not
// subject to the page's own CSP and runs before first paint.
function buildInitScript() {
    const source = fs
        .readFileSync(BUNDLE, 'utf8')
        .replace(/export\s*\{([^}]*)\}\s*;?/, (_match, specifiers) =>
            specifiers
                .split(',')
                .map((entry) => entry.trim().split(/\s+as\s+/))
                .map(
                    ([local, exported = local]) =>
                        `window.__vsr_${exported} = ${local};`,
                )
                .join('\n'),
        );

    // The bundle's last line is a `//# sourceMappingURL` comment, so the
    // closing braces must start on a line of their own or they are swallowed.
    return `(() => {\n${source}\n})();\n`;
}

const INIT_SCRIPT = buildInitScript();

// Call before page.goto(). Loads the screen reader into every document the
// page creates.
export async function attachScreenReader(page) {
    await page.addInitScript({ content: INIT_SCRIPT });
}

// Starts listening. From here the reader's cursor follows real focus, so
// driving the keyboard with Playwright is enough to move it.
export async function startScreenReader(page) {
    await page.evaluate(async () => {
        await window.__vsr_virtual.start({ container: document.body });
    });
}

// Everything the screen reader has announced since the last clear, oldest
// first. Live region announcements arrive prefixed "polite:" or "assertive:".
export async function spokenPhrases(page) {
    return page.evaluate(async () => window.__vsr_virtual.spokenPhraseLog());
}

// Just the live region announcements, with their politeness prefix stripped.
// Empty ones are dropped: clearing a live region registers as a change here,
// but a real screen reader has nothing to say about it.
export async function liveAnnouncements(page) {
    const phrases = await spokenPhrases(page);
    return phrases
        .filter((phrase) => /^(polite|assertive):/.test(phrase))
        .map((phrase) => phrase.replace(/^(polite|assertive):\s*/, ''))
        .filter((phrase) => phrase.length > 0);
}

export async function clearSpokenPhrases(page) {
    await page.evaluate(async () => {
        await window.__vsr_virtual.clearSpokenPhraseLog();
    });
}

// Announcements are queued through a microtask, and React commits its updates
// asynchronously, so give both a moment to settle before reading the log.
export async function settle(page) {
    await page.waitForTimeout(250);
}
