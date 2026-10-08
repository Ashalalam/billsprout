# Razorpay Integration Fix Guide

## Issue
Razorpay payments are failing in your BillSprout application.

## Root Causes & Solutions

### 1. Missing Razorpay Secret Key in Supabase Environment

**Problem**: The edge function needs `RAZORPAY_KEY_SECRET` but it's not configured in Supabase.

**Solution**: Add environment variables to your Supabase project:

1. Go to your Supabase dashboard: https://supabase.com/dashboard/projects
2. Select your project: `juvbhjqaioevpusnmonz`
3. Go to **Settings** > **Edge Functions**
4. Add these environment variables:
   - `RAZORPAY_KEY_ID` = `rzp_test_Tk4ZXKGF4ZFN2R`
   - `RAZORPAY_KEY_SECRET` = `your_secret_key_here` (get from Razorpay dashboard)

### 2. Get Your Razorpay Secret Key

1. Go to https://dashboard.razorpay.com/
2. Login to your account
3. Go to **Settings** > **API Keys**
4. Copy the **Key Secret** (starts with `rzp_test_` for test mode)
5. Add it to Supabase environment variables

### 3. Test the Integration

After adding the environment variables:

1. **Deploy Edge Functions**: In your terminal:
   ```bash
   supabase functions deploy create-razorpay-order
   supabase functions deploy verify-razorpay-payment
   ```

2. **Test Payment Flow**:
   - Go to subscription page in your app
   - Try to make a payment
   - Check browser console for errors

### 4. Verify Environment Variables are Set

You can test if the edge function has the environment variables by adding a test endpoint:

```typescript
// Add this to your edge function for testing
console.log('RAZORPAY_KEY_ID:', RAZORPAY_KEY_ID ? 'SET' : 'MISSING')
console.log('RAZORPAY_KEY_SECRET:', RAZORPAY_KEY_SECRET ? 'SET' : 'MISSING')
```

### 5. Common Issues and Solutions

**Issue**: "RAZORPAY_KEY_SECRET is missing"
**Solution**: Set the environment variable in Supabase dashboard

**Issue**: "Razorpay SDK not loaded"
**Solution**: Check internet connection, the SDK loads from CDN

**Issue**: "Order creation failed"
**Solution**: Check Razorpay dashboard for API limits and account status

**Issue**: "CORS errors"
**Solution**: The edge function already handles CORS, ensure it's deployed

### 6. Alternative: Direct Client-Side Integration (Less Secure)

If edge functions continue to fail, you can temporarily use client-side integration:

1. Create orders directly in the Flutter app
2. Use server-side verification for security
3. This exposes your test keys but works for development

### 7. Debug Steps

1. **Check Supabase Function Logs**:
   - Go to your Supabase dashboard
   - Navigate to Edge Functions > Logs
   - Look for errors in `create-razorpay-order` function

2. **Check Browser Console**:
   - Open DevTools (F12)
   - Look for JavaScript errors
   - Check Network tab for failed requests

3. **Verify Razorpay Account**:
   - Ensure account is activated
   - Check API key status
   - Verify test mode is enabled

## Quick Test Command

Run this in your terminal to test the edge function:

```bash
curl -X POST 'https://juvbhjqaioevpusnmonz.supabase.co/functions/v1/create-razorpay-order' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "amount": 10000,
    "currency": "INR", 
    "receipt": "test_receipt_123"
  }'
```

Replace `YOUR_ANON_KEY` with your Supabase anon key from the .env file.

## Expected Response

Success response:
```json
{
  "success": true,
  "order_id": "order_xxxxxxxxxxxxx",
  "amount": 10000,
  "currency": "INR"
}
```

Error response:
```json
{
  "error": "Missing required fields: amount, currency, receipt"
}
```