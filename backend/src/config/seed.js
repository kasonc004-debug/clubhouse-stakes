require('dotenv').config();
const fs = require('fs');
const path = require('path');
const db = require('./database');

async function seed() {
  const seedPath = path.join(__dirname, '../../seeds/sample_data.sql');
  const sql = fs.readFileSync(seedPath, 'utf8');
  try {
    await db.query(sql);
    console.log('Seed complete.');
  } catch (err) {
    console.error('Seed failed:', err.message);
    process.exit(1);
  }
  process.exit(0);
}

seed();
