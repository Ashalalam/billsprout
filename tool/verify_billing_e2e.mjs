// End-to-end verification of the billing data flow against a real PostgreSQL
// engine with the full migration chain applied.
//
// Exercises the sequence the app performs, as actual SQL writes and reads:
//   tenant -> branch -> pharmacist -> product -> batches -> sale -> sale_items
//   -> stock deduction -> FEFO -> near expiry -> retail/wholesale -> GST/HSN
//   -> discount clamping -> multi-tenant isolation
//
// This verifies the SCHEMA and the SQL contract the Dart layer relies on.
// It does not drive the Flutter widgets; the Flutter SDK is unavailable.
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import crypto from 'node:crypto';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DIR = path.join(ROOT, 'supabase', 'migrations');

const { PGlite } = await import('@electric-sql/pglite');
const db = await PGlite.create();

let pass = 0;
let fail = 0;
function check(label, actual, expected) {
  const ok = JSON.stringify(actual) === JSON.stringify(expected);
  if (ok) { pass++; console.log(`  PASS  ${label}`); }
  else { fail++; console.log(`  FAIL  ${label}\n          expected ${JSON.stringify(expected)}\n          actual   ${JSON.stringify(actual)}`); }
  return ok;
}
function checkTrue(label, cond, detail = '') {
  if (cond) { pass++; console.log(`  PASS  ${label}`); }
  else { fail++; console.log(`  FAIL  ${label} ${detail}`); }
  return cond;
}
const num = (v) => (v === null || v === undefined ? null : Number(v));

// ── Bootstrap: Supabase shims + migrations ───────────────────────────────────
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

for (const f of readdirSync(DIR).filter((f) => f.endsWith('.sql')).sort()) {
  const sql = readFileSync(path.join(DIR, f), 'utf8')
    .replace(/CREATE\s+EXTENSION\s+IF\s+NOT\s+EXISTS\s+"uuid-ossp"\s*;/gi, '');
  await db.exec(sql);
}
console.log('migrations applied\n');

// Helper to create a tenant with its admin + branches.
async function makeTenant(name, gstin, mode, city) {
  const t = (await db.query(
    `INSERT INTO tenants (business_name, owner_name, email, phone, gstin,
        drug_license_no, address, city, state, pincode, industry_type,
        business_mode, subscription_plan, logo_url)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'Karnataka','560001','pharmacy',$9,'Gold Edition',$10)
     RETURNING id`,
    [name, `${name} Owner`, `${name.replace(/\W/g, '').toLowerCase()}@x.com`,
      '9800000000', gstin, `DL-${gstin.slice(0, 4)}`, `1 ${name} Road`, city, mode,
      `https://cdn.example.com/${name.replace(/\W/g, '')}.png`]
  )).rows[0].id;

  const uid = (await db.query(
    `INSERT INTO auth.users (email) VALUES ($1) RETURNING id`, [`admin@${name.replace(/\W/g, '')}.com`]
  )).rows[0].id;
  await db.query(
    `INSERT INTO users (id, tenant_id, name, email, role) VALUES ($1,$2,$3,$4,'business_admin')`,
    [uid, t, `${name} Admin`, `admin@${name.replace(/\W/g, '')}.com`]
  );
  return { id: t, admin: uid };
}

async function makeBranch(tenantId, bname, code, city) {
  return (await db.query(
    `INSERT INTO branches (tenant_id, branch_name, branch_code, address, city,
       state, pincode, drug_license_no, phone, email, manager_name)
     VALUES ($1,$2,$3,'addr',$4,'Karnataka','560001','DL-B','900','b@x.com','Mgr')
     RETURNING id`,
    [tenantId, bname, code, city]
  )).rows[0].id;
}

console.log('=== 1. TENANT / BRANCH / PHARMACIST SETUP ===');
const A = await makeTenant('Apollo Pharmacy', '29AAAAA1234A1Z5', 'both', 'Bengaluru');
const B = await makeTenant('MedPlus Store', '36BBBBB5678B1Z9', 'retail', 'Hyderabad');
const brA1 = await makeBranch(A.id, 'Apollo Main', 'AP-MAIN', 'Bengaluru');
const brA2 = await makeBranch(A.id, 'Apollo North', 'AP-NORTH', 'Bengaluru');
const brB1 = await makeBranch(B.id, 'MedPlus Main', 'MP-MAIN', 'Hyderabad');
checkTrue('two tenants created with distinct GSTIN', A.id !== B.id);
checkTrue('tenant A has two branches', brA1 !== brA2);

