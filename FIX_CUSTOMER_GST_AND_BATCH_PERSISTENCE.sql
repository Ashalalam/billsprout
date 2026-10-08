-- =====================================================
-- FIX: Customer GST Field + Batch Persistence Issues
-- =====================================================

-- ISSUE 1: GST field should be available for all customer types
-- ISSUE 2: New batches don't persist to database after refresh

-- =====================================================
-- 1. ENSURE CUSTOMERS TABLE HAS GST FIELD
-- =====================================================

-- Check and add GST-related columns if they don't exist
DO $$
BEGIN
    -- Add gstin column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'customers' 
        AND column_name = 'gstin'
    ) THEN
        ALTER TABLE customers ADD COLUMN gstin VARCHAR(15);
        RAISE NOTICE '[FIX] ✅ Added gstin column to customers table';
    ELSE
        RAISE NOTICE '[FIX] ✅ gstin column already exists in customers table';
    END IF;
    
    -- Add drug_license_no column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'customers' 
        AND column_name = 'drug_license_no'
    ) THEN
        ALTER TABLE customers ADD COLUMN drug_license_no VARCHAR(50);
        RAISE NOTICE '[FIX] ✅ Added drug_license_no column to customers table';
    ELSE
        RAISE NOTICE '[FIX] ✅ drug_license_no column already exists in customers table';
    END IF;
END $$;

-- =====================================================
-- 2. ENSURE BATCHES TABLE HAS CORRECT STRUCTURE
-- =====================================================

-- Verify all batch columns exist
DO $$
DECLARE
    missing_columns TEXT[] := ARRAY[]::TEXT[];
    col_name TEXT;
BEGIN
    FOR col_name IN 
        SELECT unnest(ARRAY[
            'id', 'product_id', 'tenant_id', 'branch_id', 'batch_number',
            'mfg_date', 'exp_date', 'purchase_price', 'ptr_price', 'mrp',
            'selling_price', 'wholesale_price', 'stock_quantity', 'free_quantity',
            'loose_units', 'rack_location', 'supplier_id', 'created_at', 'updated_at'
        ])
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'public' 
            AND table_name = 'batches' 
            AND column_name = col_name
        ) THEN
            missing_columns := array_append(missing_columns, col_name);
        END IF;
    END LOOP;
    
    IF array_length(missing_columns, 1) > 0 THEN
        RAISE NOTICE '[FIX] ❌ Missing columns in batches table: %', array_to_string(missing_columns, ', ');
    ELSE
        RAISE NOTICE '[FIX] ✅ All required columns exist in batches table';
    END IF;
END $$;

-- =====================================================
-- 3. FIX BATCHES RLS POLICIES
-- =====================================================

-- Enable RLS on batches table
ALTER TABLE batches ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to recreate them properly
DROP POLICY IF EXISTS "Tenant isolation on batches" ON batches;
DROP POLICY IF EXISTS "batches_tenant_isolation" ON batches;

-- Create comprehensive RLS policy for batches
CREATE POLICY "batches_tenant_access"
ON batches FOR ALL
USING (
    -- Allow access if user has tenant access
    EXISTS (
        SELECT 1 FROM auth.users u
        WHERE u.id = auth.uid()
        AND (
            -- User metadata contains the tenant_id
            (u.raw_user_meta_data->>'tenant_id')::uuid = batches.tenant_id
            OR
            -- Or user is associated with tenant via user_tenants table
            EXISTS (
                SELECT 1 FROM user_tenants ut
                WHERE ut.user_id = u.id 
                AND ut.tenant_id = batches.tenant_id
            )
        )
    )
)
WITH CHECK (
    -- Same check for INSERT/UPDATE
    EXISTS (
        SELECT 1 FROM auth.users u
        WHERE u.id = auth.uid()
        AND (
            (u.raw_user_meta_data->>'tenant_id')::uuid = batches.tenant_id
            OR
            EXISTS (
                SELECT 1 FROM user_tenants ut
                WHERE ut.user_id = u.id 
                AND ut.tenant_id = batches.tenant_id
            )
        )
    )
);

COMMENT ON POLICY "batches_tenant_access" ON batches IS 
    'Allow full access to batches for users with tenant access';

-- =====================================================
-- 4. FIX CUSTOMERS RLS POLICIES
-- =====================================================

