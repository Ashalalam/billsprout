# PayPal Integration Setup Guide

## 🔐 Security First

**IMPORTANT:** Never commit your PayPal API credentials to version control!

## How Credentials Are Stored

Your PayPal credentials are stored securely:
- ✅ Encrypted in device's `SharedPreferences`
- ✅ Never exposed in source code
- ✅ Not committed to Git (protected by .gitignore)
- ✅ Only accessible on your device

## Getting Your PayPal Credentials

### 1. Create/Access PayPal Developer Account

1. Go to https://developer.paypal.com
2. Sign in with your PayPal account
3. Navigate to "My Apps & Credentials"

### 2. Get Sandbox Credentials (For Testing)

1. In PayPal Developer Dashboard, go to **"Sandbox"** section
2. Click **"Accounts"** to see test accounts
3. You'll see:
   - **Business Account** (for receiving payments)
   - **Personal Account** (for making test payments)
4. Click on **"Create App"** under "REST API apps"
5. Give your app a name (e.g., "BillSprout POS")
6. Select **Sandbox** environment
7. You'll get:
   - **Client ID** (starts with `A...`)
   - **Client Secret** (click "Show" to reveal)

### 3. Get Production Credentials (For Live Payments)

1. In PayPal Developer Dashboard, switch to **"Live"** tab
2. Click **"Create App"**
3. Follow same steps as sandbox
4. You'll get production Client ID and Secret

**⚠️ NEVER use production credentials until fully tested in sandbox!**

## Configuring in BillSprout

### Method 1: Using the Settings UI (Recommended)

1. Open BillSprout application
2. Go to **Settings → PayPal Configuration**
3. Enter your credentials:
   - **Client ID**: Your PayPal app Client ID
   - **Client Secret**: Your PayPal app Client Secret
   - **PayPal.Me Username**: Your PayPal.Me username (for QR code payments)
   - **Merchant ID**: Optional, for advanced features
   - **Environment**: Choose "Sandbox" for testing or "Production" for live
4. Click **"Save Configuration"**
5. Credentials are encrypted and stored on device

### Method 2: Testing Credentials

#### Sandbox Test Credentials (For Development Only)

For initial testing, you can use sandbox credentials like:

```
Client ID: AeHxF6VQ9J... (get from PayPal Developer)
Client Secret: ED4tR8K... (get from PayPal Developer)
Environment: Sandbox
```

**These are just examples - you must use your own credentials from PayPal Developer Dashboard!**

## PayPal.Me QR Code Setup

PayPal.Me allows customers to scan a QR code and pay directly.

### 1. Create PayPal.Me Link

1. Go to https://www.paypal.me
2. Create your custom PayPal.Me username
3. Example: `paypal.me/YourPharmacy`

### 2. Configure in BillSprout

1. In PayPal Configuration settings
2. Enter your PayPal.Me username (e.g., `YourPharmacy`)
3. Save configuration

### 3. How It Works

- When customer selects PayPal payment
- System generates QR code with payment amount
- Customer scans QR code
- Opens PayPal app/website with pre-filled amount
- Customer completes payment
- Payment confirmed in your PayPal account

## Testing Payment Flow

### Sandbox Testing Steps

1. **Configure Sandbox Credentials** in Settings
2. **Create Test Sale** in POS:
   - Add items to cart
   - Select **"PayPal"** as payment mode
   - Customer sees QR code with payment amount
3. **Test Payment**:
   - Use PayPal Sandbox Personal Account
   - Scan QR code or use test buyer credentials
   - Complete payment in sandbox environment
4. **Verify Payment**:
   - Check PayPal Developer Dashboard
   - View transaction in sandbox account
5. **Confirm in BillSprout**:
   - Payment status updates
   - Invoice marked as paid

### Production Testing

**Only after successful sandbox testing:**

1. Switch to **Production** environment in settings
2. Enter production Client ID and Secret
3. Test with small real payment first
4. Verify funds in your actual PayPal account
5. Enable for customer use

## Security Best Practices

### ✅ DO:
- Use sandbox mode for all testing
- Store credentials in BillSprout settings only
- Regularly rotate your API credentials
- Monitor PayPal dashboard for suspicious activity
- Use strong passwords for PayPal account
- Enable 2-factor authentication on PayPal

### ❌ DON'T:
- Share your Client Secret with anyone
- Commit credentials to Git/GitHub
- Use production credentials in development
- Store credentials in plain text files
- Email or message credentials
- Use same credentials across multiple apps

## Troubleshooting

### "PayPal Not Configured" Error

**Solution:** Go to Settings → PayPal Configuration and enter your credentials

### QR Code Not Generating

**Solution:** 
1. Check PayPal.Me username is configured
2. Verify username is correct (no spaces, special characters)
3. Test PayPal.Me link in browser: `paypal.me/YourUsername`

### Payment Not Confirming

**Solution:**
1. Check internet connection
2. Verify credentials are correct
3. Check PayPal account status
4. Review PayPal Developer Dashboard for errors
5. Ensure sandbox/production mode matches credentials

### "Invalid Client Credentials" Error

**Solution:**
1. Double-check Client ID and Secret are correct
2. Verify no extra spaces when copying
3. Ensure using sandbox creds in sandbox mode
4. Try regenerating credentials in PayPal Developer

## Getting Help

### PayPal Resources
- Developer Docs: https://developer.paypal.com/docs/api/overview/
- PayPal.Me: https://www.paypal.com/paypalme/
- Support: https://developer.paypal.com/support/

### BillSprout Support
- For configuration help, contact your system administrator
- Check application logs for detailed error messages

## Credential Management

### Where Credentials Are Stored

Credentials are stored in device-specific encrypted storage:
- **Windows**: `%APPDATA%\Local\SharedPreferences`
- **Android**: `SharedPreferences` (app-specific, encrypted)
- **iOS**: `UserDefaults` (encrypted with Keychain)

### Rotating Credentials

To change your PayPal API credentials:

1. Generate new credentials in PayPal Developer Dashboard
2. Go to BillSprout Settings → PayPal Configuration
3. Enter new Client ID and Secret
4. Save - old credentials immediately replaced
5. Old credentials can be deleted from PayPal Dashboard

### Removing Credentials

To remove PayPal configuration:

1. Go to Settings → PayPal Configuration
2. Click "Clear Configuration"
3. Confirm removal
4. Credentials deleted from device

---

**Remember:** Your PayPal credentials are like your bank password - keep them secret and secure! 🔒
