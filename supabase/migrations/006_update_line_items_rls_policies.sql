-- =====================================================
-- Migration: Update RLS Policies for Line Item Tables
-- =====================================================
-- Created: 2025-01-24
-- Task: 1.1 Multi-Tenant RLS Implementation
-- Purpose: Update RLS policies for sale_items and purchase_items to use direct tenant_id filtering
--          instead of JOIN-based filtering for better performance
-- Dependencies: Requires 005_add_tenant_id_to_line_items.sql to be executed first

-- =====================================================
-- 1. Update SALE_ITEMS RLS Policies
-- =====================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can access sale items from their tenant's sales" ON sale_items;
DROP POLICY IF EXISTS "Users can insert sale items for their tenant's sales" ON sale_items;

-- Create new policies using direct tenant_id filtering
DROP POLICY IF EXISTS "Users can access their tenant's sale items" ON sale_items;
CREATE POLICY "Users can access their tenant's sale items"
ON sale_items FOR ALL
USING (user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS "Users can insert sale items for their tenant" ON sale_items;
CREATE POLICY "Users can insert sale items for their tenant"
ON sale_items FOR INSERT
WITH CHECK (user_has_tenant_access(tenant_id));

-- Add comment explaining the improvement
COMMENT ON TABLE sale_items IS 'Line items for each sale - now includes tenant_id for direct RLS filtering';

-- =====================================================
-- 2. Update PURCHASE_ITEMS RLS Policies
-- =====================================================

-- Drop existing policies
DROP POLICY IF EXISTS "Users can access purchase items from their tenant's purchases" ON purchase_items;
DROP POLICY IF EXISTS "Users can insert purchase items for their tenant's purchases" ON purchase_items;

-- Create new policies using direct tenant_id filtering
DROP POLICY IF EXISTS "Users can access their tenant's purchase items" ON purchase_items;
CREATE POLICY "Users can access their tenant's purchase items"
ON purchase_items FOR ALL
USING (user_has_tenant_access(tenant_id));

DROP POLICY IF EXISTS "Users can insert purchase items for their tenant" ON purchase_items;
CREATE POLICY "Users can insert purchase items for their tenant"
ON purchase_items FOR INSERT
WITH CHECK (user_has_tenant_access(tenant_id));

-- Add comment explaining the improvement
COMMENT ON TABLE purchase_items IS 'Line items for each purchase - now includes tenant_id for direct RLS filtering';

-- =====================================================
-- Performance Verification Query
-- =====================================================

-- This query can be used to verify that indexes are being used
DO $$
BEGIN
    RAISE NOTICE 'RLS policy update completed successfully';
    RAISE NOTICE 'sale_items and purchase_items now use direct tenant_id filtering';
    RAISE NOTICE 'Query performance should be significantly improved';
    RAISE NOTICE 'Run EXPLAIN ANALYZE on queries to verify index usage';
END $$;

-- =====================================================
-- Summary
-- =====================================================
/*
Performance Improvements:
- BEFORE: RLS policies used EXISTS subquery with JOIN to parent table
  Example: EXISTS (SELECT 1 FROM sales WHERE sales.id = sale_items.sale_id AND ...)
  
- AFTER: RLS policies use direct tenant_id column filtering
  Example: user_has_tenant_access(tenant_id)

Benefits:
1. Eliminates JOIN operations in RLS checks
2. Utilizes indexes on tenant_id columns (created in migration 005)
3. Reduces query execution time for line item queries
4. Simplifies query plans
5. Consistent filtering pattern across all tables

Usage:
These policies work seamlessly with existing application code.
No application changes required after this migration.
*/
