#!/usr/bin/env node

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import crypto from 'crypto';

// Load environment variables
dotenv.config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceKey) {
  console.error('❌ Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseServiceKey);

async function setupDemoUsers() {
  console.log('🚀 Setting up BillSprout demo users...\n');

  try {
    // 1. Create Super Admin
    console.log('👑 Creating Super Admin...');
    const { data: superAdminData, error: superAdminError } = await supabase.auth.admin.createUser({
      email: 'superadmin@billsprout.online',
      password: 'SuperAdmin@123',
      email_confirm: true,
    });

    if (superAdminError && !superAdminError.message.includes('already been registered')) {
      console.error('❌ Super Admin creation error:', superAdminError.message);
    } else {
      const superAdminId = superAdminData?.user?.id;
      if (superAdminId) {
        // Insert super admin profile
        await supabase.from('users').upsert({
          id: superAdminId,
          email: 'superadmin@billsprout.online',
          name: 'Super Administrator',
          role: 'super_admin',
          tenant_id: null,
          is_active: true,
        });
        console.log('✅ Super Admin created: superadmin@billsprout.online');
      }
    }

    // 2. Create Demo Tenant (LifeSprout Care)
    console.log('\n🏢 Creating Demo Tenant...');
    const tenantId = crypto.randomUUID();
    
    const tenantData = {
      id: tenantId,
      business_name: 'LifeSprout Care',
      owner_name: 'Dr. Sarah Connor',
      email: 'admin@lifesproutcare.com',
      phone: '+44 7747 571513',
      address: '123 Healthcare Street, Medical District',
      city: 'London',
      state: 'England',
      country: 'United Kingdom',
      postal_code: 'SW1A 1AA',
      subscription_status: 'active',
      subscription_plan: 'professional',
      subscription_start_date: new Date().toISOString(),
      subscription_end_date: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000).toISOString(),
      is_active: true,
    };

    try {
      await supabase.from('tenants').upsert(tenantData);
      console.log('✅ Demo Tenant created: LifeSprout Care');
    } catch (e) {
      console.log('ℹ️  Tenant may already exist');
    }

    // 3. Create Demo Branch
    console.log('🏪 Creating Demo Branch...');
    const branchId = crypto.randomUUID();
    
    const branchData = {
      id: branchId,
      tenant_id: tenantId,
      branch_name: 'Main Branch',
      address: '123 Healthcare Street',
      city: 'London',
      phone: '+44 7747 571513',
      email: 'branch@lifesproutcare.com',
      is_primary: true,
      is_active: true,
    };

    try {
      await supabase.from('branches').upsert(branchData);
      console.log('✅ Demo Branch created: Main Branch');
    } catch (e) {
      console.log('ℹ️  Branch may already exist');
    }

    // 4. Create Business Admin User
    console.log('\n👨‍💼 Creating Business Admin...');
    const { data: adminData, error: adminError } = await supabase.auth.admin.createUser({
      email: 'admin@lifesproutcare.com',
      password: 'admin123',
      email_confirm: true,
      user_metadata: {
        tenant_id: tenantId,
        branch_id: branchId,
        role: 'business_admin',
        name: 'Dr. Sarah Connor',
      }
    });

    if (adminError && !adminError.message.includes('already been registered')) {
      console.error('❌ Business Admin creation error:', adminError.message);
    } else {
      const adminId = adminData?.user?.id;
      if (adminId) {
        // Insert business admin profile
        await supabase.from('users').upsert({
          id: adminId,
          tenant_id: tenantId,
          email: 'admin@lifesproutcare.com',
          name: 'Dr. Sarah Connor',
          phone: '+44 7747 571513',
          role: 'business_admin',
          license_no: 'PH-UK-984721',
          is_active: true,
        });
        console.log('✅ Business Admin created: admin@lifesproutcare.com');
      }
    }

    // 5. Create Customer User
    console.log('\n👤 Creating Customer...');
    const { data: customerData, error: customerError } = await supabase.auth.admin.createUser({
      email: 'patient@lifesproutcare.com',
      password: 'patient123',
      email_confirm: true,
    });

    if (customerError && !customerError.message.includes('already been registered')) {
      console.error('❌ Customer creation error:', customerError.message);
    } else {
      const customerId = customerData?.user?.id;
      if (customerId) {
        // Insert customer profile
        await supabase.from('users').upsert({
          id: customerId,
          email: 'patient@lifesproutcare.com',
          name: 'John Patient',
          phone: '+44 7777 123456',
          role: 'customer',
          tenant_id: null,
          is_active: true,
        });
        console.log('✅ Customer created: patient@lifesproutcare.com');
      }
    }

    // Success Summary
    console.log('\n🎉 Setup Complete! Your accounts are ready:\n');
    
    console.log('🔑 LOGIN CREDENTIALS:');
    console.log('┌─────────────────────────────────────────────────────────┐');
    console.log('│ Super Admin                                             │');
    console.log('│   Email:    superadmin@billsprout.online                │');
    console.log('│   Password: SuperAdmin@123                              │');
    console.log('│   Access:   ALL tenants and system management          │');
    console.log('├─────────────────────────────────────────────────────────┤');
    console.log('│ Business Admin (LifeSprout Care)                        │');
    console.log('│   Email:    admin@lifesproutcare.com                    │');
    console.log('│   Password: admin123                                    │');
    console.log('│   Access:   Full ERP/POS system for LifeSprout Care    │');
    console.log('├─────────────────────────────────────────────────────────┤');
    console.log('│ Customer                                                │');
    console.log('│   Email:    patient@lifesproutcare.com                  │');
    console.log('│   Password: patient123                                  │');
    console.log('│   Access:   Customer portal and purchase history       │');
    console.log('└─────────────────────────────────────────────────────────┘');
    
    console.log('\n✨ Your BillSprout app is now ready for real-time use!');
    console.log('🌐 Go to your app and login with any of the credentials above.');

  } catch (error) {
    console.error('❌ Setup failed:', error.message);
    process.exit(1);
  }
}

setupDemoUsers();