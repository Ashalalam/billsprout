// The direct host db.<ref>.supabase.co is reachable and speaks the Postgres
// protocol. On that host the role is plain "postgres" (the "postgres.<ref>"
// form is a Supavisor pooler convention). Test the credentials in hand against
// the correct username before concluding the password is required.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const env = {};
for (const line of readFileSync(path.join(ROOT, '.env'), 'utf8').split(/\r?\n/)) {
  const m = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$/);
  if (m) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
}
const ref = new URL(env.SUPABASE_URL).hostname.split('.')[0];
const HOST = `db.${ref}.supabase.co`;
const { Client } = (await import('pg')).default;

const creds = [
  ['postgres', env.SUPABASE_SERVICE_ROLE_KEY, 'service_role JWT'],
  ['postgres', env.SUPABASE_ANON_KEY, 'anon JWT'],
  ['supabase_admin', env.SUPABASE_SERVICE_ROLE_KEY, 'service_role JWT as supabase_admin'],
  ['service_role', env.SUPABASE_SERVICE_ROLE_KEY, 'service_role role name'],
];
if (env.SUPABASE_DB_PASSWORD) {
  creds.unshift(['postgres', env.SUPABASE_DB_PASSWORD, 'SUPABASE_DB_PASSWORD']);
}

console.log(`host: ${HOST}:5432\n`);
for (const [user, password, label] of creds) {
  if (!password) { console.log(`  SKIP     ${label} (unset)`); continue; }
  const c = new Client({
    host: HOST, port: 5432, user, database: 'postgres', password,
    ssl: { rejectUnauthorized: false }, connectionTimeoutMillis: 20000,
  });
  try {
    await c.connect();
    const r = await c.query(`select current_user u, current_database() d,
                                    (select count(*) from pg_tables where schemaname='public') t`);
    console.log(`  SUCCESS  ${label} -> ${r.rows[0].u}@${r.rows[0].d}, ${r.rows[0].t} public tables`);
    await c.end();
    console.log('\nDDL IS POSSIBLE. Run: node tool/apply_migrations.mjs');
    process.exit(0);
  } catch (e) {
    console.log(`  FAIL     ${label} as ${user}: ${e.message.slice(0, 70)}`);
  }
}

console.log('\nThe database password is required; API keys are not Postgres credentials.');
process.exit(1);
