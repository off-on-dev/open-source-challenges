import { useRef, useState } from 'react';
import BasketDialog from '../components/BasketDialog.jsx';
import SizePicker from '../components/SizePicker.jsx';

export default function Product({ product, onAddToBasket }) {
    const [size, setSize] = useState(product.sizes[1]);
    const [dialogOpen, setDialogOpen] = useState(false);
    const triggerRef = useRef(null);

    function addToBasket() {
        onAddToBasket({ product, size });
        setDialogOpen(true);
    }

    return (
        <main className="product-page">
            <img
                className="product-hero"
                src={product.image}
                alt={product.imageAlt}
            />

            <div className="product-detail">
                <h1>{product.name}</h1>
                <p className="product-copy">{product.description}</p>

                <SizePicker
                    sizes={product.sizes}
                    value={size}
                    onChange={setSize}
                />

                <button
                    ref={triggerRef}
                    type="button"
                    className="primary-action"
                    onClick={addToBasket}
                >
                    Add to basket
                </button>
            </div>

            {dialogOpen && (
                <BasketDialog
                    product={product}
                    size={size}
                    triggerRef={triggerRef}
                    onClose={() => setDialogOpen(false)}
                />
            )}
        </main>
    );
}
