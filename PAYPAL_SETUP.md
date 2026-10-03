# PayPal Configuration Guide

This guide will help you set up PayPal integration for BillSprout/LifeSprout Care ERP system.

## Overview

BillSprout uses PayPal for:
- **Subscription Payments**: SaaS monthly/annual subscriptions
- **POS Payments**: Point-of-sale QR code payments via PayPal.Me
- **Invoice Payments**: Customer invoice settlements

## Prerequisites

1. **PayPal Business Account**: You need a verified PayPal Business account
   - Create one at: https://www.paypal.com/business
   
2. **PayPal Developer Account**: Access to PayPal Developer Dashboard
   - Same login as your PayPal Business account
   - Dashboard: https://developer.paypal.com/dashboard/

## Step 1: Get PayPal API Credentials

### For Production (Live Payments)

1. Go to [PayPal Developer Dashboard](https://developer.paypal.com/dashboard/)
2. Log in with your PayPal Business account
3. Click **"Apps & Credentials"** in the left menu
4. Click the **"Live"** tab (not Sandbox)
5. Click **"Create App"** or select an existing app
6. Copy your credentials:
   - **Client ID**: Starts with `A...` (long string)
   - **Client Secret**: Click "Show" to reveal, then copy

### For Testing (Sandbox)

1. In the same Dashboard, click the **"Sandbox"** tab
2. Create a test app or use the default app
3. Copy the Sandbox Client ID and Secret
4. You can also create test buyer/seller accounts here

## Step 2: Get PayPal.Me Username (Optional)

PayPal.Me allows customers to pay via QR code scanning.

1. Go to https://www.paypal.me/
2. Create or claim your PayPal.Me link (e.g., `paypal.me/YourBusinessName`)
3. Note your username (the part after `paypal.me/`)

## Step 3: Configure BillSprout

### Option A: Using .env File (Recommended for Production)

1. Copy `.env.example` to `.env` in the project root:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and add your credentials:
   ```env
   PAYPAL_CLIENT_ID=your-actual-client-id-here
   PAYPAL_CLIENT_SECRET=your-actual-client-secret-here
   PAYPAL_ME_USERNAME=YourBusinessName
   PAYPAL_MERCHANT_ID=your-merchant-id (optional)
   PAYPAL_SANDBOX_MODE=false
   ```

3. **IMPORTANT**: Never commit `.env` to git! (Already in `.gitignore`)

### Option B: Using In-App Configuration

1. Launch the app as **Business Admin**
2. Go to **Settings** → **PayPal Configuration**
3. Enter your credentials:
   - Client ID
   - Client Secret
   - PayPal.Me Username (optional)
   - Toggle **Production** mode (turn OFF sandbox)
4. Click **Save Configuration**

Credentials are stored securely in encrypted SharedPreferences on the device.

## Step 4: Verify Configuration

1. In the app, go to **PayPal Configuration** screen
2. Check the **PayPal Environment** indicator:
   - 🟢 **Production (Live)** - Real payments will be processed
   - 🟠 **Sandbox (Testing)** - Test mode only
3. Verify the masked Client ID is showing correctly

## Security Best Practices

### ✅ DO:
- Use **production credentials** only in production builds
- Store credentials in `.env` file (gitignored)
- Rotate credentials if they are ever exposed
- Use separate apps for development and production
- Monitor transactions in PayPal Dashboard regularly

### ❌ DON'T:
- **Never** commit `.env` file to git
- **Never** hardcode credentials in source code
- **Never** share your Client Secret publicly
- **Never** use production credentials in test builds
- **Never** commit files like `paypal_credentials.json` or `paypal_keys.dart`

## Testing

### Sandbox Testing

1. Set `PAYPAL_SANDBOX_MODE=true` in `.env`
2. Use Sandbox credentials
3. Create test accounts in PayPal Developer Dashboard
4. Test payments will not charge real money

### Production Testing

⚠️ **Warning**: Production mode processes real payments!

1. Set `PAYPAL_SANDBOX_MODE=false`
2. Use Live credentials
3. Test with small amounts ($0.01)
4. Refund test transactions immediately

## Troubleshooting

### "PayPal credentials not configured"
- Check `.env` file exists and has correct values
- Verify app loaded `.env` (check console logs)
- Try configuring via in-app settings

### "Authentication failed"
- Verify Client ID and Secret are correct
- Check if you're using Sandbox credentials in Production mode (or vice versa)
- Ensure credentials are from the correct environment tab

### "PayPal.Me QR code not working"
- Verify your PayPal.Me username is correct
- Ensure your PayPal.Me link is active
- Test by opening `https://paypal.me/YourUsername` in browser

### Payments not appearing in dashboard
- Check you're logged into the correct PayPal account
- Verify you're in the right environment (Live vs Sandbox)
- Wait a few minutes for transactions to appear

## Support

- **PayPal Support**: https://www.paypal.com/support/
- **Developer Docs**: https://developer.paypal.com/docs/
- **BillSprout Support**: Support@billsprout.online

## References

- [PayPal REST API Documentation](https://developer.paypal.com/docs/api/overview/)
- [PayPal Orders API v2](https://developer.paypal.com/docs/api/orders/v2/)
- [PayPal.Me Documentation](https://www.paypal.com/paypalme/)
