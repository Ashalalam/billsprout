# Debug Razorpay Authentication Issue

## Current Status: Authentication Failed (401)

### Possible Causes:

1. **Supabase Authentication**: Edge function requires user to be logged in
2. **Environment Variables**: Missing or incorrect Razorpay keys
3. **App Authorization**: Flutter app not sending auth headers correctly

### Debugging Steps:

## 1. Verify Environment Variables in Supabase

✅ **RAZORPAY_KEY_ID**: `rzp_test_TlQpbkhf8aylDg` (confirmed)
✅ **RAZORPAY_KEY_SECRET**: `njOECeGNbHoztur3f5pLcniK` (confirmed)

## 2. Check Supabase Authentication

The edge function requires a logged-in user:

```typescript
const {
  data: { user },
} = await supabaseClient.auth.getUser()

if (!user) {
  return new Response(
    JSON.stringify({ error: 'Unauthorized' }),
    { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}
```

## 3. Test Authentication Status

**IMPORTANT**: You must be logged into the app for payments to work!

### Quick Test:
1. Make sure you're logged into BillSprout app
2. Check if user session is active
3. Try payment again

## 4. Debug in Browser Console

1. Open browser Developer Tools (F12)
2. Go to Network tab
3. Try making a payment
4. Look for the `create-razorpay-order` request
5. Check:
   - Request headers (should include Authorization)
   - Response status and body

## 5. Manual Test Edge Function

Test the function directly:

```bash
curl -X POST https://juvbhjqaioevpusnmonz.supabase.co/functions/v1/create-razorpay-order \
  -H "Authorization: Bearer YOUR_SUPABASE_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 100000,
    "currency": "INR", 
    "receipt": "test_receipt_123"
  }'
```

## 6. Likely Solution

**The user needs to be logged in to BillSprout app before making payments!**

### Steps to Fix:
1. ✅ Login to BillSprout app first
2. ✅ Navigate to subscription/payment page
3. ✅ Try payment again

If still failing after login, check browser console for detailed error messages.

## 7. Alternative: Remove Auth Check (For Testing Only)

If you want to test without authentication, we can temporarily modify the edge function to skip auth check, but this is NOT recommended for production.

Let me know if you're logged in and still getting 401 errors!