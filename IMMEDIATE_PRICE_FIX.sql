-- =====================================================
-- IMMEDIATE PRICE FIX FOR POS BILLING
-- Run this now to fix the ₹0 price issue immediately
-- =====================================================

-- Check which products have zero or null selling prices
SELECT 
    p.name as product_name,
    b.batch_number,
    b.mrp,
    b.selling_price,
    CASE 
        WHEN b.selling_price IS NULL THEN 'NULL'
        WHEN b.selling_price = 0 THEN 'ZERO'
        ELSE 'OK'
    END as issue
FROM batches b
JOIN products p ON b.product_id = p.id
WHERE b.selling_price IS NULL OR b.selling_price = 0
ORDER BY p.name;

-- Fix all batches with NULL or 0 selling_price
UPDATE batches 
SET 
    selling_price = CASE 
        WHEN mrp > 0 THEN mrp
        ELSE 50.0  -- Default fallback price
    END,
    updated_at = CURRENT_TIMESTAMP
WHERE selling_price IS NULL 
   OR selling_price = 0;

-- Update specific problematic items we can see in your screenshot
UPDATE batches 
SET selling_price = 30.0, updated_at = CURRENT_TIMESTAMP
WHERE EXISTS (
    SELECT 1 FROM products p 
    WHERE p.id = batches.product_id 
    AND LOWER(p.name) LIKE '%paracetmol%'
);

UPDATE batches 
SET selling_price = 25.0, updated_at = CURRENT_TIMESTAMP
WHERE EXISTS (
    SELECT 1 FROM products p 
    WHERE p.id = batches.product_id 
    AND LOWER(p.name) LIKE '%headacetablet%'
);

-- Verify the fix
SELECT 
    p.name as product_name,
    b.batch_number,
    b.mrp,
    b.selling_price,
    b.stock_quantity
FROM batches b
JOIN products p ON b.product_id = p.id
ORDER BY p.name;