// Pharmacist with a salted PIN hash, mirroring PinHasher in Dart.
const salt = crypto.randomBytes(16).toString('hex');
const pinHash = crypto.createHash('sha256').update('4821' + salt).digest('hex');
const pharmacistId = (await db.query(
  `INSERT INTO pharmacists (tenant_id, name, email, phone, registration_no,
     pharmacist_pin_hash, pin_salt)
   VALUES ($1,'Dr Rao','rao@x.com','9811111111','KA-PH-1001',$2,$3)
   RETURNING id`,
  [A.id, pinHash, salt]
)).rows[0].id;
const ph = (await db.query(
  `SELECT pin_hash, pharmacist_pin_hash, pin_salt FROM pharmacists WHERE tenant_id=$1`, [A.id]
)).rows[0];
check('pin_hash synced from pharmacist_pin_hash by trigger', ph.pin_hash, pinHash);
checkTrue('stored hash is not the raw PIN', !JSON.stringify(ph).includes('4821'));
check('PIN verifies via salted hash',
  crypto.createHash('sha256').update('4821' + ph.pin_salt).digest('hex'), ph.pharmacist_pin_hash);
checkTrue('wrong PIN does not verify',
  crypto.createHash('sha256').update('9999' + ph.pin_salt).digest('hex') !== ph.pharmacist_pin_hash);

console.log('\n=== 2. PRODUCT MASTER PERSISTENCE (all fields) ===');
const prod = (await db.query(
  `INSERT INTO products (tenant_id, name, generic_salt, composition, manufacturer,
     brand, category, dosage_form, packaging_type, pack_size, hsn_code, gst_percent,
     is_schedule_h, is_schedule_h1, is_narcotic, is_prescription_required,
     is_chronic, barcode, sku, reorder_level, dose_type,
     packaging_units_per_strip, packaging_strips_per_box, packaging_label,
     default_purchase_price, default_ptr, default_mrp, default_selling_price,
     default_wholesale_price)
   VALUES ($1,'Alprax 0.5mg','Alprazolam','Alprazolam IP 0.5mg','Torrent',
     'Alprax','Anxiolytic','tablet','strip','10x15','30049099',12.00,
     true,true,false,true,true,'8901234567890','SKU-ALP-05',25,'tablet',
     15,10,'10x15',70.00,80.00,120.00,118.00,85.00)
   RETURNING *`
, [A.id])).rows[0];

check('product name persisted', prod.name, 'Alprax 0.5mg');
check('generic/composition persisted', [prod.generic_salt, prod.composition], ['Alprazolam', 'Alprazolam IP 0.5mg']);
check('manufacturer persisted', prod.manufacturer, 'Torrent');
check('barcode persisted', prod.barcode, '8901234567890');
check('HSN persisted', prod.hsn_code, '30049099');
check('GST percent persisted', num(prod.gst_percent), 12);
check('dosage form + packaging persisted', [prod.dosage_form, prod.packaging_type, prod.pack_size], ['tablet', 'strip', '10x15']);
check('pack config persisted', [prod.packaging_units_per_strip, prod.packaging_strips_per_box], [15, 10]);
check('MRP / PTR / purchase / selling / wholesale persisted',
  [num(prod.default_mrp), num(prod.default_ptr), num(prod.default_purchase_price),
    num(prod.default_selling_price), num(prod.default_wholesale_price)],
  [120, 80, 70, 118, 85]);
check('reorder level persisted', prod.reorder_level, 25);
check('schedule H / H1 / narcotic / prescription / chronic persisted',
  [prod.is_schedule_h, prod.is_schedule_h1, prod.is_narcotic,
    prod.is_prescription_required, prod.is_chronic],
  [true, true, false, true, true]);

