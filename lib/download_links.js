export async function createDownloadLink({
  baseUrl,
  assetId,
  orderId,
  expiresInSeconds,
  secret,
}) {
  if (!baseUrl || !assetId || !orderId || !secret) {
    throw new Error('Missing required download link inputs');
  }

  const expiresAt = Math.floor(Date.now() / 1000) + expiresInSeconds;
  const tokenPayload = `${assetId}:${orderId}:${expiresAt}`;
  const token = await hmacHex(secret, tokenPayload);

  const url = new URL(baseUrl);
  url.searchParams.set('asset', assetId);
  url.searchParams.set('order', orderId);
  url.searchParams.set('expires', String(expiresAt));
  url.searchParams.set('token', token);

  return {
    url: url.toString(),
    token,
    expiresAt,
  };
}

export async function verifyDownloadToken({
  assetId,
  orderId,
  expiresAt,
  token,
  secret,
}) {
  if (!assetId || !orderId || !expiresAt || !token || !secret) {
    return false;
  }

  if (Number(expiresAt) < Math.floor(Date.now() / 1000)) {
    return false;
  }

  const tokenPayload = `${assetId}:${orderId}:${expiresAt}`;
  const expected = await hmacHex(secret, tokenPayload);
  return timingSafeEqual(token, expected);
}

async function hmacHex(secret, payload) {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(payload));
  return [...new Uint8Array(signature)].map((b) => b.toString(16).padStart(2, '0')).join('');
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
