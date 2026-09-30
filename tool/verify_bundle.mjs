// Executes supabase/apply_all.sql as a SINGLE script against real PostgreSQL,
// seeded with a replica of the live legacy schema (text ids, NULL companyId).
// This validates the exact artifact that will be pasted into the SQL Editor,
// not just the individual migration files.
//
// Runs it twice, because the bundle must be safe to re-run.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const BUNDLE = path.join(ROOT, 'supabase', 'apply_all.sql');

const { PGlite } = await import('@electric-sql/pglite');
const db = await PGlite.create();

console.log('engine:', (await db.query('select version() v')).rows[0].v.split(',')[0]);

// Supabase-provided objects that a bare Postgres lacks.
// Only uuid-ossp is stripped from the SQL (unavailable in WASM); everything else
// in the bundle executes verbatim.
await db.exec(`
  CREATE OR REPLACE FUNCTION uuid_generate_v4() RETURNS uuid AS $$
    SELECT gen_random_uuid(); $$ LANGUAGE sql VOLATILE;
  CREATE SCHEMA IF NOT EXISTS auth;
  CREATE TABLE IF NOT EXISTS auth.users (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), email TEXT);
  CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid; $$ LANGUAGE sql STABLE;
  DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
  END $$;
`);

// Replica of the LIVE schema, matching the service-role reading exactly:
// 6 tables, invoices holding 7 rows with text ids and NULL companyId.
await db.exec(`
  CREATE TABLE companies ("id" TEXT PRIMARY KEY, "createdAt" TIMESTAMPTZ DEFAULT now(),
    "businessName" TEXT, "ownerName" TEXT, "email" TEXT, "phone" TEXT, "gstin" TEXT,
    "address" TEXT, "drugLicenseNo" TEXT, "industryType" TEXT, "isActive" BOOLEAN DEFAULT true);
  CREATE TABLE invoices ("id" TEXT PRIMARY KEY, "timestamp" TIMESTAMPTZ DEFAULT now(),
    "companyId" TEXT, "invoiceNumber" TEXT, "customerName" TEXT, "customerPhone" TEXT,
    "doctorName" TEXT, "doctorMciNo" TEXT, "items" JSONB, "discountAmount" NUMERIC,
    "paymentMode" TEXT, "isSynced" BOOLEAN, "pharmacistPinApprovedBy" TEXT);
  CREATE TABLE ledger_entries ("id" TEXT PRIMARY KEY, "amount" NUMERIC, "description" TEXT);
  CREATE TABLE restricted_drug_logs ("id" TEXT PRIMARY KEY, "timestamp" TIMESTAMPTZ DEFAULT now(),
    "companyId" TEXT, "invoiceNumber" TEXT, "doctorName" TEXT, "productName" TEXT);
  CREATE TABLE stock_transfers ("id" TEXT PRIMARY KEY, "timestamp" TIMESTAMPTZ DEFAULT now(),
    "productName" TEXT, "batchNumber" TEXT, "quantity" INTEGER, "status" TEXT);
  CREATE TABLE ota_releases ("id" TEXT PRIMARY KEY, "latestVersion" TEXT,
    "releasedAt" TIMESTAMPTZ DEFAULT now());
`);

// The 7 live invoice rows, reproduced faithfully.
const live = [
  ['inv_1790366744736', 'INV-66744736', '2026-09-26T01:35:44.736Z', '[]', 0, 'cash', true, null],
  ['inv_1790369550569', 'INV-69550569', '2026-09-26T02:22:30.569Z', '[{"quantity":1,"unitPrice":120}]', 0, 'cash', true, 'Pharmacist PIN #1234'],
  ['inv_1790411018953', 'INV-11018953', '2026-09-26T13:53:38.953Z', '[{"quantity":2,"unitPrice":45}]', 0, 'cash', false, null],
  ['inv_1790411076080', 'INV-11076080', '2026-09-26T13:54:36.080Z', '[]', 0, 'card', false, null],
  ['inv_1790424113661', 'INV-24113661', '2026-09-26T17:31:53.661Z', '[{"quantity":1,"unitPrice":80},{"quantity":3,"unitPrice":25}]', 0, 'card', true, 'Pharmacist PIN #1234'],
  ['inv_1790424279452', 'INV-24279452', '2026-09-26T17:34:39.452Z', '[{"quantity":1,"unitPrice":60},{"quantity":2,"unitPrice":30},{"quantity":1,"unitPrice":15}]', 0, 'cash', true, 'Pharmacist PIN #1234'],
  ['inv_1790428775458', 'INV-28775458', '2026-09-26T18:49:35.458Z', '[{"quantity":1,"unitPrice":95}]', 0, 'cash', true, 'Pharmacist PIN #1234'],
];
for (const [id, num, ts, items, disc, mode, synced, pin] of live) {
  await db.query(
    `INSERT INTO invoices ("id","companyId","invoiceNumber","timestamp","customerName",
       "customerPhone","doctorName","doctorMciNo","items","discountAmount",
       "paymentMode","isSynced","pharmacistPinApprovedBy")
     VALUES ($1,NULL,$2,$3,'Walk-in Customer','+447747571513','Dr. A. Smith','MCI-88492',
       $4::jsonb,$5,$6,$7,$8)`,
    [id, num, ts, items, disc, mode, synced, pin]
  );
}

