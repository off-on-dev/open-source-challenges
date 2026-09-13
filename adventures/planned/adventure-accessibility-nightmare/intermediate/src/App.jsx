import { useEffect, useState } from 'react';
import Home from './pages/Home.jsx';
import Product from './pages/Product.jsx';
import Checkout from './pages/Checkout.jsx';
import { findProduct } from './products.js';

const PRODUCT_ROUTE = /^\/product\/([\w-]+)$/;

function readRoute() {
    return window.location.hash.replace(/^#/, '') || '/';
}

export default function App() {
    const [route, setRoute] = useState('/');
    const [basket, setBasket] = useState(null);

    useEffect(() => {
        const onHashChange = () => setRoute(readRoute());
        onHashChange();
        window.addEventListener('hashchange', onHashChange);
        return () => window.removeEventListener('hashchange', onHashChange);
    }, []);

    const productSlug = route.match(PRODUCT_ROUTE)?.[1];
    const product = productSlug ? findProduct(productSlug) : undefined;

    let page = <Home />;
    if (route === '/checkout') {
        page = <Checkout basket={basket} />;
    } else if (product) {
        page = <Product product={product} onAddToBasket={setBasket} />;
    }

    return (
        <div className="page">
            <header className="site-header">
                <a className="logo" href="#/">
                    ShopSmart
                </a>

                <button
                    type="button"
                    className="menu"
                    onClick={() => alert('Menu opened')}
                >
                    Menu
                </button>

                <nav className="nav-links" aria-label="Main">
                    <a href="#/">Home</a>
                    <a href="#/product/running-shoes">Running shoes</a>
                </nav>
            </header>

            {page}

            <footer>
                <p>© 2026 ShopSmart</p>
            </footer>
        </div>
    );
}
