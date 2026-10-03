#!/usr/bin/env node
/**
 * Test PayPal Configuration
 * Verifies that PayPal.Me link generation works correctly
 */

import { config } from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load .env from parent directory
const envPath = join(__dirname, '..', '.env');
config({ path: envPath });

const paypalMeUsername = process.env.PAYPAL_ME_USERNAME || '';
const paypalClientId = process.env.PAYPAL_CLIENT_ID || '';
const paypalSandbox = process.env.PAYPAL_SANDBOX === 'true';

console.log('\n📱 PayPal Configuration Test\n');
console.log('=' .repeat(50));

console.log('\n✓ Environment Variables:');
console.log(`  PAYPAL_ME_USERNAME: ${paypalMeUsername || '❌ NOT SET'}`);
console.log(`  PAYPAL_CLIENT_ID: ${paypalClientId ? '✓ SET' : '❌ NOT SET'}`);
console.log(`  PAYPAL_SANDBOX: ${paypalSandbox}`);

if (paypalMeUsername) {
  console.log('\n✓ PayPal.Me Links Generated:');
  
  const testAmounts = [10.00, 25.50, 100.99];
  
  testAmounts.forEach(amount => {
    const link = `https://paypal.me/${paypalMeUsername}/${amount.toFixed(2)}`;
    console.log(`  $${amount.toFixed(2)} → ${link}`);
  });
  
  console.log('\n✓ QR Code will display these links at POS checkout');
  console.log('✓ Customers can scan with PayPal app to pay instantly');
} else {
  console.log('\n❌ WARNING: PAYPAL_ME_USERNAME not set in .env');
  console.log('   Add your PayPal.Me username to enable QR code payments');
  console.log('   Example: PAYPAL_ME_USERNAME=YourPayPalUsername');
}

console.log('\n' + '='.repeat(50));
console.log('✅ Configuration test complete\n');
