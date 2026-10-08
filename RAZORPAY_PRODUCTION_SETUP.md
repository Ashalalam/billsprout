# Razorpay Production Setup Guide

## 🚨 IMPORTANT: Switch to Live Mode

Your current setup is in **TEST MODE**. To accept real payments, follow these steps:

## Step 1: Activate Razorpay Account

1. **Go to**: https://dashboard.razorpay.com/
2. **Complete KYC**: Upload business documents if not done
3. **Wait for approval** (usually takes 1-2 business days)
4. **Activate Live Mode** in your dashboard

## Step 2: Generate Live API Keys

1. **In Razorpay Dashboard** → **Settings** → **API Keys**
2. **Generate Live Keys** (NOT test keys)
3. **Copy both keys**:
   - **Key ID**: `rzp_live_XXXXXXXXXXXXXXXXXX`
   - **Key Secret**: `rzp_live_YYYYYYYYYYYYYYYYYY`

## Step 3: Update Your .env File

**Replace this line in your .env:**
```
RAZORPAY_KEY_ID=rzp_live_YOUR_LIVE_KEY_ID_HERE
```

**With your actual live key:**
```
RAZORPAY_KEY_ID=rzp_live_XXXXXXXXXXXXXXXXXX
```

## Step 4: Add Secret Key to Supabase

1. **Go to**: https://supabase.com/dashboard
2. **Select project**: `juvbhjqaioevpusnmonz`
3. **Settings** → **Edge Functions** → **Environment Variables**
4. **Add new variable**:
   - **Name**: `RAZORPAY_KEY_SECRET`
   - **Value**: `rzp_live_YYYYYYYYYYYYYYYYYY`

## Step 5: Deploy Edge Functions

```bash
cd c:\Users\saile\Desktop\erpme\billsprout
supabase functions deploy create-razorpay-order
supabase functions deploy verify-razorpay-payment
```

## Step 6: Test Live Payments

1. **Use a real debit/credit card** (not test cards)
2. **Small amount first** (₹1 or ₹10) to test
3. **Check Razorpay dashboard** for payment confirmation

## What Changed:

✅ **RAZORPAY_TEST_MODE**: Changed from `true` to `false`
✅ **Ready for live keys**: Updated .env template
✅ **Production mode**: App will now process real payments

## Next Steps:

1. **Get your live keys** from Razorpay dashboard
2. **Tell me your live keys** so I can:
   - Update your .env file
   - Add secret to Supabase
   - Deploy the functions
   - Test the payment

**Once you provide the keys, payments will work with real money! 💰**