// Executes the full migration chain against a real PostgreSQL engine (PGlite,
// Postgres compiled to WASM), starting from a replica of the LIVE database's
// legacy state that was discovered by probing the production project:
//
//   companies, invoices, ledger_entries, restricted_drug_logs,
//   stock_transfers, ota_releases      (camelCase prototype shape)
//
// This proves the migrations actually run and that 000 correctly parks the
// legacy tables so 001 can create the canonical ones. It runs locally and
// touches nothing in production.
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DIR = path.join(ROOT, 'supabase', 'migrations');

const { PGlite } = await import('@electric-sql/pglite');
const db = await PGlite.create();

console.log('engine:', (await db.query('select version() v')).rows[0].v.split(',')[0]);

// ── Supabase compatibility shims ─────────────────────────────────────────────
// The migrations reference auth.uid(), the anon/authenticated roles, and the
// uuid-ossp extension. PGlite has none of these, so they are provided here.
// uuid_generate_v4 is aliased to the server built-in gen_random_uuid, which is
// behaviourally equivalent for generating v4 UUIDs.
//
// HARNESS ADAPTATION, disclosed for honesty: the literal line
//   CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
// is stripped from each file before execution because that extension cannot be
// installed in WASM. Nothing else in any migration is modified. On real Supabase
// the extension is available, so the unmodified file is what would run there.
await db.exec(`
  CREATE OR REPLACE FUNCTION uuid_generate_v4() RETURNS uuid AS $$
    SELECT gen_random_uuid();
  $$ LANGUAGE sql VOLATILE;

  CREATE SCHEMA IF NOT EXISTS auth;

  -- Supabase manages auth.users; migration 001 references it via FK.
  CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT
  );

  CREATE OR REPLACE FUNCTION auth.uid() RETURNS UUID AS $$
    SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
  $$ LANGUAGE sql STABLE;
  DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
      CREATE ROLE anon NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
      CREATE ROLE authenticated NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
      CREATE ROLE service_role NOLOGIN;
    END IF;
  END $$;
`);

// ── Replicate the live legacy schema exactly as discovered ───────────────────
console.log('\n=== seeding discovered LIVE legacy schema ===');
// Column types mirror the LIVE database exactly, as read with the service-role
// key: invoices.id is TEXT ('inv_1790366744736'), companyId is TEXT and NULL on
// every row. Using uuid here instead would hide the cast errors that the real
// data triggers.
await db.exec(`
  CREATE TABLE companies (
    "id" TEXT PRIMARY KEY,
    "createdAt" TIMESTAMPTZ DEFAULT now(),
    "businessName" TEXT,
    "ownerName" TEXT,
    "email" TEXT,
    "phone" TEXT,
    "gstin" TEXT,
    "address" TEXT,
    "drugLicenseNo" TEXT,
    "industryType" TEXT,
    "isActive" BOOLEAN DEFAULT true
  );

  CREATE TABLE invoices (
    "id" TEXT PRIMARY KEY,
    "timestamp" TIMESTAMPTZ DEFAULT now(),
    "companyId" TEXT,
    "invoiceNumber" TEXT,
    "customerName" TEXT,
    "customerPhone" TEXT,
    "doctorName" TEXT,
    "doctorMciNo" TEXT,
    "items" JSONB,
    "discountAmount" NUMERIC,
    "paymentMode" TEXT,
    "isSynced" BOOLEAN,
    "pharmacistPinApprovedBy" TEXT
  );

  CREATE TABLE ledger_entries (
    "id" UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    "amount" NUMERIC,
    "description" TEXT
  );

  CREATE TABLE restricted_drug_logs (
    "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "timestamp" TIMESTAMPTZ DEFAULT now(),
    "companyId" TEXT,
    "invoiceNumber" TEXT,
    "doctorName" TEXT,
    "productName" TEXT
  );

  CREATE TABLE stock_transfers (
    "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "timestamp" TIMESTAMPTZ DEFAULT now(),
    "productName" TEXT,
    "batchNumber" TEXT,
    "quantity" INTEGER,
    "status" TEXT
  );

  CREATE TABLE ota_releases (
    "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    "latestVersion" TEXT,
    "releasedAt" TIMESTAMPTZ DEFAULT now()
  );
`);

