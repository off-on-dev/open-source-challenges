// Lighthouse needs a Chrome binary. Playwright already downloaded one during
// container setup, so point Lighthouse at that instead of expecting a
// system-wide Chrome install.
const { chromium } = require('playwright');

process.env.CHROME_PATH = process.env.CHROME_PATH || chromium.executablePath();

module.exports = {
    ci: {
        collect: {
            startServerCommand: 'npm run dev -- --host 127.0.0.1',
            startServerReadyPattern: 'Local:',
            url: ['http://127.0.0.1:5173/'],
            numberOfRuns: 1,
            settings: {
                chromeFlags: '--no-sandbox --disable-dev-shm-usage --disable-gpu',
            },
        },
        assert: {
            assertions: {
                'categories:accessibility': ['error', { minScore: 0.95 }],
            },
        },
        upload: {
            target: 'filesystem',
            outputDir: './.lighthouseci',
        },
    },
};