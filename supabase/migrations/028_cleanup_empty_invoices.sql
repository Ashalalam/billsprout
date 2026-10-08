-- Migration: Clean up empty invoices (invoices with no items)
-- Date: 2026-10-06
-- Description: Remove sales records that have zero items (corrupted data from failed inserts)

-- Delete sales records that have no associated sale_items
DELETE FROM sales
WHERE id NOT IN (
  SELECT DISTINCT sale_id 
  FROM sale_items 
  WHERE sale_id IS NOT NULL
);

-- Log the cleanup
DO $$
DECLARE
  deleted_count INT;
BEGIN
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RAISE NOTICE 'Cleaned up % empty invoice(s)', deleted_count;
END $$;