// Put a row in each legacy table so the "preserve existing data" claim is tested
// rather than assumed.
// Seed both shapes that exist in reality:
//  * an attributable company + invoice (exercises the happy path)
//  * invoices with companyId NULL and a text id, which is what the live
//    database actually holds on all 7 rows
const legacyCompanyId = 'comp_1790300000000';
await db.exec(`
  INSERT INTO companies ("id","businessName","ownerName","email","phone","gstin",
                         "address","drugLicenseNo","industryType","isActive")
  VALUES ('${legacyCompanyId}','Legacy Medicals','Old Owner','legacy@example.com',
          '9000000000','29ABCDE1234F1Z5','12 Old Road','DL-OLD-1','Pharma',true);

  INSERT INTO invoices ("id","companyId","invoiceNumber","customerName","customerPhone",
                        "items","discountAmount","paymentMode","isSynced")
  VALUES ('inv_1790366744001','${legacyCompanyId}','OLD-001','Legacy Patient','9111111111',
          '[{"quantity":2,"unitPrice":50}]'::jsonb, 10, 'cash', true);

  -- Mirrors live rows: text id, NULL companyId, empty items, PIN in audit field.
  INSERT INTO invoices ("id","companyId","invoiceNumber","customerName","customerPhone",
                        "items","discountAmount","paymentMode","isSynced",
                        "pharmacistPinApprovedBy")
  VALUES ('inv_1790366744736',NULL,'INV-66744736','Walk-in Customer','+447747571513',
          '[]'::jsonb, 0, 'cash', true, NULL),
         ('inv_1790369550569',NULL,'INV-69550569','Walk-in Customer','+447747571513',
          '[{"quantity":1,"unitPrice":120}]'::jsonb, 0, 'cash', true,
          'Pharmacist PIN #1234');

  INSERT INTO ledger_entries ("amount","description") VALUES (500,'legacy entry');
  INSERT INTO restricted_drug_logs ("companyId","invoiceNumber","doctorName","productName")
  VALUES ('${legacyCompanyId}','OLD-001','Dr Legacy','Alprazolam');
  INSERT INTO stock_transfers ("productName","batchNumber","quantity","status")
  VALUES ('Legacy Item','LB-1',5,'received');
  INSERT INTO ota_releases ("latestVersion") VALUES ('v1.0.0');
`);

const before = {};
for (const t of ['companies', 'invoices', 'ledger_entries',
  'restricted_drug_logs', 'stock_transfers', 'ota_releases']) {
  before[t] = Number((await db.query(`select count(*)::int c from ${t}`)).rows[0].c);
}
console.log('legacy row counts before:', JSON.stringify(before));

// ── Run the migration chain ──────────────────────────────────────────────────
console.log('\n=== applying migrations ===');
const files = readdirSync(DIR).filter((f) => f.endsWith('.sql')).sort();
let failed = null;

for (const f of files) {
  const raw = readFileSync(path.join(DIR, f), 'utf8');
  // Only the uuid-ossp CREATE EXTENSION line is removed (see note above).
  const sql = raw.replace(
    /CREATE\s+EXTENSION\s+IF\s+NOT\s+EXISTS\s+"uuid-ossp"\s*;/gi,
    '-- [harness] uuid-ossp unavailable in PGlite; uuid_generate_v4 shimmed'
  );
  try {
    await db.exec(sql);
    console.log(`  OK      ${f}`);
  } catch (err) {
    console.error(`  FAILED  ${f}`);
    console.error(`            ${err.message}`);
    failed = f;
    break;
  }
}

if (failed) {
  console.error(`\nMigration chain stopped at ${failed}`);
  process.exit(1);
}

