# Razorpay Debug Guide - "Instance of Minified" Error Fix

## 🔍 Understanding the "Instance of Minified" Error

This error occurs when Razorpay JavaScript throws an exception that Flutter Web can't properly decode. Common causes:

### 1. **Test vs Live Key Mismatch**
- **Test keys** start with `rzp_test_`
- **Live keys** start with `rzp_live_`
- Make sure your environment matches your keys

### 2. **Invalid Key Format**
- Keys must be exactly as provided by Razorpay dashboard
- No extra spaces, quotes, or characters
- Verify key length (should be ~28 characters after prefix)

### 3. **Network/CORS Issues**
- Test keys work only on localhost or test domains
- Live keys work on production domains
- Check browser console for CORS errors

## 🛠 Current Configuration Debug

### Check Your Current Setup:

1. **Environment File (.env)**
```env
# Your current test setup
RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxx
```

2. **Supabase Environment Variables**
```
RAZORPAY_KEY_SECRET=your_test_secret_here
```

3. **Web Index File (web/index.html)**
```html
<script src="https://checkout.razorpay.com/v1/checkout.js"></script>
```

## 🐛 Debugging Steps

### Step 1: Verify Razorpay SDK Loading
Open browser console and check:
```javascript
console.log('Razorpay available:', typeof Razorpay !== 'undefined');
console.log('Razorpay version:', Razorpay ? Razorpay.version : 'Not loaded');
```

### Step 2: Test Key Validation
Your test key should:
- Start with `rzp_test_`
- Be 28+ characters total
- Have no spaces or special characters

### Step 3: Check Browser Console
Look for errors like:
- `CORS policy errors`
- `Invalid key format`
- `Network request failed`
- `Script load errors`

## 🔧 Quick Fixes for Common Issues

### Fix 1: Test Environment Setup
```env
# .env file
RAZORPAY_KEY_ID=rzp_test_your_actual_test_key
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_key
```

### Fix 2: Test Payment Flow
Use these test values:
- **Amount**: ₹1.00 (100 paise)
- **Test Card**: 4111 1111 1111 1111
- **Expiry**: Any future date
- **CVV**: Any 3 digits

### Fix 3: Supabase Edge Function Environment
Make sure your Supabase project has:
```bash
# Deploy edge functions with environment
supabase functions deploy create-razorpay-order
supabase functions deploy verify-razorpay-payment
```

Environment variables in Supabase dashboard:
- `RAZORPAY_KEY_SECRET`: Your test secret key

## 🔑 When You Get Production Keys

### Step 1: Update Environment Files
```env
# .env (for Flutter app)
RAZORPAY_KEY_ID=rzp_live_your_live_key

# Supabase Environment Variables
RAZORPAY_KEY_SECRET=your_live_secret
```

### Step 2: Domain Verification
Live keys only work on:
- Registered domains in Razorpay dashboard
- HTTPS enabled domains
- Properly configured CORS settings

### Step 3: Test on Staging First
Before production:
1. Test with small amounts (₹1-10)
2. Verify webhooks are working
3. Check payment verification flow
4. Test refund functionality

## 🚨 Emergency Fallback

If Razorpay continues failing, you can temporarily:

### Option 1: Manual Payment Processing
```dart
// Add to POS provider
void recordManualPayment({
  required double amount,
  required String method,
  String? reference,
}) {
  // Record payment with manual verification flag
  // Show instructions for bank transfer/UPI
}
```

### Option 2: Alternative Payment Gateway
Consider integrating:
- **PayU**: Good for Indian market
- **CCAvenue**: Wide bank support
- **Paytm**: Popular in India
- **Stripe**: International payments

## 📊 Debug Information Collection

When reporting issues, collect:

1. **Browser Console Logs**
2. **Network Tab in DevTools**
3. **Razorpay Key Format** (first 8 chars only)
4. **Supabase Function Logs**
5. **Flutter Web Debug Console**

## 🎯 Action Items for You

### Immediate Steps:
1. ✅ Get production keys from Razorpay dashboard
2. ✅ Update `.env` file with new keys
3. ✅ Add `RAZORPAY_KEY_SECRET` to Supabase environment
4. ✅ Test with ₹1 payment first
5. ✅ Verify domain configuration

### Testing Checklist:
- [ ] Test key format validated
- [ ] Supabase functions deployed
- [ ] Environment variables set
- [ ] Browser console clean
- [ ] Test payment successful
- [ ] Payment verification working
- [ ] Error handling graceful

## 📞 Support

If issues persist after getting production keys:
1. Check Razorpay dashboard for transaction logs
2. Verify domain whitelisting
3. Test in incognito mode
4. Try different browsers
5. Check network connectivity

The enhanced error handling will now provide much better debugging information when you test again!