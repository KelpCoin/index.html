/**
 * MTG Inventory Tracker with Card Kingdom pricing and USD -> NZD conversion.
 *
 * Sheet expectations (main sheet):
 * Column A = Card Name
 * Column B = Set
 * Column C = Quantity
 * Column D = Condition
 * Column E = Price (USD)
 * Column F = Price (NZD)
 * Column G = Last Updated (ISO timestamp)
 * Column H = Notes
 */

const CONFIG = {
  MAIN_SHEET_NAME: 'Inventory', // change if your inventory sheet has a different name
  CACHE_SHEET_NAME: 'CACHE',
  LOG_SHEET_NAME: 'LOGS',
  BATCH_SIZE: 50, // default batch size (40-60 recommended)
  CACHE_TTL_MS: 24 * 60 * 60 * 1000, // 24 hours
  RATE_LIMIT_MIN_MS: 1500,
  RATE_LIMIT_JITTER_MS: 500,
  MAX_RUNTIME_MS: 5 * 60 * 1000, // stop early to avoid 6 min Apps Script limit
  CARD_KINGDOM_BASE: 'https://www.cardkingdom.com',
  CARD_KINGDOM_SEARCH_PATH: '/catalog/search?search=header&filter%5Bname%5D=',
  CARD_KINGDOM_PRICE_SELECTOR: 'data-variantprice', // update here if Card Kingdom markup changes
  CURRENCY_API: 'https://api.exchangerate.host/convert?from=USD&to=NZD'
};

/**
 * Adds menu and ensures supporting sheets exist.
 */
function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('MTG Tools')
    .addItem('Refresh Prices (Batch)', 'refreshPricesBatch')
    .addItem('Force Full Refresh', 'forceFullRefresh')
    .addToUi();

  ensureSheetSetup();
  ensureConditionalFormatting();
  ensureTimedTrigger();
}

/**
 * Main entry point for batch refresh via menu/trigger.
 */
function refreshPricesBatch() {
  processInventoryBatch(false);
}

/**
 * Forces cache bypass and restarts batching from the first data row.
 */
function forceFullRefresh() {
  const props = PropertiesService.getDocumentProperties();
  props.setProperty('LAST_ROW', '2');
  processInventoryBatch(true);
}

/**
 * Core batch processor. Handles caching, rate limiting, currency conversion, and graceful stop.
 */
function processInventoryBatch(forceRefresh) {
  const start = Date.now();
  const ss = SpreadsheetApp.getActive();
  const sheet = getMainSheet(ss);
  const props = PropertiesService.getDocumentProperties();
  const lastRowProp = parseInt(props.getProperty('LAST_ROW') || '2', 10);

  const dataRange = sheet.getDataRange();
  const values = dataRange.getValues();
  const totalRows = values.length;

  if (totalRows < 2) {
    logMessage('No data rows to process.');
    return;
  }

  const startRow = Math.max(lastRowProp, 2);
  const endRow = Math.min(startRow + CONFIG.BATCH_SIZE - 1, totalRows);

  const cache = loadCache();
  const currencyRate = fetchUsdToNzdRate();

  for (let r = startRow; r <= endRow; r++) {
    if (shouldStopEarly(start, r, endRow)) {
      props.setProperty('LAST_ROW', String(r));
      return;
    }

    const [cardNameRaw, setRaw, quantity, conditionRaw] = [values[r - 1][0], values[r - 1][1], values[r - 1][2], values[r - 1][3]];
    const cardName = String(cardNameRaw || '').trim();
    const setName = String(setRaw || '').trim();
    const condition = String(conditionRaw || 'Near Mint').trim();

    if (!cardName) {
      continue;
    }

    const key = buildCacheKey(cardName, setName, condition);
    const cached = cache[key];
    const now = new Date();
    let usdPrice = null;
    let nzdPrice = null;
    let usedCache = false;

    if (!forceRefresh && cached && now.getTime() - cached.timestamp.getTime() < CONFIG.CACHE_TTL_MS && cached.currentUSD !== null) {
      usdPrice = cached.currentUSD;
      nzdPrice = cached.currentNZD;
      usedCache = true;
    } else {
      const fetchResult = fetchCardKingdomPrice(cardName, setName, condition);
      usdPrice = fetchResult.price;

      if (typeof usdPrice === 'number') {
        nzdPrice = parseFloat((usdPrice * currencyRate).toFixed(2));
      }

      updateCache(cache, key, usdPrice, nzdPrice, now);

      if (fetchResult.hadError) {
        logMessage(fetchResult.message);
      }
    }

    writeRow(sheet, r, usdPrice, nzdPrice, now, cache[key]?.previousNZD);

    if (!usedCache) {
      respectRateLimit();
    }
  }

  const nextRow = endRow >= totalRows ? 2 : endRow + 1;
  props.setProperty('LAST_ROW', String(nextRow));
}

