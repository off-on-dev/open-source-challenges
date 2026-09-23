import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

// The compliance gate. It has run on every push for months and never reported
// a violation. Work out what it is actually covering before you extend it.
//
// Your objectives:
//   1. Have the gate audit every step a customer moves through, not only the homepage.
//   2. Find the navigation barrier that automated scanning has never reported.
//   3. Fix it and have the gate verify the fix holds.
//   4. Produce a report proving each customer journey step was audited and passes.
//
// Coverage reference — which checks each tool layer can and cannot detect:
// open /coverage-table.html on the storefront

async function seriousViolations(page) {
    const results = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag22aa'])
        .analyze();

    return results.violations
        .filter((v) => ['serious', 'critical'].includes(v.impact))
        .map((v) => ({ id: v.id, impact: v.impact, help: v.help }));
}

// @scan -- the compliance gate -----------------------------------------------
// One page. Every push. Always green.
// The customer visits four pages before an order is placed.

test('@scan the homepage passes the accessibility scan', async ({ page }) => {
    await page.goto('/');

    const found = await seriousViolations(page);
    expect(
        found,
        `axe reported violations:\n${JSON.stringify(found, null, 2)}`,
    ).toEqual([]);
});
