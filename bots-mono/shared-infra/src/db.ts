import path from 'node:path';
import fs from 'node:fs';
import knex, { Knex } from 'knex';

export type DatabaseConfig = {
  databaseUrl?: string;
  sqlitePath?: string;
  migrationsDir: string;
};

export function createDatabase(config: DatabaseConfig): Knex {
  if (config.databaseUrl) {
    return knex({
      client: 'pg',
      connection: config.databaseUrl,
      migrations: { directory: config.migrationsDir }
    });
  }
  const dbPath = config.sqlitePath ?? path.join(process.cwd(), 'data', 'app.sqlite');
  fs.mkdirSync(path.dirname(dbPath), { recursive: true });
  return knex({
    client: 'better-sqlite3',
    connection: { filename: dbPath },
    useNullAsDefault: true,
    migrations: { directory: config.migrationsDir }
  });
}

export async function migrateDatabase(db: Knex) {
  await db.migrate.latest();
}

export async function checkDatabaseHealth(db: Knex): Promise<boolean> {
  try {
    await db.raw('select 1+1 as result');
    return true;
  } catch (error) {
    return false;
  }
}
