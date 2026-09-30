// Cross-checks the Dart data layer against the real schema.
//
// Builds the schema by executing every migration in a real PostgreSQL engine,
// then extracts the column names the Dart code writes to each table and asserts
// every one of them exists. This catches the class of bug where Dart writes a
// column the database does not have, which only surfaces at runtime as a
// PostgREST 400.
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
for (const f of readdirSync(MIG).filter((x) => x.endsWith('.sql')).sort()) {
  await db.exec(readFileSync(path.join(MIG, f), 'utf8')
    .replace(/CREATE\s+EXTENSION\s+IF\s+NOT\s+EXISTS\s+"uuid-ossp"\s*;/gi, ''));
}

const cols = new Map();
for (const r of (await db.query(
  `SELECT table_name, column_name FROM information_schema.columns
    WHERE table_schema='public'`)).rows) {
  if (!cols.has(r.table_name)) cols.set(r.table_name, new Set());
  cols.get(r.table_name).add(r.column_name);
}
// Views are queried too, so include them.
console.log(`schema built: ${cols.size} relations\n`);

// The column sets the Dart layer writes, taken from the source.
const contracts = {
  sales: [
    'id', 'tenant_id', 'branch_id', 'invoice_number', 'invoice_date',
    'customer_name', 'customer_phone', 'customer_gstin', 'billing_type',
    'doctor_name', 'doctor_mci_no', 'subtotal', 'item_discount_total',
    'invoice_discount', 'taxable_amount', 'cgst_amount', 'sgst_amount',
    'igst_amount', 'total_gst', 'round_off', 'grand_total', 'payment_mode',
    'payment_status', 'authorized_pharmacist_id', 'pharmacist_authorized_name',
    'is_synced', 'created_by', 'created_at', 'updated_at',
  ],
  sale_items: [
    'id', 'sale_id', 'tenant_id', 'product_id', 'batch_id', 'product_name',
    'hsn_code', 'batch_number', 'expiry_date', 'quantity', 'free_quantity',
    'unit_price', 'ptr_price', 'mrp', 'line_discount', 'taxable_value',
    'gst_percent', 'cgst_amount', 'sgst_amount', 'igst_amount', 'line_total',
    'created_at',
  ],
  tenants: [
    'id', 'business_name', 'owner_name', 'email', 'phone', 'gstin',
    'drug_license_no', 'drug_license_expiry', 'address', 'city', 'state',
    'pincode', 'logo_url', 'industry_type', 'business_mode',
    'subscription_plan', 'subscription_status', 'max_branches', 'is_active',
    'created_at', 'updated_at',
  ],
  users: ['id', 'tenant_id', 'name', 'email', 'role', 'is_active'],
  pharmacists: [
    'id', 'tenant_id', 'name', 'email', 'phone', 'license_no',
    'registration_no', 'pharmacist_pin_hash', 'pin_salt', 'is_active',
    'created_at', 'updated_at',
  ],
  demo_requests: [
    'id', 'name', 'business_name', 'mobile', 'email', 'city', 'pincode',
    'business_type', 'num_branches', 'message', 'status', 'created_at',
  ],
  pricing_plans: [
    'id', 'plan_name', 'plan_code', 'price', 'gst_applicable', 'gst_percent',
    'max_users', 'max_branches', 'max_products', 'features', 'is_active',
    'display_order',
  ],
  branches: [
    'id', 'tenant_id', 'branch_name', 'branch_code', 'address', 'city', 'state',
    'pincode', 'gstin', 'drug_license_no', 'drug_license_expiry', 'phone',
    'email', 'manager_name', 'is_active', 'created_at', 'updated_at',
  ],
  products: [
    'id', 'tenant_id', 'name', 'generic_salt', 'manufacturer', 'hsn_code',
    'gst_percent', 'is_schedule_h', 'is_schedule_h1', 'is_narcotic',
    'is_prescription_required', 'is_chronic', 'barcode', 'reorder_level',
    'dosage_form', 'packaging_type', 'pack_size', 'dose_type',
    'packaging_units_per_strip', 'packaging_strips_per_box', 'packaging_label',
    'default_mrp', 'default_ptr', 'default_purchase_price',
    'default_selling_price', 'default_wholesale_price',
    'created_at', 'updated_at',
  ],
  batches: [
    'id', 'product_id', 'tenant_id', 'branch_id', 'batch_number', 'mfg_date',
    'exp_date', 'purchase_price', 'ptr_price', 'mrp', 'selling_price',
    'wholesale_price', 'stock_quantity', 'rack_location',
    'created_at', 'updated_at',
  ],
  near_expiry_stock: [
    'tenant_id', 'branch_id', 'branch_name', 'product_name', 'batch_number',
    'exp_date', 'stock_quantity', 'mrp', 'ptr_price', 'days_until_expiry',
    'expiry_status',
  ],
  tenant_dashboard_metrics: [
    'tenant_id', 'business_name', 'total_products', 'total_sales',
    'total_revenue',
  ],
};

let missing = 0;
let checked = 0;
for (const [table, expected] of Object.entries(contracts)) {
  const actual = cols.get(table);
  if (!actual) {
    console.log(`MISSING RELATION  ${table}`);
    missing += expected.length;
    continue;
  }
  const absent = expected.filter((c) => !actual.has(c));
  checked += expected.length;
  if (absent.length === 0) {
    console.log(`OK    ${table.padEnd(26)} ${expected.length} columns present`);
  } else {
    missing += absent.length;
    console.log(`FAIL  ${table.padEnd(26)} missing: ${absent.join(', ')}`);
  }
}

console.log(`\n${checked - missing}/${checked} Dart-written columns exist in the schema`);
await db.close();
process.exit(missing === 0 ? 0 : 1);
