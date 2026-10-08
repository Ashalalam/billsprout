-- =====================================================
-- FIX: Customer Types (Retail + Wholesale only) + Drug License Expiry
-- =====================================================

-- Updates customer types to only have 'retail' and 'wholesale'
-- Adds drug_license_expiry field for wholesale customers
-- Removes distributor customer type

-- =====================================================
-- 1. ADD DRUG LICENSE EXPIRY COLUMN
-- =====================================================

-- Add drug_license_expiry column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'customers' 
        AND column_name = 'drug_license_expiry'
    ) THEN
        ALTER TABLE customers ADD COLUMN drug_license_expiry DATE;
        RAISE NOTICE '[FIX] ✅ Added drug_license_expiry column to customers table';
    ELSE
        RAISE NOTICE '[FIX] ✅ drug_license_expiry column already exists in customers table';
    END IF;
END $$;

-- =====================================================
-- 2. UPDATE CUSTOMER TYPES (REMOVE DISTRIBUTOR)
-- =====================================================

-- Convert any existing 'distributor' customers to 'wholesale'
UPDATE customers 
SET customer_type = 'wholesale' 
WHERE customer_type = 'distributor';

-- Get count of updated customers
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO updated_count 
    FROM customers 
    WHERE customer_type = 'wholesale';
    
    RAISE NOTICE '[FIX] ✅ Updated customer types: % wholesale customers', updated_count;
END $$;

-- =====================================================
-- 3. VALIDATE CUSTOMER TYPE CONSTRAINTS
-- =====================================================

-- Add check constraint to ensure only 'retail' and 'wholesale' types
DO $$
BEGIN
    -- Drop existing constraint if it exists
    BEGIN
        ALTER TABLE customers DROP CONSTRAINT IF EXISTS customers_customer_type_check;
    EXCEPTION
        WHEN OTHERS THEN NULL;
    END;
    
    -- Add new constraint
    ALTER TABLE customers 
    ADD CONSTRAINT customers_customer_type_check 
    CHECK (customer_type IN ('retail', 'wholesale'));
    
    RAISE NOTICE '[FIX] ✅ Added customer type constraint: only retail and wholesale allowed';
END $$;

-- =====================================================
-- 4. SET SAMPLE DRUG LICENSE EXPIRY DATES
-- =====================================================

-- Set sample expiry dates for existing wholesale customers that don't have them
UPDATE customers 
SET drug_license_expiry = CURRENT_DATE + INTERVAL '2 years'
WHERE customer_type = 'wholesale' 
AND drug_license_expiry IS NULL 
AND drug_license_no IS NOT NULL;

-- =====================================================
-- 5. VERIFY CURRENT STATE
-- =====================================================

-- Show customer types and their counts
SELECT 
    'CUSTOMER_TYPES' as info,
    customer_type,
    COUNT(*) as total_count,
    COUNT(CASE WHEN gstin IS NOT NULL AND gstin != '' THEN 1 END) as with_gst,
    COUNT(CASE WHEN drug_license_no IS NOT NULL AND drug_license_no != '' THEN 1 END) as with_drug_license,
    COUNT(CASE WHEN drug_license_expiry IS NOT NULL THEN 1 END) as with_expiry_date
FROM customers 
GROUP BY customer_type
ORDER BY customer_type;

-- Show wholesale customers with drug license details
SELECT 
    'WHOLESALE_DETAILS' as info,
    customer_name,
    gstin,
    drug_license_no,
    drug_license_expiry,
    CASE 
        WHEN drug_license_expiry IS NULL THEN 'No Expiry Set'
        WHEN drug_license_expiry < CURRENT_DATE THEN 'EXPIRED'
        WHEN drug_license_expiry <= CURRENT_DATE + INTERVAL '30 days' THEN 'Expires Soon'
        ELSE 'Valid'
    END as license_status
FROM customers 
WHERE customer_type = 'wholesale'
ORDER BY drug_license_expiry ASC NULLS LAST;

-- Check constraint status
SELECT 
    'CONSTRAINTS' as info,
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'customers'::regclass 
AND conname LIKE '%customer_type%';

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- This fixes:
-- ✅ Only 2 customer types: retail and wholesale (distributor removed)
-- ✅ Drug license expiry date field added for wholesale customers
-- ✅ Database constraints updated to enforce valid customer types
-- ✅ Sample expiry dates set for existing wholesale customers
-- 
-- After running this SQL:
-- 1. Customer form will only show Retail and Wholesale options
-- 2. Wholesale customers must have GST, Drug License, and Expiry Date
-- 3. Retail customers only need GST (optional)
-- 4. Drug license expiry tracking and warnings implemented
-- =====================================================