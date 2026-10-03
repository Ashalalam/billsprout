#!/usr/bin/env node

/**
 * List all users and check if they can sign in
 * This helps identify which credentials work
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

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false }
});

console.log('\n═══════════════════════════════════════════════════════');
console.log('  User Credentials Summary');
console.log('═══════════════════════════════════════════════════════\n');

async function main() {
  try {
    // Get all users from public.users table
    const { data: users, error } = await supabase
      .from('users')
      .select('id, email, name, role, tenant_id, is_active')
      .order('role')
      .order('email');
    
    if (error) {
      console.error('❌ Error:', error.message);
      return;
    }
    
    console.log(`Found ${users.length} users in database:\n`);
    
    const credentials = [
      { email: 'admin@lifesproutcare.com', password: 'password123', role: 'business_admin' },
      { email: 'superadmin@billsprout.online', password: 'password123', role: 'super_admin' },
      { email: 'superadmin@lifesprout.com', password: 'password123', role: 'super_admin' },
      { email: 'priya@medicare.com', password: 'password123', role: 'business_admin' },
      { email: 'customer@lifesprout.com', password: 'password123', role: 'customer' },
      { email: 'patient@lifesproutcare.com', password: 'password123', role: 'customer' },
    ];
    
    for (const user of users) {
      const cred = credentials.find(c => c.email === user.email);
      const tenantInfo = user.tenant_id ? `✅ ${user.tenant_id.substring(0, 8)}...` : '❌ NO TENANT';
      const activeStatus = user.is_active ? '✅ Active' : '❌ Inactive';
      
      console.log(`📧 ${user.email}`);
      console.log(`   Name: ${user.name}`);
      console.log(`   Role: ${user.role}`);
      console.log(`   Tenant: ${tenantInfo}`);
      console.log(`   Status: ${activeStatus}`);
      
      if (cred) {
        console.log(`   🔑 Try Password: "${cred.password}"`);
      } else {
        console.log(`   ⚠️  Password unknown - may need to reset`);
      }
      console.log();
    }
    
    console.log('═══════════════════════════════════════════════════════');
    console.log('📝 Credentials to Try:\n');
    console.log('1. Business Admin:');
    console.log('   Email: admin@lifesproutcare.com');
    console.log('   Password: password123\n');
    
    console.log('2. Super Admin:');
    console.log('   Email: superadmin@lifesprout.com');
    console.log('   Password: password123\n');
    
    console.log('3. Business Admin (MediCare):');
    console.log('   Email: priya@medicare.com');
    console.log('   Password: password123\n');
    
    console.log('═══════════════════════════════════════════════════════\n');
    console.log('💡 If passwords don\'t work, reset them in Supabase Dashboard:');
    console.log('   https://supabase.com/dashboard/project/juvbhjqaioevpusnmonz/auth/users\n');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

main();
