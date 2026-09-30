// Determines exactly what the service-role key can do against this project:
//   1. authoritative schema read (bypasses RLS, so absence means truly absent)
//   2. whether any DDL path exists (SQL-over-HTTP RPC, pg-meta endpoints)
// Nothing is modified.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const env = {};
for (const line of readFileSync(path.join(ROOT, '.env'), 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$/);
  if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
}
const URL_BASE = env.SUPABASE_URL;
const KEY = env.SUPABASE_SERVICE_ROLE_KEY;
if (!KEY) { console.error('SUPABASE_SERVICE_ROLE_KEY missing'); process.exit(1); }

const ref = new URL(URL_BASE).hostname.split('.')[0];
console.log('project ref :', ref);

// Decode the JWT payload to confirm the role without trusting the label.
const payload = JSON.parse(Buffer.from(KEY.split('.')[1], 'base64url').toString());
console.log('key role    :', payload.role);
console.log('key ref     :', payload.ref);
console.log('key expires :', new Date(payload.exp * 1000).toISOString());
if (payload.ref !== ref) {
  console.error(`\nKEY MISMATCH: key is for "${payload.ref}" but SUPABASE_URL is "${ref}"`);
  process.exit(1);
}

const H = { apikey: KEY, Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' };

async function rest(pathname, init = {}) {
  const res = await fetch(`${URL_BASE}/rest/v1/${pathname}`, { headers: H, ...init });
  let body = null;
  try { body = JSON.parse(await res.text()); } catch { /* ignore */ }
  return { status: res.status, body };
}

console.log('\n=== AUTHORITATIVE TABLE PRESENCE (service role bypasses RLS) ===');
const expected = [
  'tenants', 'users', 'branches', 'suppliers', 'customers', 'products',
  'batches', 'prescriptions', 'sales', 'sale_items', 'purchases',
  'purchase_items', 'restricted_drug_logs', 'stock_movements',
  'stock_transfers', 'demo_requests', 'pricing_plans', 'pharmacists',
  'ledger_entries', 'ota_releases', 'companies', 'invoices',
  'near_expiry_stock', 'tenant_dashboard_metrics', '_migrations',
];
const present = [];
const absent = [];
for (const t of expected) {
  const { status } = await rest(`${t}?select=*&limit=1`);
  if (status === 200) present.push(t); else absent.push(t);
}
console.log('PRESENT:', present.join(', ') || '(none)');
console.log('ABSENT :', absent.join(', ') || '(none)');

console.log('\n=== ROW COUNTS FOR PRESENT TABLES ===');
for (const t of present) {
  const res = await fetch(`${URL_BASE}/rest/v1/${t}?select=*`, {
    headers: { ...H, Prefer: 'count=exact', Range: '0-0' },
  });
  console.log(`  ${t.padEnd(26)} ${res.headers.get('content-range') ?? 'n/a'}`);
}

console.log('\n=== KEY COLUMNS THE BILLING CODE NEEDS ===');
for (const [t, c] of [
  ['sale_items', 'tenant_id'], ['sales', 'billing_type'],
  ['sales', 'customer_gstin'], ['sales', 'authorized_pharmacist_id'],
]) {
  if (!present.includes(t)) { console.log(`  ${t}.${c} -> table absent`); continue; }
  const { status, body } = await rest(`${t}?select=${c}&limit=1`);
  console.log(`  ${t}.${c} -> ${status === 200 ? 'PRESENT' : `MISSING (${body?.code ?? status})`}`);
}

console.log('\n=== DDL CAPABILITY PROBES ===');
// PostgREST exposes only functions that already exist. A SQL-executing RPC is
// not created by default, so this is expected to fail; probing confirms it.
for (const fn of ['exec_sql', 'exec', 'execute_sql', 'run_sql', 'sql', 'query', 'pgmeta_query']) {
  const { status, body } = await rest(`rpc/${fn}`, {
    method: 'POST',
    body: JSON.stringify({ query: 'select 1', sql: 'select 1' }),
  });
  console.log(`  rpc/${fn.padEnd(14)} ${status} ${body?.code ?? ''} ${String(body?.message ?? '').slice(0, 60)}`);
}

// The dashboard's SQL editor uses a platform API that requires a personal access
// token, not a service-role key. Confirm it rejects us.
for (const p of [`https://api.supabase.com/v1/projects/${ref}/database/query`]) {
  try {
    const res = await fetch(p, {
      method: 'POST',
      headers: { Authorization: `Bearer ${KEY}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: 'select 1' }),
    });
    console.log(`  platform api   ${res.status} ${(await res.text()).slice(0, 90)}`);
  } catch (e) {
    console.log(`  platform api   error ${e.message}`);
  }
}