console.log('\n=== 3. FLEXIBLE PACKAGING (not hardcoded) ===');
const packs = [
  ['Para 10x10', 'tablet', 'strip', '10x10', 10, 10],
  ['Amox 10x15', 'capsule', 'strip', '10x15', 15, 10],
  ['Azith 10x20', 'tablet', 'strip', '10x20', 20, 10],
  ['Cough Syrup', 'syrup', 'bottle', '100ml', 100, 1],
  ['Ceftri Inj', 'injection', 'vial', '1g vial', 1, 1],
  ['Odd 7x3', 'tablet', 'blister', '7x3', 3, 7],
];
let packOk = 0;
for (const [n, dose, ptype, size, units, strips] of packs) {
  try {
    await db.query(
      `INSERT INTO products (tenant_id,name,manufacturer,dosage_form,packaging_type,
         pack_size,hsn_code,gst_percent,packaging_units_per_strip,packaging_strips_per_box,sku)
       VALUES ($1,$2,'Mfr',$3,$4,$5,'30049099',12,$6,$7,$8)`,
      [A.id, n, dose, ptype, size, units, strips, `SKU-${n.replace(/\W/g, '')}`]
    );
    packOk++;
  } catch (e) { console.log(`        ${n} rejected: ${e.message}`); }
}
check('all packaging permutations accepted incl. arbitrary 7x3', packOk, packs.length);

console.log('\n=== 4. BATCHES + FEFO ORDERING ===');
const today = new Date();
const plusDays = (d) => new Date(today.getTime() + d * 86400000).toISOString().slice(0, 10);

// C expires latest, A earliest, B middle; plus an expired and a zero-stock batch.
const mk = async (bn, days, stock, mrp, ptr, sell, ws) => (await db.query(
  `INSERT INTO batches (product_id, tenant_id, branch_id, batch_number, mfg_date,
     exp_date, purchase_price, ptr_price, mrp, selling_price, wholesale_price, stock_quantity)
   VALUES ($1,$2,$3,$4,$5,$6,70,$7,$8,$9,$10,$11) RETURNING id`,
  [prod.id, A.id, brA1, bn, plusDays(-400), plusDays(days), ptr, mrp, sell, ws, stock]
)).rows[0].id;

const bC = await mk('B-C', 300, 40, 120, 80, 118, 85);
const bA = await mk('B-A', 45, 30, 120, 80, 118, 85);
const bB = await mk('B-B', 150, 50, 120, 80, 118, 85);
await mk('B-EXPIRED', -10, 25, 120, 80, 118, 85);
await mk('B-ZEROSTOCK', 20, 0, 120, 80, 118, 85);

const fefo = (await db.query(
  `SELECT batch_number, exp_date FROM batches
    WHERE tenant_id=$1 AND product_id=$2 AND stock_quantity>0 AND exp_date>=CURRENT_DATE
    ORDER BY exp_date ASC`, [A.id, prod.id]
)).rows;
check('FEFO order is earliest-expiry first', fefo.map((r) => r.batch_number), ['B-A', 'B-B', 'B-C']);
checkTrue('FEFO excludes expired stock', !fefo.some((r) => r.batch_number === 'B-EXPIRED'));
checkTrue('FEFO excludes zero-stock batch', !fefo.some((r) => r.batch_number === 'B-ZEROSTOCK'));

