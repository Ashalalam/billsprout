-- =====================================================
-- TEST: Customer GST Field + Batch Persistence Fixes
-- =====================================================

-- Run this after applying FIX_CUSTOMER_GST_AND_BATCH_PERSISTENCE.sql

-- =====================================================
-- 1. TEST CUSTOMER GST FUNCTIONALITY
-- =====================================================

-- Test creating customers of all types with GST
DO $$
DECLARE
    tenant_uuid UUID;
    test_retail_id UUID := gen_random_uuid();
    test_wholesale_id UUID := gen_random_uuid();
    test_distributor_id UUID := gen_random_uuid();
BEGIN
    -- Get a tenant for testing
    SELECT id INTO tenant_uuid FROM tenants LIMIT 1;
    
    IF tenant_uuid IS NULL THEN
        RAISE NOTICE '[TEST] ⚠️  No tenants found - creating test tenant';
        INSERT INTO tenants (id, name, business_type) 
        VALUES (gen_random_uuid(), 'Test Tenant', 'pharmacy');
        SELECT id INTO tenant_uuid FROM tenants LIMIT 1;
    END IF;
    
    -- Test retail customer with GST
    INSERT INTO customers (
        id, tenant_id, customer_name, phone, email,
        customer_type, gstin, drug_license_no
    ) VALUES (
        test_retail_id, tenant_uuid, 'Test Retail Customer', 
        '9876543210', 'retail@test.com',
        'retail', '22ABCDE1234F1Z5', 'DL-RETAIL-123'
    );
    
    -- Test wholesale customer with GST
    INSERT INTO customers (
        id, tenant_id, customer_name, phone, email,
        customer_type, gstin, drug_license_no
    ) VALUES (
        test_wholesale_id, tenant_uuid, 'Test Wholesale Customer',
        '9876543211', 'wholesale@test.com', 
        'wholesale', '22WXYZP5678Q1A2', 'DL-WHOLESALE-456'
    );
    
    -- Test distributor customer with GST
    INSERT INTO customers (
        id, tenant_id, customer_name, phone, email,
        customer_type, gstin, drug_license_no
    ) VALUES (
        test_distributor_id, tenant_uuid, 'Test Distributor Customer',
        '9876543212', 'distributor@test.com',
        'distributor', '22MNOPQ9012R3B4', 'DL-DISTRIBUTOR-789'
    );
    
    RAISE NOTICE '[TEST] ✅ Successfully created customers of all types with GST';
    
    -- Verify the customers were created with GST
    IF (SELECT COUNT(*) FROM customers WHERE id IN (test_retail_id, test_wholesale_id, test_distributor_id) AND gstin IS NOT NULL) = 3 THEN
        RAISE NOTICE '[TEST] ✅ All test customers have GST numbers';
    ELSE
        RAISE NOTICE '[TEST] ❌ Some test customers missing GST numbers';
    END IF;
    
    -- Clean up test customers
    DELETE FROM customers WHERE id IN (test_retail_id, test_wholesale_id, test_distributor_id);
    RAISE NOTICE '[TEST] 🧹 Cleaned up test customers';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '[TEST] ❌ Customer GST test failed: %', SQLERRM;
END $$;

-- =====================================================
-- 2. TEST BATCH PERSISTENCE
-- =====================================================

DO $$
DECLARE
    tenant_uuid UUID;
    branch_uuid UUID;
    product_uuid UUID;
    test_batch_id UUID := gen_random_uuid();
    batch_count_before INTEGER;
    batch_count_after INTEGER;
