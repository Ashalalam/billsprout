# Pricing System Update - Testing Checklist

## Before Testing
- [ ] Applied `APPLY_PRICING_UPDATE.sql` in Supabase SQL Editor
- [ ] Verified Enterprise plan shows ₹26,000 in database
- [ ] Restarted Flutter application

---

## Test 1: Database Verification ✓

Run in Supabase SQL Editor:

```sql
-- Should show Enterprise at ₹26,000
SELECT 
  plan_code,
  plan_name,
  '₹' || price_yearly::TEXT AS inr_yearly,
  '₹' || renewal_yearly::TEXT AS inr_renewal,
  '$' || price_yearly_usd::TEXT AS usd_yearly,
  '$' || renewal_yearly_usd::TEXT AS usd_renewal
FROM subscription_plans
WHERE plan_code = 'enterprise';
```

**Expected Result:**
```
plan_code: enterprise
plan_name: Enterprise
inr_yearly: ₹26000
inr_renewal: ₹13000
usd_yearly: $350
usd_renewal: $175
```

---

## Test 2: INR Currency Flow ✓

1. **Navigate** to subscription plans page
   - URL: `/subscription-plans`

2. **Select Currency:** INR (₹)
   - Should show 🇮🇳 INR selected

3. **Verify Basic Plan:**
   - Monthly: ₹499/month
   - Yearly: ₹5,388/year
   - Renewal: ₹2,694/year

4. **Verify Professional Plan:**
   - Monthly: ₹1,499/month
   - Yearly: ₹16,188/year
   - Renewal: ₹8,094/year

5. **Verify Enterprise Plan:**
   - Monthly: ₹2,167/month
   - Yearly: **₹26,000/year** ← CRITICAL
   - Renewal: **₹13,000/year** ← CRITICAL
   - NOT ₹49,999 or ₹28,080

6. **Select Enterprise Yearly**
   - Click "Select Plan" on Enterprise
   - Verify payment page shows:
     - Amount: ₹26,000
     - Currency symbol: ₹
     - Billed: annually
     - Renewal notice: ₹13,000/year

---

## Test 3: USD Currency Flow ✓

1. **Switch Currency:** USD ($)
   - Click on 🌎 USD radio button

2. **Verify Basic Plan:**
   - Monthly: $9/month
   - Yearly: $97/year
   - Renewal: $48.50/year

3. **Verify Professional Plan:**
   - Monthly: $24/month
   - Yearly: $259/year
   - Renewal: $129.50/year

4. **Verify Enterprise Plan:**
   - Monthly: $35/month
   - Yearly: **$350/year** ← Check this
   - Renewal: **$175/year** ← Check this

5. **Select Enterprise Yearly**
   - Click "Select Plan" on Enterprise
   - Verify payment page shows:
     - Amount: $350
     - Currency symbol: $
     - Billed: annually
     - Renewal notice: $175/year

---

## Test 4: Currency Switching ✓

1. **Start with INR**
   - Select INR currency
   - Note Enterprise price: ₹26,000

2. **Switch to USD**
   - Click USD radio button
   - Enterprise price should change to: $350
   - NOT a converted value

3. **Switch back to INR**
   - Click INR radio button
   - Enterprise price returns to: ₹26,000

4. **Verify no conversion**
   - ₹26,000 ≠ $350 × 83 (exchange rate)
   - Confirms separate pricing

---

## Test 5: Billing Cycle Switching ✓

1. **Select Monthly Billing**
   - Enterprise INR: ₹2,167/month
   - Enterprise USD: $35/month

2. **Select Yearly Billing**
   - Enterprise INR: ₹26,000/year + ₹13,000 renewal
   - Enterprise USD: $350/year + $175 renewal

3. **Verify Renewal Notice Appears**
   - Orange box with renewal price
   - Should say "50% OFF"
   - Should say "After first year"

---

## Test 6: Payment Flow - INR ✓

1. **Select:** INR, Enterprise, Yearly
2. **Click:** "Select Plan" / "Get Started"
3. **Payment Page Verify:**
   - Order summary shows: ₹26,000
   - Currency symbol: ₹ (not $)
   - Billed: annually
   - Renewal box: ₹13,000/year
4. **PayPal Link Generated:**
   - URL should contain converted USD amount
   - (PayPal.Me limitation - INR not supported)

---

## Test 7: Payment Flow - USD ✓

1. **Select:** USD, Enterprise, Yearly
2. **Click:** "Select Plan"
3. **Payment Page Verify:**
   - Order summary shows: $350
   - Currency symbol: $ (not ₹)
   - Billed: annually
   - Renewal box: $175/year
