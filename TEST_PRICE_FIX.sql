-- Test if the price fix worked
-- Run this after running IMMEDIATE_PRICE_FIX.sql

SELECT 
    p.name as product_name,
    b.batch_number,
    b.mrp,
    b.selling_price,
    b.stock_quantity,
    CASE 
        WHEN b.selling_price IS NULL THEN '❌ Still NULL'
        WHEN b.selling_price = 0 THEN '❌ Still ZERO'
        WHEN b.selling_price > 0 THEN '✅ FIXED'
        ELSE '❓ Unknown'
    END as status
FROM batches b
JOIN products p ON b.product_id = p.id
WHERE p.name ILIKE '%paracetmol%' 
   OR p.name ILIKE '%headacetablet%'
   OR p.name ILIKE '%amoxicillin%'
   OR p.name ILIKE '%cetirizine%'
ORDER BY p.name;

-- Count of fixed vs broken items
SELECT 
    CASE 
        WHEN b.selling_price IS NULL THEN 'NULL prices'
        WHEN b.selling_price = 0 THEN 'ZERO prices'  
        WHEN b.selling_price > 0 THEN 'FIXED prices'
        ELSE 'Unknown'
    END as price_status,
    COUNT(*) as count
FROM batches b
GROUP BY 
    CASE 
        WHEN b.selling_price IS NULL THEN 'NULL prices'
        WHEN b.selling_price = 0 THEN 'ZERO prices'
        WHEN b.selling_price > 0 THEN 'FIXED prices'
        ELSE 'Unknown'
    END
ORDER BY count DESC;