const before = Number((await db.query('select count(*)::int c from invoices')).rows[0].c);
console.log(`seeded live replica: ${before} invoice row(s), 0 companies\n`);

const bundleRaw = readFileSync(BUNDLE, 'utf8');
const bundle = bundleRaw.replace(
  /CREATE\s+EXTENSION\s+IF\s+NOT\s+EXISTS\s+"uuid-ossp"\s*;/gi,
  '-- [harness] uuid-ossp unavailable in WASM; uuid_generate_v4 shimmed above'
);

async function run(label) {
  console.log(`=== ${label} ===`);
  const notices = [];
  const onNotice = (n) => notices.push(n.message ?? String(n));
  db.onNotice?.(onNotice);
  try {
    await db.exec(bundle);
    console.log('  bundle executed without error');
  } catch (e) {
    console.error(`  FAILED: ${e.message}`);
    return false;
  }
  notices.filter((n) => /\[009\]|SUCCESS|WARNING|not migrated/i.test(n))
    .slice(0, 12).forEach((n) => console.log(`    notice: ${n}`));
  return true;
}

if (!await run('PASS 1')) process.exit(1);

const snap = async () => {
  const q = async (s) => Number((await db.query(s)).rows[0].c);
  return {
    tables: await q(`select count(*)::int c from information_schema.tables where table_schema='public'`),
    columns: await q(`select count(*)::int c from information_schema.columns where table_schema='public'`),
    policies: await q(`select count(*)::int c from pg_policies where schemaname='public'`),
    indexes: await q(`select count(*)::int c from pg_indexes where schemaname='public'`),
    ledger: await q(`select count(*)::int c from _migrations`),
    legacyInvoices: await q(`select count(*)::int c from invoices_legacy_v0`),
    sales: await q(`select count(*)::int c from sales`),
    tenants: await q(`select count(*)::int c from tenants`),
    plans: await q(`select count(*)::int c from pricing_plans`),
  };
};

const first = await snap();
console.log('\nafter pass 1:', JSON.stringify(first));

if (!await run('PASS 2 (re-run the same bundle)')) {
  console.error('\nBundle is not safe to re-run.');
  process.exit(1);
}
const second = await snap();
console.log('\nafter pass 2:', JSON.stringify(second));

console.log('\n=== STABILITY ===');
let drift = 0;
for (const k of Object.keys(first)) {
  const same = first[k] === second[k];
  if (!same) drift++;
  console.log(`  ${same ? 'STABLE' : 'DRIFT '}  ${k.padEnd(16)} ${first[k]} -> ${second[k]}`);
}

console.log('\n=== DATA PRESERVATION ===');
const kept = Number((await db.query('select count(*)::int c from invoices_legacy_v0')).rows[0].c);
console.log(`  legacy invoices retained : ${kept} of ${before}`);
if (kept !== before) { drift++; console.log('  DATA LOSS'); }

const migrated = Number((await db.query('select count(*)::int c from sales')).rows[0].c);
console.log(`  migrated into sales      : ${migrated} (expected 0; all companyId are NULL)`);

console.log('\n=== BILLING OBJECTS ===');
for (const [t, c] of [
  ['sale_items', 'tenant_id'], ['sales', 'billing_type'],
  ['sales', 'customer_gstin'], ['sales', 'authorized_pharmacist_id'],
  ['products', 'is_chronic'], ['pharmacists', 'pin_salt'],
]) {
  const ok = (await db.query(
    `select 1 from information_schema.columns
      where table_schema='public' and table_name=$1 and column_name=$2`, [t, c])).rows.length > 0;
  if (!ok) drift++;
  console.log(`  ${ok ? 'PRESENT' : 'MISSING'}  ${t}.${c}`);
}

console.log(drift === 0
  ? '\nRESULT: apply_all.sql is correct, idempotent, and preserves all legacy rows.'
  : `\nRESULT: ${drift} problem(s).`);
await db.close();
process.exit(drift === 0 ? 0 : 1);
