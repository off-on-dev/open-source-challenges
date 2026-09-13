import { useState } from 'react';

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
