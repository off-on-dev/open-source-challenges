import { chromium, expect } from '@playwright/test';

export default async function globalSetup(config) {
    const { baseURL } = config.projects[0].use;
    const browser = await chromium.launch();
    const page = await (await browser.newContext()).newPage();

    try {
        await page.goto(`${baseURL}/#/payment`, { waitUntil: 'networkidle' });
        const heading = page.getByRole('heading', {
            name: 'Payment',
            level: 1,
        });

        await expect(
            heading,
            `Something other than this level is serving ${baseURL}. The payment ` +
                'page did not render. If you are running the beginner or intermediate level, ' +
                'stop it and start this one with `npm run dev`.',
        ).toBeVisible({ timeout: 15_000 });
    } finally {
        await browser.close();
    }
}
