# Add Razorpay Secret Key to Supabase

## Step 1: Get Your Razorpay Secret Key

1. Go to https://dashboard.razorpay.com/
2. Login to your account
3. Go to Settings → API Keys
4. Copy your **Key Secret** (starts with `rzp_test_` or `rzp_live_`)

## Step 2: Add to Supabase Environment Variables

1. Go to https://supabase.com/dashboard
2. Select your project: `juvbhjqaioevpusnmonz`
3. Go to **Settings** → **Edge Functions**
4. Click on **Environment Variables**
5. Add a new environment variable:
   - **Name**: `RAZORPAY_KEY_SECRET`
   - **Value**: Your secret key (e.g., `rzp_test_YOUR_SECRET_KEY_HERE`)

## Step 3: Redeploy Edge Functions

After adding the environment variable, you need to redeploy your edge functions:

```bash
# Navigate to your project
cd c:\Users\saile\Desktop\erpme\billsprout

# Deploy the create-razorpay-order function
supabase functions deploy create-razorpay-order

# Deploy the verify-razorpay-payment function  
supabase functions deploy verify-razorpay-payment
```

## Step 4: Test the Payment

1. Go to your app
2. Try making a payment
3. Check the browser console for any errors
4. If still having issues, use the debug guide in `RAZORPAY_DEBUG_GUIDE.md`

## Alternative: Direct Environment Variable Setup

If you want me to help you add it directly, please provide your:
- **RAZORPAY_KEY_SECRET** (starts with rzp_test_ or rzp_live_)

Then I can help you add it programmatically.