// Reads the actual legacy rows with the service-role key (bypasses RLS) so the
// migration's data handling can be judged against real content rather than
// assumptions. Read-only.
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
const H = { apikey: KEY, Authorization: `Bearer ${KEY}` };

async function all(table) {
  const res = await fetch(`${URL_BASE}/rest/v1/${table}?select=*`, { headers: H });
  if (res.status !== 200) return { error: await res.text() };
  return { rows: await res.json() };
}

for (const t of ['companies', 'invoices', 'ledger_entries',
  'restricted_drug_logs', 'stock_transfers', 'ota_releases']) {
  const r = await all(t);
  console.log(`\n===== ${t} =====`);
  if (r.error) { console.log('  error:', r.error.slice(0, 200)); continue; }
  console.log(`  ${r.rows.length} row(s)`);
  if (r.rows.length > 0) {
    console.log('  columns:', Object.keys(r.rows[0]).join(', '));
    r.rows.slice(0, 10).forEach((row, i) => {
      // Truncate the items blob so the output stays readable.
      const shown = { ...row };
      if (shown.items) {
        const s = JSON.stringify(shown.items);
        shown.items = `<${Array.isArray(shown.items) ? shown.items.length : '?'} item(s), ${s.length} chars>`;
      }
      console.log(`  [${i}]`, JSON.stringify(shown));
    });
  }
}

// Do the invoice companyId values resolve to a companies row? If not, the
// backfill in 009 would skip them, which would silently drop real records.
const inv = await all('invoices');
const co = await all('companies');
if (inv.rows?.length) {
  const companyIds = new Set((co.rows ?? []).map((c) => c.id));
  const orphans = inv.rows.filter((i) => !companyIds.has(i.companyId));
  console.log('\n===== REFERENTIAL CHECK =====');
  console.log(`  invoices: ${inv.rows.length}, companies: ${co.rows?.length ?? 0}`);
  console.log(`  invoices whose companyId has no companies row: ${orphans.length}`);
  const distinct = [...new Set(inv.rows.map((i) => i.companyId))];
  console.log(`  distinct companyId values: ${JSON.stringify(distinct)}`);

  // Inspect one items blob closely: 009 sums quantity * unitPrice from it.
  const withItems = inv.rows.find((i) => i.items);
  if (withItems) {
    console.log('\n  sample items blob:');
    console.log('   ', JSON.stringify(withItems.items).slice(0, 900));
  }
}
