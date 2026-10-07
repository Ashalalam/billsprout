-- =====================================================
-- Fix: Ensure allow_loose_sales column exists in products table
-- =====================================================
-- This migration ensures migration 021 columns are present
-- Addresses PostgREST cache issue PGRST204

-- Check and add missing columns to products table
DO $$
BEGIN
    -- Allow loose sales flag
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'products' 
        AND column_name = 'allow_loose_sales'
    ) THEN
        ALTER TABLE products ADD COLUMN allow_loose_sales BOOLEAN DEFAULT false;
        RAISE NOTICE '[024] Added products.allow_loose_sales column';
    ELSE
        RAISE NOTICE '[024] products.allow_loose_sales column already exists';
    END IF;
    
    -- Minimum sale unit
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'products' 
        AND column_name = 'min_sale_unit'
    ) THEN
        ALTER TABLE products ADD COLUMN min_sale_unit VARCHAR(20) DEFAULT 'strip';
        RAISE NOTICE '[024] Added products.min_sale_unit column';
    ELSE
        RAISE NOTICE '[024] products.min_sale_unit column already exists';
    END IF;
    
    -- Base unit
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'products' 
        AND column_name = 'base_unit'
    ) THEN
        ALTER TABLE products ADD COLUMN base_unit VARCHAR(20) DEFAULT 'tablet';
        RAISE NOTICE '[024] Added products.base_unit column';
    ELSE
        RAISE NOTICE '[024] products.base_unit column already exists';
    END IF;
    
    -- Price per base unit
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'products' 
        AND column_name = 'price_per_base_unit'
    ) THEN
        ALTER TABLE products ADD COLUMN price_per_base_unit DECIMAL(10, 2);
        RAISE NOTICE '[024] Added products.price_per_base_unit column';
    ELSE
        RAISE NOTICE '[024] products.price_per_base_unit column already exists';
    END IF;
    
    -- Base units per pack
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'products' 
        AND column_name = 'base_units_per_pack'
    ) THEN
        ALTER TABLE products ADD COLUMN base_units_per_pack INTEGER DEFAULT 10;
        RAISE NOTICE '[024] Added products.base_units_per_pack column';
    ELSE
        RAISE NOTICE '[024] products.base_units_per_pack column already exists';
    END IF;
END $$;

-- Add check constraints if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'products_min_sale_unit_check'
    ) THEN
        ALTER TABLE products ADD CONSTRAINT products_min_sale_unit_check 
            CHECK (min_sale_unit IN ('strip', 'tablet', 'capsule', 'ml', 'gm', 'unit', 'pack', 'bottle', 'vial'));
        RAISE NOTICE '[024] Added products_min_sale_unit_check constraint';
    ELSE
        RAISE NOTICE '[024] products_min_sale_unit_check constraint already exists';
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'products_base_unit_check'
    ) THEN
        ALTER TABLE products ADD CONSTRAINT products_base_unit_check 
            CHECK (base_unit IN ('tablet', 'capsule', 'ml', 'gm', 'unit', 'dose'));
        RAISE NOTICE '[024] Added products_base_unit_check constraint';
    ELSE
        RAISE NOTICE '[024] products_base_unit_check constraint already exists';
    END IF;
END $$;

-- Backfill defaults for existing products if columns were just added
DO $$
DECLARE
    v_column_just_added BOOLEAN;
BEGIN
    -- Check if we need to backfill
    SELECT EXISTS (
        SELECT 1 FROM products 
        WHERE allow_loose_sales IS NULL 
        LIMIT 1
    ) INTO v_column_just_added;
    
    IF v_column_just_added THEN
        -- Tablets and capsules: enable loose sales
        UPDATE products
        SET 
            allow_loose_sales = true,
            min_sale_unit = 'tablet',
            base_unit = 'tablet',
            base_units_per_pack = COALESCE(base_units_per_pack, 10)
        WHERE dosage_form IN ('tablet', 'capsule')
          AND allow_loose_sales IS NULL;
        
        -- Capsules: adjust unit type
        UPDATE products
        SET 
            base_unit = 'capsule',
            min_sale_unit = 'capsule'
        WHERE dosage_form = 'capsule'
          AND allow_loose_sales = true;
        
        -- Liquids: no loose sales
        UPDATE products
        SET 
            allow_loose_sales = false,
            min_sale_unit = 'bottle',
            base_unit = 'ml',
            base_units_per_pack = COALESCE(base_units_per_pack, 60)
        WHERE dosage_form IN ('syrup', 'drops', 'suspension')
          AND allow_loose_sales IS NULL;
        
        -- Injections
        UPDATE products
        SET 
            allow_loose_sales = false,
            min_sale_unit = 'vial',
            base_unit = 'ml',
            base_units_per_pack = COALESCE(base_units_per_pack, 1)
        WHERE dosage_form = 'injection'
          AND allow_loose_sales IS NULL;
        
        -- Topicals
        UPDATE products
        SET 
            allow_loose_sales = false,
            min_sale_unit = 'tube',
            base_unit = 'gm',
            base_units_per_pack = COALESCE(base_units_per_pack, 1)
        WHERE dosage_form IN ('cream', 'ointment', 'gel', 'lotion')
          AND allow_loose_sales IS NULL;
        
        -- Other forms
        UPDATE products
        SET 
            allow_loose_sales = false,
            min_sale_unit = 'unit',
            base_unit = 'unit',
            base_units_per_pack = COALESCE(base_units_per_pack, 1)
        WHERE allow_loose_sales IS NULL;
        
        RAISE NOTICE '[024] Backfilled loose-unit defaults for existing products';
    ELSE
        RAISE NOTICE '[024] No backfill needed - products already have loose-unit configuration';
    END IF;
END $$;

-- Force PostgREST schema cache reload
NOTIFY pgrst, 'reload schema';

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- This ensures all loose-unit sales columns exist and:
-- ✅ Adds missing columns from migration 021 if not present
-- ✅ Preserves existing data if columns already exist
-- ✅ Backfills intelligent defaults for existing products
-- ✅ Forces PostgREST to reload the schema cache
-- =====================================================