/**
 * Builds a stable cache key from card name, set, and condition.
 */
function buildCacheKey(cardName, setName, condition) {
  return [cardName.toLowerCase(), setName.toLowerCase(), condition.toLowerCase()].join('||');
}

/**
 * Ensures the main, cache, and log sheets exist and are configured.
 */
function ensureSheetSetup() {
  const ss = SpreadsheetApp.getActive();
  getMainSheet(ss); // creates if missing
  const cacheSheet = ss.getSheetByName(CONFIG.CACHE_SHEET_NAME) || ss.insertSheet(CONFIG.CACHE_SHEET_NAME);
  cacheSheet.hideSheet();
  const logSheet = ss.getSheetByName(CONFIG.LOG_SHEET_NAME) || ss.insertSheet(CONFIG.LOG_SHEET_NAME);

  if (cacheSheet.getLastRow() === 0) {
    cacheSheet.appendRow(['Key', 'Previous NZD', 'Previous USD', 'Current NZD', 'Current USD', 'Last Updated']);
  }
  if (logSheet.getLastRow() === 0) {
    logSheet.appendRow(['Timestamp', 'Message']);
  }
}

/**
 * Ensures the NZD price column has conditional formatting tied to previous prices.
 */
function ensureConditionalFormatting() {
  const ss = SpreadsheetApp.getActive();
  const sheet = getMainSheet(ss);
  const rules = sheet.getConditionalFormatRules().filter(rule => {
    const range = rule.getRanges()[0];
    return !(range && range.getA1Notation() === 'F2:F');
  });

  const greenRule = SpreadsheetApp.newConditionalFormatRule()
    .whenFormulaSatisfied('=F2>IFERROR(VLOOKUP($A2&"||"&$B2&"||"&$D2,CACHE!$A$2:$F,2,FALSE),F2)')
    .setBackground('#d0f0c0')
    .setRanges([sheet.getRange('F2:F')])
    .build();

  const redRule = SpreadsheetApp.newConditionalFormatRule()
    .whenFormulaSatisfied('=F2<IFERROR(VLOOKUP($A2&"||"&$B2&"||"&$D2,CACHE!$A$2:$F,2,FALSE),F2)')
    .setBackground('#f4cccc')
    .setRanges([sheet.getRange('F2:F')])
    .build();

  const yellowRule = SpreadsheetApp.newConditionalFormatRule()
    .whenFormulaSatisfied('=F2=IFERROR(VLOOKUP($A2&"||"&$B2&"||"&$D2,CACHE!$A$2:$F,2,FALSE),F2)')
    .setBackground('#fff2cc')
    .setRanges([sheet.getRange('F2:F')])
    .build();

  rules.push(greenRule, redRule, yellowRule);
  sheet.setConditionalFormatRules(rules);
}

/**
 * Fetches and returns USD->NZD rate once per run.
 */
function fetchUsdToNzdRate() {
  try {
    const response = UrlFetchApp.fetch(CONFIG.CURRENCY_API, { muteHttpExceptions: true });
    const json = JSON.parse(response.getContentText());
    if (json && json.result) {
      return Number(json.result);
    }
  } catch (e) {
    logMessage('Currency API failed: ' + e.message);
  }
  return 1; // fallback to 1:1 if API fails
}

