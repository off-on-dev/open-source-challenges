import { chromium, expect } from '@playwright/test';

// Both levels of this adventure serve on port 5173, and the Playwright config
// reuses whatever is already listening. Without this, a stale server from the
// other level is graded instead, and every failure is a lie.
export default async function globalSetup(config) {
    const { baseURL } = config.projects[0].use;
    const browser = await chromium.launch();
    const page = await (await browser.newContext()).newPage();

    try {
        await page.goto(`${baseURL}/#/product/running-shoes`, {
            waitUntil: 'networkidle',
        });
        const heading = page.getByRole('heading', {
            name: 'Running shoes',
            level: 1,
        });

        await expect(
            heading,
            `Something other than this level is serving ${baseURL}. The product ` +
                'page did not render. If you are running the beginner level, or ' +
                'another dev server, stop it and start this one with `npm run dev`.',
        ).toBeVisible({ timeout: 15_000 });
    } finally {
        await browser.close();
    }
}