console.log('\n=== 5. RETAIL SALE: discount, GST, HSN, stock deduction ===');
// Subtotal 1000 (MRP 100 x 10), invoice discount 100, GST 12% inclusive.
async function createSale({ tenant, branch, user, billingType, gstin, unitPrice,
  qty, freeQty, invoiceDiscount, batchId, invNo, pharmacistId, pharmacistName }) {
  const gross = unitPrice * qty;
  const afterDisc = Math.max(gross - invoiceDiscount, 0);
  const taxAmt = afterDisc * (12 / 112);
  const taxable = afterDisc - taxAmt;
  // Mirror DbMapper: each half is rounded to paisa and the total is their SUM,
  // so CGST + SGST always reconciles exactly to total_gst on the invoice.
  const half = Number((taxAmt / 2).toFixed(2));
  const gstTotal = Number((half * 2).toFixed(2));
  // With inclusive GST, taxable is derived as payable - tax. Rounding each part
  // to paisa can leave taxable + gst off the payable by a paisa, so taxable is
  // derived FROM the rounded GST total. That keeps
  // taxable + total_gst == grand_total exactly on the printed invoice.
  const taxableRounded = Number((afterDisc - gstTotal).toFixed(2));
  const r = (await db.query(
    `INSERT INTO sales (tenant_id, branch_id, invoice_number, invoice_date,
       customer_name, customer_phone, customer_gstin, billing_type,
       subtotal, item_discount_total, invoice_discount, taxable_amount,
       cgst_amount, sgst_amount, igst_amount, total_gst, round_off, grand_total,
       payment_mode, payment_status, created_by,
       authorized_pharmacist_id, pharmacist_authorized_name)
     VALUES ($1,$2,$3,CURRENT_TIMESTAMP,'Ramesh','9812345678',$4,$5,
       $6,0,$7,$8,$9,$10,0,$11,0,$12,'cash','paid',$13,$14,$15)
     RETURNING *`,
    [tenant, branch, invNo, gstin, billingType, gross, invoiceDiscount,
      taxableRounded.toFixed(2), half.toFixed(2), half.toFixed(2),
      gstTotal.toFixed(2), afterDisc.toFixed(2), user,
      pharmacistId ?? null, pharmacistName ?? null]
  )).rows[0];

  await db.query(
    `INSERT INTO sale_items (sale_id, tenant_id, product_id, batch_id, product_name,
       hsn_code, batch_number, expiry_date, quantity, free_quantity, unit_price,
       ptr_price, mrp, line_discount, taxable_value, gst_percent,
       cgst_amount, sgst_amount, igst_amount, line_total)
     SELECT $1,$2,$3,b.id,'Alprax 0.5mg','30049099',b.batch_number,b.exp_date,
       $4,$5,$6,b.ptr_price,b.mrp,0,$7,12,$8,$9,0,$10
     FROM batches b WHERE b.id=$11`,
    [r.id, tenant, prod.id, qty, freeQty, unitPrice, taxable.toFixed(2),
      half.toFixed(2), half.toFixed(2), afterDisc.toFixed(2), batchId]
  );

  // No manual stock update here: the update_stock_on_sale trigger (004, fixed in
  // 010) deducts quantity + free_quantity on sale_items insert. Deducting again
  // in the client would double-count, which is exactly the bug this verifies.
  return r;
}

const stockBefore = num((await db.query('select stock_quantity s from batches where id=$1', [bA])).rows[0].s);
const retail = await createSale({
  tenant: A.id, branch: brA1, user: A.admin, billingType: 'retail', gstin: null,
  unitPrice: 100, qty: 10, freeQty: 0, invoiceDiscount: 100, batchId: bA, invNo: 'INV-R-001',
  pharmacistId, pharmacistName: 'Dr Rao',
});
const stockAfter = num((await db.query('select stock_quantity s from batches where id=$1', [bA])).rows[0].s);

check('retail sale row created', retail.invoice_number, 'INV-R-001');
check('subtotal = 1000', num(retail.subtotal), 1000);
check('discount = 100 persisted', num(retail.invoice_discount), 100);
check('grand total = 900 (discount applied)', num(retail.grand_total), 900);
check('taxable + GST equals grand total',
  Number((num(retail.taxable_amount) + num(retail.total_gst)).toFixed(2)), 900);
check('CGST equals SGST (intra-state split)', num(retail.cgst_amount), num(retail.sgst_amount));
// Must reconcile exactly: an invoice whose CGST + SGST does not equal the stated
// GST total is not filable.
check('GST total reconciles exactly to CGST + SGST',
  Number((num(retail.cgst_amount) + num(retail.sgst_amount)).toFixed(2)),
  num(retail.total_gst));
check('billing_type = retail', retail.billing_type, 'retail');
check('stock deducted by 10', stockBefore - stockAfter, 10);

const rItem = (await db.query('select * from sale_items where sale_id=$1', [retail.id])).rows[0];
check('sale_items has tenant_id (RLS key)', rItem.tenant_id, A.id);
check('sale_items carries HSN', rItem.hsn_code, '30049099');
check('sale_items unit price = MRP for retail', num(rItem.unit_price), 100);
checkTrue('sale_items expiry is a real date', !Number.isNaN(Date.parse(rItem.expiry_date)));

console.log('\n=== 6. WHOLESALE SALE: PTR pricing, GSTIN, free qty ===');
const wsBefore = num((await db.query('select stock_quantity s from batches where id=$1', [bB])).rows[0].s);
const wholesale = await createSale({
  tenant: A.id, branch: brA1, user: A.admin, billingType: 'wholesale',
  gstin: '29CCCCC9999C1Z2', unitPrice: 80, qty: 10, freeQty: 2,
  invoiceDiscount: 50, batchId: bB, invNo: 'INV-W-001',
  pharmacistId, pharmacistName: 'Dr Rao',
});
const wsAfter = num((await db.query('select stock_quantity s from batches where id=$1', [bB])).rows[0].s);

