import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The compliance report is written to the project root by the test run, which is
// outside the served directory. The coverage reference page reads it from there
// to show the state of the last run, so serve it read-only in development.
function serveComplianceReport() {
    return {
        name: 'serve-compliance-report',
        apply: 'serve',
        configureServer(server) {
            const root = server.config.root;
            server.middlewares.use('/compliance-report.json', async (_req, res) => {
                res.setHeader('Content-Type', 'application/json');
                res.setHeader('Cache-Control', 'no-store');
                try {
                    res.end(await readFile(join(root, 'compliance-report.json'), 'utf8'));
                } catch {
                    res.statusCode = 404;
                    res.end('{"error":"no report"}');
                }
            });
        },
    };
}

// In a Codespace the browser reaches the dev server through a forwarded
// hostname, not localhost. Vite rejects unknown Host headers by default, so the
// forwarded domain has to be allowed or the page never loads at all. The
// websocket for hot reload needs the public port too, which only applies there.
const inCodespace = Boolean(process.env.CODESPACES);

export default defineConfig({
    plugins: [react(), serveComplianceReport()],
    server: {
        host: true,
        allowedHosts: ['.app.github.dev'],
        ...(inCodespace
            ? { hmr: { clientPort: 443, protocol: 'wss' } }
            : {}),
    },
    preview: {
        host: true,
        allowedHosts: ['.app.github.dev'],
    },
});
