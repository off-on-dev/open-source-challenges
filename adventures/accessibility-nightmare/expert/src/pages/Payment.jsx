export default function Payment({ basket }) {
    return (
        <main className="payment-page">
            <h1>Payment</h1>

            {basket && (
                <p className="checkout-summary">
                    {basket.product.name}, size {basket.size}
                </p>
            )}

            <form className="payment-form" onSubmit={(e) => e.preventDefault()}>
                <h2>Card details</h2>

                <div className="form-field">
                    <label htmlFor="cc-number">Card number</label>
                    <input
                        id="cc-number"
                        type="text"
                        autoComplete="cc-number"
                        placeholder="1234 5678 9012 3456"
                    />
                </div>

                <div className="form-field">
                    <label htmlFor="cc-expiry">Expiry</label>
                    <input
                        id="cc-expiry"
                        type="text"
                        autoComplete="cc-exp"
                        placeholder="MM / YY"
                    />
                </div>

                <div className="form-field">
                    <label htmlFor="cc-cvc">CVC</label>
                    <input
                        id="cc-cvc"
                        type="text"
                        autoComplete="cc-csc"
                        placeholder="123"
                    />
                </div>

                <button type="submit">Pay now</button>
            </form>
        </main>
    );
}
