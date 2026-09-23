import { PRODUCTS } from '../products.js';

export default function Home() {
    return (
        <main>
            <section className="hero">
                <div>
                    <p className="eyebrow">Summer sale</p>
                    <h1>Everything you need, delivered fast</h1>
                    <p className="hero-copy">
                        Discover popular products at prices that are hard to ignore.
                    </p>

                    <a className="primary-action" href="#/product/running-shoes">
                        Start shopping
                    </a>
                </div>

                <img
                    src="/images/store.svg"
                    alt="A ShopSmart storefront with shelves of boxed products."
                />
            </section>

            <section id="products" className="products-section">
                <h2>Featured products</h2>

                <div className="product-grid">
                    {PRODUCTS.map((product) => (
                        <article className="product-card" key={product.slug}>
                            <img src={product.image} alt="" />
                            <h3>{product.name}</h3>
                            <p>{product.description}</p>
                            <a
                                className="buy-button"
                                href={`#/product/${product.slug}`}
                            >
                                View {product.name}
                            </a>
                        </article>
                    ))}
                </div>
            </section>
        </main>
    );
}
