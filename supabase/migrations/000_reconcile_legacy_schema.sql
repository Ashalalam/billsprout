-- =====================================================
-- Reconcile pre-existing legacy schema before 001 runs
-- =====================================================
-- WHY THIS EXISTS
-- The live database was found holding an earlier, camelCase prototype schema:
--
--   companies            (id, createdAt, businessName, ownerName, email, phone,
--                         gstin, address, drugLicenseNo, industryType, isActive)
--   invoices             (id, timestamp, companyId, invoiceNumber, customerName,
--                         customerPhone, doctorName, doctorMciNo, items,
--                         discountAmount, paymentMode, isSynced,
--                         pharmacistPinApprovedBy)
--   ledger_entries       (id, amount, description, ...)
--   restricted_drug_logs (id, timestamp, companyId, invoiceNumber, doctorName,
--                         productName)
--   stock_transfers      (id, timestamp, productName, batchNumber, quantity,
--                         status)
--   ota_releases         (id, latestVersion, releasedAt)
--
-- Migration 001 creates `tenants`, `sales`, `sale_items`, etc., and it declares
-- restricted_drug_logs and stock_transfers with CREATE TABLE IF NOT EXISTS.
-- Because those two names are already taken by the legacy shape, 001 would
-- silently SKIP them and leave tables that lack tenant_id, sale_id,
-- pharmacist_id and authorization_timestamp. Later migrations then fail when
-- they index or gate those columns, and the app's Schedule H logging breaks.
--
-- SAFETY
-- Every legacy table was verified empty (0 rows) at the time of writing via
-- PostgREST count. Even so, nothing is dropped: each legacy table is RENAMED to
-- <name>_legacy_v0, which preserves any row that might appear between
-- inspection and deployment and keeps the data recoverable.
--
-- The rename is guarded on the table actually having the legacy shape, so
-- re-running this file after 001 has created the canonical tables does nothing.
-- =====================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Renames <name> to <name>_legacy_v0 only when the table exists, has the given
-- legacy marker column, and is NOT already the canonical shape.
CREATE OR REPLACE FUNCTION pg_temp.park_legacy_table(
    p_table TEXT,
    p_legacy_marker TEXT,
    p_canonical_marker TEXT
)
RETURNS void AS $fn$
DECLARE
    has_legacy    BOOLEAN;
    has_canonical BOOLEAN;
    row_count     BIGINT;
    archive_name  TEXT := p_table || '_legacy_v0';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = 'public' AND table_name = p_table) THEN
        RAISE NOTICE '[000] %: absent, nothing to park', p_table;
        RETURN;
    END IF;

    SELECT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = p_table
                     AND column_name = p_legacy_marker)
      INTO has_legacy;

    SELECT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = p_table
                     AND column_name = p_canonical_marker)
      INTO has_canonical;

    -- Canonical already present (or partially migrated): leave it alone.
    IF has_canonical OR NOT has_legacy THEN
        RAISE NOTICE '[000] %: already canonical or unrecognised, left untouched',
            p_table;
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = 'public' AND table_name = archive_name) THEN
        RAISE NOTICE '[000] % already parked as %, skipping', p_table, archive_name;
        RETURN;
    END IF;

    EXECUTE format('SELECT count(*) FROM public.%I', p_table) INTO row_count;
    EXECUTE format('ALTER TABLE public.%I RENAME TO %I', p_table, archive_name);
    RAISE NOTICE '[000] parked % (% rows preserved) as %',
        p_table, row_count, archive_name;
END;
$fn$ LANGUAGE plpgsql;

DO $$
BEGIN
    -- Blocking conflicts: 001 declares these with IF NOT EXISTS and would skip.
    PERFORM pg_temp.park_legacy_table('restricted_drug_logs', 'companyId', 'tenant_id');
    PERFORM pg_temp.park_legacy_table('stock_transfers',      'productName', 'tenant_id');

    -- Superseded prototypes. companies -> tenants and invoices -> sales are the
    -- same entities under new names, so parking them keeps the old rows readable
    -- while the canonical tables take over.
    PERFORM pg_temp.park_legacy_table('companies', 'businessName', 'business_name');
    PERFORM pg_temp.park_legacy_table('invoices',  'companyId',    'tenant_id');
END $$;

-- ledger_entries and ota_releases do not collide with any table created by
-- 001-007, so they are left in place and continue to serve the app.

-- =====================================================
-- Carry legacy rows forward where the mapping is unambiguous.
-- Runs at the END of the migration chain would be ideal, but the canonical
-- tables do not exist yet at this point, so the backfill is deferred to
-- migration 009 which runs after 001 has created them.
-- =====================================================

COMMENT ON FUNCTION pg_temp.park_legacy_table(TEXT, TEXT, TEXT) IS
    'Renames a legacy-shaped table aside so migration 001 can create the canonical one';
