require('dotenv').config();
const fs = require('fs');
const path = require('path');
const db = require('./database');

const MIGRATIONS = ['001_schema.sql', '002_skins.sql'];

async function migrate() {
  for (const file of MIGRATIONS) {
    const filePath = path.join(__dirname, '../../migrations', file);
    if (!fs.existsSync(filePath)) {
      console.log(`Migration ${file} not found — skipping.`);
      continue;
    }
    const sql = fs.readFileSync(filePath, 'utf8');
    try {
      await db.query(sql);
      console.log(`Migration ${file} complete.`);
    } catch (err) {
      if (err.code === '42P07') {
        console.log(`Migration ${file}: Tables already exist — skipping.`);
      } else {
        console.error(`Migration ${file} failed:`, err.message);
        process.exit(1);
      }
    }
  }
  process.exit(0);
}

migrate();
