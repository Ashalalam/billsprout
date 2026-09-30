-- Check subscription status
SELECT 
  ts.id,
  ts.status,
  ts.billing_cycle,
  ts.amount_paid,
  ts.start_date,
  ts.end_date,
  sp.plan_name
FROM tenant_subscriptions ts
JOIN subscription_plans sp ON ts.plan_id = sp.id
ORDER BY ts.created_at DESC
LIMIT 5;
