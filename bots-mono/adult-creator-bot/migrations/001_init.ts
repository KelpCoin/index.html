import type { Knex } from 'knex';

export async function up(knex: Knex): Promise<void> {
  await knex.schema.createTable('guild_config', (table) => {
    table.string('guild_id').primary();
    table.string('verified_role_id');
    table.string('quarantine_role_id');
    table.string('mod_role_id');
    table.string('creator_role_id');
    table.string('rules_channel_id');
    table.string('reports_channel_id');
    table.string('modlog_channel_id');
    table.string('creatorops_channel_id');
    table.boolean('auto_dm_on_join').defaultTo(false);
    table.boolean('auto_quarantine').defaultTo(true);
    table.timestamps(true, true);
  });

  await knex.schema.createTable('onboarding_status', (table) => {
    table.increments('id').primary();
    table.string('guild_id').notNullable();
    table.string('user_id').notNullable();
    table.boolean('confirmed_18').defaultTo(false);
    table.boolean('agreed_rules').defaultTo(false);
    table.boolean('completed').defaultTo(false);
    table.timestamps(true, true);
    table.unique(['guild_id', 'user_id']);
  });

  await knex.schema.createTable('reports', (table) => {
    table.increments('id').primary();
    table.string('guild_id').notNullable();
    table.string('reporter_id').notNullable();
    table.string('target_user_id').notNullable();
    table.string('reason').notNullable();
    table.string('message_id');
    table.string('channel_id');
    table.string('status').defaultTo('open');
    table.timestamps(true, true);
  });

  await knex.schema.createTable('cases', (table) => {
    table.increments('id').primary();
    table.string('guild_id').notNullable();
    table.string('report_id');
    table.string('moderator_id').notNullable();
    table.string('action').notNullable();
    table.string('details');
    table.timestamps(true, true);
  });

  await knex.schema.createTable('content_tags', (table) => {
    table.increments('id').primary();
    table.string('guild_id').notNullable();
    table.string('tag').notNullable();
    table.timestamps(true, true);
  });

  await knex.schema.createTable('link_hub', (table) => {
    table.increments('id').primary();
    table.string('guild_id').notNullable();
    table.string('user_id').notNullable();
    table.string('bio');
    table.string('links');
    table.timestamps(true, true);
    table.unique(['guild_id', 'user_id']);
  });

  await knex.schema.createTable('support_message', (table) => {
    table.string('guild_id').primary();
    table.string('link');
    table.string('message');
    table.timestamps(true, true);
  });

  await knex.schema.createTable('creator_reminders', (table) => {
    table.increments('id').primary();
    table.string('guild_id').notNullable();
    table.string('creator_id').notNullable();
    table.timestamp('scheduled_for').notNullable();
    table.string('note');
    table.string('status').defaultTo('scheduled');
    table.timestamps(true, true);
  });

  await knex.schema.createTable('job_runs', (table) => {
    table.string('job_name').primary();
    table.timestamp('last_run_at');
  });
}

export async function down(knex: Knex): Promise<void> {
  await knex.schema.dropTableIfExists('job_runs');
  await knex.schema.dropTableIfExists('creator_reminders');
  await knex.schema.dropTableIfExists('support_message');
  await knex.schema.dropTableIfExists('link_hub');
  await knex.schema.dropTableIfExists('content_tags');
  await knex.schema.dropTableIfExists('cases');
  await knex.schema.dropTableIfExists('reports');
  await knex.schema.dropTableIfExists('onboarding_status');
  await knex.schema.dropTableIfExists('guild_config');
}