4. **PayPal Link Generated:**
   - URL should contain $350

---

## Test 8: Subscription Creation ✓

1. **Complete payment flow**
   - Click "I Have Paid"
2. **Verify subscription record:**

```sql
SELECT 
  billing_cycle,
  currency,
  is_renewal,
  status
FROM subscriptions
WHERE tenant_id = 'YOUR_TENANT_ID'
ORDER BY created_at DESC
LIMIT 1;
```

**Expected:**
- `billing_cycle`: 'yearly' (if yearly selected)
- `currency`: 'INR' or 'USD' (matches selection)
- `is_renewal`: false (first purchase)
- `status`: 'active'

---

## Test 9: Critical Price Validation ✓

**MUST VERIFY THESE EXACT VALUES:**

### Enterprise INR
- ✅ Yearly: ₹26,000 (NOT ₹49,999, NOT ₹28,080)
- ✅ Renewal: ₹13,000
- ✅ Calculation: ₹13,000 = ₹26,000 × 50%

### Enterprise USD
- ✅ Yearly: $350
- ✅ Renewal: $175
- ✅ Calculation: $175 = $350 × 50%

### Not Converted
- ❌ $350 ≠ ₹26,000 ÷ 83
- ❌ ₹26,000 ≠ $350 × 83
- ✅ Separate independent pricing

---

## Test 10: Renewal Behavior ✓

1. **Check auto_renew field:**

```sql
SELECT auto_renew 
FROM subscriptions
WHERE tenant_id = 'YOUR_TENANT_ID';
```

**Expected:** `false` (manual renewal only)

2. **Verify UI messaging:**
   - Renewal price is shown for information
   - No checkbox for "Auto-renew"
   - No mention of automatic charging
   - Says "After first year" (customer must manually renew)

---

## Common Issues & Solutions

### Issue: Prices not updating
**Solution:** 
- Clear browser cache
- Hard refresh (Ctrl + Shift + R)
- Restart Flutter: `r` in terminal

### Issue: Still shows ₹49,999
**Solution:**
- Re-run `APPLY_PRICING_UPDATE.sql`
- Check database: `SELECT price_yearly FROM subscription_plans WHERE plan_code = 'enterprise'`
- Should return 26000, not 49999

### Issue: USD shows INR symbol (₹)
**Solution:**
- Verify currency selector is working
- Check browser console for errors
- Ensure `_selectedCurrency` state is 'USD'

### Issue: Wrong PayPal amount
**Solution:**
- Verify `widget.currency` in payment_page.dart
- Check `_generatePaymentUrl()` logic
- Ensure correct price column is used

---

## Sign-Off Checklist

Before marking as complete:

- [ ] Enterprise INR is exactly ₹26,000 (not ₹49,999 or ₹28,080)
- [ ] Enterprise renewal INR is exactly ₹13,000
- [ ] Enterprise USD is exactly $350
- [ ] Enterprise renewal USD is exactly $175
- [ ] Currency switch works INR ↔ USD
- [ ] Billing cycle switch works monthly ↔ yearly
- [ ] Payment page shows correct currency
- [ ] Payment page shows correct amount
- [ ] Subscription stores correct currency
- [ ] Renewal is NOT automatic
- [ ] No breaking changes to existing features

---

## Final Verification Query

Run this in Supabase to verify everything:

```sql
-- Complete pricing verification
SELECT 
  plan_code,
  plan_name,
  price_monthly AS inr_monthly,
  price_yearly AS inr_yearly,
  renewal_yearly AS inr_renewal,
  price_monthly_usd AS usd_monthly,
  price_yearly_usd AS usd_yearly,
  renewal_yearly_usd AS usd_renewal,
  -- Verify renewal is exactly 50%
  (renewal_yearly::DECIMAL / price_yearly::DECIMAL * 100)::INT AS inr_renewal_percent,
  (renewal_yearly_usd::DECIMAL / price_yearly_usd::DECIMAL * 100)::INT AS usd_renewal_percent
FROM subscription_plans
ORDER BY display_order;
```

**Expected for Enterprise:**
- `inr_yearly`: 26000
- `inr_renewal`: 13000
- `inr_renewal_percent`: 50
- `usd_yearly`: 350
- `usd_renewal`: 175
- `usd_renewal_percent`: 50

---

## Status: Ready for Testing ✅

All code changes complete. Ready to:
1. Apply database migration
2. Test each scenario
3. Verify pricing accuracy
4. Deploy to production

**Last Updated:** 2026-10-05
