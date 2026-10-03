#!/usr/bin/env node

/**
 * Apply migration 008 directly using SQL execution
 */

import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import * as dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, '..');

dotenv.config({ path: join(projectRoot, '.env') });

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

console.log('\n═══════════════════════════════════════════════════════');
console.log('  Applying Migration 008 via SQL API');
console.log('═══════════════════════════════════════════════════════\n');

async function executeSql(sql) {
  const url = `${SUPABASE_URL}/rest/v1/rpc/exec`;
  
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': SUPABASE_SERVICE_KEY,
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
    },
    body: JSON.stringify({ query: sql })
  });
  
  const text = await response.text();
  return { ok: response.ok, status: response.status, body: text };
}

async function main() {
  try {
    const migrationPath = join(projectRoot, 'supabase', 'migrations', '008_sync_user_tenant_metadata.sql');
    const sql = readFileSync(migrationPath, 'utf8');
    
    console.log('📄 Migration loaded\n');
    console.log('⚠️  This migration must be applied via Supabase Dashboard SQL Editor\n');
    console.log('🔗 Go to: https://supabase.com/dashboard/project/juvbhjqaioevpusnmonz/sql/new\n');
    console.log('📋 Copy and paste the migration, then click "Run"\n');
    console.log('Migration file location:');
    console.log(`   ${migrationPath}\n`);
    console.log('═══════════════════════════════════════════════════════\n');
    
    // Meanwhile, let's manually trigger the sync for the current user
    console.log('🔧 Manually syncing user metadata as workaround...\n');
    
    const userId = 'fcda42ca-2e41-4be4-b261-8c01c787bdfa'; // admin@lifesproutcare.com
    const tenantId = '49d25b05-d505-416f-9b2d-31baf7f06f85';
    const branchId = '655da8cf-be9d-4caa-ad89-3e989ccf8aa3';
    
    const updateMetadataUrl = `${SUPABASE_URL}/auth/v1/admin/users/${userId}`;
    
    const response = await fetch(updateMetadataUrl, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
      },
      body: JSON.stringify({
        user_metadata: {
          tenant_id: tenantId,
          branch_id: branchId,
          name: 'admin',
          role: 'business_admin'
        }
      })
    });
    
    if (response.ok) {
      console.log('✅ User metadata updated successfully!');
      console.log(`   User: admin@lifesproutcare.com`);
      console.log(`   Tenant: ${tenantId}`);
      console.log(`   Branch: ${branchId}\n`);
      console.log('═══════════════════════════════════════════════════════');
      console.log('✅ RESTART THE WINDOWS APP NOW!');
      console.log('   Login with: admin@lifesproutcare.com / password123\n');
    } else {
      const error = await response.text();
      console.error('❌ Failed to update metadata:', error);
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

main();
