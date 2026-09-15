import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App.jsx';
import './styles.css';

ReactDOM.createRoot(document.getElementById('root')).render(
    <React.StrictMode>
        <App />
    </React.StrictMode>,
);

// Add ?listen to the URL to see what a screen reader would announce as you move
// around. Development only: this whole branch is dropped from a production build.
//
// Accepted before the hash (/?listen#/checkout) and after it
// (/#/checkout?listen), because routes here live in the hash and appending to
// the end of the address is the obvious thing to do.
function wantsListenPanel() {
    const { search, hash } = window.location;
    return (
        new URLSearchParams(search).has('listen') ||
        /[?&]listen(=|&|$)/.test(hash)
    );
}

if (import.meta.env.DEV && wantsListenPanel()) {
    import('./dev/announcements.js').then((tool) => tool.start());
}
