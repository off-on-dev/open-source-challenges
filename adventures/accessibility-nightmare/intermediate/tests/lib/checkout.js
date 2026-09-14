import { expect } from '@playwright/test';

export const PRODUCT_URL = '/#/product/running-shoes';
export const CHECKOUT_URL = '/#/checkout';
export const SIZES = ['41', '42', '43'];
export const STARTING_SIZE = '42';

export function sizePicker(page) {
    return page.getByRole('combobox', { name: /size/i });
}

export function addToBasket(page) {
    return page.getByRole('button', { name: 'Add to basket' });
}

export function basketDialog(page) {
    return page.getByRole('dialog');
}

export function checkoutLink(page) {
    return page.getByRole('link', { name: 'Checkout' });
}

export function continueShopping(page) {
    return page.getByRole('button', { name: 'Continue shopping' });
}

export function placeOrder(page) {
    return page.getByRole('button', { name: 'Place order' });
}

export const NO_DIALOG =
    'The basket confirmation covers the page, but nothing tells assistive technology that a dialog opened.';

const NATIVE_SELECT =
    'The size picker is a native <select>. On real work that is the right answer, ' +
    'and it is accessible as it stands. It is out of scope here because the point ' +
    'of the exercise is understanding what a native control does for you, so build ' +
    'the select-only combobox instead: ' +
    'https://www.w3.org/WAI/ARIA/apg/patterns/combobox/examples/combobox-select-only/';

const NO_PICKER =
    'No control on the product page presents itself as a size picker. It needs a ' +
    'role, an accessible name and its current value.';

// Fails with an explanation when the picker is a native <select>, which passes
// every accessibility check but is deliberately not what this level asks for.
export async function assertPickerShape(page) {
    const nativeSelect = await page
        .locator('.size-picker select, select')
        .count();
    expect(nativeSelect, NATIVE_SELECT).toBe(0);
}

// Presses Tab until the target has focus. Fails with the tab order it walked
// through, which is the useful part when a control cannot be reached at all.
export async function tabTo(page, target, limit = 15) {
    const walked = [];

    for (let step = 0; step < limit; step++) {
        await page.keyboard.press('Tab');
        walked.push(await describeFocus(page));
        if (await isFocused(page, target)) return walked;
    }

    throw new Error(
        `Tab never reached the expected control. Focus went:\n  ${walked.join('\n  ')}`,
    );
}

async function isFocused(page, target) {
    // count() resolves immediately. Going straight to evaluate() would wait for
    // a control that is not there yet, and the walk would stall rather than
    // report where the keyboard actually went.
    if ((await target.count()) === 0) return false;
    return target
        .evaluate((node) => node === document.activeElement)
        .catch(() => false);
}

export async function describeFocus(page) {
    return page.evaluate(() => {
        const node = document.activeElement;
        if (!node || node === document.body) return '(nothing)';
        const role = node.getAttribute('role') ?? node.tagName.toLowerCase();
        const text = (node.textContent ?? '').trim().slice(0, 30);
        return `${role} "${text || node.id || node.className}"`;
    });
}

export async function focusIsInsideDialog(page) {
    return page.evaluate(
        () => !!document.activeElement?.closest('[role="dialog"]'),
    );
}

// The option the keyboard is currently on, whichever technique the picker
// uses: real DOM focus on the option, or aria-activedescendant on the
// combobox. Returns null when the keyboard is not on an option at all.
export async function activeOptionName(page) {
    return page.evaluate(() => {
        const active = document.activeElement;
        if (!active) return null;
        const pointer = active.getAttribute('aria-activedescendant');
        const node = pointer ? document.getElementById(pointer) : active;
        if (!node || node.getAttribute('role') !== 'option') return null;
        return (node.textContent ?? '').trim();
    });
}

// Opens the picker, moves one option with the arrow keys and commits, all from
// the keyboard. Returns the size that was committed.
export async function chooseAnotherSize(page) {
    const picker = sizePicker(page);
    await assertPickerShape(page);
    expect(await picker.count(), NO_PICKER).toBeGreaterThan(0);
    await tabTo(page, picker);

    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('listbox')).toBeVisible();
    await expect(page.getByRole('option')).toHaveCount(SIZES.length);

    const before = await activeOptionName(page);
    expect(
        before,
        'Opening the list should put the keyboard on one of the options.',
    ).not.toBeNull();

    await page.keyboard.press('ArrowDown');
    const after = await activeOptionName(page);
    expect(
        after,
        'An arrow key should move the keyboard to a different option.',
    ).not.toBe(before);

    await page.keyboard.press('Enter');
    await expect(page.getByRole('listbox')).toHaveCount(0);
    await expect(picker).toBeFocused();
    await expect(picker).toHaveText(after);

    return after;
}

// Adds the item with the mouse, for the tests that are about what the dialog
// announces rather than about how it handles focus. Waits on the confirmation
// text rather than the dialog role, so it works before the dialog is repaired.
export async function addWithMouse(page) {
    await addToBasket(page).click();
    await expect(page.getByText('Added to basket')).toBeVisible();
}
