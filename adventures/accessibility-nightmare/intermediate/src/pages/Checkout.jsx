import CheckoutForm from '../components/CheckoutForm.jsx';

export default function Checkout({ basket }) {
    return (
        <main className="checkout-page">
            <h1>Checkout</h1>

            {basket && (
                <p className="checkout-summary">
                    {basket.product.name}, size {basket.size}
                </p>
            )}

            <h2>Delivery details</h2>
            <CheckoutForm />
        </main>
    );
}
