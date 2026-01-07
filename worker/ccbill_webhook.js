import { createDownloadLink } from '../lib/download_links.js';
import { appendAuditLog } from '../lib/audit_logger.js';
import { sendFailureEmail, sendReceiptEmail, sendRefundEmail } from '../lib/email_sender.js';

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    const rawBody = await request.text();
    const signature = request.headers.get('x-ccbill-signature') || '';

    const verified = await verifySignature({ rawBody, signature, secret: env.CCBILL_SALT });
    if (!verified) {
      await appendAuditLog(env, buildAuditEntry({
        eventType: 'signature_invalid',
        status: 'rejected',
        payload: safeParse(rawBody),
      }));
      return new Response('Invalid signature', { status: 401 });
    }

    const payload = safeParse(rawBody);
    const eventType = normalizeEventType(payload);
    const orderId = payload.orderId || payload.transactionId || payload.subscriptionId || crypto.randomUUID();
    const now = new Date();

    const baseLog = {
      eventId: crypto.randomUUID(),
      eventType,
      orderId,
      receivedAt: now.toISOString(),
      account: payload.accountNumber || env.CCBILL_ACCOUNT_NUMBER || 'unknown',
      subaccount: payload.subAccountNumber || env.CCBILL_SUBACCOUNT || 'unknown',
      rawEvent: payload,
    };

    try {
      if (eventType === 'payment_success') {
        const downloadAssetId = payload.productId || payload.assetId || env.DEFAULT_ASSET_ID;
        const link = await createDownloadLink({
          baseUrl: env.DOWNLOAD_BASE_URL,
          assetId: downloadAssetId,
          orderId,
          expiresInSeconds: Number(env.DOWNLOAD_LINK_TTL || 3600),
          secret: env.DOWNLOAD_SIGNING_SECRET,
        });

        await storeToken(env, orderId, {
          assetId: downloadAssetId,
          token: link.token,
          expiresAt: link.expiresAt,
        });

        const recipient = payload.customerEmail || payload.email || payload.clientEmail;
        if (recipient) {
          await sendReceiptEmail(env, {
            to: recipient,
            orderId,
            amount: payload.amount || payload.price || '0.00',
            currency: payload.currency || 'USD',
            taxes: payload.taxes || payload.taxAmount || '0.00',
            descriptor: payload.descriptor || env.BILLING_DESCRIPTOR || 'Amplissa',
            downloadUrl: link.url,
            expiresAtHuman: new Date(link.expiresAt * 1000).toISOString(),
            refundPolicy: env.REFUND_POLICY || 'Refunds available within 7 days of purchase.',
            creatorName: env.CREATOR_NAME || 'LILLPEGGY',
          });
        }

        await appendAuditLog(env, buildAuditEntry({
          ...baseLog,
          status: 'fulfilled',
          downloadUrl: link.url,
        }));

        return jsonResponse({ status: 'ok', orderId, downloadUrl: link.url });
      }

      if (eventType === 'payment_failure') {
        const recipient = payload.customerEmail || payload.email || payload.clientEmail;
        if (recipient) {
          await sendFailureEmail(env, {
            to: recipient,
            orderId,
            creatorName: env.CREATOR_NAME || 'LILLPEGGY',
          });
        }

        await appendAuditLog(env, buildAuditEntry({
          ...baseLog,
          status: 'failed',
        }));

        return jsonResponse({ status: 'received', orderId });
      }

      if (eventType === 'refund') {
        await revokeToken(env, orderId);

        const recipient = payload.customerEmail || payload.email || payload.clientEmail;
        if (recipient) {
          await sendRefundEmail(env, {
            to: recipient,
            orderId,
          });
        }

        await appendAuditLog(env, buildAuditEntry({
          ...baseLog,
          status: 'refunded',
        }));

        return jsonResponse({ status: 'refunded', orderId });
      }

      await appendAuditLog(env, buildAuditEntry({
        ...baseLog,
        status: 'ignored',
      }));

      return jsonResponse({ status: 'ignored', orderId, eventType });
    } catch (error) {
      await appendAuditLog(env, buildAuditEntry({
        ...baseLog,
        status: 'error',
        error: error.message,
      }));

      return new Response('Server error', { status: 500 });
    }
  },
};

async function verifySignature({ rawBody, signature, secret }) {
  if (!secret) {
    throw new Error('CCBILL_SALT not configured');
  }
  if (!signature) {
    return false;
  }
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signed = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(rawBody));
  const expected = [...new Uint8Array(signed)].map((b) => b.toString(16).padStart(2, '0')).join('');
  return timingSafeEqual(signature, expected);
}

function normalizeEventType(payload) {
  const raw = String(payload.eventType || payload.event_type || payload.event || '').toLowerCase();
  if (raw.includes('success') || raw === 'payment_success') {
    return 'payment_success';
  }
  if (raw.includes('fail') || raw === 'payment_failure') {
    return 'payment_failure';
  }
  if (raw.includes('refund')) {
    return 'refund';
  }
  if (raw.includes('cancel')) {
    return 'subscription_cancel';
  }
  if (raw.includes('chargeback')) {
    return 'chargeback_notice';
  }
  return raw || 'unknown';
}

function safeParse(rawBody) {
  try {
    return JSON.parse(rawBody);
  } catch (error) {
    return { raw: rawBody };
  }
}

function buildAuditEntry(data) {
  return {
    eventId: data.eventId || crypto.randomUUID(),
    eventType: data.eventType,
    orderId: data.orderId,
    status: data.status,
    receivedAt: data.receivedAt || new Date().toISOString(),
    account: data.account,
    subaccount: data.subaccount,
    downloadUrl: data.downloadUrl,
    error: data.error,
    rawEvent: data.rawEvent,
  };
}

function timingSafeEqual(a, b) {
  if (a.length !== b.length) {
    return false;
  }
  let result = 0;
  for (let i = 0; i < a.length; i += 1) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return result === 0;
}

function jsonResponse(payload) {
  return new Response(JSON.stringify(payload), {
    status: 200,
    headers: { 'content-type': 'application/json' },
  });
}

async function storeToken(env, orderId, tokenData) {
  if (!env.DOWNLOAD_TOKENS) {
    return;
  }
  await env.DOWNLOAD_TOKENS.put(`order:${orderId}`, JSON.stringify(tokenData), {
    expirationTtl: Number(env.DOWNLOAD_LINK_TTL || 3600),
  });
}

async function revokeToken(env, orderId) {
  if (!env.DOWNLOAD_TOKENS) {
    return;
  }
  await env.DOWNLOAD_TOKENS.delete(`order:${orderId}`);
}