/**
 * Loads cache sheet into an in-memory map.
 */
function loadCache() {
  const ss = SpreadsheetApp.getActive();
  const sheet = ss.getSheetByName(CONFIG.CACHE_SHEET_NAME) || ss.insertSheet(CONFIG.CACHE_SHEET_NAME);
  sheet.hideSheet();

  const values = sheet.getDataRange().getValues();
  const map = {};
  for (let i = 1; i < values.length; i++) {
    const [key, previousNZD, previousUSD, currentNZD, currentUSD, ts] = values[i];
    if (!key) continue;
    map[key] = {
      previousNZD: isNaN(previousNZD) ? null : Number(previousNZD),
      previousUSD: isNaN(previousUSD) ? null : Number(previousUSD),
      currentNZD: isNaN(currentNZD) ? null : Number(currentNZD),
      currentUSD: isNaN(currentUSD) ? null : Number(currentUSD),
      timestamp: ts instanceof Date ? ts : new Date(ts),
      row: i + 1
    };
  }
  return map;
}

/**
 * Updates the in-memory cache map and writes to the CACHE sheet.
 */
function updateCache(cache, key, usdPrice, nzdPrice, timestamp) {
  const ss = SpreadsheetApp.getActive();
  const sheet = ss.getSheetByName(CONFIG.CACHE_SHEET_NAME);
  let record = cache[key];

  if (!record) {
    record = {
      previousNZD: null,
      previousUSD: null,
      currentNZD: null,
      currentUSD: null,
      timestamp: timestamp,
      row: sheet.getLastRow() + 1
    };
    sheet.appendRow([key, '', '', '', '', timestamp]);
  }

  const newPreviousNZD = record.currentNZD;
  const newPreviousUSD = record.currentUSD;

  record.previousNZD = newPreviousNZD;
  record.previousUSD = newPreviousUSD;
  record.currentNZD = typeof nzdPrice === 'number' ? nzdPrice : null;
  record.currentUSD = typeof usdPrice === 'number' ? usdPrice : null;
  record.timestamp = timestamp;

  sheet.getRange(record.row, 1, 1, 6).setValues([[key, record.previousNZD, record.previousUSD, record.currentNZD, record.currentUSD, timestamp]]);
  cache[key] = record;
}

/**
 * Writes computed prices back to the main sheet and applies color coding.
 */
function writeRow(sheet, row, usdPrice, nzdPrice, timestamp, previousNZD) {
  const usdDisplay = typeof usdPrice === 'number' ? usdPrice : 'N/A';
  const nzdDisplay = typeof nzdPrice === 'number' ? nzdPrice : 'N/A';

  const usdCell = sheet.getRange(row, 5);
  const nzdCell = sheet.getRange(row, 6);
  const updatedCell = sheet.getRange(row, 7);

  usdCell.setValue(usdDisplay);
  nzdCell.setValue(nzdDisplay);
  updatedCell.setValue(timestamp);

  // Apply background colors for immediate visual feedback (conditional formatting also exists).
  if (typeof nzdPrice === 'number' && typeof previousNZD === 'number') {
    if (nzdPrice > previousNZD) {
      nzdCell.setBackground('#d0f0c0');
    } else if (nzdPrice < previousNZD) {
      nzdCell.setBackground('#f4cccc');
    } else {
      nzdCell.setBackground('#fff2cc');
    }
  } else {
    nzdCell.setBackground(null);
  }
}

/**
 * Fetches card price from Card Kingdom search results.
 */
