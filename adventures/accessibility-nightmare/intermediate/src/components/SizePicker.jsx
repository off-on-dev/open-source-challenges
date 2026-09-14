import { useState } from 'react';

// This is the largest of the three repairs, so it is worth doing last.
//
// The pattern it needs is the select-only combobox, which has a worked example
// and a full keyboard contract here:
// https://www.w3.org/WAI/ARIA/apg/patterns/combobox/examples/combobox-select-only/
//
// A native <select> would be the right answer on real work and is deliberately
// not accepted here, because the point is understanding what it does for you.

export default function SizePicker({ sizes, value, onChange }) {
    const [open, setOpen] = useState(false);

    return (
        <div className="size-picker">
            <span className="size-picker-label">Size</span>

            <div
                className="size-picker-trigger"
                onClick={() => setOpen((wasOpen) => !wasOpen)}
            >
                {value}
            </div>

            {open && (
                <div className="size-picker-list">
                    {sizes.map((size) => (
                        <div
                            key={size}
                            className="size-picker-option"
                            onClick={() => {
                                onChange(size);
                                setOpen(false);
                            }}
                        >
                            {size}
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}
