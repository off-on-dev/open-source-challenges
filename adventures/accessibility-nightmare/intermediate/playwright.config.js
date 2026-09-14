import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
    testDir: './tests',
    // Refuses to grade anything until port 5173 is confirmed to be this level.
    globalSetup: './tests/global-setup.js',
    timeout: 30_000,
    use: {
        baseURL: 'http://127.0.0.1:5173',
        trace: 'on-first-retry',
    },
    webServer: {
        command: 'npm run dev',
        url: 'http://127.0.0.1:5173',
        reuseExistingServer: true,
        timeout: 120_000,
    },
    projects: [
        {
            name: 'chromium',
            use: {
                ...devices['Desktop Chrome'],
            },
        },
    ],
});
