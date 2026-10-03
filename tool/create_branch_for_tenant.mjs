#!/usr/bin/env node

/**
 * Create a branch for the tenant so data can be saved
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, '..');

dotenv.config({ path: join(projectRoot, '.env') });

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

const TENANT_ID = '49d25b05-d505-416f-9b2d-31baf7f06f85';

console.log('\n═══════════════════════════════════════════════════════');
console.log('  Creating Branch for Tenant');
console.log('═══════════════════════════════════════════════════════\n');

async function main() {
  try {
    // Check if branch already exists
    const { data: existingBranches } = await supabase
      .from('branches')
      .select('*')
      .eq('tenant_id', TENANT_ID);
    
    if (existingBranches && existingBranches.length > 0) {
      console.log('✅ Branch already exists:');
      existingBranches.forEach(b => {
        console.log(`   - ${b.branch_name} (${b.id})`);
      });
      console.log();
      return;
    }
    
    console.log('📝 Creating main branch for tenant...\n');
    
    // Create main branch
    const { data: branch, error } = await supabase
      .from('branches')
      .insert({
        tenant_id: TENANT_ID,
        branch_name: 'Main Branch',
        branch_code: 'MAIN',
        address: 'Main Office',
        city: 'City',
        state: 'State',
        pincode: '000000',
        is_active: true
      })
      .select()
      .single();
    
    if (error) {
      console.error('❌ Error creating branch:', error.message);
      return;
    }
    
    console.log('✅ Branch created successfully!');
    console.log(`   Branch ID: ${branch.id}`);
    console.log(`   Branch Name: ${branch.branch_name}`);
    console.log();
    
    console.log('═══════════════════════════════════════════════════════');
    console.log('✅ Done! Now restart your Windows app and login again.\n');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

main();
