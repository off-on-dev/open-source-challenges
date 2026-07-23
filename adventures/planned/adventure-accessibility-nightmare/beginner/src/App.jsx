export default function App() {
    return (
        <div className="page">
            <header className="site-header">
                <div className="logo">ShopSmart</div>

                <div className="menu" onClick={() => alert('Menu opened')}>
                    Menu
                </div>

                <nav className="nav-links">
                    <a href="#deals">Deals</a>
                    <a href="#products">Products</a>
                    <a href="#contact">Contact</a>
                </nav>
            </header>

            <main>
                <section className="hero">
                    <div>
                        <p className="eyebrow">Summer sale</p>
                        <h1>Everything you need, delivered fast</h1>
                        <p className="hero-copy">
                            Discover popular products at prices that are hard to ignore.
                        </p>

                        <div
                            className="primary-action"
                            onClick={() => alert('Shopping started')}
                        >
                            Start shopping
                        </div>
                    </div>

                    <img src="/images/store.svg" />
                </section>

                <section id="products" className="products-section">
                    <h2>Featured products</h2>

                    <div className="product-grid">
                        <article className="product-card">
                            <img src="/images/watch.svg" />
                            <h3>Smart watch</h3>
                            <p>Track your day with a clean, lightweight design.</p>
                            <button className="buy-button">Buy now</button>
                        </article>

                        <article className="product-card">
                            <img src="/images/headphones.svg" />
                            <h3>Wireless headphones</h3>
                            <p>Comfortable sound for work, travel, and exercise.</p>
                            <button className="buy-button">Buy now</button>
                        </article>

                        <article className="product-card">
                            <img src="/images/shoes.svg" />
                            <h3>Running shoes</h3>
                            <p>Flexible everyday shoes made for active routines.</p>
                            <button className="buy-button">Buy now</button>
                        </article>
                    </div>
                </section>
            </main>

            <footer id="contact">
                <p>© 2026 ShopSmart</p>
            </footer>
        </div>
    );
}