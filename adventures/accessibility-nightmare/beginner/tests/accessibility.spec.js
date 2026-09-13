import { expect, test } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test('homepage has no serious or critical accessibility violations', async ({
    page,
}) => {
    await page.goto('/');

    const results = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag22aa'])
        .analyze();

    const seriousViolations = results.violations.filter(
        (violation) =>
            violation.impact === 'serious' || violation.impact === 'critical',
    );

    const summary = seriousViolations.map((violation) => ({
        id: violation.id,
        impact: violation.impact,
        affectedElements: violation.nodes.length,
        help: violation.help,
    }));

    expect(summary, JSON.stringify(summary, null, 2)).toEqual([]);
});

test('menu and primary action are keyboard reachable with visible focus', async ({
    page,
}) => {
    await page.goto('/');

    const menu = page.getByText('Menu', { exact: true });
    const startShopping = page.getByText('Start shopping', { exact: true });

    await expect(menu).toBeVisible();
    await expect(startShopping).toBeVisible();

    for (const element of [menu, startShopping]) {
        await element.focus();
        await expect(element).toBeFocused();

        const focusStyles = await element.evaluate((node) => {
            const styles = getComputedStyle(node);
            return {
                outlineStyle: styles.outlineStyle,
                outlineWidth: styles.outlineWidth,
                boxShadow: styles.boxShadow,
            };
        });

        const hasVisibleOutline =
            focusStyles.outlineStyle !== 'none' &&
            focusStyles.outlineWidth !== '0px';

        const hasVisibleBoxShadow = focusStyles.boxShadow !== 'none';

        expect(
            hasVisibleOutline || hasVisibleBoxShadow,
            `Expected a visible focus indicator, got ${JSON.stringify(focusStyles)}`,
        ).toBe(true);
    }
});
