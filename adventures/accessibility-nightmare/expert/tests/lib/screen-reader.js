// Drives the Guidepup Virtual Screen Reader inside the page under test.
//
// This is a simulation. It reads the accessibility tree the browser builds
// and reports what a screen reader would announce from it. It is not NVDA,
// JAWS or VoiceOver — passing these assertions means the tree says the right
// thing. Test with a real screen reader before shipping.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);

const BUNDLE = path.join(
    path.dirname(require.resolve('@guidepup/virtual-screen-reader/package.json')),
    'lib/esm/index.browser.js',
);

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

    return `(() => {\n${source}\n})();\n`;
}

const INIT_SCRIPT = buildInitScript();

// Call before page.goto(). Loads the screen reader into every document.
export async function attachScreenReader(page) {
    await page.addInitScript({ content: INIT_SCRIPT });
}

// Starts listening. From here the reader's cursor follows real focus.
export async function startScreenReader(page) {
    await page.evaluate(async () => {
        await window.__vsr_virtual.start({ container: document.body });
    });
}

// Everything the screen reader has announced since the last clear, oldest first.
// Live region announcements arrive prefixed "polite:" or "assertive:".
export async function spokenPhrases(page) {
    return page.evaluate(async () => window.__vsr_virtual.spokenPhraseLog());
}

// Just the live region announcements, with their politeness prefix stripped.
// Empty announcements (clearing a region) are dropped.
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

// React commits asynchronously and announcements queue through a microtask,
// so give both a moment to settle before reading the log.
export async function settle(page) {
    await page.waitForTimeout(250);
}
