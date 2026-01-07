export async function appendAuditLog(env, entry) {
  const dateKey = new Date().toISOString().slice(0, 10);
  const logKey = `logs/payments/${dateKey}.jsonl`;
  const line = `${JSON.stringify(entry)}\n`;

  if (!env.AUDIT_LOGS) {
    console.log('AUDIT_LOGS bucket not configured. Log entry:', entry);
    return;
  }

  const existing = await env.AUDIT_LOGS.get(logKey);
  if (!existing) {
    await env.AUDIT_LOGS.put(logKey, line, {
      httpMetadata: { contentType: 'application/jsonl' },
    });
    return;
  }

  const previousText = await existing.text();
  const updated = previousText + line;
  await env.AUDIT_LOGS.put(logKey, updated, {
    httpMetadata: { contentType: 'application/jsonl' },
  });
}
