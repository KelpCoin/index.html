import { EmbedBuilder, TextChannel } from 'discord.js';
import type { Client } from 'discord.js';
import type { Knex } from 'knex';
import fs from 'node:fs';
import path from 'node:path';
import { computeScore, fetchQuotes } from '../services/priceService.js';
import { createMockMarketAdapter } from '../adapters/mockMarket.js';
import { scryfallAdapter } from '../adapters/scryfall.js';
import { resolveCard } from '../services/cardService.js';

const COOLDOWN_MINUTES = 120;

export async function runAlertJob(params: {
  client: Client;
  db: Knex;
  marketApiKey?: string;
  logger: { info: (msg: string, meta?: unknown) => void; error: (msg: string, meta?: unknown) => void };
}) {
  const configs = await params.db('guild_config').select();
  for (const config of configs) {
    const watchlists = await params.db('watchlists').where({ guild_id: config.guild_id }).select();
    for (const watch of watchlists) {
      const card = await resolveCard(params.db, { name: watch.card_name });
      if (!card) {
        continue;
      }
      const quotes = await fetchQuotes([scryfallAdapter, createMockMarketAdapter(params.marketApiKey)], {
        name: card.name,
        scryfallId: card.scryfall_id
      });
      if (quotes.length < 2) {
        continue;
      }
      const prices = quotes.map((quote) => quote.price);
      const min = Math.min(...prices);
      const max = Math.max(...prices);
      const spreadPercent = ((max - min) / Math.max(min, 1)) * 100;
      const action = spreadPercent >= config.spread_threshold ? 'spread' : 'stable';
      if (action === 'stable') {
        continue;
      }
      const latestAlert = await params.db('alerts')
        .where({ guild_id: config.guild_id, card_name: card.name })
        .orderBy('created_at', 'desc')
        .first();
      if (latestAlert) {
        const since = Date.now() - new Date(latestAlert.created_at).getTime();
        if (since < COOLDOWN_MINUTES * 60 * 1000) {
          continue;
        }
      }
      const volatility = Math.random() * 0.4;
      const score = computeScore(quotes, volatility);
      const routeFree = score >= config.confidence_free;
      const routePremium = score >= config.confidence_premium;
      const alertRow = {
        guild_id: config.guild_id,
        card_name: card.name,
        action,
        score,
        details: JSON.stringify({ quotes, spreadPercent, volatility })
      };
      const [alertId] = await params.db('alerts').insert(alertRow);
      const embed = new EmbedBuilder()
        .setTitle(`MTG Alert: ${card.name}`)
        .setDescription(`Action: ${action.toUpperCase()} | Score: ${score}`)
        .addFields(
          { name: 'Spread', value: `${spreadPercent.toFixed(2)}%`, inline: true },
          { name: 'Sources', value: `${quotes.length}`, inline: true },
          {
            name: 'Prices',
            value: quotes.map((quote) => `${quote.source}: $${quote.price}`).join('\n'),
            inline: false
          }
        )
        .setThumbnail(card.image_uri ?? null)
        .setColor(score >= config.confidence_free ? 0x2ecc71 : 0xf1c40f);
      if (routeFree && config.free_channel_id) {
        const channel = await params.client.channels.fetch(config.free_channel_id);
        if (channel && channel.isTextBased()) {
          await (channel as TextChannel).send({ embeds: [embed] });
        }
      }
      if (routePremium && config.premium_channel_id) {
        const channel = await params.client.channels.fetch(config.premium_channel_id);
        if (channel && channel.isTextBased()) {
          await (channel as TextChannel).send({ embeds: [embed] });
        }
      }
      await writeAlertArtifact(alertId, {
        alert: alertRow,
        quotes,
        spreadPercent,
        volatility,
        routed: { free: routeFree, premium: routePremium }
      });
      params.logger.info('Alert generated', { alertId, card: card.name, score });
    }
  }
}

async function writeAlertArtifact(id: number, payload: unknown) {
  const date = new Date().toISOString().slice(0, 10);
  const folder = path.join(process.cwd(), 'data', 'artifacts', 'alerts', date);
  await fs.promises.mkdir(folder, { recursive: true });
  const filePath = path.join(folder, `alert_${id}.json`);
  await fs.promises.writeFile(filePath, JSON.stringify(payload, null, 2));
}