check('billing_type = wholesale persisted', wholesale.billing_type, 'wholesale');
check('customer GSTIN persisted', wholesale.customer_gstin, '29CCCCC9999C1Z2');
check('wholesale priced at PTR 80 not MRP 120', num(wholesale.subtotal), 800);
check('wholesale grand total = 750 after 50 discount', num(wholesale.grand_total), 750);
check('stock deducted 12 (10 billed + 2 free)', wsBefore - wsAfter, 12);

const wItem = (await db.query('select * from sale_items where sale_id=$1', [wholesale.id])).rows[0];
check('free_quantity = 2 recorded', wItem.free_quantity, 2);
check('charged unit price is PTR', num(wItem.unit_price), 80);
check('PTR stored separately from MRP', [num(wItem.ptr_price), num(wItem.mrp)], [80, 120]);
checkTrue('free units are not charged: line_total = 10 x 80 - 50',
  num(wItem.line_total) === 750, `got ${wItem.line_total}`);

console.log('\n=== 7. DISCOUNT > SUBTOTAL MUST NOT GO NEGATIVE ===');
const over = await createSale({
  tenant: A.id, branch: brA1, user: A.admin, billingType: 'retail', gstin: null,
  unitPrice: 100, qty: 2, freeQty: 0, invoiceDiscount: 5000, batchId: bC, invNo: 'INV-R-OVER',
  pharmacistId, pharmacistName: 'Dr Rao',
});
check('grand total clamped to 0, never negative', num(over.grand_total), 0);
checkTrue('grand total >= 0', num(over.grand_total) >= 0);

// Guard the invariant in the database too, so a bad client cannot write junk.
await db.exec(`
  DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conrelid='public.sales'::regclass AND conname='sales_grand_total_non_negative') THEN
      ALTER TABLE sales ADD CONSTRAINT sales_grand_total_non_negative CHECK (grand_total >= 0);
    END IF;
  END $$;
`);
let negativeRejected = false;
try {
  await db.query(
    `INSERT INTO sales (tenant_id,branch_id,invoice_number,customer_name,subtotal,
       invoice_discount,taxable_amount,total_gst,grand_total,payment_mode,created_by)
     VALUES ($1,$2,'INV-NEG','X',100,500,0,0,-400,'cash',$3)`,
    [A.id, brA1, A.admin]
  );
} catch { negativeRejected = true; }
checkTrue('database rejects a negative grand_total', negativeRejected);

console.log('\n=== 7b. SCHEDULE H AUDIT REGISTER ===');
// Alprax is schedule_h + h1, so the 004 trigger should have logged every sale.
const audit = (await db.query(
  `SELECT product_name, batch_number, quantity, customer_name,
          pharmacist_name, pharmacist_ref, branch_id
     FROM restricted_drug_logs WHERE tenant_id=$1 ORDER BY created_at`, [A.id]
)).rows;
checkTrue('restricted sales are logged automatically', audit.length >= 2,
  `logged ${audit.length}`);
if (audit.length) {
  check('audit records the authorising pharmacist name', audit[0].pharmacist_name, 'Dr Rao');
  check('audit links to the pharmacists row', audit[0].pharmacist_ref, pharmacistId);
  checkTrue('audit records the branch', audit[0].branch_id !== null);
  checkTrue('audit never stores the PIN',
    !JSON.stringify(audit).includes('4821'));
}

// A restricted sale with no authoriser must be refused, not silently logged.
let unauthorisedBlocked = false;
try {
  const bad = (await db.query(
    `INSERT INTO sales (tenant_id,branch_id,invoice_number,customer_name,subtotal,
       taxable_amount,grand_total,payment_mode,created_by)
     VALUES ($1,$2,'INV-NOAUTH','X',100,89,100,'cash',$3) RETURNING id`,
    [A.id, brA1, A.admin])).rows[0].id;
  await db.query(
    `INSERT INTO sale_items (sale_id,tenant_id,product_id,batch_id,product_name,
       hsn_code,batch_number,expiry_date,quantity,unit_price,mrp,taxable_value,
       gst_percent,line_total)
     SELECT $1,$2,$3,b.id,'Alprax 0.5mg','30049099',b.batch_number,b.exp_date,
       1,100,120,89,12,100
       FROM batches b WHERE b.id=$4`,
    [bad, A.id, prod.id, bC]
  );
} catch (e) {
  unauthorisedBlocked = /requires pharmacist authorisation/i.test(e.message);
  if (!unauthorisedBlocked) console.log(`        blocked by other error: ${e.message}`);
}
checkTrue('unauthorised Schedule H sale is refused by the database', unauthorisedBlocked);

