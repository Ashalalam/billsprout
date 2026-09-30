// Isolates why the anon demo-request insert was refused.
//
// Hypothesis: PostgREST's `Prefer: return=representation` performs
// INSERT ... RETURNING, which needs SELECT privilege. migration 007 deliberately
// REVOKEs SELECT from anon so visitors cannot read other people's leads. If so,
// a plain insert (no representation) should succeed and only the verifier was
// at fault, not the schema.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const env = {};
for (const line of readFileSync(path.join(ROOT, '.env'), 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$/);
  if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
}
const BASE = env.SUPABASE_URL;
const ANON = env.SUPABASE_ANON_KEY;
const SVC = env.SUPABASE_SERVICE_ROLE_KEY;

const mobile = () => `9${Math.floor(100000000 + Math.random() * 899999999)}`;

async function attempt(label, extraHeaders) {
  const m = mobile();
  const res = await fetch(`${BASE}/rest/v1/demo_requests`, {
    method: 'POST',
    headers: {
      apikey: ANON, Authorization: `Bearer ${ANON}`,
      'Content-Type': 'application/json', ...extraHeaders,
    },
    body: JSON.stringify({ name: 'Probe', mobile: m, business_name: 'Probe Co' }),
  });
  const text = (await res.text()).slice(0, 160).replace(/\s+/g, ' ');
  console.log(`  ${res.status === 201 ? 'OK     ' : 'REFUSED'} ${label.padEnd(38)} ${res.status} ${text}`);
  return { ok: res.status === 201, mobile: m };
}

console.log('=== anon INSERT variants ===');
const plain = await attempt('plain insert (what the app does)', {});
const repr = await attempt('insert + return=representation', { Prefer: 'return=representation' });
const minimal = await attempt('insert + return=minimal', { Prefer: 'return=minimal' });

console.log('\n=== what actually landed (read with service role) ===');
for (const a of [plain, repr, minimal]) {
  if (!a.mobile) continue;
  const res = await fetch(`${BASE}/rest/v1/demo_requests?mobile=eq.${a.mobile}&select=mobile`, {
    headers: { apikey: SVC, Authorization: `Bearer ${SVC}` },
  });
  const rows = await res.json();
  console.log(`  ${a.mobile}: ${Array.isArray(rows) && rows.length ? 'ROW PRESENT' : 'no row'}`);
}

console.log('\n=== anon table privileges on demo_requests ===');
// information_schema is readable; check the grants that actually exist.
const g = await fetch(
  `${BASE}/rest/v1/demo_requests?select=id&limit=1`,
  { headers: { apikey: ANON, Authorization: `Bearer ${ANON}` } });
console.log(`  anon SELECT -> ${g.status} ${(await g.text()).slice(0, 90)}`);

console.log('\n=== cleanup ===');
for (const a of [plain, repr, minimal]) {
  if (!a.mobile) continue;
  await fetch(`${BASE}/rest/v1/demo_requests?mobile=eq.${a.mobile}`, {
    method: 'DELETE', headers: { apikey: SVC, Authorization: `Bearer ${SVC}` },
  });
}
console.log('  probe rows removed');

console.log(plain.ok
  ? '\nCONCLUSION: the app\'s insert path works. Only return=representation is\nrefused, because that needs SELECT, which is intentionally revoked.'
  : '\nCONCLUSION: anon genuinely cannot insert. The GRANT needs fixing.');
