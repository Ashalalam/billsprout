// Verifies the LIVE Supabase database after apply_all.sql has been run.
// Uses the service-role key, which bypasses RLS, so a missing object means the
// object genuinely does not exist rather than being hidden by a policy.
//
// Read-only by default. Pass --write to additionally create a disposable tenant,
// branch, product, batch and sale, confirm the trigger-driven stock deduction
// and Schedule H audit behave, then delete everything it created.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import crypto from 'node:crypto';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const env = {};
for (const line of readFileSync(path.join(ROOT, '.env'), 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$/);
  if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
}
const BASE = env.SUPABASE_URL;
const KEY = env.SUPABASE_SERVICE_ROLE_KEY;
if (!KEY) { console.error('SUPABASE_SERVICE_ROLE_KEY missing from .env'); process.exit(1); }
const WRITE = process.argv.includes('--write');

const H = { apikey: KEY, Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' };

let pass = 0, fail = 0;
const ok = (label) => { pass++; console.log(`  PASS  ${label}`); };
// ASCII only: the Windows console codepage mangles non-ASCII punctuation.
const no = (label, detail = '') => { fail++; console.log(`  FAIL  ${label}${detail ? ` - ${detail}` : ''}`); };
const check = (label, cond, detail = '') => (cond ? ok(label) : no(label, detail));

async function rest(p, init = {}) {
  const res = await fetch(`${BASE}/rest/v1/${p}`, { headers: H, ...init });
  const text = await res.text();
  let body = null;
  try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  return { status: res.status, body };
}
const tableExists = async (t) => (await rest(`${t}?select=*&limit=1`)).status === 200;
const colExists = async (t, c) => (await rest(`${t}?select=${c}&limit=1`)).status === 200;

console.log(`target: ${BASE}\n`);

console.log('=== 1. CANONICAL TABLES ===');
const required = ['tenants', 'users', 'branches', 'suppliers', 'customers',
  'products', 'batches', 'prescriptions', 'sales', 'sale_items', 'purchases',
  'purchase_items', 'restricted_drug_logs', 'stock_movements', 'stock_transfers',
  'demo_requests', 'pricing_plans', 'pharmacists'];
const missingTables = [];
for (const t of required) {
  const present = await tableExists(t);
  if (present) ok(t); else { no(t, 'absent'); missingTables.push(t); }
}

if (missingTables.length === required.length) {
  console.log(`
=========================================================
MIGRATIONS HAVE NOT BEEN APPLIED YET.
Run supabase/apply_all.sql in the Supabase SQL Editor, then
re-run this script.
=========================================================`);
  process.exit(1);
}

console.log('\n=== 2. VIEWS ===');
for (const v of ['near_expiry_stock', 'tenant_dashboard_metrics']) {
  check(v, await tableExists(v), 'absent');
}

console.log('\n=== 3. COLUMNS THE BILLING CODE WRITES ===');
for (const [t, c] of [
  ['sale_items', 'tenant_id'], ['sale_items', 'hsn_code'], ['sale_items', 'free_quantity'],
  ['sale_items', 'ptr_price'],
  ['sales', 'billing_type'], ['sales', 'customer_gstin'], ['sales', 'invoice_discount'],
  ['sales', 'authorized_pharmacist_id'], ['sales', 'pharmacist_authorized_name'],
  ['sales', 'legacy_source_id'],
  ['products', 'is_chronic'], ['products', 'reorder_level'], ['products', 'default_ptr'],
  ['products', 'packaging_units_per_strip'], ['products', 'hsn_code'],
  ['batches', 'ptr_price'], ['batches', 'exp_date'], ['batches', 'stock_quantity'],
  ['pharmacists', 'pharmacist_pin_hash'], ['pharmacists', 'pin_salt'],
  ['tenants', 'logo_url'], ['tenants', 'business_mode'],
  ['demo_requests', 'business_type'], ['pricing_plans', 'plan_code'],
]) {
  check(`${t}.${c}`, await colExists(t, c), 'missing');
}

console.log('\n=== 4. SEED DATA ===');
const plans = await rest('pricing_plans?select=plan_code,plan_name,price&order=display_order');
check('pricing plans seeded', Array.isArray(plans.body) && plans.body.length >= 3,
  `got ${Array.isArray(plans.body) ? plans.body.length : 'n/a'}`);
if (Array.isArray(plans.body)) {
  plans.body.forEach((p) => console.log(`          ${p.plan_code}: ${p.plan_name} = ${p.price}`));
}

console.log('\n=== 5. LEGACY DATA PRESERVED ===');
for (const t of ['companies_legacy_v0', 'invoices_legacy_v0']) {
  const present = await tableExists(t);
  if (!present) { no(t, 'not parked'); continue; }
  const res = await fetch(`${BASE}/rest/v1/${t}?select=*`, {
    headers: { ...H, Prefer: 'count=exact', Range: '0-0' },
  });
  const range = res.headers.get('content-range') ?? '';
  const total = Number(String(range).split('/')[1] ?? 0);
  ok(`${t} retained (${total} row(s))`);
  if (t === 'invoices_legacy_v0') {
    check('all 7 original invoices intact', total === 7, `found ${total}`);
  }
}

console.log('\n=== 6. MIGRATION LEDGER ===');
const ledger = await rest('_migrations?select=filename,applied_at&order=filename');
if (Array.isArray(ledger.body)) {
  check('ledger records 11 migrations', ledger.body.length === 11, `got ${ledger.body.length}`);
  ledger.body.forEach((r) => console.log(`          ${r.filename}`));
} else {
  no('_migrations table', 'absent');
}

console.log('\n=== 7. RLS IS ENABLED (anon must see nothing) ===');
const anonKey = env.SUPABASE_ANON_KEY;
for (const t of ['products', 'sales', 'sale_items', 'batches', 'pharmacists']) {
  const res = await fetch(`${BASE}/rest/v1/${t}?select=*&limit=1`, {
    headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
  });
  let rows = [];
  try { rows = JSON.parse(await res.text()); } catch { /* ignore */ }
  // An unauthenticated caller has no tenant, so RLS must return zero rows.
  const denied = res.status === 200 ? (Array.isArray(rows) && rows.length === 0) : true;
  check(`anon cannot read ${t}`, denied, `status ${res.status}`);
}
const anonPlans = await fetch(`${BASE}/rest/v1/pricing_plans?select=plan_code`, {
  headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
});
let ap = [];
try { ap = JSON.parse(await anonPlans.text()); } catch { /* ignore */ }
check('anon CAN read pricing_plans (public pricing page)',
  Array.isArray(ap) && ap.length >= 3, `got ${Array.isArray(ap) ? ap.length : 'n/a'}`);

console.log('\n=== 8. DEMO REQUEST INSERT AS ANON (public form) ===');
const probeMobile = `9${Math.floor(100000000 + Math.random() * 899999999)}`;
// No `Prefer: return=representation` here. That makes PostgREST do
// INSERT ... RETURNING, which needs SELECT, and SELECT is intentionally revoked
// from anon so a visitor cannot read other people's leads. The app inserts
// without asking for the row back, which is what this mirrors.
const dr = await fetch(`${BASE}/rest/v1/demo_requests`, {
  method: 'POST',
  headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}`,
    'Content-Type': 'application/json', Prefer: 'return=minimal' },
  body: JSON.stringify({ name: 'Verify Probe', mobile: probeMobile,
    business_name: 'Probe Pharmacy', city: 'Pune', business_type: 'Pharmacy / Medical' }),
});
const drText = await dr.text();
check('anon can submit a demo request', dr.status === 201, `${dr.status} ${drText.slice(0, 90)}`);

// Confirm with the service role that the row genuinely landed, rather than
// trusting the status code alone.
const landed = await rest(`demo_requests?mobile=eq.${probeMobile}&select=mobile,status`);
check('submitted lead is actually stored',
  Array.isArray(landed.body) && landed.body.length === 1,
  JSON.stringify(landed.body).slice(0, 90));
// The anon role must be able to write but not read back other people's leads.
const drRead = await fetch(`${BASE}/rest/v1/demo_requests?select=*`, {
  headers: { apikey: anonKey, Authorization: `Bearer ${anonKey}` },
});
let drRows = [];
try { drRows = JSON.parse(await drRead.text()); } catch { /* ignore */ }
check('anon cannot read demo requests back',
  !(Array.isArray(drRows) && drRows.length > 0), 'lead harvesting possible');
// Clean up the probe row with the service key.
if (dr.status === 201) {
  await rest(`demo_requests?mobile=eq.${probeMobile}`, { method: 'DELETE' });
}

if (WRITE) {
  console.log('\n=== 9. LIVE BILLING WRITE TEST (creates then removes data) ===');
  const stamp = Date.now();
  let tenantId, branchId, productId, batchId, saleId, pharmacistId, userId;
  try {
    tenantId = (await rest('tenants', {
      method: 'POST', headers: { ...H, Prefer: 'return=representation' },
      body: JSON.stringify({
        business_name: `ZZ Verify ${stamp}`, owner_name: 'Probe', phone: '9800000000',
        email: `verify${stamp}@probe.local`, gstin: '29ZZZZZ0000Z1Z0',
        drug_license_no: 'DL-PROBE', address: 'probe', city: 'Probe',
        state: 'Probe', pincode: '560001', industry_type: 'pharmacy',
        business_mode: 'both', subscription_plan: 'Gold Edition',
      }),
    })).body?.[0]?.id;
    check('tenant created', !!tenantId);

    branchId = (await rest('branches', {
      method: 'POST', headers: { ...H, Prefer: 'return=representation' },
      body: JSON.stringify({
        tenant_id: tenantId, branch_name: 'Probe Branch', branch_code: `PB${stamp}`,
        address: 'a', city: 'Probe', state: 'Probe', pincode: '560001',
        drug_license_no: 'DL-B', phone: '9', email: 'b@probe.local', manager_name: 'M',
      }),
    })).body?.[0]?.id;
    check('branch created', !!branchId);

    // sales.created_by references users(id) which references auth.users(id).
    const au = await fetch(`${BASE}/auth/v1/admin/users`, {
      method: 'POST', headers: H,
      body: JSON.stringify({ email: `probe${stamp}@probe.local`,
        password: crypto.randomBytes(12).toString('hex'), email_confirm: true,
        user_metadata: { tenant_id: tenantId, role: 'business_admin' } }),
    });
    userId = (await au.json())?.id;
    check('auth user created', !!userId, `status ${au.status}`);
    if (userId) {
      const u = await rest('users', {
        method: 'POST', headers: { ...H, Prefer: 'return=representation' },
        body: JSON.stringify({ id: userId, tenant_id: tenantId, name: 'Probe Admin',
          email: `probe${stamp}@probe.local`, role: 'business_admin' }),
      });
      check('users row created', u.status === 201, JSON.stringify(u.body).slice(0, 90));
    }

    const salt = crypto.randomBytes(16).toString('hex');
    const pinHash = crypto.createHash('sha256').update('4821' + salt).digest('hex');
    pharmacistId = (await rest('pharmacists', {
      method: 'POST', headers: { ...H, Prefer: 'return=representation' },
      body: JSON.stringify({ tenant_id: tenantId, name: 'Dr Probe',
        email: 'ph@probe.local', phone: '9811111111',
        registration_no: `RP${stamp}`, pharmacist_pin_hash: pinHash, pin_salt: salt }),
    })).body?.[0]?.id;
    check('pharmacist created with hashed PIN', !!pharmacistId);
    if (pharmacistId) {
      const p = (await rest(`pharmacists?id=eq.${pharmacistId}&select=pin_hash,pharmacist_pin_hash`)).body?.[0];
      check('pin_hash synced by trigger', p?.pin_hash === pinHash, `${p?.pin_hash}`);
      check('raw PIN not stored', !JSON.stringify(p ?? {}).includes('4821'));
    }

    productId = (await rest('products', {
      method: 'POST', headers: { ...H, Prefer: 'return=representation' },
      body: JSON.stringify({ tenant_id: tenantId, name: 'Probe Alprax',
        generic_salt: 'Alprazolam', manufacturer: 'Probe', hsn_code: '30049099',
        gst_percent: 12, is_schedule_h: true, is_chronic: true,
        dosage_form: 'tablet', packaging_type: 'strip', pack_size: '10x15',
        packaging_units_per_strip: 15, packaging_strips_per_box: 10,
        default_mrp: 120, default_ptr: 80, reorder_level: 25,
        sku: `SKU${stamp}`, barcode: `890${stamp}` }),
    })).body?.[0]?.id;
    check('product created with full master data', !!productId);

    const exp = new Date(Date.now() + 45 * 86400000).toISOString().slice(0, 10);
    batchId = (await rest('batches', {
      method: 'POST', headers: { ...H, Prefer: 'return=representation' },
      body: JSON.stringify({ product_id: productId, tenant_id: tenantId,
        branch_id: branchId, batch_number: `BP${stamp}`, exp_date: exp,
        mfg_date: '2025-01-01', purchase_price: 70, ptr_price: 80, mrp: 120,
        selling_price: 118, wholesale_price: 85, stock_quantity: 50 }),
    })).body?.[0]?.id;
    check('batch created with PTR separate from MRP', !!batchId);

    // Wholesale sale: 10 billed at PTR 80 + 2 free, 50 discount.
    const gross = 800, disc = 50, payable = gross - disc;
    const gst = Math.round((payable * 12 / 112) * 100) / 100;
    const half = Math.round((gst / 2) * 100) / 100;
    const gstTotal = Math.round(half * 2 * 100) / 100;
    saleId = (await rest('sales', {
      method: 'POST', headers: { ...H, Prefer: 'return=representation' },
      body: JSON.stringify({ tenant_id: tenantId, branch_id: branchId,
        invoice_number: `PROBE-${stamp}`, customer_name: 'Probe Buyer',
        customer_phone: '9812345678', customer_gstin: '29CCCCC9999C1Z2',
        billing_type: 'wholesale', subtotal: gross, invoice_discount: disc,
        taxable_amount: +(payable - gstTotal).toFixed(2),
        cgst_amount: half, sgst_amount: half, total_gst: gstTotal,
        grand_total: payable, payment_mode: 'cash', payment_status: 'paid',
        created_by: userId, authorized_pharmacist_id: pharmacistId,
        pharmacist_authorized_name: 'Dr Probe' }),
    })).body?.[0]?.id;
    check('wholesale sale created', !!saleId);

    const si = await rest('sale_items', {
      method: 'POST', headers: { ...H, Prefer: 'return=representation' },
      body: JSON.stringify({ sale_id: saleId, tenant_id: tenantId,
        product_id: productId, batch_id: batchId, product_name: 'Probe Alprax',
        hsn_code: '30049099', batch_number: `BP${stamp}`, expiry_date: exp,
        quantity: 10, free_quantity: 2, unit_price: 80, ptr_price: 80, mrp: 120,
        taxable_value: +(payable - gstTotal).toFixed(2), gst_percent: 12,
        cgst_amount: half, sgst_amount: half, line_total: payable }),
    });
    check('sale_items accepted (tenant_id + HSN + free qty)', si.status === 201,
      JSON.stringify(si.body).slice(0, 120));

    const after = (await rest(`batches?id=eq.${batchId}&select=stock_quantity`)).body?.[0];
    check('stock deducted 12 = 10 billed + 2 free by trigger',
      Number(after?.stock_quantity) === 38, `stock now ${after?.stock_quantity}`);

    const audit = (await rest(
      `restricted_drug_logs?sale_id=eq.${saleId}&select=product_name,pharmacist_name,pharmacist_ref,quantity`)).body;
    check('Schedule H auto-logged', Array.isArray(audit) && audit.length === 1,
      `${JSON.stringify(audit).slice(0, 100)}`);
    if (Array.isArray(audit) && audit[0]) {
      check('audit names the pharmacist, not a PIN',
        audit[0].pharmacist_name === 'Dr Probe' && !JSON.stringify(audit[0]).includes('4821'));
    }

    const ne = (await rest(
      `near_expiry_stock?tenant_id=eq.${tenantId}&days_until_expiry=lte.90&select=batch_number,days_until_expiry,mrp,ptr_price,branch_name`)).body;
    check('near expiry view returns the 45-day batch',
      Array.isArray(ne) && ne.some((r) => r.batch_number === `BP${stamp}`),
      JSON.stringify(ne).slice(0, 120));

    const neg = await rest('sales', {
      method: 'POST', headers: H,
      body: JSON.stringify({ tenant_id: tenantId, branch_id: branchId,
        invoice_number: `NEG-${stamp}`, customer_name: 'X', subtotal: 100,
        invoice_discount: 500, taxable_amount: 0, grand_total: -400,
        payment_mode: 'cash', created_by: userId }),
    });
    check('database rejects a negative grand_total', neg.status >= 400,
      `status ${neg.status}`);
  } catch (e) {
    no('write test threw', e.message);
  } finally {
    console.log('\n--- cleaning up probe data ---');
    if (saleId) await rest(`sale_items?sale_id=eq.${saleId}`, { method: 'DELETE' });
    if (saleId) await rest(`restricted_drug_logs?sale_id=eq.${saleId}`, { method: 'DELETE' });
    if (saleId) await rest(`stock_movements?reference_id=eq.${saleId}`, { method: 'DELETE' });
    if (saleId) await rest(`sales?id=eq.${saleId}`, { method: 'DELETE' });
    if (tenantId) await rest(`sales?tenant_id=eq.${tenantId}`, { method: 'DELETE' });
    if (batchId) await rest(`batches?id=eq.${batchId}`, { method: 'DELETE' });
    if (productId) await rest(`products?id=eq.${productId}`, { method: 'DELETE' });
    if (pharmacistId) await rest(`pharmacists?id=eq.${pharmacistId}`, { method: 'DELETE' });
    if (userId) {
      await rest(`users?id=eq.${userId}`, { method: 'DELETE' });
      await fetch(`${BASE}/auth/v1/admin/users/${userId}`, { method: 'DELETE', headers: H });
    }
    if (branchId) await rest(`branches?id=eq.${branchId}`, { method: 'DELETE' });
    if (tenantId) await rest(`tenants?id=eq.${tenantId}`, { method: 'DELETE' });

    const leftover = (await rest(`tenants?id=eq.${tenantId}&select=id`)).body;
    console.log(Array.isArray(leftover) && leftover.length === 0
      ? '  probe data removed'
      : '  WARNING: probe tenant may remain, check manually');
  }
} else {
  console.log('\n(9. live write test skipped - pass --write to run it)');
}

console.log(`\n${'='.repeat(58)}`);
console.log(`RESULT: ${pass} passed, ${fail} failed`);
console.log('='.repeat(58));
process.exit(fail === 0 ? 0 : 1);
