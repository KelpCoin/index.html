import type { Knex } from 'knex';

export async function up(knex: Knex): Promise<void> {
  await knex.schema.createTable('guild_config', (table) => {
    table.string('guild_id').primary();
    table.string('free_channel_id');
    table.string('premium_channel_id');
    table.string('logs_channel_id');
    table.string('deal_role_id');
    table.float('spike_threshold').defaultTo(15);
    table.float('drop_threshold').defaultTo(15);
    table.float('spread_threshold').defaultTo(20);
    table.integer('confidence_free').defaultTo(80);
    table.integer('confidence_premium').defaultTo(60);
    table.integer('job_interval_minutes').defaultTo(30);
    table.timestamps(true, true);
  });

  await knex.schema.createTable('cards', (table) => {
    table.increments('id').primary();
    table.string('name').notNullable();
    table.string('set_code');
    table.string('collector_number');
    table.string('scryfall_id');
    table.string('image_uri');
    table.string('rarity');
    table.string('type_line');
    table.timestamps(true, true);
  });

  await knex.schema.createTable('watchlists', (table) => {
    table.increments('id').primary();
    table.string('guild_id').notNullable();
    table.string('user_id').notNullable();
    table.string('card_name').notNullable();
    table.string('set_code');
    table.string('language');
    table.timestamps(true, true);
  });

  await knex.schema.createTable('alerts', (table) => {
    table.increments('id').primary();
    table.string('guild_id').notNullable();
    table.string('card_name').notNullable();
    table.string('action').notNullable();
    table.integer('score').notNullable();
    table.json('details');
    table.timestamps(true, true);
  });

  await knex.schema.createTable('deal_queue', (table) => {
    table.increments('id').primary();
    table.string('guild_id').notNullable();
    table.string('card_name').notNullable();
    table.float('price_diff').notNullable();
    table.string('status').defaultTo('queued');
    table.string('moderator_id');
    table.string('reason');
    table.timestamps(true, true);
  });

  await knex.schema.createTable('job_runs', (table) => {
    table.string('job_name').primary();
    table.timestamp('last_run_at');
  });
}

export async function down(knex: Knex): Promise<void> {
  await knex.schema.dropTableIfExists('job_runs');
  await knex.schema.dropTableIfExists('deal_queue');
  await knex.schema.dropTableIfExists('alerts');
  await knex.schema.dropTableIfExists('watchlists');
  await knex.schema.dropTableIfExists('cards');
  await knex.schema.dropTableIfExists('guild_config');
}
