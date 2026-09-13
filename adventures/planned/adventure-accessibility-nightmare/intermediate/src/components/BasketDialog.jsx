export default function BasketDialog({ product, size, onClose }) {
    return (
        <div className="dialog-overlay">
            <div className="dialog">
                <h2 className="dialog-title">Added to basket</h2>

                <p className="dialog-summary">
                    {product.name}, size {size}
                </p>

                <a className="dialog-checkout" href="#/checkout">
                    Checkout
                </a>

                <button type="button" className="dialog-close" onClick={onClose}>
                    Continue shopping
                </button>
            </div>
        </div>
    );
}