function fetchCardKingdomPrice(cardName, setName, condition) {
  try {
    const searchUrl = CONFIG.CARD_KINGDOM_BASE + CONFIG.CARD_KINGDOM_SEARCH_PATH + encodeURIComponent(cardName) + '&filter%5Bkingdoms%5D=mtg&filter%5Bproduct_type%5D=mtg_single';
    const response = UrlFetchApp.fetch(searchUrl, { muteHttpExceptions: true, followRedirects: true });
    const code = response.getResponseCode();
    if (code >= 400) {
      return { price: null, hadError: true, message: 'Card Kingdom returned ' + code + ' for ' + cardName };
    }

    const html = response.getContentText();
    const price = parseCardKingdomPrice(html);
    if (price === null) {
      return { price: null, hadError: true, message: 'Price not found for ' + cardName + ' (' + setName + ')' };
    }

    return { price: price, hadError: false };
  } catch (e) {
    return { price: null, hadError: true, message: 'Fetch failed for ' + cardName + ': ' + e.message };
  }
}

/**
 * Centralized parser for Card Kingdom price markup.
 * Update ONLY this selector/regex if their layout changes.
 */
function parseCardKingdomPrice(html) {
  // Primary selector: data-variantprice attribute on the cheapest non-foil entry.
  const regex = new RegExp(CONFIG.CARD_KINGDOM_PRICE_SELECTOR + '="([\\d.,]+)"', 'i');
  const match = html.match(regex);
  if (match && match[1]) {
    return Number(match[1].replace(/,/g, ''));
  }

  // Fallback: look for "$xx.xx" patterns inside price spans.
  const altMatch = html.match(/\$\s*([0-9]+(?:\.[0-9]{2})?)/);
  if (altMatch && altMatch[1]) {
    return Number(altMatch[1]);
  }
  return null;
}

/**
 * Respects rate limiting between live HTTP requests.
 */
function respectRateLimit() {
  const wait = CONFIG.RATE_LIMIT_MIN_MS + Math.floor(Math.random() * CONFIG.RATE_LIMIT_JITTER_MS);
  Utilities.sleep(wait);
}

/**
 * Returns true if the batch should stop to avoid exceeding execution time.
 */
function shouldStopEarly(startMs, currentRow, plannedEndRow) {
  const elapsed = Date.now() - startMs;
  const remainingRows = plannedEndRow - currentRow + 1;
  // Rough heuristic: assume worst-case 2s per remaining row.
  const projected = elapsed + remainingRows * (CONFIG.RATE_LIMIT_MIN_MS + CONFIG.RATE_LIMIT_JITTER_MS);
  return elapsed > CONFIG.MAX_RUNTIME_MS || projected > CONFIG.MAX_RUNTIME_MS;
}

/**
 * Creates the 10-minute time-based trigger if missing.
 */
function ensureTimedTrigger() {
  const triggers = ScriptApp.getProjectTriggers();
  const hasTrigger = triggers.some(t => t.getHandlerFunction() === 'refreshPricesBatch');
  if (!hasTrigger) {
    ScriptApp.newTrigger('refreshPricesBatch').timeBased().everyMinutes(10).create();
  }
}

/**
 * Ensures the main sheet exists and has headers.
 */
function getMainSheet(ss) {
  let sheet = ss.getSheetByName(CONFIG.MAIN_SHEET_NAME);
  if (!sheet) {
    sheet = ss.getSheets()[0];
    sheet.setName(CONFIG.MAIN_SHEET_NAME);
  }
  const headers = ['Card Name', 'Set', 'Quantity', 'Condition', 'Price (USD)', 'Price (NZD)', 'Last Updated', 'Notes'];
  const firstRow = sheet.getRange(1, 1, 1, headers.length).getValues()[0];
  let needsHeader = false;
  for (let i = 0; i < headers.length; i++) {
    if (String(firstRow[i] || '') !== headers[i]) {
      needsHeader = true;
      break;
    }
  }
  if (needsHeader) {
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  }
  return sheet;
}

/**
 * Records a message in the LOGS sheet.
 */
function logMessage(message) {
  const ss = SpreadsheetApp.getActive();
  const sheet = ss.getSheetByName(CONFIG.LOG_SHEET_NAME) || ss.insertSheet(CONFIG.LOG_SHEET_NAME);
  sheet.appendRow([new Date(), message]);
}
