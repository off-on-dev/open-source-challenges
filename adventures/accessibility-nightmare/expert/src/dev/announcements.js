// Development tool. Renders a live log of what a screen reader would announce,
// below the storefront. Switched on by adding ?listen to the URL, and stripped
// from production builds entirely.
//
// It is a simulation built from the accessibility tree, not NVDA, JAWS or
// VoiceOver, and it will not reproduce the differences between them. Silence
// here means silence there. Sound here is necessary but not sufficient.
//
// The panel is appended to <body>, outside the React root, so React never sees
// it. It is aria-hidden and inert so the reader cannot read it and the keyboard
// cannot reach it: a tool that changed the tab order would be measuring itself.

const POLL_MS = 200;

// A strip across the bottom, not a rail down the side. A side rail either
// covered the page or squeezed it: at a narrow width the storefront lost its
// header and nav entirely. Taking height instead leaves the layout at its full
// width at every viewport, and the matching padding on <body> means the panel
// never sits on top of the page either.
const PANEL_HEIGHT = 'min(15rem, 33vh)';

const PANEL_STYLE = `
    position: fixed;
    left: 0;
    right: 0;
    bottom: 0;
    height: ${PANEL_HEIGHT};
    z-index: 9999;
    display: flex;
    flex-direction: column;
    border-top: 1px solid #2c2c3a;
    background: #14141c;
    color: #e8e8ef;
    font: 12px/1.5 ui-monospace, SFMono-Regular, Menlo, monospace;
`;

export async function start() {
    const root = document.getElementById('root');
    if (!root) return;

    const { virtual } = await import(
        '@guidepup/virtual-screen-reader/browser.js'
    );

    const panel = document.createElement('aside');
    panel.setAttribute('aria-hidden', 'true');
    panel.inert = true;
    panel.style.cssText = PANEL_STYLE;

    // One compact bar, so the strip spends its height on the log itself.
    const heading = document.createElement('div');
    heading.style.cssText = `
        display: flex;
        gap: 0.6rem;
        align-items: baseline;
        flex-wrap: wrap;
        padding: 0.5rem 0.9rem;
        border-bottom: 1px solid #2c2c3a;
    `;

    const title = document.createElement('strong');
    title.textContent = 'What a screen reader would say';

    const note = document.createElement('span');
    note.textContent = 'a simulation, not real assistive technology';
    note.style.cssText = 'color: #9a9aae;';

    heading.append(title, note);

    const list = document.createElement('div');
    list.style.cssText = `
        flex: 1;
        overflow-y: auto;
        padding: 0.5rem 0.9rem 0.75rem;
    `;

    const empty = document.createElement('p');
    empty.textContent =
        'Nothing yet. Move around with the keyboard, or follow a link to another page.';
    empty.style.cssText = 'color: #9a9aae; margin: 0.5rem 0;';
    list.append(empty);

    panel.append(heading, list);
    document.body.append(panel);
    // Reserve the strip's height so the page is never hidden behind it.
    document.body.style.paddingBottom = PANEL_HEIGHT;

    // Read only the application, never the panel itself.
    await virtual.start({ container: root });

    let shown = 0;
    let markerPending = null;

    function append(text, style) {
        empty.remove();
        const line = document.createElement('p');
        line.textContent = text;
        line.style.cssText = style;
        list.append(line);
        list.scrollTop = list.scrollHeight;
    }

    // Reading the log is asynchronous, so two overlapping calls would both slice
    // from the same `shown` index and print the same phrases twice.
    let draining = false;

    async function drain() {
        if (draining) return;
        draining = true;
        try {
            await flush();
        } finally {
            draining = false;
        }
    }

    async function flush() {
        const log = await virtual.spokenPhraseLog();
        if (log.length === shown) {
            drainMarker();
            return;
        }

        for (const phrase of log.slice(shown)) {
            const isLive = /^(polite|assertive):/.test(phrase);
            append(
                phrase,
                `
                margin: 0 0 0.35rem;
                padding-left: 0.6rem;
                border-left: 2px solid ${isLive ? '#57d977' : '#3a3a4c'};
                color: ${isLive ? '#8ff0a4' : '#e8e8ef'};
                word-break: break-word;
            `,
            );
        }
        shown = log.length;
        drainMarker();
    }

    // Appended only once the phrases spoken before the navigation have been
    // printed, so the boundary lands in the right place.
    function drainMarker() {
        if (!markerPending) return;
        append(
            `· ${markerPending}`,
            `
            margin: 0.5rem 0 0.35rem;
            color: #6f6f85;
            word-break: break-word;
        `,
        );
        markerPending = null;
    }

    // Marks where the address changed, so what the reader said before a
    // navigation can be told apart from what it said after one.
    //
    // React commits its re-render after this handler returns, so a drain kicked
    // off here reads a log that still ends at the previous page. The marker is
    // printed at the end of that drain, below the phrases it belongs below and
    // above anything the new page goes on to say.
    window.addEventListener('hashchange', () => {
        markerPending = window.location.hash || '#/';
        drain();
    });

    // Deliberately never cleared: the panel lives for as long as the page does.
    setInterval(drain, POLL_MS);
}
