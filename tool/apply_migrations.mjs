#!/usr/bin/env node
// Applies supabase/migrations/*.sql to the project's database over a direct
// Postgres connection, in filename order, each file in its own transaction.
//
// Requires a credential that can run DDL. The anon key cannot, so this reads,
// in order of preference:
//   SUPABASE_DB_URL       full postgres connection string
//   SUPABASE_DB_PASSWORD  database password (host derived from SUPABASE_URL)
//
// Usage:
//   node tool/apply_migrations.mjs --check      report applied state, change nothing
//   node tool/apply_migrations.mjs              apply pending migrations
//   node tool/apply_migrations.mjs --file 007_x.sql   apply one file
//
// A _migrations ledger table records what has run, so re-running is safe.
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import crypto from 'node:crypto';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const MIGRATIONS_DIR = path.join(ROOT, 'supabase', 'migrations');

function loadEnv() {
  const out = { ...process.env };
  try {
    const raw = readFileSync(path.join(ROOT, '.env'), 'utf8');
    for (const line of raw.split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$/);
      if (m && !out[m[1]]) out[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
  } catch { /* .env optional */ }
  return out;
}

const env = loadEnv();

function buildConnectionString() {
  if (env.SUPABASE_DB_URL) return env.SUPABASE_DB_URL;

  const password = env.SUPABASE_DB_PASSWORD;
  if (!password) return null;

  const url = env.SUPABASE_URL;
  if (!url) return null;
  const ref = new URL(url).hostname.split('.')[0];

  // Pooler region for this project, established by probing which Supavisor host
  // recognises the tenant: a wrong host answers "Tenant or user not found",
  // the right one answers "password authentication failed".
  const region = env.SUPABASE_DB_REGION || 'ap-southeast-2';
  const host = `aws-0-${region}.pooler.supabase.com`;
  return `postgresql://postgres.${ref}:${encodeURIComponent(password)}@${host}:5432/postgres`;
}

function migrationFiles() {
  return readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();
}

function sha(text) {
  return crypto.createHash('sha256').update(text).digest('hex').slice(0, 16);
}

async function main() {
  const args = process.argv.slice(2);
  const checkOnly = args.includes('--check');
  const oneFile = args.includes('--file')
    ? args[args.indexOf('--file') + 1]
    : null;

  const files = oneFile ? [oneFile] : migrationFiles();

  console.log(`migrations dir : ${MIGRATIONS_DIR}`);
  console.log(`files          : ${files.length}`);
  files.forEach((f) => {
    const sql = readFileSync(path.join(MIGRATIONS_DIR, f), 'utf8');
    console.log(`   ${f}  (${sql.length} bytes, sha ${sha(sql)})`);
  });

  const conn = buildConnectionString();
  if (!conn) {
    console.error(`
CANNOT CONNECT: no Postgres credential available.

Verified against this project:
  * anon key          -> PostgREST only, RLS applies, no DDL
  * service_role key  -> PostgREST only, bypasses RLS, still NO DDL.
                         Tested as a Postgres password on
                         db.<ref>.supabase.co and the Supavisor pooler:
                         "password authentication failed". API keys are JWTs,
                         not database credentials.
  * supabase CLI      -> cannot link this project from the signed-in account
                         ("account does not have the necessary privileges")

TWO WAYS FORWARD

1. SQL Editor (no extra secret needed)
   Open supabase/apply_all.sql, paste the whole file into
   Dashboard -> SQL Editor -> New query, and Run.
   Then confirm with:  node tool/verify_live.mjs --write

2. Supply the database password and let this script do it
   Dashboard -> Project Settings -> Database -> Database password
   Add to .env:
       SUPABASE_DB_PASSWORD=<password>
   Then re-run: node tool/apply_migrations.mjs

   The direct host db.<ref>.supabase.co is IPv6-only; if this machine has no
   IPv6 route, use the pooler connection string instead:
       SUPABASE_DB_URL=postgresql://postgres.<ref>:<password>@aws-0-ap-southeast-2.pooler.supabase.com:5432/postgres

Nothing has been changed.`);
    process.exit(2);
  }

  let pg;
  try {
    pg = await import('pg');
  } catch {
    console.error(`
The 'pg' package is not installed. Install it with:
  npm install pg
Nothing has been changed.`);
    process.exit(3);
  }

  const { Client } = pg.default ?? pg;
  const client = new Client({
    connectionString: conn,
    ssl: { rejectUnauthorized: false },
    statement_timeout: 300000,
  });

  await client.connect();
  console.log('\nconnected');

  const info = await client.query(
    'select current_database() db, current_user usr, version() ver'
  );
  console.log(`database : ${info.rows[0].db}`);
  console.log(`user     : ${info.rows[0].usr}`);
  console.log(`server   : ${info.rows[0].ver.split(',')[0]}`);

  await client.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      filename   TEXT PRIMARY KEY,
      checksum   TEXT NOT NULL,
      applied_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
    )`);

  const applied = new Map(
    (await client.query('select filename, checksum from _migrations')).rows.map(
      (r) => [r.filename, r.checksum]
    )
  );

  console.log('\n=== STATE ===');
  for (const f of files) {
    const sql = readFileSync(path.join(MIGRATIONS_DIR, f), 'utf8');
    const prev = applied.get(f);
    const state = !prev
      ? 'PENDING'
      : prev === sha(sql)
        ? 'APPLIED'
        : 'APPLIED (content changed since)';
    console.log(`  ${f.padEnd(42)} ${state}`);
  }

  if (checkOnly) {
    console.log('\n--check: nothing applied.');
    await client.end();
    return;
  }

  console.log('\n=== APPLYING ===');
  let ok = 0;
  let skipped = 0;

  for (const f of files) {
    const sql = readFileSync(path.join(MIGRATIONS_DIR, f), 'utf8');
    const checksum = sha(sql);

    if (applied.get(f) === checksum) {
      console.log(`  SKIP    ${f} (already applied)`);
      skipped++;
      continue;
    }

    // Each file in its own transaction: a failure rolls that file back whole
    // rather than leaving the schema half-changed.
    try {
      await client.query('BEGIN');
      const notices = [];
      const onNotice = (n) => notices.push(n.message);
      client.on('notice', onNotice);

      await client.query(sql);

      await client.query(
        `INSERT INTO _migrations (filename, checksum) VALUES ($1, $2)
         ON CONFLICT (filename) DO UPDATE
           SET checksum = EXCLUDED.checksum, applied_at = CURRENT_TIMESTAMP`,
        [f, checksum]
      );
      await client.query('COMMIT');
      client.off('notice', onNotice);

      console.log(`  OK      ${f}`);
      notices.slice(0, 40).forEach((n) => console.log(`            ${n}`));
      ok++;
    } catch (err) {
      await client.query('ROLLBACK').catch(() => {});
      console.error(`  FAILED  ${f}`);
      console.error(`            ${err.message}`);
      if (err.position) console.error(`            at position ${err.position}`);
      console.error('\nStopped. Earlier files remain applied; this one was rolled back.');
      await client.end();
      process.exit(1);
    }
  }

  console.log(`\napplied ${ok}, skipped ${skipped}`);
  await client.end();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
