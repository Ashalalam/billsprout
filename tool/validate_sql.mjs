// Parses every migration with libpg_query (the actual PostgreSQL grammar) to
// prove the SQL is syntactically valid before it is applied anywhere.
// Syntax validity only; it cannot verify semantics against a live schema.
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const DIR = path.join(ROOT, 'supabase', 'migrations');

const mod = await import('pgsql-parser');
const parse = mod.parse ?? mod.default?.parse;
if (typeof parse !== 'function') {
  console.error('pgsql-parser: no parse export found', Object.keys(mod));
  process.exit(3);
}

const files = readdirSync(DIR).filter((f) => f.endsWith('.sql')).sort();
let bad = 0;

for (const f of files) {
  const sql = readFileSync(path.join(DIR, f), 'utf8');
  try {
    const result = await parse(sql);
    const stmts = Array.isArray(result) ? result : (result?.stmts ?? []);
    console.log(`OK     ${f.padEnd(42)} ${stmts.length} statement(s)`);
  } catch (err) {
    bad++;
    console.error(`FAIL   ${f}`);
    console.error(`         ${err.message}`);
    if (err.cursorPosition) {
      const pos = Number(err.cursorPosition);
      console.error(`         near: ${JSON.stringify(sql.slice(Math.max(0, pos - 90), pos + 90))}`);
    }
  }
}

console.log(`\n${files.length - bad}/${files.length} files parse cleanly`);
process.exit(bad === 0 ? 0 : 1);
