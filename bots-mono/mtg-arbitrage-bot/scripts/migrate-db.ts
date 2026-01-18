import { createDatabase, loadEnv, migrateDatabase } from 'shared-infra';
import { loadConfig } from '../src/config.js';

await loadEnv();
const config = loadConfig();
const db = createDatabase({
  databaseUrl: config.databaseUrl,
  sqlitePath: config.sqlitePath,
  migrationsDir: new URL('../migrations', import.meta.url).pathname
});
await migrateDatabase(db);
await db.destroy();
console.log('Database migrations complete.');
