// Discovers the live schema by probing candidate table names and reading the
// PostgREST "Perhaps you meant" hints, which reveal real table names even when
// RLS blocks row access.
import { readFileSync } from 'node:fs';

const env = {};
for (const line of readFileSync(new URL('../.env', import.meta.url), 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$/);
  if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
}
const URL_BASE = env.SUPABASE_URL;
const KEY = env.SUPABASE_ANON_KEY;

async function probe(path) {
  const res = await fetch(`${URL_BASE}/rest/v1/${path}`, {
    headers: { apikey: KEY, Authorization: `Bearer ${KEY}` },
  });
  let body = null;
  try { body = JSON.parse(await res.text()); } catch { /* ignore */ }
  return { status: res.status, body };
}

const candidates = [
  'companies', 'tenants', 'users', 'profiles', 'branches', 'stores',
  'products', 'medicines', 'inventory', 'batches', 'product_batches',
  'sales', 'invoices', 'sale_items', 'invoice_items', 'bills', 'bill_items',
  'customers', 'patients', 'suppliers', 'vendors',
  'pharmacists', 'staff', 'demo_requests', 'demo_leads', 'pricing_plans',
  'plans', 'subscriptions', 'stock_movements', 'ledger_entries',
  'restricted_drug_logs', 'stock_transfers', 'purchase_orders',
  'rtv_notes', 'ota_releases', 'prescriptions',
];

const found = [];
const missing = [];
const hints = new Set();

for (const t of candidates) {
  const { status, body } = await probe(`${t}?select=*&limit=1`);
  const code = body && body.code;
  if (status === 200) {
    found.push(t);
  } else if (code === '42501' || code === 'PGRST301') {
    found.push(`${t} (RLS denied, exists)`);
  } else {
    missing.push(t);
    const hint = body && body.hint;
    if (hint) {
      for (const m of String(hint).matchAll(/public\.(\w+)/g)) hints.add(m[1]);
    }
  }
}

console.log('=== TABLES PRESENT (anon-readable or RLS-protected) ===');
found.forEach((t) => console.log(' ', t));
console.log('\n=== NOT FOUND ===');
console.log(' ', missing.join(', '));
console.log('\n=== REAL TABLE NAMES SUGGESTED BY POSTGREST HINTS ===');
console.log(' ', [...hints].sort().join(', ') || '(none)');

// For each table that exists, list its columns. PostgREST returns column names
// in the error when an unknown column is requested.
console.log('\n=== COLUMNS ===');
for (const entry of found) {
  const t = entry.split(' ')[0];
  const { body } = await probe(`${t}?select=__nope__&limit=1`);
  const msg = (body && (body.message || body.details)) || '';
  console.log(`\n${t}:`);
  console.log('  ', String(msg).slice(0, 700));
}