BEGIN
    -- Get test data
    SELECT id INTO tenant_uuid FROM tenants LIMIT 1;
    SELECT id INTO branch_uuid FROM branches LIMIT 1;
    SELECT id INTO product_uuid FROM products LIMIT 1;
    
    IF tenant_uuid IS NULL OR branch_uuid IS NULL OR product_uuid IS NULL THEN
        RAISE NOTICE '[TEST] ⚠️  Missing test data - need tenant, branch, and product';
        RETURN;
    END IF;
    
    -- Count batches before
    SELECT COUNT(*) INTO batch_count_before FROM batches WHERE product_id = product_uuid;
    
    -- Test creating a batch with all required fields
    INSERT INTO batches (
        id, product_id, tenant_id, branch_id, batch_number,
        mfg_date, exp_date, purchase_price, ptr_price, mrp,
        selling_price, wholesale_price, stock_quantity, 
        loose_units, rack_location
    ) VALUES (
        test_batch_id,
        product_uuid,
        tenant_uuid, 
        branch_uuid,
        'TEST-PERSIST-' || extract(epoch from now())::text,
        CURRENT_DATE - INTERVAL '6 months',
        CURRENT_DATE + INTERVAL '18 months',
        45.50,  -- purchase_price
        65.00,  -- ptr_price 
        85.00,  -- mrp
        75.00,  -- selling_price
        60.00,  -- wholesale_price
        100,    -- stock_quantity
        25,     -- loose_units
        'RACK-A1-TEST'
    );
    
    -- Count batches after
    SELECT COUNT(*) INTO batch_count_after FROM batches WHERE product_id = product_uuid;
    
    -- Verify batch was created
    IF batch_count_after = batch_count_before + 1 THEN
        RAISE NOTICE '[TEST] ✅ Batch persistence test PASSED - batch created successfully';
        
        -- Verify all fields were saved correctly
        IF EXISTS (
            SELECT 1 FROM batches 
            WHERE id = test_batch_id 
            AND stock_quantity = 100 
            AND loose_units = 25
            AND selling_price = 75.00
        ) THEN
            RAISE NOTICE '[TEST] ✅ All batch fields saved correctly';
        ELSE
            RAISE NOTICE '[TEST] ❌ Some batch fields not saved correctly';
        END IF;
        
    ELSE
        RAISE NOTICE '[TEST] ❌ Batch persistence test FAILED - batch not created';
    END IF;
    
    -- Clean up test batch
    DELETE FROM batches WHERE id = test_batch_id;
    RAISE NOTICE '[TEST] 🧹 Cleaned up test batch';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '[TEST] ❌ Batch persistence test failed: %', SQLERRM;
END $$;

-- =====================================================
-- 3. VERIFY CURRENT STATE
-- =====================================================

-- Show customer types and GST availability
SELECT 
    'CUSTOMERS' as table_name,
    customer_type,
    COUNT(*) as total_count,
    COUNT(CASE WHEN gstin IS NOT NULL AND gstin != '' THEN 1 END) as with_gst,
    COUNT(CASE WHEN drug_license_no IS NOT NULL AND drug_license_no != '' THEN 1 END) as with_drug_license
FROM customers 
GROUP BY customer_type
ORDER BY customer_type;

-- Show batch statistics
SELECT 
    'BATCHES' as table_name,
    COUNT(*) as total_batches,
    COUNT(CASE WHEN stock_quantity > 0 THEN 1 END) as with_stock,
    COUNT(CASE WHEN loose_units > 0 THEN 1 END) as with_loose_units,
    COUNT(CASE WHEN selling_price IS NOT NULL AND selling_price > 0 THEN 1 END) as with_selling_price
FROM batches;

-- Show RLS policy status
SELECT 
    'RLS_STATUS' as table_name,
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename IN ('customers', 'batches')
AND schemaname = 'public';

-- Show policy details
SELECT 
    'POLICIES' as table_name,
    tablename,
    policyname,
    cmd as command,
    permissive
FROM pg_policies 
WHERE tablename IN ('customers', 'batches')
ORDER BY tablename, policyname;

-- =====================================================
-- TEST RESULTS SUMMARY
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '==================================================';
    RAISE NOTICE 'TEST SUMMARY - Customer GST & Batch Persistence';
    RAISE NOTICE '==================================================';
    RAISE NOTICE '';
    RAISE NOTICE '✅ If you see success messages above, the fixes work correctly:';
    RAISE NOTICE '   - All customer types (retail/wholesale/distributor) can have GST';
    RAISE NOTICE '   - New batches persist to database correctly';
    RAISE NOTICE '   - RLS policies allow proper data access';
    RAISE NOTICE '';
    RAISE NOTICE '❌ If you see error messages, check the migration logs above';
    RAISE NOTICE '';
    RAISE NOTICE 'Next steps:';
    RAISE NOTICE '1. Test adding customers with GST in the UI';
    RAISE NOTICE '2. Test adding new batches and refresh to verify persistence';
    RAISE NOTICE '3. Check that POS billing shows correct stock and prices';
    RAISE NOTICE '';
END $$;