#!/usr/bin/env node

/**
 * Test login to verify credentials work
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
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;

console.log('\n═══════════════════════════════════════════════════════');
console.log('  Testing Login Credentials');
console.log('═══════════════════════════════════════════════════════\n');

// Create a regular client (not service role) to test login
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testLogin(email, password) {
  console.log(`Testing: ${email}`);
  
  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    });
    
    if (error) {
      console.log(`❌ Failed: ${error.message}\n`);
      return false;
    }
    
    console.log(`✅ Success! User ID: ${data.user.id}`);
    console.log(`   Email confirmed: ${data.user.email_confirmed_at ? 'Yes' : 'No'}`);
    console.log(`   Metadata:`, data.user.user_metadata);
    console.log();
    
    // Sign out
    await supabase.auth.signOut();
    return true;
  } catch (err) {
    console.log(`❌ Error: ${err.message}\n`);
    return false;
  }
}

async function main() {
  const testUsers = [
    { email: 'admin@lifesproutcare.com', password: 'password123' },
    { email: 'superadmin@lifesprout.com', password: 'password123' },
    { email: 'priya@medicare.com', password: 'password123' },
  ];
  
  for (const user of testUsers) {
    await testLogin(user.email, user.password);
  }
  
  console.log('═══════════════════════════════════════════════════════');
}

main();
