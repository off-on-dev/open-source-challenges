import { useEffect, useId, useRef, useState } from 'react';

export default function SizePicker({ sizes, value, onChange }) {
    const [open, setOpen] = useState(false);
    const triggerId = useId();
    const listId = useId();
    const activeId = useId();
    const triggerRef = useRef(null);

    const activeIndex = sizes.indexOf(value);

    function openList() {
        setOpen(true);
    }

    function closeList() {
        setOpen(false);
        triggerRef.current?.focus();
    }

    function handleKeyDown(e) {
        if (!open) {
            if (e.key === 'ArrowDown' || e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                openList();
            }
            return;
        }

        if (e.key === 'Escape') {
            e.preventDefault();
            closeList();
        } else if (e.key === 'ArrowDown') {
            e.preventDefault();
            const next = (activeIndex + 1) % sizes.length;
            onChange(sizes[next]);
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            const prev = (activeIndex - 1 + sizes.length) % sizes.length;
            onChange(sizes[prev]);
        } else if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault();
            closeList();
        } else if (e.key === 'Tab') {
            closeList();
        }
    }

    useEffect(() => {
        if (!open) return;
        function handleClickOutside(e) {
            if (!e.target.closest('.size-picker')) closeList();
        }
        document.addEventListener('mousedown', handleClickOutside);
        return () => document.removeEventListener('mousedown', handleClickOutside);
    }, [open]);

    return (
        <div className="size-picker">
            <span className="size-picker-label" id={triggerId}>
                Size
            </span>

            <div
                ref={triggerRef}
                className="size-picker-trigger"
                role="combobox"
                aria-labelledby={triggerId}
                aria-expanded={open}
                aria-haspopup="listbox"
                aria-activedescendant={open ? `${activeId}-${activeIndex}` : undefined}
                tabIndex={0}
                onClick={() => (open ? closeList() : openList())}
                onKeyDown={handleKeyDown}
            >
                {value}
            </div>

            {open && (
                <ul
                    className="size-picker-list"
                    role="listbox"
                    aria-labelledby={triggerId}
                    id={listId}
                >
                    {sizes.map((size, i) => (
                        <li
                            key={size}
                            id={`${activeId}-${i}`}
                            className="size-picker-option"
                            role="option"
                            aria-selected={size === value}
                            tabIndex={-1}
                            onMouseDown={(e) => {
                                e.preventDefault();
                                onChange(size);
                                closeList();
                            }}
                        >
                            {size}
                        </li>
                    ))}
                </ul>
            )}
        </div>
    );
}
