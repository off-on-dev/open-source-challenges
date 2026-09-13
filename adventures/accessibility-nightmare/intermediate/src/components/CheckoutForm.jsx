import { useState } from 'react';

const FIELDS = [
    {
        name: 'name',
        label: 'Full name',
        type: 'text',
        error: 'Enter your full name',
    },
    {
        name: 'email',
        label: 'Email',
        type: 'email',
        error: 'Enter your email address',
    },
];

export default function CheckoutForm() {
    const [values, setValues] = useState({ name: '', email: '' });
    const [errors, setErrors] = useState({});
    const [placed, setPlaced] = useState(false);

    function handleChange(event) {
        const { name, value } = event.target;
        setValues((current) => ({ ...current, [name]: value }));
    }

    function handleSubmit(event) {
        event.preventDefault();

        const nextErrors = {};
        for (const field of FIELDS) {
            if (!values[field.name].trim()) {
                nextErrors[field.name] = field.error;
            }
        }

        setErrors(nextErrors);
        setPlaced(Object.keys(nextErrors).length === 0);
    }

    return (
        <form className="checkout-form" onSubmit={handleSubmit} noValidate>
            {FIELDS.map((field) => (
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
                    />
                    {errors[field.name] && (
                        <p className="field-error">{errors[field.name]}</p>
                    )}
                </div>
            ))}

            <button type="submit" className="place-order">
                Place order
            </button>

            {placed && (
                <p className="order-confirmation">Order placed. Thank you.</p>
            )}
        </form>
    );
}