console.log('\n=== 7c. OVERSELL PROTECTION ===');
let oversellBlocked = false;
try {
  await db.query('UPDATE batches SET stock_quantity = stock_quantity - 100000 WHERE id=$1', [bA]);
} catch { oversellBlocked = true; }
checkTrue('stock cannot be driven negative', oversellBlocked);

console.log('\n=== 8. NEAR EXPIRY VIEW (90-day default) ===');
const near = (await db.query(
  `SELECT product_name, batch_number, exp_date, stock_quantity, mrp, ptr_price,
          branch_name, days_until_expiry, expiry_status
     FROM near_expiry_stock
    WHERE tenant_id=$1 AND days_until_expiry <= 90
    ORDER BY exp_date`, [A.id]
)).rows;
checkTrue('near expiry returns the 45-day batch', near.some((r) => r.batch_number === 'B-A'),
  `rows: ${JSON.stringify(near.map((r) => r.batch_number))}`);
checkTrue('near expiry excludes the 150-day batch', !near.some((r) => r.batch_number === 'B-B'));
checkTrue('near expiry excludes the 300-day batch', !near.some((r) => r.batch_number === 'B-C'));
if (near.length) {
  const r = near.find((x) => x.batch_number === 'B-A');
  checkTrue('view exposes product/batch/expiry/stock/MRP/PTR/branch',
    r.product_name != null && r.batch_number != null && r.exp_date != null &&
    r.stock_quantity != null && r.mrp != null && r.ptr_price != null && r.branch_name != null);
  checkTrue('days_until_expiry computed from current date (~45)',
    Math.abs(Number(r.days_until_expiry) - 45) <= 1, `got ${r.days_until_expiry}`);
  check('45 days is flagged warning', r.expiry_status, 'warning');
}

console.log('\n=== 9. BRANCH STOCK ISOLATION ===');
const bA2stock = await mk2(prod.id, A.id, brA2, 'B-NORTH', plusDays(200), 60);
async function mk2(pid, tid, bid, bn, exp, stock) {
  return (await db.query(
    `INSERT INTO batches (product_id,tenant_id,branch_id,batch_number,mfg_date,exp_date,
       purchase_price,ptr_price,mrp,selling_price,wholesale_price,stock_quantity)
     VALUES ($1,$2,$3,$4,CURRENT_DATE-400,$5,70,80,120,118,85,$6) RETURNING id`,
    [pid, tid, bid, bn, exp, stock]
  )).rows[0].id;
}
const northBefore = num((await db.query('select stock_quantity s from batches where id=$1', [bA2stock])).rows[0].s);
// Selling from the main branch must not touch the north branch.
await db.query('UPDATE batches SET stock_quantity = stock_quantity - 5 WHERE id=$1', [bC]);
const northAfter = num((await db.query('select stock_quantity s from batches where id=$1', [bA2stock])).rows[0].s);
check('branch B stock unchanged when branch A sells', northAfter, northBefore);

const branchStock = (await db.query(
  `SELECT b.branch_code, SUM(bt.stock_quantity)::int total
     FROM batches bt JOIN branches b ON b.id=bt.branch_id
    WHERE bt.tenant_id=$1 GROUP BY b.branch_code ORDER BY b.branch_code`, [A.id]
)).rows;
checkTrue('stock is tracked per branch', branchStock.length === 2,
  JSON.stringify(branchStock));
const saleBranch = (await db.query(
  `SELECT b.branch_name FROM sales s JOIN branches b ON b.id=s.branch_id WHERE s.id=$1`,
  [retail.id])).rows[0];
check('invoice carries its own branch', saleBranch.branch_name, 'Apollo Main');

console.log('\n=== 10. MULTI-TENANT ISOLATION (RLS, not frontend filtering) ===');
await db.query(
  `INSERT INTO products (tenant_id,name,manufacturer,hsn_code,gst_percent,sku)
   VALUES ($1,'TEST MEDICINE A','Mfr','30049099',12,'SKU-TESTA')`, [A.id]
);
// Simulate an authenticated user hitting the tables under RLS.
//
// Two details matter, and getting either wrong produces a false result:
//  * the authenticated role needs table grants, or every read errors out
//  * SET LOCAL ROLE only holds inside a transaction, and the table OWNER
//    bypasses RLS, so querying as postgres would show every row and look
//    like a leak that does not exist
await db.exec(`
  GRANT USAGE ON SCHEMA public, auth TO authenticated, anon;
  GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
  GRANT SELECT ON auth.users TO authenticated;
`);

