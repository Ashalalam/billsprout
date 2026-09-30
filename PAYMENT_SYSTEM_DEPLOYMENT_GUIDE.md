# Payment System Deployment & Testing Guide

## Overview
This guide covers deployment and testing of the complete payment system for LifeSprout, including subscription plans, Razorpay integration, webhooks, and email notifications.

---

## Pre-Deployment Checklist

### 1. Database Migrations
Run all migrations in order:

```bash
# Apply migrations to Supabase
cd supabase
supabase db push

# Or manually apply each migration:
# - 012_subscription_plans_payments.sql
# - 013_software_downloads.sql
```

**Verify:**
- [ ] `subscription_plans` table created with 3 seeded plans (Basic, Professional, Enterprise)
- [ ] `tenant_subscriptions` table created
- [ ] `payment_transactions` table created with Razorpay fields
- [ ] `webhook_logs` table created
- [ ] `software_versions` table created with v1.0.0
- [ ] `software_downloads` table created with platform downloads
- [ ] All RLS policies enabled and working

### 2. Razorpay Configuration

**Test Mode Setup:**
1. Go to [Razorpay Dashboard](https://dashboard.razorpay.com/)
2. Use Test Mode for development
3. Get credentials:
   - Key ID: `rzp_test_XXXXXXXXXXXX`
   - Key Secret: `XXXXXXXXXXXX`
   - Webhook Secret: `whsec_XXXXXXXXXXXX`

**Environment Variables:**
Set in Supabase Dashboard → Settings → Edge Functions → Secrets:

```bash
RAZORPAY_KEY_ID=rzp_test_XXXXXXXXXXXX
RAZORPAY_KEY_SECRET=your_razorpay_key_secret
RAZORPAY_WEBHOOK_SECRET=your_webhook_secret
```

**Flutter Configuration:**
Update `lib/services/payment_service.dart`:

```dart
static const String _razorpayKeyId = String.fromEnvironment(
  'RAZORPAY_KEY_ID',
  defaultValue: 'rzp_test_XXXXXXXXXXXX', // Your test key
);
```

### 3. Email Service Configuration

**Resend Setup:**
1. Sign up at [Resend](https://resend.com/)
2. Get API key
3. Verify your domain or use dev mode

**Environment Variables:**
```bash
RESEND_API_KEY=re_XXXXXXXXXXXX
FROM_EMAIL=noreply@yourdomain.com  # or use Resend dev email
```

### 4. Deploy Edge Functions

```bash
# Deploy all edge functions
supabase functions deploy create-razorpay-order
supabase functions deploy verify-razorpay-payment
supabase functions deploy razorpay-webhook
supabase functions deploy send-email

# Set secrets for each function
supabase secrets set RAZORPAY_KEY_ID=rzp_test_XXXXXXXXXXXX
supabase secrets set RAZORPAY_KEY_SECRET=your_secret
supabase secrets set RAZORPAY_WEBHOOK_SECRET=your_webhook_secret
supabase secrets set RESEND_API_KEY=re_XXXXXXXXXXXX
supabase secrets set FROM_EMAIL=noreply@yourdomain.com
```

### 5. Configure Razorpay Webhook

1. Go to Razorpay Dashboard → Settings → Webhooks
2. Add webhook URL:
   ```
   https://your-project.supabase.co/functions/v1/razorpay-webhook
   ```
3. Select events:
   - [x] payment.captured
   - [x] payment.failed
   - [x] order.paid
4. Set webhook secret (copy it to environment variables)

### 6. Flutter Dependencies

```bash
# Install new packages
flutter pub get

# Verify razorpay_flutter is installed
flutter pub deps | grep razorpay
```

---

## End-to-End Testing Workflow

### Test Scenario 1: New Subscription Purchase (Happy Path)

**Objective:** Complete payment flow from plan selection to subscription activation

**Steps:**

1. **View Plans**
   ```dart
   // Navigate to SubscriptionPlansView
   Navigator.push(context, MaterialPageRoute(
     builder: (context) => SubscriptionPlansView(),
   ));
   ```
   
   **Verify:**
   - [ ] 3 plans displayed (Basic, Professional, Enterprise)
   - [ ] Monthly/Yearly toggle works
   - [ ] Prices update correctly
   - [ ] Yearly savings shown
   - [ ] Features list displays for each plan
   - [ ] Plan limits shown correctly

2. **Select Plan & Checkout**
   - Click "Choose Basic" button
   - Should navigate to PaymentCheckoutView
   
   **Verify:**
   - [ ] Order summary shows correct plan
   - [ ] Subtotal calculated correctly
   - [ ] GST (18%) added
   - [ ] Total amount correct
   - [ ] Payment methods displayed
   - [ ] Security info shown

3. **Initiate Payment**
   - Click "Pay" button
   - Razorpay checkout should open
   
   **Backend Verification:**
   ```sql
   -- Check payment transaction created
   SELECT * FROM payment_transactions 
   WHERE tenant_id = 'YOUR_TENANT_ID'
   ORDER BY created_at DESC LIMIT 1;
   
   -- Should show status = 'pending'
   ```
   
   **Verify:**
   - [ ] Razorpay modal opens
   - [ ] Order ID displayed
   - [ ] Amount shown correctly
   - [ ] Multiple payment options available

4. **Complete Payment (Test Mode)**
   - Use Razorpay test cards:
     - Success: `4111 1111 1111 1111`
     - CVV: Any 3 digits
     - Expiry: Any future date
   
   **Verify:**
   - [ ] Payment success callback triggered
   - [ ] Success dialog shown
   - [ ] User redirected to dashboard

5. **Verify Backend Updates**
   ```sql
   -- Check payment transaction updated
   SELECT * FROM payment_transactions 
   WHERE razorpay_payment_id IS NOT NULL
   ORDER BY created_at DESC LIMIT 1;
   
   -- Should show status = 'success'
   
   -- Check subscription created
   SELECT * FROM tenant_subscriptions
   WHERE tenant_id = 'YOUR_TENANT_ID'
   ORDER BY created_at DESC LIMIT 1;
   
   -- Should show status = 'active'
   
   -- Check tenant updated
   SELECT subscription_plan, subscription_status 
   FROM tenants 
   WHERE id = 'YOUR_TENANT_ID';
   
   -- Should show plan code and 'active' status
   ```
   
   **Verify:**
   - [ ] `payment_transactions` record status = 'success'
   - [ ] `tenant_subscriptions` record created with status = 'active'
   - [ ] `tenants.subscription_status` = 'active'
   - [ ] `tenants.subscription_plan` = selected plan code

6. **Verify Webhook Received**
   ```sql
   -- Check webhook logs
   SELECT * FROM webhook_logs
   WHERE event_type = 'payment.captured'
   ORDER BY created_at DESC LIMIT 1;
   
   -- Should show status = 'processed'
   ```
   
   **Verify:**
   - [ ] Webhook log created
   - [ ] Event type = 'payment.captured'
   - [ ] Status = 'processed'
   - [ ] Payload contains payment details

7. **Verify Email Notifications**
   - Check inbox for 2 emails:
     1. Payment success email
     2. Subscription activated email
   
   **Verify:**
   - [ ] Payment success email received with transaction ID
   - [ ] Subscription activated email received with plan details
   - [ ] Both emails properly formatted with templates
   - [ ] Links work correctly

8. **Verify Dashboard Access**
   - Log in to business admin dashboard
   
   **Verify:**
   - [ ] SubscriptionStatusWidget shows active subscription
   - [ ] Plan name displayed correctly
   - [ ] Expiry date shown (30 days or 365 days from now)
   - [ ] Days remaining calculated correctly
   - [ ] No warnings shown (subscription is active)

---

### Test Scenario 2: Payment Failure

**Objective:** Test payment failure handling

**Steps:**

1. Select any plan and proceed to checkout
2. Use Razorpay test card for failure:
   - Card: `4000 0000 0000 0002`
   - CVV: Any 3 digits
   - Expiry: Any future date

**Verify:**
- [ ] Payment error callback triggered
- [ ] Error message shown to user
- [ ] Payment transaction status = 'failed'
- [ ] No subscription created
- [ ] Tenant status unchanged
- [ ] User can retry payment

---

### Test Scenario 3: Subscription Expiry Warning

**Objective:** Test expiring subscription notifications

**Manual Database Setup:**
```sql
-- Manually create a subscription expiring in 15 days
UPDATE tenant_subscriptions
SET end_date = NOW() + INTERVAL '15 days'
WHERE tenant_id = 'YOUR_TENANT_ID';
```

**Verify:**
- [ ] SubscriptionStatusWidget shows warning banner
- [ ] Orange/yellow color scheme applied
- [ ] "Renew Now" button displayed
- [ ] Days remaining shows correct count
- [ ] Clicking renew redirects to plans page

---

### Test Scenario 4: Demo Request Form

**Objective:** Test demo form submission and email

**Steps:**

1. Navigate to DemoRequestForm
2. Fill in form:
   - Name: "Test User"
   - Mobile: "9876543210"
   - Email: "test@example.com"
   - Business Type: "Pharmacy / Medical"
3. Submit form

**Verify:**
- [ ] Form validates correctly
- [ ] Success confirmation shown
- [ ] Record inserted in `demo_requests` table
- [ ] Confirmation email sent to provided email
- [ ] Email template renders correctly

**Backend Verification:**
```sql
SELECT * FROM demo_requests
ORDER BY created_at DESC LIMIT 1;
```

---

### Test Scenario 5: Software Downloads

**Objective:** Test downloads page and logging

**Steps:**

1. Navigate to DownloadsView
2. Select platform (Windows/Mac/Linux)
3. Click download button

**Verify:**
- [ ] Latest version displayed
- [ ] All platforms shown
- [ ] File sizes displayed
- [ ] Release notes visible
- [ ] System requirements shown
- [ ] Installation instructions displayed
- [ ] Download initiated
- [ ] Download logged in `download_logs` table

**Backend Verification:**
```sql
SELECT * FROM download_logs
ORDER BY downloaded_at DESC LIMIT 10;
```

---

## Production Deployment Steps

### 1. Switch to Production Mode

**Razorpay:**
- Switch to Live Mode in Razorpay Dashboard
- Update credentials to live keys (starting with `rzp_live_`)
- Update webhook URL to production

**Email:**
- Verify domain in Resend
- Update FROM_EMAIL to production domain

**Environment Variables:**
```bash
# Production secrets
RAZORPAY_KEY_ID=rzp_live_XXXXXXXXXXXX
RAZORPAY_KEY_SECRET=live_secret
RAZORPAY_WEBHOOK_SECRET=live_webhook_secret
RESEND_API_KEY=production_key
FROM_EMAIL=noreply@lifesprout.com
```

### 2. Update Download URLs

```sql
-- Update software download URLs to actual storage
UPDATE software_downloads
SET download_url = 'https://your-cdn.com/releases/v1.0.0/LifeSprout-1.0.0-Windows-x64.exe'
WHERE platform = 'windows';

-- Update checksums
UPDATE software_downloads
SET checksum_sha256 = 'actual_sha256_checksum'
WHERE platform = 'windows';
```

### 3. Test Payment Flow in Production

**Use Real Test Payment:**
- Small amount (₹10) for testing
- Verify complete flow
- Check all emails sent
- Verify webhook received
- Test refund process

### 4. Enable Payment Gateway Features

**Razorpay Production Features:**
- [ ] Enable all payment methods (cards, UPI, wallets, net banking)
- [ ] Set up settlement schedule
- [ ] Configure auto-refunds
- [ ] Enable 3D Secure
- [ ] Set up email notifications
- [ ] Configure SMS notifications

---

## Monitoring & Troubleshooting

### Key Metrics to Monitor

```sql
-- Total active subscriptions
SELECT COUNT(*) FROM tenant_subscriptions
WHERE status = 'active' AND end_date > NOW();

-- Revenue by plan
SELECT 
  sp.plan_name,
  COUNT(*) as subscribers,
  SUM(ts.amount_paid) as total_revenue
FROM tenant_subscriptions ts
JOIN subscription_plans sp ON ts.plan_id = sp.id
WHERE ts.status = 'active'
GROUP BY sp.plan_name;

-- Failed payments (last 24 hours)
SELECT COUNT(*) FROM payment_transactions
WHERE status = 'failed'
AND created_at > NOW() - INTERVAL '24 hours';

-- Webhook failures
SELECT COUNT(*) FROM webhook_logs
WHERE status = 'failed'
AND created_at > NOW() - INTERVAL '24 hours';
```

### Common Issues & Solutions

**Issue: Webhook not received**
- Check webhook URL is correct
- Verify webhook secret matches
- Check Supabase function logs
- Ensure function is deployed

**Issue: Payment success but subscription not activated**
- Check webhook logs for errors
- Verify RLS policies allow subscription insert
- Check edge function logs
- Manually run activation query

**Issue: Email not sent**
- Verify Resend API key
- Check domain verification
- Review send-email function logs
- Check email rate limits

**Issue: Razorpay checkout not opening**
- Verify key ID is correct
- Check if razorpay_flutter initialized
- Review browser console for errors
- Test with different payment amounts

---

## Security Checklist

- [ ] Razorpay keys secured in environment variables
- [ ] Webhook signature verification enabled
- [ ] RLS policies tested for all tables
- [ ] Service role key never exposed to client
- [ ] Payment verification on backend (never trust client)
- [ ] SQL injection prevention (parameterized queries)
- [ ] Rate limiting on payment endpoints
- [ ] CORS properly configured
- [ ] HTTPS enforced for all requests
- [ ] Sensitive data not logged

---

## Rollback Plan

If issues occur in production:

1. **Disable new subscriptions:**
   ```sql
   UPDATE subscription_plans SET is_active = false;
   ```

2. **Revert migrations:**
   ```bash
   supabase db reset
   # Apply only stable migrations
   ```

3. **Redeploy previous edge functions:**
   ```bash
   git checkout <previous-commit>
   supabase functions deploy
   ```

4. **Notify affected users**

---

## Post-Deployment Tasks

- [ ] Update documentation
- [ ] Train support team
- [ ] Set up monitoring alerts
- [ ] Create refund process documentation
- [ ] Set up automated subscription expiry reminders
- [ ] Create revenue reports
- [ ] Set up backup payment method
- [ ] Document common support queries

---

## Support Resources

- **Razorpay Docs:** https://razorpay.com/docs/
- **Supabase Functions:** https://supabase.com/docs/guides/functions
- **Resend Docs:** https://resend.com/docs
- **Test Cards:** https://razorpay.com/docs/payments/payments/test-card-details/

---

## Success Criteria

✅ All 8 tasks completed
✅ Payment flow works end-to-end
✅ Webhooks processed successfully
✅ Emails sent reliably
✅ Subscriptions activated automatically
✅ Downloads page functional
✅ Demo form working with confirmations
✅ Zero critical bugs in production
✅ All security measures in place
✅ Monitoring and alerts configured

---

**Status:** Ready for production deployment after thorough testing in staging environment.
