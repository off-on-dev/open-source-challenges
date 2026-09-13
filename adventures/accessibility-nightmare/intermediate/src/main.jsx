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
if (
    import.meta.env.DEV &&
    new URLSearchParams(window.location.search).has('listen')
) {
    import('./dev/announcements.js').then((tool) => tool.start());
}