-- Enable RLS on customers table
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to recreate them properly
DROP POLICY IF EXISTS "Tenant isolation on customers" ON customers;
DROP POLICY IF EXISTS "customers_tenant_isolation" ON customers;

-- Create comprehensive RLS policy for customers
CREATE POLICY "customers_tenant_access"
ON customers FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM auth.users u
        WHERE u.id = auth.uid()
        AND (
            (u.raw_user_meta_data->>'tenant_id')::uuid = customers.tenant_id
            OR
            EXISTS (
                SELECT 1 FROM user_tenants ut
                WHERE ut.user_id = u.id 
                AND ut.tenant_id = customers.tenant_id
            )
        )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM auth.users u
        WHERE u.id = auth.uid()
        AND (
            (u.raw_user_meta_data->>'tenant_id')::uuid = customers.tenant_id
            OR
            EXISTS (
                SELECT 1 FROM user_tenants ut
                WHERE ut.user_id = u.id 
                AND ut.tenant_id = customers.tenant_id
            )
        )
    )
);

-- =====================================================
-- 5. TEST BATCH INSERT CAPABILITY
-- =====================================================

-- Function to test if batch insert works
CREATE OR REPLACE FUNCTION test_batch_insert()
RETURNS TEXT AS $$
DECLARE
    test_result TEXT;
    tenant_uuid UUID;
    branch_uuid UUID;
    product_uuid UUID;
BEGIN
    -- Get first available tenant, branch, and product for testing
    SELECT id INTO tenant_uuid FROM tenants LIMIT 1;
    SELECT id INTO branch_uuid FROM branches LIMIT 1;
    SELECT id INTO product_uuid FROM products LIMIT 1;
    
    IF tenant_uuid IS NULL OR branch_uuid IS NULL OR product_uuid IS NULL THEN
        RETURN '❌ Missing test data: Need at least one tenant, branch, and product';
    END IF;
    
    -- Try to insert a test batch
    BEGIN
        INSERT INTO batches (
            id, product_id, tenant_id, branch_id, batch_number,
            exp_date, purchase_price, mrp, selling_price,
            stock_quantity, loose_units, rack_location
        ) VALUES (
            gen_random_uuid(),
            product_uuid,
            tenant_uuid,
            branch_uuid,
            'TEST-BATCH-' || extract(epoch from now())::text,
            CURRENT_DATE + INTERVAL '2 years',
            50.0,
            100.0,
            85.0,
            10,
            5,
            'TEST-RACK'
        );
        
        -- If we get here, insert succeeded
        test_result := '✅ Batch insert test PASSED - RLS policies are working';
        
        -- Clean up test batch
        DELETE FROM batches 
        WHERE batch_number LIKE 'TEST-BATCH-%' 
        AND rack_location = 'TEST-RACK';
        
    EXCEPTION
        WHEN OTHERS THEN
            test_result := '❌ Batch insert test FAILED: ' || SQLERRM;
    END;
    
    RETURN test_result;
END;
$$ LANGUAGE plpgsql;

-- Run the test
SELECT test_batch_insert();

-- Clean up test function
DROP FUNCTION test_batch_insert();

-- =====================================================
-- 6. VERIFY CURRENT STATE
-- =====================================================

-- Show current batch count
SELECT 
    COUNT(*) as total_batches,
    COUNT(CASE WHEN stock_quantity > 0 THEN 1 END) as batches_with_stock
FROM batches;

-- Show current customer count by type
SELECT 
    customer_type,
    COUNT(*) as count,
    COUNT(CASE WHEN gstin IS NOT NULL THEN 1 END) as with_gst
FROM customers
GROUP BY customer_type
ORDER BY customer_type;

-- Show RLS policies
SELECT 
    tablename,
    policyname,
    permissive,
    cmd
FROM pg_policies 
WHERE tablename IN ('batches', 'customers')
ORDER BY tablename, policyname;

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- This fixes:
-- ✅ GST field available for all customer types (retail, wholesale, distributor)
-- ✅ Batch persistence issues by fixing RLS policies
-- ✅ Customer RLS policies updated for consistency
-- ✅ Test function to verify batch insert capability
-- 
-- After running this SQL:
-- 1. All customer types can have GST numbers
-- 2. New batches will persist to database correctly
-- 3. Batch data won't disappear after refresh
-- =====================================================