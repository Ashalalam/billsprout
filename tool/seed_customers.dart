/// Seed sample customers to Supabase database
/// 
/// Run this script to populate your Supabase database with sample customer data.
/// This data will persist and be available across all devices and sessions.
/// 
/// Usage: dart run tool/seed_customers.dart

import 'dart:io';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

// Supabase credentials
const supabaseUrl = 'https://juvbhjqaioevpusnmonz.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1dmJoanFhaW9ldnB1c25tb256Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMjE2MDYsImV4cCI6MjEwNTg5NzYwNn0.D1bXZHEAnkdsSpWOeMpFlKOdhL-V8zpeficOneLPY0U';

void main() async {
  print('👥 Seeding Customers to Supabase Database...\n');

  try {
    final supabase = SupabaseClient(supabaseUrl, supabaseKey);
    print('✅ Connected to Supabase\n');

    // Sample customers data
    final customers = [
      // Retail Customers
      {
        'id': const Uuid().v4(),
        'name': 'Rajesh Kumar',
        'phone': '+91 98765 43210',
        'email': 'rajesh.kumar@example.com',
        'address': '123 MG Road, Bangalore, Karnataka 560001',
        'customer_type': 'Retail',
        'notes': 'Regular customer, prefers home delivery',
      },
      {
        'id': const Uuid().v4(),
        'name': 'Priya Sharma',
        'phone': '+91 98765 43211',
        'email': 'priya.sharma@example.com',
        'address': '456 Park Street, Mumbai, Maharashtra 400001',
        'customer_type': 'Retail',
        'notes': 'Senior citizen, needs assistance with prescriptions',
      },
      {
        'id': const Uuid().v4(),
        'name': 'Amit Patel',
        'phone': '+91 98765 43212',
        'email': 'amit.patel@example.com',
        'address': '789 Gandhi Nagar, Ahmedabad, Gujarat 380001',
        'customer_type': 'Retail',
        'notes': 'Diabetic patient, monthly medication refills',
      },
      {
        'id': const Uuid().v4(),
        'name': 'Sneha Reddy',
        'phone': '+91 98765 43213',
        'email': 'sneha.reddy@example.com',
        'address': '321 Banjara Hills, Hyderabad, Telangana 500034',
        'customer_type': 'Retail',
        'notes': 'Prefers generic medicines',
      },
      {
        'id': const Uuid().v4(),
        'name': 'Vikram Singh',
        'phone': '+91 98765 43214',
        'email': 'vikram.singh@example.com',
        'address': '654 Civil Lines, Delhi, Delhi 110054',
        'customer_type': 'Retail',
        'notes': 'Corporate employee, insurance claim support needed',
      },

      // Wholesale Customers
      {
        'id': const Uuid().v4(),
        'name': 'City Medical Store',
        'phone': '+91 98765 43215',
        'email': 'orders@citymedical.com',
        'address': '12 Market Road, Pune, Maharashtra 411001',
        'customer_type': 'Wholesale',
        'gst_number': '27AABCU9603R1ZM',
        'notes': 'Bulk orders, payment terms: 30 days credit',
      },
      {
        'id': const Uuid().v4(),
        'name': 'Health Plus Pharmacy',
        'phone': '+91 98765 43216',
        'email': 'purchase@healthplus.com',
        'address': '45 Commercial Street, Chennai, Tamil Nadu 600001',
        'customer_type': 'Wholesale',
        'gst_number': '33AACCH1234F1Z5',
        'notes': 'Weekly bulk orders, 10% discount applicable',
      },
      {
        'id': const Uuid().v4(),
        'name': 'MediCare Distributors',
        'phone': '+91 98765 43217',
        'email': 'info@medicare.com',
        'address': '78 Industrial Area, Kolkata, West Bengal 700001',
        'customer_type': 'Wholesale',
        'gst_number': '19AACCM5678G1Z3',
        'notes': 'Large distributor, minimum order ₹50,000',
      },

      // Distributor Customers
      {
        'id': const Uuid().v4(),
        'name': 'PharmaLink Distributors',
        'phone': '+91 98765 43218',
        'email': 'sales@pharmalink.com',
        'address': '90 Warehouse Complex, Noida, Uttar Pradesh 201301',
        'customer_type': 'Distributor',
        'gst_number': '09AACCP1234H1Z7',
        'notes': 'Regional distributor, supplies to 50+ pharmacies',
      },
      {
        'id': const Uuid().v4(),
        'name': 'MedSupply Chain Pvt Ltd',
        'phone': '+91 98765 43219',
        'email': 'orders@medsupply.com',
        'address': '23 Logistics Hub, Surat, Gujarat 395001',
        'customer_type': 'Distributor',
        'gst_number': '24AACCM9876K1Z2',
        'notes': 'Exclusive distributor for western region',
      },

      // Hospital/Clinic Customers
      {
        'id': const Uuid().v4(),
        'name': 'Sunshine Hospital',
        'phone': '+91 98765 43220',
        'email': 'pharmacy@sunshinehospital.com',
        'address': '101 Hospital Road, Bangalore, Karnataka 560002',
        'customer_type': 'Wholesale',
        'gst_number': '29AACCS1234L1Z9',
        'notes': 'Hospital pharmacy, emergency supplies needed 24/7',
      },
      {
        'id': const Uuid().v4(),
        'name': 'Dr. Mehta Clinic',
        'phone': '+91 98765 43221',
        'email': 'clinic@drmehta.com',
        'address': '67 Clinic Street, Jaipur, Rajasthan 302001',
        'customer_type': 'Wholesale',
        'gst_number': '08AACCD5678M1Z4',
        'notes': 'Multi-specialty clinic, monthly orders',
      },

      // International/Walk-in Customers
      {
        'id': const Uuid().v4(),
        'name': 'John Smith',
        'phone': '+44 7700 900123',
        'email': 'john.smith@example.com',
        'address': '456 Oxford Street, London, UK',
        'customer_type': 'Retail',
        'notes': 'Tourist, one-time purchase',
      },
      {
        'id': const Uuid().v4(),
        'name': 'Maria Garcia',
        'phone': '+1 555 0123',
        'email': 'maria.garcia@example.com',
        'address': '789 Main Street, New York, USA',
        'customer_type': 'Retail',
        'notes': 'International visitor, requires invoice for insurance',
      },
      {
        'id': const Uuid().v4(),
        'name': 'Walk-in Customer',
        'phone': '',
        'email': '',
        'address': '',
        'customer_type': 'Retail',
        'notes': 'Default customer for quick sales without details',
      },
    ];

    print('📦 Inserting ${customers.length} customers...\n');

    int successCount = 0;
    int failCount = 0;

    for (final customer in customers) {
      try {
        await supabase.from('customers').insert(customer);
        print('✅ Added: ${customer['name']}');
        successCount++;
      } catch (e) {
        print('❌ Failed: ${customer['name']} - $e');
        failCount++;
      }
    }

    print('\n✨ Seeding Complete!');
    print('   ✅ Success: $successCount customers');
    if (failCount > 0) {
      print('   ❌ Failed: $failCount customers');
    }
    print('\n👥 Customer Types Summary:');
    print('   🛒 Retail: Individual/walk-in customers');
    print('   🏪 Wholesale: Pharmacies and medical stores');
    print('   🚚 Distributor: Large-scale distributors');
    print('\n📱 Now refresh your app to see the new customers!\n');

  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }

  exit(0);
}
