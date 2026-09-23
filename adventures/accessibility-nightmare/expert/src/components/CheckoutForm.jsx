import { useEffect, useRef, useState } from 'react';

const FIELDS = [
    { name: 'name', label: 'Full name', type: 'text', error: 'Enter your full name' },
    { name: 'email', label: 'Email', type: 'email', error: 'Enter your email address' },
];

export default function CheckoutForm() {
    const [values, setValues] = useState({ name: '', email: '' });
    const [errors, setErrors] = useState({});
    const [placed, setPlaced] = useState(false);
    const liveRef = useRef(null);
    const firstErrorRef = useRef(null);

    function handleChange(e) {
        const { name, value } = e.target;
        setValues((prev) => ({ ...prev, [name]: value }));
    }

    function handleSubmit(e) {
        e.preventDefault();

        const nextErrors = {};
        for (const field of FIELDS) {
            if (!values[field.name].trim()) nextErrors[field.name] = field.error;
        }

        setErrors(nextErrors);
        setPlaced(Object.keys(nextErrors).length === 0);
        firstErrorRef.current = Object.keys(nextErrors)[0] ?? null;
    }

    useEffect(() => {
        if (firstErrorRef.current) {
            document.getElementById(`checkout-${firstErrorRef.current}`)?.focus();
        }
    }, [errors]);

    const firstErrorField = FIELDS.find((f) => errors[f.name]);
    const liveMessage = placed
        ? 'Order placed. Thank you.'
        : firstErrorField
          ? `${firstErrorField.label}: ${errors[firstErrorField.name]}`
          : '';

    return (
        <form className="checkout-form" onSubmit={handleSubmit} noValidate>
            <div
                ref={liveRef}
                role="status"
                aria-live="polite"
                aria-atomic="true"
                className="visually-hidden"
            >
                {liveMessage}
            </div>

            {FIELDS.map((field) => {
                const errorId = `checkout-${field.name}-error`;
                return (
                    <div className="form-field" key={field.name}>
                        <label htmlFor={`checkout-${field.name}`}>
                            {field.label}
                        </label>
                        <input
                            id={`checkout-${field.name}`}
                            name={field.name}
                            type={field.type}
                            value={values[field.name]}
                            onChange={handleChange}
                            aria-invalid={errors[field.name] ? 'true' : undefined}
                            aria-describedby={
                                errors[field.name] ? errorId : undefined
                            }
                        />
                        {errors[field.name] && (
                            <p className="field-error" id={errorId} role="alert">
                                {errors[field.name]}
                            </p>
                        )}
                    </div>
                );
            })}

            <button type="submit" className="place-order">
                Place order
            </button>

            {placed && (
                <p className="order-confirmation" aria-hidden="true">
                    Order placed. Thank you.
                </p>
            )}
        </form>
    );
}
