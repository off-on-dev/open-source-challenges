import { expect, test } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import {
    CHECKOUT_URL,
    NO_DIALOG,
    PRODUCT_URL,
    STARTING_SIZE,
    activeOptionName,
    addToBasket,
    addWithMouse,
    basketDialog,
    checkoutLink,
    chooseAnotherSize,
    continueShopping,
    describeFocus,
    focusIsInsideDialog,
    placeOrder,
    sizePicker,
    tabTo,
} from './lib/checkout.js';
import {
    attachScreenReader,
    clearSpokenPhrases,
    liveAnnouncements,
    settle,
    spokenPhrases,
    startScreenReader,
} from './lib/screen-reader.js';

async function seriousViolations(page) {
    const results = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag22aa'])
        .analyze();

    return results.violations
        .filter((violation) =>
            ['serious', 'critical'].includes(violation.impact),
        )
        .map((violation) => ({
            id: violation.id,
            impact: violation.impact,
            affectedElements: violation.nodes.length,
            help: violation.help,
        }));
}

async function expectClean(page, state) {
    const found = await seriousViolations(page);
    expect(
        found,
        `axe reported violations in the "${state}" state:\n${JSON.stringify(found, null, 2)}`,
    ).toEqual([]);
}

// -----------------------------------------------------------------------------
// The premise. This is green before a single line is changed, and it has to
// stay green: the repairs below are invisible to the scanner in both directions.
// -----------------------------------------------------------------------------

test('@scan the automated scan reports no violations', async ({ page }) => {
    await page.goto('/');
    await expectClean(page, 'homepage');

    await page.goto(PRODUCT_URL);
    await expectClean(page, 'product page');

    await addWithMouse(page);
    await expectClean(page, 'basket confirmation open');

    await page.goto(CHECKOUT_URL);
    await expectClean(page, 'checkout page');

    await placeOrder(page).click();
    await expectClean(page, 'submission rejected');

    await page.getByLabel('Full name').fill('Ada Lovelace');
    await page.getByLabel('Email').fill('ada@example.com');
    await placeOrder(page).click();
    await expectClean(page, 'order placed');
});

// -----------------------------------------------------------------------------
// The size picker
// -----------------------------------------------------------------------------

test('@picker the size picker is reachable and operable from the keyboard', async ({
    page,
}) => {
    await page.goto(PRODUCT_URL);

    const chosen = await chooseAnotherSize(page);
    expect(chosen).not.toBe(STARTING_SIZE);
});

test('@picker the size picker announces its name, its state and its value', async ({
    page,
}) => {
    await attachScreenReader(page);
    await page.goto(PRODUCT_URL);
    await startScreenReader(page);

    await clearSpokenPhrases(page);
    await tabTo(page, sizePicker(page));
    await settle(page);

    const [heard] = (await spokenPhrases(page)).slice(-1);
    expect(heard, 'Nothing was announced when the picker took focus.').toBeTruthy();
    expect(
        heard,
        `A screen reader should hear what the control is called. Heard: ${heard}`,
    ).toMatch(/size/i);
    expect(
        heard,
        `A screen reader should hear whether the list of sizes is open. Heard: ${heard}`,
    ).toMatch(/not expanded|collapsed/i);

    await clearSpokenPhrases(page);
    await page.keyboard.press('ArrowDown');
    await settle(page);

    expect(
        await activeOptionName(page),
        'Opening the list should put the keyboard on one of the options.',
    ).not.toBeNull();
    expect(
        (await spokenPhrases(page)).join(' | '),
        'A screen reader should hear the sizes it landed among, not loose text.',
    ).toMatch(/option/i);

    // The picker's current value is the option it reports as selected. The
    // virtual screen reader does not read a value off a combobox that has no
    // input, so this is asserted where ARIA actually carries it.
    await expect(
        page.getByRole('option', { selected: true }),
        'The size that is currently chosen should be marked as the selected option.',
    ).toHaveText(STARTING_SIZE);
});

test('@picker the open list of sizes still scans clean', async ({ page }) => {
    await page.goto(PRODUCT_URL);

    await tabTo(page, sizePicker(page));
    await page.keyboard.press('ArrowDown');
    await expect(page.getByRole('listbox')).toBeVisible();

    await expectClean(page, 'size list open');
});

// -----------------------------------------------------------------------------
// The basket confirmation dialog
// -----------------------------------------------------------------------------

test('@dialog adding to the basket moves the keyboard into the confirmation', async ({
    page,
}) => {
    await page.goto(PRODUCT_URL);

    await tabTo(page, addToBasket(page));
    await page.keyboard.press('Enter');

    await expect(basketDialog(page), NO_DIALOG).toBeVisible();
    expect(
        await focusIsInsideDialog(page),
        `The keyboard stayed behind the dialog, on ${await describeFocus(page)}.`,
    ).toBe(true);
});

test('@dialog the keyboard cannot wander out of the open dialog', async ({
    page,
}) => {
    await page.goto(PRODUCT_URL);

    await tabTo(page, addToBasket(page));
    await page.keyboard.press('Enter');
    await expect(basketDialog(page), NO_DIALOG).toBeVisible();

    const escaped = [];
    for (let step = 0; step < 12; step++) {
        await page.keyboard.press('Tab');
        if (!(await focusIsInsideDialog(page))) {
            escaped.push(`Tab ${step + 1}: ${await describeFocus(page)}`);
        }
    }
    for (let step = 0; step < 6; step++) {
        await page.keyboard.press('Shift+Tab');
        if (!(await focusIsInsideDialog(page))) {
            escaped.push(`Shift+Tab ${step + 1}: ${await describeFocus(page)}`);
        }
    }

    expect(
        escaped,
        `The keyboard left the dialog and landed on the page behind it:\n  ${escaped.join('\n  ')}`,
    ).toEqual([]);
});

