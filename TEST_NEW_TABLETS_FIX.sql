-- Test script to verify new tablets will show properly in POS
-- Run this to check current database state

-- 1. Check products without batches
SELECT 
    p.name as product_name,
    COUNT(b.id) as batch_count,
    COALESCE(SUM(b.stock_quantity), 0) as total_stock
FROM public.products p
LEFT JOIN public.batches b ON p.id = b.product_id
GROUP BY p.id, p.name
HAVING COUNT(b.id) = 0
ORDER BY p.name;

-- 2. Check batches with missing/zero selling prices
SELECT 
    p.name as product_name,
    b.batch_number,
    b.stock_quantity,
    b.mrp,
    b.selling_price,
    CASE 
        WHEN b.selling_price IS NULL OR b.selling_price = 0 THEN '❌ Missing'
        ELSE '✅ OK'
    END as selling_price_status
FROM public.products p
JOIN public.batches b ON p.id = b.product_id
WHERE b.selling_price IS NULL OR b.selling_price = 0
ORDER BY p.name, b.batch_number;

-- 3. Check recently added products (last 7 days)
SELECT 
    p.name as product_name,
    b.batch_number,
    b.stock_quantity,
    b.selling_price,
    b.exp_date,
    p.created_at,
    CASE 
        WHEN b.stock_quantity > 0 AND b.selling_price > 0 AND b.exp_date > NOW() THEN '✅ Should show in POS'
        WHEN b.stock_quantity = 0 THEN '⚠️ No stock'
        WHEN b.selling_price IS NULL OR b.selling_price = 0 THEN '❌ No selling price'
        WHEN b.exp_date <= NOW() THEN '⚠️ Expired'
        ELSE '❓ Unknown issue'
    END as pos_status
FROM public.products p
JOIN public.batches b ON p.id = b.product_id
WHERE p.created_at >= NOW() - INTERVAL '7 days'
ORDER BY p.created_at DESC;

-- 4. Count total products and batches
SELECT 
    COUNT(DISTINCT p.id) as total_products,
    COUNT(b.id) as total_batches,
    COUNT(CASE WHEN b.stock_quantity > 0 THEN 1 END) as batches_with_stock,
    COUNT(CASE WHEN b.selling_price > 0 THEN 1 END) as batches_with_price
FROM public.products p
LEFT JOIN public.batches b ON p.id = b.product_id;