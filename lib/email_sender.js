const templates = {
  receipt: (data) => `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Your Amplissa Receipt</title>
  </head>
  <body style="font-family: Arial, sans-serif; color: #1f2937;">
    <h2>Thanks for your purchase from ${escapeHtml(data.creatorName)}!</h2>
    <p>Order ID: <strong>${escapeHtml(data.orderId)}</strong></p>
    <p>Amount: <strong>${escapeHtml(data.amount)} ${escapeHtml(data.currency)}</strong></p>
    <p>Taxes: <strong>${escapeHtml(data.taxes || '0.00')} ${escapeHtml(data.currency)}</strong></p>
    <p>Descriptor: <strong>${escapeHtml(data.descriptor)}</strong></p>
    <p>Your download link (expires ${escapeHtml(data.expiresAtHuman)}):</p>
    <p><a href="${escapeHtml(data.downloadUrl)}">Download your file</a></p>
    <p style="font-size: 12px; color: #6b7280;">Refund policy: ${escapeHtml(data.refundPolicy)}</p>
  </body>
</html>`,
  failure: (data) => `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Payment Update</title>
  </head>
  <body style="font-family: Arial, sans-serif; color: #1f2937;">
    <h2>Payment update for ${escapeHtml(data.creatorName)}</h2>
    <p>Order ID: <strong>${escapeHtml(data.orderId)}</strong></p>
    <p>We were unable to process your payment. Please retry using the checkout page.</p>
  </body>
</html>`,
  refund: (data) => `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Refund Notice</title>
  </head>
  <body style="font-family: Arial, sans-serif; color: #1f2937;">
    <h2>Your refund has been processed.</h2>
    <p>Order ID: <strong>${escapeHtml(data.orderId)}</strong></p>
    <p>The download link for this order has been disabled.</p>
  </body>
</html>`,
};

export async function sendReceiptEmail(env, data) {
  const html = templates.receipt(data);
  const subject = `Your Amplissa receipt - Order ${data.orderId}`;
  await sendEmail(env, {
    to: data.to,
    subject,
    html,
  });
}

export async function sendFailureEmail(env, data) {
  const html = templates.failure(data);
  const subject = `Payment issue - Order ${data.orderId}`;
  await sendEmail(env, {
    to: data.to,
    subject,
    html,
  });
}

export async function sendRefundEmail(env, data) {
  const html = templates.refund(data);
  const subject = `Refund processed - Order ${data.orderId}`;
  await sendEmail(env, {
    to: data.to,
    subject,
    html,
  });
}

async function sendEmail(env, { to, subject, html }) {
  if (!env.MAIL_FROM || !env.MAIL_REPLY_TO) {
    throw new Error('MAIL_FROM and MAIL_REPLY_TO must be configured');
  }

  const payload = {
    personalizations: [
      {
        to: [{ email: to }],
      },
    ],
    from: {
      email: env.MAIL_FROM,
      name: env.MAIL_FROM_NAME || 'Amplissa',
    },
    reply_to: {
      email: env.MAIL_REPLY_TO,
      name: env.MAIL_FROM_NAME || 'Amplissa',
    },
    subject,
    content: [
      {
        type: 'text/html',
        value: html,
      },
    ],
  };

  const response = await fetch('https://api.mailchannels.net/tx/v1/send', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`MailChannels error ${response.status}: ${body}`);
  }
}

function escapeHtml(value) {
  return String(value || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}
