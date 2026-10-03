/// Setup tenant and branch for Supabase user
/// 
/// This script creates a tenant (company) and branch in Supabase,
/// then updates your user account with the tenant_id and branch_id.
/// 
/// Usage: dart run tool/setup_tenant.dart

import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

// Supabase credentials
const supabaseUrl = 'https://juvbhjqaioevpusnmonz.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1dmJoanFhaW9ldnB1c25tb256Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMjE2MDYsImV4cCI6MjEwNTg5NzYwNn0.D1bXZHEAnkdsSpWOeMpFlKOdhL-V8zpeficOneLPY0U';

void main() async {
  print('🏢 Setting up Tenant & Branch for BillSprout...\n');

  // Using default Business Admin credentials
  const email = 'admin@lifesproutcare.com';
  const password = 'admin123';  // You can change this

  try {
    final supabase = SupabaseClient(supabaseUrl, supabaseKey);

    // Sign in or create account
    print('🔐 Attempting to sign in as $email...');
    
    AuthResponse authResponse;
    try {
      authResponse = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('⚠️  Sign in failed, creating new account...');
      
      // Try to sign up
      authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': 'Admin User',
          'role': 'businessAdmin',
        },
        emailRedirectTo: null,
      );
    }

    final userId = authResponse.user?.id ?? supabase.auth.currentUser?.id;
    if (userId == null) {
      print('❌ Could not get user ID');
      exit(1);
    }

    print('✅ Authenticated successfully\n');

    // Step 2: Create or find tenant (company)
    print('🏢 Setting up tenant (company)...');
    
    final tenantId = const Uuid().v4();
    final tenant = {
      'id': tenantId,
      'name': 'LifeSprout Care',
      'email': email,
      'phone': '+44 7747 571513',
      'subscription_status': 'active',
      'subscription_plan': 'professional',
      'subscription_start_date': DateTime.now().toIso8601String(),
      'subscription_end_date': DateTime.now().add(const Duration(days: 365)).toIso8601String(),
      'owner_user_id': userId,
    };

    try {
      await supabase.from('tenants').insert(tenant);
      print('✅ Created tenant: ${tenant['name']}');
    } catch (e) {
      print('⚠️  Tenant may already exist, continuing...');
    }

    // Step 3: Create or find branch
    print('🏪 Setting up branch...');
    
    final branchId = const Uuid().v4();
    final branch = {
      'id': branchId,
      'tenant_id': tenantId,
      'name': 'Main Branch',
      'address': 'Main Street, City',
      'phone': '+44 7747 571513',
      'is_primary': true,
    };

    try {
      await supabase.from('branches').insert(branch);
      print('✅ Created branch: ${branch['name']}');
    } catch (e) {
      print('⚠️  Branch may already exist, continuing...');
    }

    // Step 4: Update user metadata with tenant_id and branch_id
    print('👤 Updating user profile...');
    
    await supabase.auth.updateUser(
      UserAttributes(
        data: {
          'tenant_id': tenantId,
          'branch_id': branchId,
          'name': 'Admin User',
          'role': 'businessAdmin',
        },
      ),
    );

    print('✅ Updated user profile\n');

    // Summary
    print('🎉 Setup Complete!\n');
    print('Tenant ID: $tenantId');
    print('Branch ID: $branchId');
    print('User Email: $email');
    print('\n📱 Now log in to your app with these credentials:');
    print('   Email: $email');
    print('   Password: ********');
    print('\n✨ Your dashboard should now show data!\n');

    await supabase.auth.signOut();

  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }

  exit(0);
}
