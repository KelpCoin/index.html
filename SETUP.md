# MTG Inventory Tracker for Google Sheets

This project includes a complete Google Apps Script (`MTGInventory.gs`) that scrapes Card Kingdom for MTG card prices, caches them, and writes USD and NZD prices into your sheet with batching and triggers.

## How to attach the script to your Google Sheet
1. Open your Google Sheet and rename the main tab to **Inventory** (or adjust `CONFIG.MAIN_SHEET_NAME` in `MTGInventory.gs`).
2. Click **Extensions → Apps Script** and delete any placeholder code.
3. Copy the full contents of `MTGInventory.gs` into the script editor and save.
4. Return to the sheet, refresh the page, and you should see the **MTG Tools** menu with:
   - **Refresh Prices (Batch)**: Processes the next batch of cards using caching.
   - **Force Full Refresh**: Resets batching and bypasses the 24-hour cache window.
5. Run **Refresh Prices (Batch)** once manually to authorize URL fetch and trigger creation.
6. The script automatically creates the hidden `CACHE` sheet, a `LOGS` sheet, conditional formatting for NZD prices, and a 10-minute time-based trigger for continuous batching.

## Batch size tuning
- The default `CONFIG.BATCH_SIZE` is **50** (recommended range 40–60).
- Increase it if your sheet consistently finishes quickly; decrease it if you see partial batches stopping early.
- The script stops early if it projects approaching the Apps Script execution limit (~6 minutes) and resumes from where it left off.

## Card Kingdom selector maintenance
- If Card Kingdom changes their HTML, update **one place**: `CONFIG.CARD_KINGDOM_PRICE_SELECTOR` (used by `parseCardKingdomPrice`).
- The parser first looks for `data-variantprice="…"`; if that changes, adjust the selector string or the fallback regex inside `parseCardKingdomPrice`.

## Multi-source pricing roadmap
- The code isolates source-specific logic in `fetchCardKingdomPrice` and `parseCardKingdomPrice`.
- To add sources (TCGplayer, CardMarket, Scryfall):
  - Create functions like `fetchTcgplayerPrice`, `fetchCardMarketPrice`, etc., each returning `{ price, hadError, message }`.
  - Add a small orchestrator that picks the best price (e.g., lowest non-foil, or an average) and call it from `processInventoryBatch` instead of the single-source fetch.
  - Keep caching keyed by card name/set/condition so downstream logic stays unchanged.

## Safe failure behavior
- If a price cannot be found or Card Kingdom blocks requests, the script writes `N/A`, logs the issue in `LOGS`, and continues without stopping the batch.
- The cache keeps previous prices, enabling conditional formatting and historical comparisons even when live fetch fails.
