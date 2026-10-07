-- =====================================================
-- Diagnostic: Check batches table schema and permissions
-- =====================================================
-- This migration helps diagnose why batch INSERT is failing

-- 1. Verify all expected columns exist in batches table
DO $$
DECLARE
    missing_columns TEXT[] := ARRAY[]::TEXT[];
    col_name TEXT;
BEGIN
    -- Check for each expected column
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
        RAISE NOTICE '[026] ❌ Missing columns in batches table: %', array_to_string(missing_columns, ', ');
    ELSE
        RAISE NOTICE '[026] ✅ All expected columns exist in batches table';
    END IF;
END $$;

-- 2. Verify RLS is enabled and policies exist
DO $$
DECLARE
    policy_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO policy_count
    FROM pg_policies
    WHERE tablename = 'batches';
    
    IF policy_count = 0 THEN
        RAISE NOTICE '[026] ❌ No RLS policies found for batches table';
    ELSE
        RAISE NOTICE '[026] ✅ Found % RLS policies for batches table', policy_count;
    END IF;
END $$;

-- 3. Show current RLS policies for batches
DO $$
DECLARE
    pol_record RECORD;
BEGIN
    RAISE NOTICE '[026] Current RLS policies for batches:';
    FOR pol_record IN 
        SELECT policyname, cmd, permissive
        FROM pg_policies 
        WHERE tablename = 'batches'
    LOOP
        RAISE NOTICE '[026]   - Policy: % | Command: % | Permissive: %', 
            pol_record.policyname, pol_record.cmd, pol_record.permissive;
    END LOOP;
END $$;

-- 4. Verify user_has_tenant_access function exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        AND p.proname = 'user_has_tenant_access'
    ) THEN
        RAISE NOTICE '[026] ✅ user_has_tenant_access function exists';
    ELSE
        RAISE NOTICE '[026] ❌ user_has_tenant_access function NOT FOUND';
    END IF;
END $$;

-- 5. Check if there are any existing batches
DO $$
DECLARE
    batch_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO batch_count FROM batches;
    RAISE NOTICE '[026] Current batch count: %', batch_count;
END $$;

-- 6. Show sample batch data structure (if any exist)
DO $$
DECLARE
    sample_batch RECORD;
BEGIN
    SELECT * INTO sample_batch FROM batches LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE '[026] ✅ Sample batch found - structure looks valid';
    ELSE
        RAISE NOTICE '[026] ⚠️  No existing batches in database yet';
    END IF;
END $$;

-- =====================================================
-- DIAGNOSTIC COMPLETE
-- =====================================================
-- Run this migration and check the NOTICES in output
-- This will tell us exactly what's missing or misconfigured
-- =====================================================
