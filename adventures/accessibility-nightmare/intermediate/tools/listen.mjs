// npm run listen
//
// Walks the checkout the way a keyboard user would and prints what a screen
// reader would announce at each step. Nothing here grades you; it is a
// microscope, not a test.
//
// This is a simulation built from the accessibility tree, not NVDA, JAWS or
// VoiceOver, and it will not reproduce the differences between them. Silence
// here means silence there. Sound here is necessary but not sufficient.
import { chromium } from 'playwright';
import {
    attachScreenReader,
    clearSpokenPhrases,
    settle,
    spokenPhrases,
    startScreenReader,
} from '../tests/lib/screen-reader.js';

const BASE = process.env.LISTEN_URL ?? 'http://127.0.0.1:5173';

const dim = (s) => `\x1b[2m${s}\x1b[0m`;
const bold = (s) => `\x1b[1m${s}\x1b[0m`;
const red = (s) => `\x1b[31m${s}\x1b[0m`;
const green = (s) => `\x1b[32m${s}\x1b[0m`;

async function reachable(url) {
    try {
        return (await fetch(url)).ok;
    } catch {
        return false;
    }
}

if (!(await reachable(BASE))) {
    console.error(`\nShopSmart is not running at ${BASE}.`);
    console.error('Start it with `npm run dev`, then run this again.\n');
    process.exit(1);
}

const browser = await chromium.launch();
const context = await browser.newContext();
const page = await context.newPage();
await attachScreenReader(page);
await page.goto(`${BASE}/#/product/running-shoes`, { waitUntil: 'networkidle' });
await startScreenReader(page);

let silences = 0;

async function step(what, action) {
    await clearSpokenPhrases(page);
    await action();
    await settle(page);
    const heard = await spokenPhrases(page);

    console.log(`\n${bold(what)}`);
    if (heard.length === 0) {
        silences += 1;
        console.log(`  ${red('(silence)')}`);
        return;
    }
    for (const phrase of heard) {
        const live = /^(polite|assertive):/.test(phrase);
        console.log(`  ${live ? green(phrase) : phrase}`);
    }
}

console.log(bold('\nWhat a screen reader would announce'));
console.log(dim(`${BASE}  ·  a simulation, not real assistive technology`));

await step('Tabbing through the product page', async () => {
    for (let i = 0; i < 6; i += 1) await page.keyboard.press('Tab');
});

await step('Adding the item to the basket', async () => {
    await page.getByRole('button', { name: 'Add to basket' }).click();
});

await step('Pressing Escape on the confirmation', async () => {
    await page.keyboard.press('Escape');
});

await page.goto(`${BASE}/#/checkout`, { waitUntil: 'networkidle' });

await step('Submitting the checkout form with nothing filled in', async () => {
    await page.getByRole('button', { name: 'Place order' }).click();
});

await step('Filling the fields in and submitting again', async () => {
    await page.getByLabel('Full name').fill('Ada Lovelace');
    await page.getByLabel('Email').fill('ada@example.com');
    await page.getByRole('button', { name: 'Place order' }).click();
});

console.log(
    `\n${dim('Announcements from a live region are prefixed polite: or assertive:')}`,
);
if (silences > 0) {
    console.log(
        red(
            `${silences} step${silences === 1 ? '' : 's'} said nothing at all.`,
        ),
    );
}
console.log();

await browser.close();
