#!/usr/bin/env node
/**
 * Grant or revoke admin access for a user by email.
 *
 * Usage:
 *   node scripts/grant-admin.js <email>           # promote to admin
 *   node scripts/grant-admin.js <email> --revoke  # revoke admin
 *   node scripts/grant-admin.js --list            # list all admins
 *
 * Environment: reads DATABASE_URL or DB_* vars (same as the API).
 *
 * On Railway: `railway run node scripts/grant-admin.js you@example.com`
 */

require('dotenv').config();
const db = require('../src/config/database');

async function main() {
  const args   = process.argv.slice(2);
  const list   = args.includes('--list');
  const revoke = args.includes('--revoke');
  const email  = args.find(a => !a.startsWith('--'));

  if (list) {
    const { rows } = await db.query(
      `SELECT name, email, created_at FROM users WHERE is_admin = TRUE ORDER BY created_at`
    );
    if (!rows.length) {
      console.log('No admins yet.');
    } else {
      console.log(`Admins (${rows.length}):`);
      rows.forEach(u => console.log(`  - ${u.name} <${u.email}>`));
    }
    process.exit(0);
  }

  if (!email) {
    console.error('Usage: node scripts/grant-admin.js <email> [--revoke]');
    console.error('       node scripts/grant-admin.js --list');
    process.exit(1);
  }

  const target = email.toLowerCase();
  const { rows } = await db.query(
    'SELECT id, name, email, is_admin FROM users WHERE email = $1',
    [target]
  );
  if (!rows.length) {
    console.error(`No user found with email: ${target}`);
    console.error('They need to sign up in the app first.');
    process.exit(1);
  }

  const user      = rows[0];
  const newValue  = !revoke;
  const verb      = revoke ? 'Revoking' : 'Granting';

  if (user.is_admin === newValue) {
    console.log(`${user.name} <${user.email}> is already ${newValue ? 'an admin' : 'not an admin'}. Nothing to do.`);
    process.exit(0);
  }

  await db.query('UPDATE users SET is_admin = $1 WHERE id = $2', [newValue, user.id]);
  console.log(`${verb} admin ${revoke ? 'from' : 'to'}: ${user.name} <${user.email}>`);
  process.exit(0);
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
