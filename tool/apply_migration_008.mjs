#!/usr/bin/env node

/**
 * Apply migration 008_sync_user_tenant_metadata.sql to Supabase
 * 
 * This uses the Supabase SQL Editor API to execute the migration.
 * 
 * Usage: node tool/apply_migration_008.mjs
 */

import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import * as dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, '..');

// Load environment variables
dotenv.config({ path: join(projectRoot, '.env') });

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env file');
  process.exit(1);
}

async function executeSQLViaAPI(sql) {
  const url = `${SUPABASE_URL}/rest/v1/rpc/exec`;
  
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_SERVICE_KEY,
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
      'Prefer': 'return=representation'
    },
    body: JSON.stringify({ sql })
  });
  
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`HTTP ${response.status}: ${text}`);
  }
  
  return await response.json();
}

async function main() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('  Applying Migration 008');
  console.log('═══════════════════════════════════════════════════════\n');
  
  try {
    // Read the migration file
    const migrationPath = join(projectRoot, 'supabase', 'migrations', '008_sync_user_tenant_metadata.sql');
    console.log('📄 Reading migration file...');
    console.log(`   ${migrationPath}\n`);
    
    const sql = readFileSync(migrationPath, 'utf8');
    console.log(`✅ Loaded ${sql.length} bytes\n`);
    
    console.log('⚠️  MANUAL STEP REQUIRED:\n');
    console.log('This migration must be applied through the Supabase Dashboard SQL Editor');
    console.log('because it contains advanced features that cannot be executed via the API.\n');
    
    console.log('📋 Instructions:\n');
    console.log('1. Go to: https://supabase.com/dashboard/project/juvbhjqaioevpusnmonz/sql/new');
    console.log('2. Copy the contents of:');
    console.log(`   ${migrationPath}`);
    console.log('3. Paste into the SQL Editor');
    console.log('4. Click "Run" to execute\n');
    
    console.log('📝 Migration Summary:\n');
    console.log('This migration will:');
    console.log('• Create sync_user_metadata_to_auth() function');
    console.log('• Create trigger on users table to auto-sync tenant_id to auth.users');
    console.log('• Create assign_default_tenant_to_user() helper function');
    console.log('• Backfill existing users\' auth metadata');
    console.log('• Create create_user_with_tenant() helper function\n');
    
    console.log('After applying the migration, run:');
    console.log('  node tool/fix_user_metadata.mjs\n');
    
    console.log('═══════════════════════════════════════════════════════\n');
    
    // Also output the SQL file location for easy copy
    console.log('💡 TIP: The migration file is at:');
    console.log(`   ${migrationPath}\n`);
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

main();
