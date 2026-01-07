# CCBill Webhook Fulfillment Pipeline (Amplissa)

This package implements a CCBill → Amplissa fulfillment pipeline designed for adult-safe digital storefronts. It verifies webhook signatures, generates expiring download links, sends email receipts, and appends immutable audit logs.

## Files

- `/worker/ccbill_webhook.js` – Cloudflare Worker webhook handler for `/webhooks/payments`.
- `/lib/download_links.js` – Signed URL generator + verifier.
- `/lib/email_sender.js` – MailChannels email sender with HTML templates.
- `/lib/audit_logger.js` – JSONL audit log appender (R2-backed).
- `/scripts/deploy_ccbill_worker.ps1` – PowerShell deployment script.
- `/emails/*` – Email template references.

## Cloudflare Worker Environment

Required bindings/vars:

- `CCBILL_SALT` (secret): HMAC secret provided by CCBill.
- `CCBILL_ACCOUNT_NUMBER` (string)
- `CCBILL_SUBACCOUNT` (string)
- `DOWNLOAD_BASE_URL` (string) – Base URL used to build signed download links.
- `DOWNLOAD_SIGNING_SECRET` (secret)
- `DOWNLOAD_LINK_TTL` (string/number) – seconds; default 3600.
- `DEFAULT_ASSET_ID` (string)
- `CREATOR_NAME` (string) – default `LILLPEGGY`.
- `MAIL_FROM` (string) – sender address for receipts.
- `MAIL_FROM_NAME` (string) – sender name.
- `MAIL_REPLY_TO` (string)
- `BILLING_DESCRIPTOR` (string)
- `REFUND_POLICY` (string)

Bindings:

- `AUDIT_LOGS` (R2 bucket) – audit log storage (immutable JSONL).
- `DOWNLOAD_TOKENS` (KV namespace) – active download tokens by order.

## Webhook Signature

CCBill should send the raw JSON body and an `X-CCBill-Signature` header that contains an HMAC-SHA256 hash of the raw body using your `CCBILL_SALT`.

## Supported Events

- `payment_success`
- `payment_failure`
- `refund`
- `subscription_cancel` (logged)
- `chargeback_notice` (logged)

## Example Webhook Payloads

### payment_success

```json
{
  "eventType": "payment_success",
  "orderId": "A-10001",
  "customerEmail": "fan@example.com",
  "amount": "39.00",
  "currency": "USD",
  "taxes": "2.34",
  "descriptor": "AMPLISSA.COM",
  "productId": "lillpeggy-pack-01",
  "accountNumber": "123456",
  "subAccountNumber": "0001"
}
```

### payment_failure

```json
{
  "eventType": "payment_failure",
  "orderId": "A-10002",
  "customerEmail": "fan@example.com",
  "amount": "39.00",
  "currency": "USD"
}
```

### refund

```json
{
  "eventType": "refund",
  "orderId": "A-10001",
  "customerEmail": "fan@example.com"
}
```

## Sample Email Output

- See `/emails/receipt.html` for the receipt template.
- See `/emails/payment_failure.html` for payment failure.
- See `/emails/refund.html` for refund notification.

## CCBill FlexForms Callback Configuration

1. Webhook URL: `https://YOUR-WORKER-DOMAIN/webhooks/payments`
2. Method: `POST`
3. Content-Type: `application/json`
4. Signature header: `X-CCBill-Signature` (HMAC-SHA256 of raw body with `CCBILL_SALT`).

## Download Links

Links are signed with HMAC-SHA256 and expire after `DOWNLOAD_LINK_TTL` seconds.

Example URL:

```
https://downloads.amplissa.com/download?asset=lillpeggy-pack-01&order=A-10001&expires=1710000000&token=...
```

On refund, the order token is removed from `DOWNLOAD_TOKENS` KV. Use the included verifier in `lib/download_links.js` at your download endpoint to check validity.

## Audit Logs

JSONL log entries are appended to:

```
/logs/payments/YYYY-MM-DD.jsonl
```

Store logs in the `AUDIT_LOGS` R2 bucket. Each line is immutable and suitable for compliance review.

## Local Test Command

```bash
payload='{"eventType":"payment_success","orderId":"A-10001","customerEmail":"fan@example.com","amount":"39.00","currency":"USD","taxes":"2.34","descriptor":"AMPLISSA.COM","productId":"lillpeggy-pack-01"}'

signature=$(printf "%s" "$payload" | openssl dgst -sha256 -hmac "$CCBILL_SALT" | awk '{print $2}')

curl -X POST https://YOUR-WORKER-DOMAIN/webhooks/payments \
  -H "Content-Type: application/json" \
  -H "X-CCBill-Signature: $signature" \
  -d "$payload"
```

## Deployment

Use the PowerShell script below or run the same commands manually with `wrangler`.

```
./scripts/deploy_ccbill_worker.ps1 -AccountId YOUR_ACCOUNT_ID -ZoneId YOUR_ZONE_ID -WorkerName amplissa-ccbill
```