test('@dialog Escape closes the dialog and gives the keyboard back', async ({
    page,
}) => {
    await page.goto(PRODUCT_URL);

    const trigger = addToBasket(page);
    await tabTo(page, trigger);
    await page.keyboard.press('Enter');
    await expect(basketDialog(page), NO_DIALOG).toBeVisible();

    await page.keyboard.press('Escape');

    await expect(basketDialog(page)).toHaveCount(0);
    await expect(trigger).toBeFocused();
});

test('@dialog dismissing the dialog returns the keyboard to what opened it', async ({
    page,
}) => {
    await page.goto(PRODUCT_URL);

    const trigger = addToBasket(page);
    await tabTo(page, trigger);
    await page.keyboard.press('Enter');
    await expect(basketDialog(page), NO_DIALOG).toBeVisible();

    await continueShopping(page).click();

    await expect(basketDialog(page)).toHaveCount(0);
    await expect(trigger).toBeFocused();
});

test('@dialog the confirmation is announced as a dialog with a name', async ({
    page,
}) => {
    await attachScreenReader(page);
    await page.goto(PRODUCT_URL);
    await startScreenReader(page);

    await tabTo(page, addToBasket(page));
    await clearSpokenPhrases(page);
    await page.keyboard.press('Enter');
    await settle(page);

    const heard = (await spokenPhrases(page)).join(' | ');
    expect(
        heard,
        `A screen reader user should be told a dialog opened. Heard: ${heard}`,
    ).toMatch(/dialog/i);
    expect(
        heard,
        `The dialog should say what it is for. Heard: ${heard}`,
    ).toMatch(/added to basket/i);
});

// -----------------------------------------------------------------------------
// The checkout form
// -----------------------------------------------------------------------------

test('@form a rejected submission is announced and the field is marked', async ({
    page,
}) => {
    await attachScreenReader(page);
    await page.goto(CHECKOUT_URL);
    await startScreenReader(page);

    await clearSpokenPhrases(page);
    await placeOrder(page).click();
    await settle(page);

    const announced = await liveAnnouncements(page);
    expect(
        announced,
        'Nothing was announced. The error is on screen and silent.',
    ).not.toEqual([]);
    expect(
        announced.join(' | '),
        `The announcement should say what went wrong. Heard: ${announced.join(' | ')}`,
    ).toMatch(/full name/i);

    const nameField = page.getByLabel('Full name');
    await expect(
        nameField,
        'The field that was rejected should say so.',
    ).toHaveAttribute('aria-invalid', 'true');

    await expect(
        nameField,
        'The keyboard should be taken to the first field that needs attention.',
    ).toBeFocused();

    await clearSpokenPhrases(page);
    await page.keyboard.press('Shift+Tab');
    await page.keyboard.press('Tab');
    await settle(page);

    const heard = (await spokenPhrases(page)).join(' | ');
    expect(
        heard,
        `Landing on the rejected field should carry its error with it. Heard: ${heard}`,
    ).toMatch(/full name/i);
    expect(heard, `Heard: ${heard}`).toMatch(/invalid/i);
});

test('@form a completed order is announced', async ({ page }) => {
    await attachScreenReader(page);
    await page.goto(CHECKOUT_URL);
    await startScreenReader(page);

    await page.getByLabel('Full name').fill('Ada Lovelace');
    await page.getByLabel('Email').fill('ada@example.com');

    await clearSpokenPhrases(page);
    await placeOrder(page).click();
    await settle(page);

    const announced = await liveAnnouncements(page);
    expect(
        announced.join(' | '),
        `A screen reader user should be told the order went through. Heard: ${announced.join(' | ')}`,
    ).toMatch(/order placed/i);
});

// -----------------------------------------------------------------------------
// The whole thing, end to end, without touching a mouse
// -----------------------------------------------------------------------------

test('@journey the checkout can be completed with the keyboard alone', async ({
    page,
}) => {
    await attachScreenReader(page);
    await page.goto(PRODUCT_URL);
    await startScreenReader(page);

    const chosen = await chooseAnotherSize(page);

    await tabTo(page, addToBasket(page));
    await page.keyboard.press('Enter');
    await expect(basketDialog(page), NO_DIALOG).toBeVisible();
    expect(await focusIsInsideDialog(page)).toBe(true);

    await expect(
        basketDialog(page),
        'The confirmation should say which size was added.',
    ).toContainText(chosen);

    await tabTo(page, checkoutLink(page), 5);
    await page.keyboard.press('Enter');

    await expect(
        page.getByRole('heading', { name: 'Checkout', level: 1 }),
    ).toBeVisible();
    await expect(
        page.getByText(chosen, { exact: false }).first(),
        'The size chosen on the product page should carry through to checkout.',
    ).toBeVisible();

    await tabTo(page, page.getByLabel('Full name'), 8);
    await page.keyboard.type('Ada Lovelace');
    await page.keyboard.press('Tab');
    await page.keyboard.type('ada@example.com');

    await clearSpokenPhrases(page);
    await tabTo(page, placeOrder(page), 4);
    await page.keyboard.press('Enter');
    await settle(page);

    expect(
        (await liveAnnouncements(page)).join(' | '),
        'The order was placed with the keyboard, but nothing said so.',
    ).toMatch(/order placed/i);
});
