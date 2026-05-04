require('dotenv').config();
const fs = require('fs');
const path = require('path');
const db = require('./database');

// Auto-discover every .sql file in migrations/ and run in lexical order.
// All migrations are idempotent (IF NOT EXISTS / ADD COLUMN IF NOT EXISTS etc.),
// so running this on every deploy is safe.
const MIGRATIONS_DIR = path.join(__dirname, '../../migrations');

async function migrate() {
  const files = fs.readdirSync(MIGRATIONS_DIR)
    .filter(f => f.endsWith('.sql'))
    .sort();

  if (!files.length) {
    console.log('No migrations found.');
    process.exit(0);
  }

  // Postgres SQLSTATE codes for "already exists" things we can safely skip:
  // 42P07 duplicate_table, 42710 duplicate_object (triggers, indexes, types),
  // 42P06 duplicate_schema, 42723 duplicate_function, 42701 duplicate_column.
  const SKIPPABLE = new Set(['42P07', '42710', '42P06', '42723', '42701']);

  for (const file of files) {
    const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8');
    try {
      await db.query(sql);
      console.log(`Migration ${file} complete.`);
    } catch (err) {
      if (SKIPPABLE.has(err.code) || /already exists/i.test(err.message)) {
        console.log(`Migration ${file}: already applied — skipping (${err.message.split('\n')[0]}).`);
      } else {
        console.error(`Migration ${file} failed:`, err.message);
        process.exit(1);
      }
    }
  }
  process.exit(0);
}

migrate();
