import { defineConfig } from 'vite';

// In a Codespace the browser reaches the dev server through a forwarded
// hostname, not localhost. Vite rejects unknown Host headers by default, so the
// forwarded domain has to be allowed or the page never loads at all. The
// websocket for hot reload needs the public port too, which only applies there.
const inCodespace = Boolean(process.env.CODESPACES);

export default defineConfig({
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
