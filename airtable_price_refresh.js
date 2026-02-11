/*
Airtable Scripting Extension / Automation Script

Before running:
1) Set TABLE_NAME to your table name.
2) Ensure field names match exactly.
3) Add automation schedule (e.g. every 30 min).
*/

const TABLE_NAME = "Singles";
const FIELD = {
  scryfallId: "Scryfall ID",
  quantity: "Quantity",
  discount: "Discount %",
  usd: "USD Price",
  fx: "USD->NZD",
  nzdMarket: "NZD Market",
  offerNzd: "Offer NZD",
  lastUpdated: "Last Updated",
};

const table = base.getTable(TABLE_NAME);
const query = await table.selectRecordsAsync({
  fields: Object.values(FIELD),
});

async function getUsdToNzd() {
  const res = await fetch("https://open.er-api.com/v6/latest/USD");
  if (!res.ok) throw new Error(`FX API failed: ${res.status}`);
  const data = await res.json();
  const rate = data?.rates?.NZD;
  if (!rate) throw new Error("NZD rate missing from FX API response");
  return rate;
}

async function getUsdPriceFromScryfall(scryfallId) {
  const res = await fetch(`https://api.scryfall.com/cards/${scryfallId}`);
  if (!res.ok) return null;
  const card = await res.json();

  const usdCandidates = [
    card?.prices?.usd,
    card?.prices?.usd_foil,
    card?.prices?.usd_etched,
  ].filter(Boolean);

  if (usdCandidates.length === 0) return null;

  return Number(usdCandidates[0]);
}

const fxRate = await getUsdToNzd();
const updates = [];

for (const record of query.records) {
  const scryfallId = record.getCellValueAsString(FIELD.scryfallId)?.trim();
  const quantity = record.getCellValue(FIELD.quantity) ?? 0;

  if (!scryfallId || quantity <= 0) continue;

  const usdPrice = await getUsdPriceFromScryfall(scryfallId);
  if (usdPrice === null || Number.isNaN(usdPrice)) continue;

  const discount = Number(record.getCellValue(FIELD.discount) ?? 0.2);
  const nzdMarket = usdPrice * fxRate;
  const offerNzd = nzdMarket * (1 - discount);

  updates.push({
    id: record.id,
    fields: {
      [FIELD.usd]: Number(usdPrice.toFixed(2)),
      [FIELD.fx]: Number(fxRate.toFixed(5)),
      [FIELD.nzdMarket]: Number(nzdMarket.toFixed(2)),
      [FIELD.offerNzd]: Number(offerNzd.toFixed(2)),
      [FIELD.lastUpdated]: new Date().toISOString(),
    },
  });

  if (updates.length === 50) {
    await table.updateRecordsAsync(updates);
    updates.length = 0;
  }
}

if (updates.length) {
  await table.updateRecordsAsync(updates);
}

output.markdown(`Updated prices with USD->NZD = ${fxRate}`);