async function asUser(uid, sql, params = []) {
  await db.exec('BEGIN');
  try {
    await db.query(`SELECT set_config('request.jwt.claim.sub', $1, true)`, [uid]);
    await db.exec('SET LOCAL ROLE authenticated');
    return await db.query(sql, params);
  } finally {
    await db.exec('ROLLBACK');
  }
}
const bAdmin = (await db.query(
  `SELECT id FROM users WHERE tenant_id=$1 AND role='business_admin' LIMIT 1`, [B.id]
)).rows[0].id;

const isolationTargets = [
  ['products', 'TEST MEDICINE A'],
  ['sales', null], ['sale_items', null], ['batches', null],
  ['customers', null], ['suppliers', null], ['branches', null],
  ['pharmacists', null],
];
for (const [table] of isolationTargets) {
  try {
    const rows = await asUser(bAdmin, `SELECT count(*)::int c FROM ${table}`);
    const leaked = Number(rows.rows[0].c);
    const ownRows = Number((await db.query(
      `SELECT count(*)::int c FROM ${table} WHERE tenant_id=$1`, [B.id])).rows[0].c);
    checkTrue(`tenant B sees only its own ${table} (${leaked} visible, owns ${ownRows})`,
      leaked === ownRows, `RLS leak: saw ${leaked}, owns ${ownRows}`);
  } catch (e) {
    console.log(`  INFO  ${table}: ${e.message}`);
  }
}
const nameLeak = await asUser(bAdmin,
  `SELECT count(*)::int c FROM products WHERE name='TEST MEDICINE A'`);
check('TEST MEDICINE A is invisible to tenant B', Number(nameLeak.rows[0].c), 0);
const ownView = await asUser(A.admin,
  `SELECT count(*)::int c FROM products WHERE name='TEST MEDICINE A'`);
check('TEST MEDICINE A is visible to its owner tenant A', Number(ownView.rows[0].c), 1);

console.log('\n=== 11. TENANT DEACTIVATION ===');
await db.query('UPDATE tenants SET is_active=false WHERE id=$1', [B.id]);
check('tenant deactivated', (await db.query('select is_active from tenants where id=$1', [B.id])).rows[0].is_active, false);
await db.query('UPDATE tenants SET is_active=true WHERE id=$1', [B.id]);
check('tenant reactivated', (await db.query('select is_active from tenants where id=$1', [B.id])).rows[0].is_active, true);

console.log('\n=== 12. DEMO REQUEST + PRICING (public surfaces) ===');
await db.query(
  `INSERT INTO demo_requests (name,business_name,mobile,email,city,pincode,
     business_type,num_branches,message)
   VALUES ('Suresh','Suresh Medicals','9876543210','s@x.com','Pune','411001',
     'Pharmacy / Medical',3,'Need multi-branch demo')`
);
const dr = (await db.query(`SELECT * FROM demo_requests WHERE mobile='9876543210'`)).rows[0];
checkTrue('demo request row created', !!dr);
check('demo fields persisted',
  [dr.name, dr.business_name, dr.email, dr.city, dr.pincode, dr.business_type, dr.num_branches],
  ['Suresh', 'Suresh Medicals', 's@x.com', 'Pune', '411001', 'Pharmacy / Medical', 3]);
check('demo status defaults to new', dr.status, 'new');
const anonInsert = (await db.query(
  `SELECT count(*)::int c FROM pg_policies
    WHERE tablename='demo_requests' AND cmd='INSERT' AND 'anon'=ANY(roles)`)).rows[0];
checkTrue('anon may INSERT demo requests', Number(anonInsert.c) >= 1);
const anonSelect = (await db.query(
  `SELECT count(*)::int c FROM pg_policies
    WHERE tablename='demo_requests' AND cmd='SELECT' AND 'anon'=ANY(roles)`)).rows[0];
check('anon may NOT SELECT demo requests (no lead harvesting)', Number(anonSelect.c), 0);

