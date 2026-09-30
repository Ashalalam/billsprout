// Applies the entire migration chain TWICE against the same database.
// The second pass must succeed and must not duplicate or destroy anything,
// because these files will be re-applied to a live database.
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const MIG = path.join(ROOT, 'supabase', 'migrations');
const { PGlite } = await import('@electric-sql/pglite');
const db = await PGlite.create();

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

// Seed the legacy shape so 000 has something real to park on pass 1.
await db.exec(`
  CREATE TABLE companies ("id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "createdAt" TIMESTAMPTZ DEFAULT now(), "businessName" TEXT, "ownerName" TEXT,
    "email" TEXT, "phone" TEXT, "gstin" TEXT, "address" TEXT,
    "drugLicenseNo" TEXT, "industryType" TEXT, "isActive" BOOLEAN DEFAULT true);
  CREATE TABLE restricted_drug_logs ("id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "timestamp" TIMESTAMPTZ DEFAULT now(), "companyId" UUID, "invoiceNumber" TEXT,
    "doctorName" TEXT, "productName" TEXT);
  CREATE TABLE stock_transfers ("id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "timestamp" TIMESTAMPTZ DEFAULT now(), "productName" TEXT, "batchNumber" TEXT,
    "quantity" INTEGER, "status" TEXT);
  INSERT INTO companies ("businessName","ownerName","email","phone","gstin","address","drugLicenseNo","industryType")
    VALUES ('Legacy Co','O','l@x.com','9','29A','addr','DL','Pharma');
`);

const files = readdirSync(MIG).filter((f) => f.endsWith('.sql')).sort();
const read = (f) => readFileSync(path.join(MIG, f), 'utf8')
  .replace(/CREATE\s+EXTENSION\s+IF\s+NOT\s+EXISTS\s+"uuid-ossp"\s*;/gi, '');

async function runPass(label) {
  console.log(`\n=== ${label} ===`);
  for (const f of files) {
    try {
      await db.exec(read(f));
      console.log(`  OK      ${f}`);
    } catch (e) {
      console.error(`  FAILED  ${f}: ${e.message}`);
      return false;
    }
  }
  return true;
}

async function snapshot() {
  const q = async (sql) => Number((await db.query(sql)).rows[0].c);
  return {
    tables: await q(`select count(*)::int c from information_schema.tables where table_schema='public'`),
    columns: await q(`select count(*)::int c from information_schema.columns where table_schema='public'`),
    policies: await q(`select count(*)::int c from pg_policies where schemaname='public'`),
    indexes: await q(`select count(*)::int c from pg_indexes where schemaname='public'`),
    triggers: await q(`select count(*)::int c from information_schema.triggers where trigger_schema='public'`),
    tenants: await q(`select count(*)::int c from tenants`),
    plans: await q(`select count(*)::int c from pricing_plans`),
    legacyCompanies: await q(`select count(*)::int c from companies_legacy_v0`),
  };
}

if (!await runPass('PASS 1')) process.exit(1);
const first = await snapshot();
console.log('\nafter pass 1:', JSON.stringify(first, null, 0));

if (!await runPass('PASS 2 (re-apply)')) {
  console.error('\nMigrations are NOT idempotent: second pass failed.');
  process.exit(1);
}
const second = await snapshot();
console.log('\nafter pass 2:', JSON.stringify(second, null, 0));

console.log('\n=== COMPARISON ===');
let drift = 0;
for (const k of Object.keys(first)) {
  const same = first[k] === second[k];
  if (!same) drift++;
  console.log(`  ${same ? 'STABLE' : 'DRIFT '}  ${k.padEnd(18)} ${first[k]} -> ${second[k]}`);
}

// Duplicate seed rows are the classic idempotency failure.
const dupPlans = Number((await db.query(
  `select count(*)::int c from (select plan_code from pricing_plans
     group by plan_code having count(*) > 1) d`)).rows[0].c);
console.log(`  ${dupPlans === 0 ? 'STABLE' : 'DRIFT '}  duplicate plan_codes  ${dupPlans}`);
if (dupPlans !== 0) drift++;

console.log(drift === 0
  ? '\nRESULT: migrations are idempotent, re-applying changes nothing.'
  : `\nRESULT: ${drift} drift(s) detected.`);
await db.close();
process.exit(drift === 0 ? 0 : 1);
