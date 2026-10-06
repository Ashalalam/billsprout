-- One-time fix to add batches for existing products with zero stock
-- Run this in Supabase SQL Editor

-- Get your tenant_id and branch_id from the products table
-- Replace these with actual values from your database
DO $$
DECLARE
    v_tenant_id UUID;
    v_branch_id UUID;
    v_product_id UUID;
BEGIN
    -- Get tenant and branch from existing products
    SELECT tenant_id INTO v_tenant_id FROM products LIMIT 1;
    SELECT id INTO v_branch_id FROM branches WHERE tenant_id = v_tenant_id LIMIT 1;
    
    -- Add batch for Cetirizine 10 mg Tablets
    SELECT id INTO v_product_id FROM products WHERE name = 'Cetirizine 10 mg Tablets' AND tenant_id = v_tenant_id;
    IF v_product_id IS NOT NULL THEN
        INSERT INTO batches (
            id, product_id, tenant_id, branch_id, batch_number,
            mfg_date, exp_date, purchase_price, mrp, selling_price,
            stock_quantity, loose_units, rack_location
        ) VALUES (
            gen_random_uuid(), v_product_id, v_tenant_id, v_branch_id, 'BATCH001',
            CURRENT_DATE, CURRENT_DATE + INTERVAL '2 years', 10.00, 25.00, 25.00,
            100, 0, 'A1'
        ) ON CONFLICT (tenant_id, branch_id, product_id, batch_number) DO UPDATE
          SET stock_quantity = 100;
    END IF;
    
    -- Add batch for Dolo 650 mg Tablets
    SELECT id INTO v_product_id FROM products WHERE name = 'Dolo 650 mg Tablets' AND tenant_id = v_tenant_id;
    IF v_product_id IS NOT NULL THEN
        INSERT INTO batches (
            id, product_id, tenant_id, branch_id, batch_number,
            mfg_date, exp_date, purchase_price, mrp, selling_price,
            stock_quantity, loose_units, rack_location
        ) VALUES (
            gen_random_uuid(), v_product_id, v_tenant_id, v_branch_id, 'BATCH002',
            CURRENT_DATE, CURRENT_DATE + INTERVAL '2 years', 50.00, 100.00, 100.00,
            100, 0, 'A2'
        ) ON CONFLICT (tenant_id, branch_id, product_id, batch_number) DO UPDATE
          SET stock_quantity = 100;
    END IF;
    
    -- Add batch for amoxicilin 500mg
    SELECT id INTO v_product_id FROM products WHERE name = 'amoxicilin 500mg' AND tenant_id = v_tenant_id;
    IF v_product_id IS NOT NULL THEN
        INSERT INTO batches (
            id, product_id, tenant_id, branch_id, batch_number,
            mfg_date, exp_date, purchase_price, mrp, selling_price,
            stock_quantity, loose_units, rack_location
        ) VALUES (
            gen_random_uuid(), v_product_id, v_tenant_id, v_branch_id, 'BATCH003',
            CURRENT_DATE, CURRENT_DATE + INTERVAL '2 years', 40.00, 80.00, 80.00,
            100, 0, 'A3'
        ) ON CONFLICT (tenant_id, branch_id, product_id, batch_number) DO UPDATE
          SET stock_quantity = 100;
    END IF;
END $$;

-- Verify the batches were created
SELECT p.name, b.batch_number, b.stock_quantity, b.loose_units
FROM products p
LEFT JOIN batches b ON b.product_id = p.id
WHERE p.name IN ('Cetirizine 10 mg Tablets', 'Dolo 650 mg Tablets', 'amoxicilin 500mg')
ORDER BY p.name;
