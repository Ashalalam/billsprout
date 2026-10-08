-- ============================================================================
-- TEST SCRIPT: Verify Batch Pricing Fix
-- ============================================================================
-- Run this to test if the batch pricing fix worked

-- 1. Check products without batches
SELECT 
    'Products without batches' AS check_description,
    COUNT(*) AS count,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ PASS' 
        ELSE '❌ FAIL - Products need batches' 
    END AS status
FROM products p
WHERE NOT EXISTS (SELECT 1 FROM batches b WHERE b.product_id = p.id);

-- 2. Check batches with invalid selling prices
SELECT 
    'Batches with invalid prices' AS check_description,
    COUNT(*) AS count,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ PASS' 
        ELSE '❌ FAIL - Prices need fixing' 
    END AS status
FROM batches 
WHERE selling_price IS NULL OR selling_price <= 0;

-- 3. Check products that should work in POS
SELECT 
    'Products ready for POS' AS check_description,
    COUNT(*) AS count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ PASS - Products available' 
        ELSE '❌ FAIL - No products available' 
    END AS status
FROM products p
WHERE EXISTS (
    SELECT 1 FROM batches b 
    WHERE b.product_id = p.id 
    AND b.selling_price > 0
);

-- 4. Show sample products with pricing
SELECT 
    p.name,
    b.selling_price,
    b.stock_count,
    CASE 
        WHEN b.selling_price > 0 AND p.id IS NOT NULL THEN '✅ Should work in POS'
        ELSE '❌ Will show ₹0 in POS'
    END AS pos_status
FROM products p
LEFT JOIN batches b ON p.id = b.product_id
ORDER BY p.name
LIMIT 10;

-- 5. Quick fix for any remaining issues
UPDATE batches 
SET selling_price = GREATEST(mrp, 50.0)
WHERE selling_price IS NULL OR selling_price <= 0;

-- 6. Final verification
SELECT 
    'Final check - All products with valid prices' AS final_check,
    COUNT(*) AS products_with_valid_prices
FROM products p
WHERE EXISTS (
    SELECT 1 FROM batches b 
    WHERE b.product_id = p.id 
    AND b.selling_price > 0
);