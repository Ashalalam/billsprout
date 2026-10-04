# My PayPal Sandbox Credentials

## ⚠️ IMPORTANT - SECURITY NOTICE
**This file contains your actual PayPal credentials. DO NOT commit this file to git!**
It has been added to .gitignore for your protection.

---

## 🔑 API Credentials (REST API)

### Client ID (API Key)
```
AQOnHpG-Yd_zyEfRiHVNnA6pb27Nkd1R_phWNJWmHG6gA-EfrZopX1G2IejjMTOMjag63EcClDCb6hz5
```

### Client Secret
```
EKLkmbn9VqnxRzovsNFKUCv1yfQO0EdSEQOdXGI5nkw1alg4GaJ8bZBrtja_GJb15mJRQ1edskFM4TFw
```

---

## 👤 Sandbox Business Account

### Email
```
sb-hgj9w52902035@business.example.com
```

### Password
```
eA]5!k;0
```

---

## 📱 How to Configure in BillSprout

### Step 1: Run the App
```bash
cd lifesprout
flutter run -d windows
# or
flutter run -d chrome
```

### Step 2: Login to BillSprout
- Login as Business Admin user

### Step 3: Navigate to PayPal Settings
- Click on **Settings** tab
- Click on **PayPal** tab (4th tab with payment icon)

### Step 4: Enter Credentials
Copy and paste these values:

1. **Client ID**: 
   ```
   AQOnHpG-Yd_zyEfRiHVNnA6pb27Nkd1R_phWNJWmHG6gA-EfrZopX1G2IejjMTOMjag63EcClDCb6hz5
   ```

2. **Client Secret**: 
   ```
   EKLkmbn9VqnxRzovsNFKUCv1yfQO0EdSEQOdXGI5nkw1alg4GaJ8bZBrtja_GJb15mJRQ1edskFM4TFw
   ```

3. **PayPal.Me Username**: 
   ```
   sb-hgj9w52902035
   ```
   (This is extracted from your email: sb-hgj9w52902035@business.example.com)

4. **Merchant ID**: (Optional - leave blank for now)

5. **Sandbox Mode**: ✅ **KEEP THIS ON** (should be blue/enabled)

### Step 5: Save and Test
- Click **Save Configuration**
- Wait for success message: "✅ PayPal configuration saved securely"
- Click **Test Connection** button
- Should see: "✅ Successfully connected to PayPal Sandbox"

---

## 🧪 Testing Payment Flow

### Test a Payment

1. **Go to POS Billing**
   - Navigate to POS Billing view
   - Add some products to cart

2. **Checkout with PayPal**
   - Click **Checkout** button
   - Select **PayPal** payment chip
   - Continue to payment

3. **QR Code Display**
   - QR code dialog will appear
   - Note the PayPal.Me URL shown

4. **Test Payment (Two Options)**

   **Option A - With Your Phone:**
   - Scan QR code with phone camera
   - Login to PayPal sandbox using:
     - Email: `sb-hgj9w52902035@business.example.com`
     - Password: `eA]5!k;0`
   - Complete the payment
   - Return to BillSprout and click "Payment Completed"

   **Option B - Simulated (Quick Test):**
   - Just click "Payment Completed" button
   - This simulates successful payment for testing UI flow

5. **Verify Transaction**
   - Go back to Settings → PayPal tab
   - Check "Transaction Statistics" section
   - Should see 1 completed transaction
   - Check "Recent Transactions" list

---

## 🌐 PayPal Sandbox URLs

### Login to PayPal Sandbox
- URL: https://www.sandbox.paypal.com
- Email: `sb-hgj9w52902035@business.example.com`
- Password: `eA]5!k;0`

### PayPal Developer Dashboard
- URL: https://developer.paypal.com/dashboard
- This is where you got your API credentials

### View Transactions
- Login to sandbox account
- Check your PayPal sandbox dashboard for received payments

---

## 🎯 Expected PayPal.Me URL Format

When you generate a QR code for ₹100.00, the URL should look like:

```
https://paypal.me/sb-hgj9w52902035/100.00INR?note=Invoice-INV-001
```

This URL:
- Opens PayPal payment page
- Pre-fills amount (100.00)
- Pre-fills currency (INR)
- Includes invoice reference in note

---

## ✅ Testing Checklist

- [ ] App runs without errors
- [ ] Can navigate to Settings → PayPal tab
- [ ] Can enter and save credentials
- [ ] "Test Connection" shows success
- [ ] Configuration status shows "Configured" (green)
- [ ] Can add products to POS cart
- [ ] PayPal payment chip appears in checkout
- [ ] Selecting PayPal opens QR code dialog
- [ ] QR code is visible and clear
- [ ] PayPal.Me URL is displayed correctly
- [ ] Can scan QR code with phone (optional)
- [ ] Can complete payment flow
- [ ] Transaction appears in statistics
- [ ] Transaction appears in recent transactions list
- [ ] Invoice is generated after payment

---

## 🔧 Troubleshooting

### "Failed to connect to PayPal"
- Verify credentials copied correctly (no extra spaces)
- Ensure Sandbox Mode is ON
- Check internet connection

### "Configuration not found"
- Make sure you clicked "Save Configuration"
- Restart the app if needed

### QR code doesn't scan properly
- Make sure phone camera app supports QR codes
- Try a dedicated QR scanner app
- Try increasing QR code size

### Payment not going through
- Login to PayPal sandbox first in browser
- Make sure sandbox account has funds
- Check PayPal sandbox status page

---

## 📞 Need Help?

If you encounter any issues:
1. Check the detailed testing guide: `PAYPAL_TESTING_CHECKLIST.md`
2. Review setup guide: `PAYPAL_SETUP.md`
3. Check console output for error messages

---

## 🔒 Security Reminder

**NEVER commit this file to git!**

Your credentials are:
- ✅ Stored encrypted in SharedPreferences when you save in app
- ✅ Protected by .gitignore from being committed
- ✅ Only for sandbox testing (not real money)
- ⚠️ Keep this file private and secure

When ready for production, you'll need to:
1. Get LIVE PayPal API credentials (not sandbox)
2. Toggle Sandbox Mode OFF in settings
3. Test with small real payment first

---

**Status**: Ready to Configure ✅

**Next Step**: Run the app and enter these credentials in Settings → PayPal tab!
