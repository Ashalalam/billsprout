#!/usr/bin/env node

/**
 * Verify that data is actually being saved to Supabase
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

console.log('\n═══════════════════════════════════════════════════════');
console.log('  Verifying Data in Supabase');
console.log('═══════════════════════════════════════════════════════\n');

async function checkData() {
  const tenantId = '49d25b05-d505-416f-9b2d-31baf7f06f85';
  
  console.log(`📊 Checking data for tenant: ${tenantId.substring(0, 8)}...\n`);
  
  try {
    // Check products
    const { data: products, error: prodError } = await supabase
      .from('products')
      .select('id, name, manufacturer, created_at')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false })
      .limit(10);
    
    if (prodError) {
      console.log('❌ Products error:', prodError.message);
    } else {
      console.log(`✅ Products: ${products.length} found`);
      products.forEach((p, idx) => {
        console.log(`   ${idx + 1}. ${p.name} (${p.manufacturer || 'No manufacturer'})`);
      });
      console.log();
    }
    
    // Check customers
    const { data: customers, error: custError } = await supabase
      .from('customers')
      .select('id, customer_name, phone, email, created_at')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false })
      .limit(10);
    
    if (custError) {
      console.log('❌ Customers error:', custError.message);
    } else {
      console.log(`✅ Customers: ${customers.length} found`);
      customers.forEach((c, idx) => {
        console.log(`   ${idx + 1}. ${c.customer_name} (${c.phone || c.email || 'No contact'})`);
      });
      console.log();
    }
    
    // Check sales/invoices
    const { data: sales, error: salesError } = await supabase
      .from('sales')
      .select('id, invoice_number, grand_total, invoice_date')
      .eq('tenant_id', tenantId)
      .order('invoice_date', { ascending: false })
      .limit(10);
    
    if (salesError) {
      console.log('❌ Sales error:', salesError.message);
    } else {
      console.log(`✅ Invoices/Sales: ${sales.length} found`);
      sales.forEach((s, idx) => {
        console.log(`   ${idx + 1}. ${s.invoice_number} - ₹${s.grand_total}`);
      });
      console.log();
    }
    
    // Check batches
    const { data: batches, error: batchError } = await supabase
      .from('batches')
      .select('id, batch_number, stock_quantity, mrp, created_at')
      .eq('tenant_id', tenantId)
      .order('created_at', { ascending: false })
      .limit(10);
    
    if (batchError) {
      console.log('❌ Batches error:', batchError.message);
    } else {
      console.log(`✅ Batches: ${batches.length} found`);
      batches.forEach((b, idx) => {
        console.log(`   ${idx + 1}. Batch ${b.batch_number} - Stock: ${b.stock_quantity} - MRP: ₹${b.mrp}`);
      });
      console.log();
    }
    
    console.log('═══════════════════════════════════════════════════════');
    
    const totalRecords = 
      (products?.length || 0) + 
      (customers?.length || 0) + 
      (sales?.length || 0) + 
      (batches?.length || 0);
    
    if (totalRecords === 0) {
      console.log('⚠️  NO DATA FOUND IN SUPABASE!');
      console.log('   Please add medicines/customers in the app and run this again.\n');
    } else {
      console.log(`✅ TOTAL: ${totalRecords} records found in Supabase!`);
      console.log('   Data is being saved correctly! 🎉\n');
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Auto-refresh every 5 seconds
async function watchData() {
  await checkData();
  
  console.log('🔄 Watching for new data... (Press Ctrl+C to stop)\n');
  console.log('Add medicines/customers in the app and watch them appear here!\n');
  
  setInterval(async () => {
    console.clear();
    console.log('═══════════════════════════════════════════════════════');
    console.log('  Live Data Monitor - ' + new Date().toLocaleTimeString());
    console.log('═══════════════════════════════════════════════════════\n');
    await checkData();
  }, 5000);
}

// Run once or watch
const watchMode = process.argv.includes('--watch');

if (watchMode) {
  watchData();
} else {
  checkData();
}
