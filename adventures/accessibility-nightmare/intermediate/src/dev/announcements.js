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
        'Nothing yet. Move around the page with the keyboard.';
    empty.style.cssText = 'color: #9a9aae; margin: 0.5rem 0;';
    list.append(empty);

    panel.append(heading, list);
    document.body.append(panel);
    // Reserve the strip's height so the page is never hidden behind it.
    document.body.style.paddingBottom = PANEL_HEIGHT;

    // Read only the application, never the panel itself.
    await virtual.start({ container: root });

    let shown = 0;

    // Deliberately never cleared: the panel lives for as long as the page does.
    setInterval(async () => {
        const log = await virtual.spokenPhraseLog();
        if (log.length === shown) return;

        empty.remove();
        for (const phrase of log.slice(shown)) {
            const line = document.createElement('p');
            line.textContent = phrase;
            const isLive = /^(polite|assertive):/.test(phrase);
            line.style.cssText = `
                margin: 0 0 0.35rem;
                padding-left: 0.6rem;
                border-left: 2px solid ${isLive ? '#57d977' : '#3a3a4c'};
                color: ${isLive ? '#8ff0a4' : '#e8e8ef'};
                word-break: break-word;
            `;
            list.append(line);
        }
        shown = log.length;
        list.scrollTop = list.scrollHeight;
    }, POLL_MS);
}