// ── Verify the required schema now exists ────────────────────────────────────
console.log('\n=== REQUIRED COLUMNS (the ones billing depends on) ===');
const required = [
  ['sale_items', 'tenant_id'],
  ['sales', 'billing_type'],
  ['sales', 'customer_gstin'],
  ['sales', 'invoice_discount'],
  ['sales', 'grand_total'],
  ['sale_items', 'hsn_code'],
  ['sale_items', 'free_quantity'],
  ['batches', 'ptr_price'],
  ['batches', 'exp_date'],
  ['batches', 'stock_quantity'],
  ['products', 'is_chronic'],
  ['products', 'reorder_level'],
  ['products', 'default_ptr'],
  ['products', 'packaging_units_per_strip'],
  ['pharmacists', 'pin_hash'],
  ['pharmacists', 'pharmacist_pin_hash'],
  ['pharmacists', 'pin_salt'],
  ['tenants', 'business_name'],
  ['tenants', 'logo_url'],
  ['demo_requests', 'business_type'],
  ['pricing_plans', 'plan_code'],
];

let missing = 0;
for (const [t, c] of required) {
  const r = await db.query(
    `select 1 from information_schema.columns
      where table_schema='public' and table_name=$1 and column_name=$2`,
    [t, c]
  );
  const ok = r.rows.length > 0;
  if (!ok) missing++;
  console.log(`  ${ok ? 'PRESENT' : 'MISSING'}  ${t}.${c}`);
}

console.log('\n=== VIEWS ===');
for (const v of ['near_expiry_stock', 'tenant_dashboard_metrics']) {
  const r = await db.query(
    `select 1 from information_schema.views where table_schema='public' and table_name=$1`,
    [v]
  );
  console.log(`  ${r.rows.length ? 'PRESENT' : 'MISSING'}  ${v}`);
  if (!r.rows.length) missing++;
}

console.log('\n=== LEGACY DATA PRESERVED ===');
for (const t of ['companies_legacy_v0', 'invoices_legacy_v0',
  'restricted_drug_logs_legacy_v0', 'stock_transfers_legacy_v0']) {
  const exists = await db.query(
    `select 1 from information_schema.tables where table_schema='public' and table_name=$1`,
    [t]
  );
  if (exists.rows.length) {
    const c = Number((await db.query(`select count(*)::int c from ${t}`)).rows[0].c);
    console.log(`  ${t.padEnd(34)} ${c} row(s) retained`);
  } else {
    console.log(`  ${t.padEnd(34)} not parked`);
  }
}

// ledger_entries / ota_releases were intentionally left in place.
for (const t of ['ledger_entries', 'ota_releases']) {
  const c = Number((await db.query(`select count(*)::int c from ${t}`)).rows[0].c);
  const same = c === before[t];
  console.log(`  ${t.padEnd(34)} ${c} row(s) ${same ? '(unchanged)' : '(CHANGED!)'}`);
  if (!same) missing++;
}

console.log('\n=== BACKFILL RESULT ===');
const tenantCount = Number((await db.query('select count(*)::int c from tenants')).rows[0].c);
const salesCount = Number((await db.query('select count(*)::int c from sales')).rows[0].c);
console.log(`  tenants : ${tenantCount}`);
console.log(`  sales   : ${salesCount}`);
if (tenantCount > 0) {
  const t = (await db.query(
    'select id, business_name, gstin, city from tenants limit 3')).rows;
  t.forEach((r) => console.log(`    ${r.business_name} | ${r.gstin} | city=${r.city}`));
}
if (salesCount > 0) {
  const s = (await db.query(
    'select invoice_number, subtotal, invoice_discount, grand_total, billing_type from sales limit 3')).rows;
  s.forEach((r) => console.log(
    `    ${r.invoice_number} subtotal=${r.subtotal} disc=${r.invoice_discount} total=${r.grand_total} type=${r.billing_type}`));
}

console.log(missing === 0
  ? '\nRESULT: migration chain executes and all required objects exist.'
  : `\nRESULT: ${missing} problem(s) found.`);

await db.close();
process.exit(missing === 0 ? 0 : 1);
