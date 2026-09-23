import { expect } from '@playwright/test';

export const PRODUCT_URL = '/#/product/running-shoes';
export const CHECKOUT_URL = '/#/checkout';
export const PAYMENT_URL = '/#/payment';

// Presses Tab until the target has focus. Throws with the tab order it walked
// when the target cannot be reached.
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