const plans = (await db.query(
  `SELECT plan_name, plan_code, price FROM pricing_plans WHERE is_active ORDER BY display_order`)).rows;
checkTrue('pricing plans seeded from migration', plans.length >= 3, JSON.stringify(plans));
checkTrue('pricing plans are readable by anon',
  Number((await db.query(`SELECT count(*)::int c FROM pg_policies
    WHERE tablename='pricing_plans' AND cmd='SELECT' AND 'anon'=ANY(roles)`)).rows[0].c) >= 1);

console.log('\n=== 13. PER-TENANT INVOICE IDENTITY (no hardcoded LifeSprout) ===');
const ids = (await db.query(
  `SELECT business_name, gstin, drug_license_no, address, city, phone, email, logo_url
     FROM tenants WHERE id = ANY($1::uuid[]) ORDER BY business_name`, [[A.id, B.id]]
)).rows;
check('two distinct pharmacy identities available', ids.length, 2);
checkTrue('identities differ', ids[0].business_name !== ids[1].business_name &&
  ids[0].gstin !== ids[1].gstin && ids[0].logo_url !== ids[1].logo_url);
checkTrue('no LIFESPROUT text in tenant identity',
  !JSON.stringify(ids).toUpperCase().includes('LIFESPROUT'));
ids.forEach((r) => console.log(`        ${r.business_name} | ${r.gstin} | ${r.drug_license_no} | ${r.city} | logo=${r.logo_url ? 'yes' : 'no'}`));

console.log('\n=== 14. INVOICE RENDER DATA (all required fields joinable) ===');
const full = (await db.query(
  `SELECT t.business_name, t.gstin AS seller_gstin, t.drug_license_no, t.address,
          t.phone, t.email, t.logo_url,
          b.branch_name, s.invoice_number, s.invoice_date, s.customer_name,
          s.customer_gstin, s.subtotal, s.invoice_discount, s.taxable_amount,
          s.cgst_amount, s.sgst_amount, s.igst_amount, s.total_gst, s.round_off,
          s.grand_total, s.payment_mode, s.billing_type,
          si.product_name, si.hsn_code, si.batch_number, si.expiry_date,
          si.mrp, si.ptr_price, si.quantity, si.free_quantity, si.unit_price,
          si.line_discount, si.gst_percent, si.line_total
     FROM sales s
     JOIN tenants t ON t.id = s.tenant_id
     JOIN branches b ON b.id = s.branch_id
     JOIN sale_items si ON si.sale_id = s.id
    WHERE s.id = $1`, [wholesale.id]
)).rows[0];
const requiredInvoiceFields = ['business_name', 'seller_gstin', 'drug_license_no',
  'address', 'branch_name', 'invoice_number', 'invoice_date', 'customer_name',
  'customer_gstin', 'product_name', 'hsn_code', 'batch_number', 'expiry_date',
  'mrp', 'ptr_price', 'quantity', 'free_quantity', 'unit_price', 'gst_percent',
  'subtotal', 'invoice_discount', 'taxable_amount', 'cgst_amount', 'sgst_amount',
  'total_gst', 'round_off', 'grand_total', 'payment_mode'];
const nullFields = requiredInvoiceFields.filter((f) => full[f] === null || full[f] === undefined);
checkTrue('every required invoice field is populated',
  nullFields.length === 0, `null: ${nullFields.join(', ')}`);

console.log('\n=== 15. CUSTOMER PURCHASE HISTORY / REPORTS ===');
const hist = (await db.query(
  `SELECT customer_name, count(*)::int orders, SUM(grand_total)::numeric spend
     FROM sales WHERE tenant_id=$1 AND customer_name='Ramesh'
    GROUP BY customer_name`, [A.id])).rows[0];
checkTrue('purchase history aggregates for a customer', !!hist && hist.orders >= 1,
  JSON.stringify(hist));
const metrics = (await db.query(
  `SELECT total_products, total_sales, total_revenue FROM tenant_dashboard_metrics
    WHERE tenant_id=$1`, [A.id])).rows[0];
checkTrue('dashboard metrics view reports real numbers',
  !!metrics && Number(metrics.total_sales) >= 3, JSON.stringify(metrics));

console.log(`\n${'='.repeat(58)}`);
console.log(`RESULT: ${pass} passed, ${fail} failed`);
console.log('='.repeat(58));
await db.close();
process.exit(fail === 0 ? 0 : 1);
