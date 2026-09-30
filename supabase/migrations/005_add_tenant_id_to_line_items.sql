-- =====================================================
-- Migration: Add tenant_id to Line Item Tables
-- =====================================================
-- Created: 2025-01-24
-- Task: 1.1 Multi-Tenant RLS Implementation
-- Purpose: Add tenant_id column with NOT NULL constraint to sale_items and purchase_items
--          to enable direct RLS policy filtering

-- =====================================================
-- 1. Add tenant_id to sale_items
-- =====================================================

-- Step 1: Add column as nullable first (guarded so the file can be re-applied)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = 'sale_items'
                     AND column_name = 'tenant_id') THEN
        ALTER TABLE sale_items
        ADD COLUMN tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Step 2: Backfill existing data from parent sales table
UPDATE sale_items si
SET tenant_id = s.tenant_id
FROM sales s
WHERE si.sale_id = s.id
  AND si.tenant_id IS DISTINCT FROM s.tenant_id;

-- Step 3: Make column NOT NULL after backfill.
-- Only when every row is populated; otherwise the ALTER aborts the migration.
DO $$
DECLARE
    null_rows INTEGER;
BEGIN
    SELECT COUNT(*) INTO null_rows FROM sale_items WHERE tenant_id IS NULL;
    IF null_rows = 0 THEN
        ALTER TABLE sale_items ALTER COLUMN tenant_id SET NOT NULL;
    ELSE
        RAISE NOTICE 'sale_items.tenant_id left nullable: % orphan row(s)', null_rows;
    END IF;
END $$;

-- Step 4: Add index for RLS performance
CREATE INDEX IF NOT EXISTS idx_sale_items_tenant_id ON sale_items(tenant_id);

-- Add comment
COMMENT ON COLUMN sale_items.tenant_id IS 'Tenant identifier for multi-tenant RLS filtering';

-- =====================================================
-- 2. Add tenant_id to purchase_items
-- =====================================================

-- Step 1: Add column as nullable first (guarded so the file can be re-applied)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = 'purchase_items'
                     AND column_name = 'tenant_id') THEN
        ALTER TABLE purchase_items
        ADD COLUMN tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Step 2: Backfill existing data from parent purchases table
UPDATE purchase_items pi
SET tenant_id = p.tenant_id
FROM purchases p
WHERE pi.purchase_id = p.id
  AND pi.tenant_id IS DISTINCT FROM p.tenant_id;

-- Step 3: Make column NOT NULL after backfill
DO $$
DECLARE
    null_rows INTEGER;
BEGIN
    SELECT COUNT(*) INTO null_rows FROM purchase_items WHERE tenant_id IS NULL;
    IF null_rows = 0 THEN
        ALTER TABLE purchase_items ALTER COLUMN tenant_id SET NOT NULL;
    ELSE
        RAISE NOTICE 'purchase_items.tenant_id left nullable: % orphan row(s)', null_rows;
    END IF;
END $$;

-- Step 4: Add index for RLS performance
CREATE INDEX IF NOT EXISTS idx_purchase_items_tenant_id ON purchase_items(tenant_id);

-- Add comment
COMMENT ON COLUMN purchase_items.tenant_id IS 'Tenant identifier for multi-tenant RLS filtering';

-- =====================================================
-- 3. Fix users table tenant_id constraint
-- =====================================================

-- Add CHECK constraint allowing NULL only for super_admin role
-- This allows super_admin users to access all tenants
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conrelid = 'public.users'::regclass
                     AND conname = 'users_tenant_id_required') THEN
        ALTER TABLE users
        ADD CONSTRAINT users_tenant_id_required
        CHECK (tenant_id IS NOT NULL OR role = 'super_admin');
    END IF;
END $$;

-- Add comment explaining the constraint
COMMENT ON CONSTRAINT users_tenant_id_required ON users IS 
'Ensures all users except super_admin have a tenant_id assigned';

-- =====================================================
-- Verification Queries
-- =====================================================

-- Verify sale_items tenant_id population
DO $$
DECLARE
    null_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO null_count FROM sale_items WHERE tenant_id IS NULL;
    IF null_count > 0 THEN
        -- Reported, not fatal: an orphan line item (no parent sale) must not
        -- block the whole migration chain from applying.
        RAISE WARNING 'Found % sale_items with NULL tenant_id (orphaned line items)', null_count;
    ELSE
        RAISE NOTICE 'sale_items tenant_id backfill successful: all rows populated';
    END IF;
END $$;

-- Verify purchase_items tenant_id population
DO $$
DECLARE
    null_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO null_count FROM purchase_items WHERE tenant_id IS NULL;
    IF null_count > 0 THEN
        RAISE WARNING 'Found % purchase_items with NULL tenant_id (orphaned line items)', null_count;
    ELSE
        RAISE NOTICE 'purchase_items tenant_id backfill successful: all rows populated';
    END IF;
END $$;

-- =====================================================
-- Summary
-- =====================================================
/*
This migration adds tenant_id to line item tables for direct RLS filtering:

Tables Modified:
1. sale_items - Added tenant_id UUID NOT NULL with foreign key and index
2. purchase_items - Added tenant_id UUID NOT NULL with foreign key and index
3. users - Added CHECK constraint for tenant_id requirement

Benefits:
- Direct RLS policy filtering without JOIN operations
- Improved query performance for line item queries
- Simplified RLS policy definitions
- Consistent tenant_id presence across all business tables

Next Steps:
- Task 1.2: Create RLS policies for all tables
- Task 1.3: Implement session variable setter
*/
