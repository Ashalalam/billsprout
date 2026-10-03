/// Seed sample medicines to Supabase database
/// 
/// Run this script to populate your Supabase database with sample medicine data.
/// This data will persist and be available across all devices and sessions.
/// 
/// Usage: dart run tool/seed_medicines.dart

import 'dart:io';
import 'package:supabase/supabase.dart';

// Supabase credentials - matches your .env file
const supabaseUrl = 'https://juvbhjqaioevpusnmonz.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1dmJoanFhaW9ldnB1c25tb256Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMjE2MDYsImV4cCI6MjEwNTg5NzYwNn0.D1bXZHEAnkdsSpWOeMpFlKOdhL-V8zpeficOneLPY0U';

void main() async {
  print('🌱 Seeding Medicines to Supabase Database...\n');

  try {
    // Initialize Supabase client
    final supabase = SupabaseClient(supabaseUrl, supabaseKey);

    print('✅ Connected to Supabase');

    // Sample medicines data
    final medicines = [
      // Pain Relief & Fever
      {
        'name': 'Paracetamol 500mg',
        'category': 'Pain Relief',
        'mrp': 25.00,
        'selling_price': 22.00,
        'stock_quantity': 500,
        'reorder_level': 100,
        'manufacturer': 'Sun Pharma',
        'prescription_required': false,
        'schedule': 'OTC',
        'description': 'Fever and pain reliever',
        'batch_number': 'PCM2024A',
        'expiry_date': '2026-12-31',
        'gst_percentage': 12.0,
      },
      {
        'name': 'Ibuprofen 400mg',
        'category': 'Pain Relief',
        'mrp': 45.00,
        'selling_price': 40.00,
        'stock_quantity': 300,
        'reorder_level': 80,
        'manufacturer': 'Cipla',
        'prescription_required': false,
        'schedule': 'OTC',
        'description': 'Anti-inflammatory pain reliever',
        'batch_number': 'IBU2024B',
        'expiry_date': '2026-11-30',
        'gst_percentage': 12.0,
      },
      {
        'name': 'Aspirin 75mg',
        'category': 'Cardiovascular',
        'mrp': 15.00,
        'selling_price': 13.00,
        'stock_quantity': 400,
        'reorder_level': 100,
        'manufacturer': 'Bayer',
        'prescription_required': true,
        'schedule': 'H',
        'description': 'Blood thinner for heart health',
        'batch_number': 'ASP2024C',
        'expiry_date': '2026-10-31',
        'gst_percentage': 12.0,
      },

      // Antibiotics
      {
        'name': 'Amoxicillin 500mg',
        'category': 'Antibiotics',
        'mrp': 120.00,
        'selling_price': 108.00,
        'stock_quantity': 200,
        'reorder_level': 50,
        'manufacturer': 'GlaxoSmithKline',
        'prescription_required': true,
        'schedule': 'H',
        'description': 'Broad-spectrum antibiotic',
        'batch_number': 'AMX2024D',
        'expiry_date': '2026-09-30',
        'gst_percentage': 12.0,
      },
      {
        'name': 'Azithromycin 500mg',
        'category': 'Antibiotics',
        'mrp': 180.00,
        'selling_price': 162.00,
        'stock_quantity': 150,
        'reorder_level': 40,
        'manufacturer': 'Pfizer',
        'prescription_required': true,
        'schedule': 'H',
        'description': 'Macrolide antibiotic',
        'batch_number': 'AZI2024E',
        'expiry_date': '2026-08-31',
        'gst_percentage': 12.0,
      },

      // Diabetes
      {
        'name': 'Metformin 500mg',
        'category': 'Diabetes',
        'mrp': 85.00,
        'selling_price': 76.50,
        'stock_quantity': 350,
        'reorder_level': 80,
        'manufacturer': 'Lupin',
        'prescription_required': true,
        'schedule': 'H',
        'description': 'Type 2 diabetes medication',
        'batch_number': 'MET2024F',
        'expiry_date': '2027-01-31',
        'gst_percentage': 12.0,
      },
      {
        'name': 'Glimepiride 2mg',
        'category': 'Diabetes',
        'mrp': 95.00,
        'selling_price': 85.50,
        'stock_quantity': 250,
        'reorder_level': 60,
        'manufacturer': 'Torrent',
        'prescription_required': true,
        'schedule': 'H',
        'description': 'Diabetes sulfonylurea medication',
        'batch_number': 'GLI2024G',
        'expiry_date': '2027-02-28',
        'gst_percentage': 12.0,
      },

      // Blood Pressure
      {
        'name': 'Amlodipine 5mg',
        'category': 'Cardiovascular',
        'mrp': 65.00,
        'selling_price': 58.50,
        'stock_quantity': 300,
        'reorder_level': 70,
        'manufacturer': 'Dr Reddy',
        'prescription_required': true,
        'schedule': 'H',
        'description': 'Calcium channel blocker for hypertension',
        'batch_number': 'AML2024H',
        'expiry_date': '2026-12-31',
        'gst_percentage': 12.0,
      },
      {
        'name': 'Atenolol 50mg',
        'category': 'Cardiovascular',
        'mrp': 55.00,
        'selling_price': 49.50,
        'stock_quantity': 280,
        'reorder_level': 70,
        'manufacturer': 'Zydus',
        'prescription_required': true,
        'schedule': 'H',
        'description': 'Beta blocker for blood pressure',
        'batch_number': 'ATE2024I',
        'expiry_date': '2026-11-30',
        'gst_percentage': 12.0,
      },

      // Vitamins & Supplements
      {
        'name': 'Vitamin D3 60K IU',
        'category': 'Vitamins',
        'mrp': 45.00,
        'selling_price': 40.00,
        'stock_quantity': 400,
        'reorder_level': 100,
        'manufacturer': 'HealthKart',
        'prescription_required': false,
        'schedule': 'OTC',
        'description': 'Vitamin D supplement',
        'batch_number': 'VTD2024J',
        'expiry_date': '2027-03-31',
        'gst_percentage': 18.0,
      },
      {
        'name': 'Multivitamin Tablets',
        'category': 'Vitamins',
        'mrp': 250.00,
        'selling_price': 225.00,
        'stock_quantity': 200,
        'reorder_level': 50,
        'manufacturer': 'Revital',
        'prescription_required': false,
        'schedule': 'OTC',
        'description': 'Daily multivitamin supplement',
        'batch_number': 'MVT2024K',
        'expiry_date': '2027-04-30',
        'gst_percentage': 18.0,
      },
      {
        'name': 'Calcium + Vitamin D',
        'category': 'Vitamins',
        'mrp': 180.00,
        'selling_price': 162.00,
        'stock_quantity': 250,
        'reorder_level': 60,
        'manufacturer': 'Shelcal',
        'prescription_required': false,
        'schedule': 'OTC',
        'description': 'Bone health supplement',
        'batch_number': 'CAL2024L',
        'expiry_date': '2027-05-31',
        'gst_percentage': 18.0,
      },

      // Digestive Health
      {
        'name': 'Omeprazole 20mg',
        'category': 'Digestive',
        'mrp': 75.00,
        'selling_price': 67.50,
        'stock_quantity': 300,
        'reorder_level': 70,
        'manufacturer': 'Sun Pharma',
        'prescription_required': true,
        'schedule': 'H',
        'description': 'Proton pump inhibitor for acidity',
        'batch_number': 'OME2024M',
        'expiry_date': '2026-10-31',
        'gst_percentage': 12.0,
      },
      {
        'name': 'Ranitidine 150mg',
        'category': 'Digestive',
        'mrp': 45.00,
        'selling_price': 40.50,
        'stock_quantity': 350,
        'reorder_level': 80,
        'manufacturer': 'Cipla',
        'prescription_required': false,
        'schedule': 'OTC',
        'description': 'H2 blocker for heartburn',
        'batch_number': 'RAN2024N',
        'expiry_date': '2026-09-30',
        'gst_percentage': 12.0,
      },

      // Cold & Cough
      {
        'name': 'Cetirizine 10mg',
        'category': 'Allergy',
        'mrp': 35.00,
        'selling_price': 31.50,
        'stock_quantity': 450,
        'reorder_level': 100,
        'manufacturer': 'Dr Reddy',
        'prescription_required': false,
        'schedule': 'OTC',
        'description': 'Antihistamine for allergies',
        'batch_number': 'CET2024O',
        'expiry_date': '2027-01-31',
        'gst_percentage': 12.0,
      },
      {
        'name': 'Cough Syrup 100ml',
        'category': 'Respiratory',
        'mrp': 95.00,
        'selling_price': 85.50,
        'stock_quantity': 180,
        'reorder_level': 40,
        'manufacturer': 'Benadryl',
        'prescription_required': false,
        'schedule': 'OTC',
        'description': 'Cough suppressant syrup',
        'batch_number': 'COU2024P',
        'expiry_date': '2026-08-31',
        'gst_percentage': 12.0,
      },
    ];

    print('\n📦 Inserting ${medicines.length} medicines...\n');

    // Note: We need tenant_id and branch_id from your actual login
    // For now, we'll insert without them and you can update via the app
    // Or you can add them here if you know your IDs

    int successCount = 0;
    int failCount = 0;

    for (final medicine in medicines) {
      try {
        await supabase.from('products').insert(medicine);
        print('✅ Added: ${medicine['name']}');
        successCount++;
      } catch (e) {
        print('❌ Failed: ${medicine['name']} - $e');
        failCount++;
      }
    }

    print('\n✨ Seeding Complete!');
    print('   ✅ Success: $successCount medicines');
    if (failCount > 0) {
      print('   ❌ Failed: $failCount medicines');
    }
    print('\n📱 Now refresh your app to see the new medicines!\n');

  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }

  exit(0);
}
