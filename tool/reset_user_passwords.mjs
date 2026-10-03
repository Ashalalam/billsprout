#!/usr/bin/env node

/**
 * Reset passwords for all users to a known value for testing
 * Uses Supabase Admin API to update auth.users
 */

import * as dotenv from 'dotenv';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const projectRoot = join(__dirname, '..');

dotenv.config({ path: join(projectRoot, '.env') });

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const DEFAULT_PASSWORD = 'password123';

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

console.log('\n═══════════════════════════════════════════════════════');
console.log('  Reset User Passwords');
console.log('═══════════════════════════════════════════════════════\n');

async function resetPassword(userId, email) {
  try {
    const response = await fetch(
      `${SUPABASE_URL}/auth/v1/admin/users/${userId}`,
      {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'apikey': SUPABASE_SERVICE_KEY,
          'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
        },
        body: JSON.stringify({
          password: DEFAULT_PASSWORD,
          email_confirm: true  // Skip email confirmation
        })
      }
    );

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`HTTP ${response.status}: ${error}`);
    }

    const data = await response.json();
    return { success: true, data };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

async function listUsers() {
  try {
    const response = await fetch(
      `${SUPABASE_URL}/auth/v1/admin/users`,
      {
        headers: {
          'apikey': SUPABASE_SERVICE_KEY,
          'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`
        }
      }
    );

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const data = await response.json();
    return data.users || [];
  } catch (error) {
    console.error('❌ Error listing users:', error.message);
    return [];
  }
}

async function main() {
  console.log('📋 Fetching users from auth.users...\n');
  
  const users = await listUsers();
  
  if (users.length === 0) {
    console.log('⚠️  No users found in auth.users table.');
    console.log('   Users may need to be created first.\n');
    return;
  }

  console.log(`Found ${users.length} users. Resetting passwords to: "${DEFAULT_PASSWORD}"\n`);

  for (const user of users) {
    process.stdout.write(`📧 ${user.email} ... `);
    
    const result = await resetPassword(user.id, user.email);
    
    if (result.success) {
      console.log('✅ Password reset');
    } else {
      console.log(`❌ Failed: ${result.error}`);
    }
  }

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('✅ Password reset complete!\n');
  console.log('All users can now login with password: "password123"\n');
  console.log('Test credentials:');
  console.log('  Email: admin@lifesproutcare.com');
  console.log('  Password: password123\n');
}

main();
