require('dotenv').config();
const fs = require('fs');
const path = require('path');
const db = require('./database');

async function migrate() {
  const schemaPath = path.join(__dirname, '../../migrations/001_schema.sql');
  const sql = fs.readFileSync(schemaPath, 'utf8');
  try {
    await db.query(sql);
    console.log('Migration complete.');
  } catch (err) {
    if (err.code === '42P07') {
      console.log('Tables already exist — skipping migration.');
    } else {
      console.error('Migration failed:', err.message);
      process.exit(1);
    }
  }
  process.exit(0);
}

migrate();
