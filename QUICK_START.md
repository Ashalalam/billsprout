# 🚀 Quick Start: Payment System

## For Developers

### 1. Install Dependencies
```bash
cd lifesprout
flutter pub get
```

### 2. Apply Database Migrations
```sql
-- In Supabase SQL Editor, run:
-- File: supabase/apply_all.sql
-- This includes migrations 012 & 013
```

### 3. Deploy Edge Functions
```bash
# Deploy all functions
supabase functions deploy create-razorpay-order
supabase functions deploy verify-razorpay-payment
supabase functions deploy razorpay-webhook
supabase functions deploy send-email

# Set secrets
supabase secrets set \
  RAZORPAY_KEY_ID="rzp_test_YOUR_KEY" \
  RAZORPAY_KEY_SECRET="YOUR_SECRET" \
  RAZORPAY_WEBHOOK_SECRET="YOUR_WEBHOOK_SECRET" \
  RESEND_API_KEY="re_YOUR_KEY" \
  FROM_EMAIL="noreply@yourdomain.com"
```

### 4. Configure Razorpay
1. Go to https://dashboard.razorpay.com/
2. Use Test Mode
3. Settings → Webhooks → Add New Webhook
4. URL: `https://your-project.supabase.co/functions/v1/razorpay-webhook`
5. Events: `payment.captured`, `payment.failed`, `order.paid`

### 5. Update Flutter App
Edit `lib/services/payment_service.dart`:
```dart
static const String _razorpayKeyId = String.fromEnvironment(
  'RAZORPAY_KEY_ID',
  defaultValue: 'rzp_test_YOUR_KEY_ID', // Your test key
);
```

### 6. Run the App
```bash
flutter run -d windows
```

---

## Testing with Test Cards

### Success Payment:
```
Card: 4111 1111 1111 1111
CVV: Any 3 digits
Expiry: Any future date
```

### Failed Payment:
```
Card: 4000 0000 0000 0002
CVV: Any 3 digits
Expiry: Any future date
```

---

## Key Files to Know

### Frontend:
- `lib/views/subscription/subscription_plans_view.dart` - Pricing page
- `lib/views/subscription/payment_checkout_view.dart` - Checkout
- `lib/services/payment_service.dart` - Payment logic
- `lib/providers/subscription_provider.dart` - State management

### Backend:
- `supabase/functions/create-razorpay-order/` - Order creation
- `supabase/functions/razorpay-webhook/` - Payment webhooks
- `supabase/functions/send-email/` - Email notifications
- `supabase/migrations/012_subscription_plans_payments.sql` - DB schema

---

## Common Issues

### Issue: Webhook not received
**Solution**: Check webhook URL is correct and function is deployed

### Issue: Payment succeeds but subscription not created
**Solution**: Check webhook logs in `webhook_logs` table

### Issue: Email not sent
**Solution**: Verify Resend API key and domain verification

### Issue: RLS error when fetching plans
**Solution**: Plans table should allow public read - check RLS policies

---

## Useful Commands

```bash
# Check Edge Function logs
supabase functions logs razorpay-webhook

# Check database
supabase db remote

# Test webhook locally
curl -X POST http://localhost:54321/functions/v1/razorpay-webhook \
  -H "Content-Type: application/json" \
  -d '{"event":"payment.captured",...}'

# Verify migrations applied
psql -c "SELECT * FROM subscription_plans;"
```

---

## Architecture Overview

```
┌──────────────┐
│  Flutter App │
└──────┬───────┘
       │ 1. Select Plan
       │
       ▼
┌──────────────┐
│  Razorpay    │ ◄─── 2. Create Order (via Edge Function)
│  Checkout    │
└──────┬───────┘
       │ 3. Payment Success
       │
       ▼
┌──────────────┐
│  Webhook     │ ◄─── 4. Razorpay sends webhook
│  Handler     │
└──────┬───────┘
       │ 5. Activate Subscription
       │ 6. Send Emails
       ▼
┌──────────────┐
│  Database    │
└──────────────┘
```

---

## Need Help?

See `PAYMENT_SYSTEM_DEPLOYMENT_GUIDE.md` for detailed instructions.
