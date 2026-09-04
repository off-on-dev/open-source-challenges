# Adventure Idea: ♿ The Accessibility Nightmare

## Overview

**Theme:** ShopSmart is an online retailer moving into the European market, and support has traced a run of abandoned orders back to the storefront itself. Customers who navigate by keyboard cannot reach the main menu or start an order, and customers using a screen reader are never told what the product images show or why the checkout form rejects them. There is no second route to a purchase. Complaints reached the company, then a legal notice citing the ADA and the European Accessibility Act, and the EU launch is on hold until the storefront can be shown to work. As the lead frontend engineer, your mission is to audit the storefront, fix what blocks these customers, and add checks that stop the same faults shipping again.

**Skills:**

- Audit and remediate critical WCAG 2.2 violations using automated and manual testing tools
- Repair focus management, ARIA patterns, and error announcement in shared interface components
- Implement automated accessibility gates that cover what static scanning misses

**Technologies:** React, Playwright, axe-core, Lighthouse, Guidepup Virtual Screen Reader, eslint-plugin-jsx-a11y

---

## Levels

### 🟢 Beginner: The Initial Audit

#### Description

Audit the ShopSmart homepage and fix critical WCAG 2.2 violations to pass the initial legal compliance check.

#### Story

The legal notice just landed. The CEO is panicking over the ADA and EAA violations. Your first task is to look at the public-facing homepage, run the automated audits, and fix the glaring issues that are triggering the lawsuit before the regulators escalate.

#### The Problem

The homepage is riddled with basic accessibility failures. It currently scores a 45 on Lighthouse. Interactive elements can't be reached via keyboard, images lack alt text, color contrast fails WCAG standards, and focus states are completely hidden, making it impossible for motor-impaired users to navigate.

#### Objective

- Run Lighthouse and axe-core to identify and interpret the accessibility violations
- Fix color contrast and missing alt text on all homepage assets
- Ensure all interactive elements are keyboard accessible and have visible Focus Appearance (WCAG 2.4.11)
- Achieve a Lighthouse accessibility score of 95+ with zero critical axe-core violations

#### What You'll Learn

- How to interpret automated accessibility reports (Lighthouse, axe-core)
- The fundamentals of WCAG 2.2 perceivable and operable criteria
- How to test and fix basic keyboard navigation and focus states with Playwright

#### Tools & Infrastructure

- **Tools:** Lighthouse, axe-core, Playwright, Browser DevTools
- **Infrastructure:** ShopSmart E-commerce Frontend (React/Vite)

---

### 🟡 Intermediate: The Checkout Trap

#### Description

Repair the shared checkout components so keyboard and screen reader users can complete a purchase, on a page where the automated scanner already reports no violations.

#### Story

The homepage is fixed and every automated scan comes back green, so the team declared the problem solved. The complaints kept arriving, and support has traced all of them to the checkout. One customer opens the quick add panel and the keyboard never follows it there. Their next Tab lands somewhere behind the panel, on the page it is covering, and they carry on through controls they can no longer see. Another fills in the delivery details, submits, and is told nothing at all: the error sits on screen in red, and their screen reader never mentions it. The design team keeps shipping these same patterns, and nobody can see the problem, because the scanner insists there isn't one. Fix the checkout before the next batch of complaints reaches legal.

#### The Problem

The three checkout components are built out of plain containers dressed up with styling instead of real controls, so automated scanning reports nothing, yet none of them can be used without a mouse. The quick add panel loses track of where the keyboard is as it opens and closes. The size picker cannot be reached or operated from the keyboard, and gives a screen reader nothing to announce. The checkout form rejects a submission in a way a screen reader user never hears.

#### Objective

- Complete the checkout end to end using only the keyboard
- Have every step of that journey announced to a screen reader, including why a submission was rejected
- Keep the axe-core scan reporting no violations throughout

#### What You'll Learn

- How to move, hold and restore focus across a modal boundary, and why hiding the background is not the same as putting it out of reach
- How a validation failure actually reaches a screen reader user, through live regions and the attributes that bind a message to its field
- Why an automated scan can report a clean page that no keyboard or screen reader user can operate

#### Tools & Infrastructure

- **Tools:** Playwright, Guidepup Virtual Screen Reader (a simulation, not real assistive technology), axe-core
- **Infrastructure:** ShopSmart E-commerce Frontend with checkout flow (React/Vite)

---

### 🔴 Expert: The Compliance Engine

#### Description

Repair the automated check that is meant to stop inaccessible code from shipping, and find out why it has never once caught the barrier the company is being sued over.

#### Story

The components are repaired, and the legal team needs proof of continuous compliance for the EAA audit next week. Every merge already arrives with a green accessibility check attached, and the record says the storefront has been clean for months. But one item on the original legal notice was never reproduced. A customer reached the payment step, and once the keyboard was inside the card fields it never came out again, cycling between them however many times they pressed Tab. They never reached the button to place the order, and the check has never once reported anything there. Work out what that check is really looking at before the auditors arrive.

#### The Problem

The check runs on every build and always passes. The trouble is not the rules it applies but where it applies them. It never reaches the pages a customer moves through on the way to paying, and the barrier behind the lawsuit is a fault in how the page behaves rather than in how it is written, so no automated scanner would report it wherever it looked.

#### Objective

- Check the page as it appears in a browser, not the file the build produces
- Catch the barrier on the payment step that no scan has ever reported
- Prove the check works both ways: it fails a build that carries a known problem and passes one that does not

#### What You'll Learn

- Why a green accessibility check means nothing until you know which pages and states it actually looked at
- How reading the source code, scanning the finished page, and driving the page with a keyboard each catch different faults, and why some faults only the last of them can find
- How a third-party component you cannot change still becomes your own legal problem

#### Tools & Infrastructure

- **Tools:** Playwright, axe-core, eslint-plugin-jsx-a11y
- **Infrastructure:** ShopSmart E-commerce Frontend, checkout flow and vendor payment widget (React/Vite)
