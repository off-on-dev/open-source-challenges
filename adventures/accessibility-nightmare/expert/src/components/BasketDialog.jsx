import { useEffect, useRef } from 'react';

export default function BasketDialog({ product, size, triggerRef, onClose }) {
    const dialogRef = useRef(null);

    useEffect(() => {
        const first = dialogRef.current?.querySelector(
            'a[href], button, [tabindex="0"]',
        );
        first?.focus();
    }, []);

    useEffect(() => {
        function handleKeyDown(e) {
            if (e.key === 'Escape') {
                onClose();
                return;
            }
            if (e.key !== 'Tab') return;

            const dialog = dialogRef.current;
            const focusable = Array.from(
                dialog.querySelectorAll('a[href], button'),
            ).filter((el) => !el.disabled);
            const first = focusable[0];
            const last = focusable[focusable.length - 1];

            if (e.shiftKey && document.activeElement === first) {
                e.preventDefault();
                last.focus();
            } else if (!e.shiftKey && document.activeElement === last) {
                e.preventDefault();
                first.focus();
            }
        }

        document.addEventListener('keydown', handleKeyDown);
        return () => {
            document.removeEventListener('keydown', handleKeyDown);
            triggerRef?.current?.focus();
        };
    }, [onClose, triggerRef]);

    return (
        <div className="dialog-overlay">
            <div
                className="dialog"
                role="dialog"
                aria-labelledby="dialog-title"
                aria-modal="true"
                ref={dialogRef}
            >
                <h2 className="dialog-title" id="dialog-title">
                    Added to basket
                </h2>

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
