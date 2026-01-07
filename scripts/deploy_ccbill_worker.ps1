param(
  [Parameter(Mandatory = $true)]
  [string]$AccountId,

  [Parameter(Mandatory = $true)]
  [string]$ZoneId,

  [Parameter(Mandatory = $true)]
  [string]$WorkerName,

  [string]$Route = "amplissa.com/webhooks/payments"
)

Write-Host "Deploying CCBill webhook worker..."

wrangler deploy ./worker/ccbill_webhook.js --name $WorkerName --account-id $AccountId

Write-Host "Registering route $Route"
wrangler route add $Route --zone-id $ZoneId --name $WorkerName

Write-Host "Setting secrets..."
wrangler secret put CCBILL_SALT --name $WorkerName
wrangler secret put DOWNLOAD_SIGNING_SECRET --name $WorkerName

Write-Host "Setting vars..."
wrangler secret put MAIL_FROM --name $WorkerName
wrangler secret put MAIL_REPLY_TO --name $WorkerName

wrangler kv:namespace create DOWNLOAD_TOKENS
wrangler r2 bucket create AUDIT_LOGS

Write-Host "Test webhook commands:"
Write-Host "`$payload = '{\"eventType\":\"payment_success\",\"orderId\":\"A-10001\",\"customerEmail\":\"fan@example.com\",\"amount\":\"39.00\",\"currency\":\"USD\",\"taxes\":\"2.34\",\"descriptor\":\"AMPLISSA.COM\",\"productId\":\"lillpeggy-pack-01\"}'"
Write-Host "`$sig = echo `$payload | openssl dgst -sha256 -hmac $env:CCBILL_SALT"
Write-Host "curl -X POST https://$Route -H \"Content-Type: application/json\" -H \"X-CCBill-Signature: `$sig\" -d `$payload"
