# Amplissa Static Deployment Guide

This repository ships a static, compliant website for Amplissa.com plus reusable model portals and checkout shells.

## Structure
- `index.html` — public marketing site.
- `assets/` — shared CSS + JS.
- `portals/` — model portal template and LILLPEGGY live page.
- `checkout/` — static checkout shells for the store and LILLPEGGY digital set.
- `emails/` — drip + transactional email templates.

## Quick deploy (static hosting)
1. **Build**: No build step required; static assets only.
2. **Host**: Point any static host (Cloudflare Pages, Netlify, Vercel, S3+CloudFront). Set the project root to the repo root.
3. **HTTPS**: Enforce HTTPS and redirect HTTP → HTTPS.
4. **Caching**: Cache assets under `assets/` aggressively; keep HTML with short max-age to ship updates quickly.

## Payments
- Embed **Stripe Elements** or **CCBill FlexForms** inside the checkout pages. Replace publishable/test keys via data attributes or inline config where indicated.
- Add webhook endpoint (serverless works) at `/webhooks/payments` that maps `payment_succeeded`, `payment_failed`, and `refund` events to the included email templates.
- Receipts must include merchant descriptor, tax lines, and refund links to satisfy Stripe/CCBill evidence requirements.

## Automation
- `assets/js/main.js` handles age + geo gating and saves signups to `localStorage`. Swap this with your ESP/CRM API if desired.
- Use the webhook payload samples in `checkout/*.html` to connect payment events to your automation runner.
- Drip templates live in `emails/`; merge fields include `{{ email }}`, `{{ creator }}`, `{{ coupon_code }}`, and `{{ checkout_url }}`.

## Compliance and safety
- Keep adult content behind the age + country gate found in each portal/checkout page.
- Honor blocks for jurisdictions that disallow adult media. Adjust the `restricted` array in `assets/js/main.js` to match your legal list.
- Collect VAT/sales tax; do not remove or misclassify tax lines.

## Updating or adding model portals
1. Duplicate `portals/template.html` and rename it.
2. Fill in creator bio, offers, and compliance statements.
3. Point checkout buttons to either `checkout/index.html` or a dedicated checkout page.
4. Publish. The shared CSS/JS will keep styling consistent across portals.

## Zero manual conversation
- All pages link to drip and receipt templates. Map webhooks to automatically send them and surface self-serve refund links.
- Do not promise live chat; encourage fans to use the provided automation or help pages.

## Local preview
```bash
python3 -m http.server 4173
```
Then open `http://localhost:4173/index.html` in your browser.
