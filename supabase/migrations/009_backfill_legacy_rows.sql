-- =====================================================
-- Backfill rows parked by migration 000 into the canonical tables
-- =====================================================
-- Runs after 001-008 have created tenants / sales / sale_items.
--
-- WRITTEN AGAINST THE REAL LIVE DATA, inspected with the service-role key:
--
--   companies : 0 rows
--   invoices  : 7 rows, and critically
--                 * "id" is TEXT like 'inv_1790366744736', NOT a uuid
--                 * "companyId" is NULL on every single row
--                 * "items" is a JSON blob; some are '[]'
--                 * "pharmacistPinApprovedBy" holds 'Pharmacist PIN #1234',
--                   i.e. the literal PIN was written into the audit field
--
-- Two consequences drive the design below:
--
-- 1. sales.id is UUID. Inserting the text id directly raises
--    "invalid input syntax for type uuid". A deterministic UUID is derived from
--    the legacy id instead (md5 of the text, shaped into a v4-looking uuid), so
--    re-running maps the same legacy row to the same sales.id and the insert
--    stays idempotent. The original text is kept in sales.legacy_source_id.
--
-- 2. sales.tenant_id is NOT NULL, and every legacy invoice has companyId NULL.
--    There is no correct tenant to assign. Inventing one would attribute real
--    dispensing records to a business that did not make them, which is worse
--    than not migrating them. Those rows therefore stay in invoices_legacy_v0,
--    fully intact, and this migration reports the count loudly so the decision
--    is visible rather than silent.
--
--    If those invoices are later identified as belonging to a specific tenant,
--    set SET app.legacy_target_tenant = '<tenant uuid>' before running and they
--    will be attached to it.
-- =====================================================

-- Derives a stable UUID from arbitrary legacy text.
CREATE OR REPLACE FUNCTION pg_temp.legacy_uuid(p_text TEXT)
RETURNS UUID AS $$
DECLARE
    h TEXT;
BEGIN
    -- NULL in, NULL out: callers use the result in COALESCE and IS NOT NULL
    -- tests, so a NULL companyId must not become a bogus uuid.
    IF p_text IS NULL OR btrim(p_text) = '' THEN
        RETURN NULL;
    END IF;

    -- Already a uuid? Use it unchanged so genuine uuid ids keep their identity.
    IF p_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
        RETURN p_text::uuid;
    END IF;

    h := md5(p_text);
    RETURN (
        substr(h, 1, 8)  || '-' ||
        substr(h, 9, 4)  || '-' ||
        '4' || substr(h, 14, 3) || '-' ||   -- version nibble
        '8' || substr(h, 18, 3) || '-' ||   -- variant nibble
        substr(h, 21, 12)
    )::uuid;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Traceability column so a migrated sale can be tied back to its legacy row.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema='public' AND table_name='sales')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_schema='public' AND table_name='sales'
                         AND column_name='legacy_source_id') THEN
        ALTER TABLE sales ADD COLUMN legacy_source_id TEXT;
        COMMENT ON COLUMN sales.legacy_source_id IS
            'Original id from the prototype invoices table, for traceability';
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema='public' AND table_name='sales')
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_schema='public' AND table_name='sales'
                         AND column_name='legacy_pharmacist_authorized_by') THEN
        -- sales.pharmacist_authorized_by is a UUID FK to users(id); the legacy
        -- value is free text that resolves to no user row.
        ALTER TABLE sales ADD COLUMN legacy_pharmacist_authorized_by TEXT;
        COMMENT ON COLUMN sales.legacy_pharmacist_authorized_by IS
            'Free-text approver label carried over from the prototype invoices table';
    END IF;
END $$;

-- =====================================================
-- 1. companies_legacy_v0 -> tenants
-- =====================================================
DO $$
DECLARE
    moved INTEGER := 0;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = 'public'
                     AND table_name = 'companies_legacy_v0') THEN
        RAISE NOTICE '[009] no companies_legacy_v0, nothing to backfill';
        RETURN;
    END IF;

    INSERT INTO tenants (
        id, business_name, owner_name, email, phone, gstin,
        drug_license_no, address, city, state, pincode,
        industry_type, business_mode, subscription_plan, subscription_status,
        max_branches, is_active, created_at, updated_at
    )
    SELECT
        pg_temp.legacy_uuid(c."id"::text),
        COALESCE(NULLIF(c."businessName", ''), 'Unnamed (migrated)'),
        COALESCE(NULLIF(c."ownerName", ''), 'Unknown'),
        -- tenants.email is UNIQUE in some revisions; keep it deterministic.
        COALESCE(NULLIF(c."email", ''),
                 'migrated+' || left(md5(c."id"::text), 8) || '@invalid.local'),
        COALESCE(NULLIF(c."phone", ''), ''),
        COALESCE(NULLIF(c."gstin", ''), ''),
        COALESCE(NULLIF(c."drugLicenseNo", ''), ''),
        COALESCE(NULLIF(c."address", ''), ''),
        'MIGRATED - SET CITY',
        'MIGRATED - SET STATE',
        '000000',
        CASE lower(COALESCE(c."industryType", ''))
            WHEN 'pharma'    THEN 'pharmacy'
            WHEN 'pharmacy'  THEN 'pharmacy'
            WHEN 'wholesale' THEN 'wholesale'
            WHEN 'retail'    THEN 'retail'
            WHEN 'fmcg'      THEN 'fmcg'
            ELSE 'pharmacy'
        END,
        'retail',
        'Basic',
        'active',
        1,
        COALESCE(c."isActive", true),
        COALESCE(c."createdAt", CURRENT_TIMESTAMP),
        CURRENT_TIMESTAMP
    FROM companies_legacy_v0 c
    WHERE NOT EXISTS (
        SELECT 1 FROM tenants t
        WHERE t.id = pg_temp.legacy_uuid(c."id"::text)
    );

    GET DIAGNOSTICS moved = ROW_COUNT;
    RAISE NOTICE '[009] backfilled % tenant(s) from companies_legacy_v0', moved;
END $$;

-- =====================================================
-- 2. invoices_legacy_v0 -> sales
-- =====================================================
DO $$
DECLARE
    moved         INTEGER := 0;
    unattributed  INTEGER := 0;
    total_legacy  INTEGER := 0;
    target_tenant UUID;
    rec           RECORD;
    new_uid       UUID;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = 'public'
                     AND table_name = 'invoices_legacy_v0') THEN
        RAISE NOTICE '[009] no invoices_legacy_v0, nothing to backfill';
        RETURN;
    END IF;

    SELECT COUNT(*) INTO total_legacy FROM invoices_legacy_v0;

    -- Optional operator override for invoices that carry no companyId.
    BEGIN
        target_tenant := NULLIF(current_setting('app.legacy_target_tenant', true), '')::uuid;
    EXCEPTION WHEN OTHERS THEN
        target_tenant := NULL;
    END;

    IF target_tenant IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM tenants WHERE id = target_tenant) THEN
        RAISE WARNING '[009] app.legacy_target_tenant % is not an existing tenant; ignoring',
            target_tenant;
        target_tenant := NULL;
    END IF;

    -- Count rows that cannot be attributed to any tenant.
    SELECT COUNT(*) INTO unattributed
    FROM invoices_legacy_v0 i
    WHERE target_tenant IS NULL
      AND (i."companyId" IS NULL
           OR NOT EXISTS (
               SELECT 1 FROM tenants t
               WHERE t.id = pg_temp.legacy_uuid(i."companyId"::text)));

    -- Every migrated tenant needs a system author, because sales.created_by is
    -- NOT NULL and the legacy rows recorded no user.
    -- legacy_uuid() must do the conversion; a direct ::uuid cast on the raw
    -- legacy text ('comp_1790300000000') raises "invalid input syntax for uuid".
    FOR rec IN
        SELECT DISTINCT
            COALESCE(target_tenant,
                     pg_temp.legacy_uuid(i."companyId"::text)) AS tenant_id
        FROM invoices_legacy_v0 i
        WHERE target_tenant IS NOT NULL
           OR NULLIF(i."companyId"::text, '') IS NOT NULL
    LOOP
        CONTINUE WHEN rec.tenant_id IS NULL;
        CONTINUE WHEN NOT EXISTS (SELECT 1 FROM tenants WHERE id = rec.tenant_id);
        CONTINUE WHEN EXISTS (
            SELECT 1 FROM users u
            WHERE u.tenant_id = rec.tenant_id
              AND u.email = 'migration@system.local');

        new_uid := uuid_generate_v4();
        BEGIN
            INSERT INTO auth.users (id, email)
            VALUES (new_uid, 'migration@system.local')
            ON CONFLICT (id) DO NOTHING;
        EXCEPTION WHEN insufficient_privilege OR undefined_table OR unique_violation THEN
            NULL;  -- managed auth schema, or the address already exists
        END;

        BEGIN
            INSERT INTO users (id, tenant_id, name, email, role, is_active)
            VALUES (new_uid, rec.tenant_id, 'Legacy Data Migration',
                    'migration@system.local', 'business_admin', false);
        EXCEPTION WHEN foreign_key_violation OR unique_violation THEN
            RAISE NOTICE '[009] no system user for tenant %; its legacy sales are skipped',
                rec.tenant_id;
        END;
    END LOOP;

    -- A branch is required (sales.branch_id NOT NULL) and the legacy rows had none.
    INSERT INTO branches (
        id, tenant_id, branch_name, branch_code, address, city, state, pincode,
        drug_license_no, phone, email, manager_name, is_active
    )
    SELECT
        uuid_generate_v4(), t.id, 'Migrated Records', 'MIGRATED',
        '', 'MIGRATED - SET CITY', 'MIGRATED - SET STATE', '000000',
        '', '', '', '', true
    FROM tenants t
    WHERE EXISTS (
        SELECT 1 FROM invoices_legacy_v0 i
        WHERE COALESCE(target_tenant, pg_temp.legacy_uuid(i."companyId"::text)) = t.id
    )
    AND NOT EXISTS (
        SELECT 1 FROM branches b
        WHERE b.tenant_id = t.id AND b.branch_code = 'MIGRATED'
    );

    INSERT INTO sales (
        id, legacy_source_id, tenant_id, branch_id, invoice_number, invoice_date,
        customer_name, customer_phone, doctor_name, doctor_mci_no,
        subtotal, item_discount_total, invoice_discount, taxable_amount,
        cgst_amount, sgst_amount, igst_amount, total_gst, round_off,
        grand_total, payment_mode, payment_status,
        legacy_pharmacist_authorized_by, is_synced, billing_type,
        created_by, created_at, updated_at
    )
    SELECT
        pg_temp.legacy_uuid(i."id"::text),
        i."id"::text,
        COALESCE(target_tenant, pg_temp.legacy_uuid(i."companyId"::text)),
        (SELECT b.id FROM branches b
          WHERE b.tenant_id = COALESCE(target_tenant,
                                       pg_temp.legacy_uuid(i."companyId"::text))
            AND b.branch_code = 'MIGRATED'
          LIMIT 1),
        COALESCE(NULLIF(i."invoiceNumber", ''),
                 'MIGRATED-' || left(md5(i."id"::text), 8)),
        COALESCE(i."timestamp", CURRENT_TIMESTAMP),
        COALESCE(NULLIF(i."customerName", ''), 'Walk-in Customer'),
        COALESCE(NULLIF(i."customerPhone", ''), ''),
        i."doctorName",
        i."doctorMciNo",
        -- Line items were a JSON blob with no computed totals. Sum what is
        -- recoverable; leave the GST split at zero rather than inventing a tax
        -- breakdown that was never recorded.
        COALESCE(src.gross, 0),
        0,
        COALESCE(i."discountAmount", 0),
        0, 0, 0, 0, 0, 0,
        GREATEST(COALESCE(src.gross, 0) - COALESCE(i."discountAmount", 0), 0),
        CASE lower(COALESCE(i."paymentMode", 'cash'))
            WHEN 'card'   THEN 'card'
            WHEN 'upi'    THEN 'upi'
            WHEN 'credit' THEN 'credit'
            WHEN 'split'  THEN 'split'
            ELSE 'cash'
        END,
        'paid',
        i."pharmacistPinApprovedBy",
        COALESCE(i."isSynced", true),
        'retail',
        (SELECT u.id FROM users u
          WHERE u.tenant_id = COALESCE(target_tenant,
                                       pg_temp.legacy_uuid(i."companyId"::text))
            AND u.email = 'migration@system.local'
          LIMIT 1),
        COALESCE(i."timestamp", CURRENT_TIMESTAMP),
        CURRENT_TIMESTAMP
    FROM invoices_legacy_v0 i
    CROSS JOIN LATERAL (
        SELECT COALESCE(SUM(
                   COALESCE((it->>'quantity')::numeric, 0)
                 * COALESCE((it->>'unitPrice')::numeric, 0)), 0) AS gross
        FROM jsonb_array_elements(
            CASE
                WHEN i."items" IS NULL THEN '[]'::jsonb
                WHEN jsonb_typeof(
                        CASE WHEN pg_typeof(i."items")::text = 'jsonb'
                             THEN i."items"::jsonb
                             ELSE i."items"::text::jsonb END) = 'array'
                    THEN CASE WHEN pg_typeof(i."items")::text = 'jsonb'
                              THEN i."items"::jsonb
                              ELSE i."items"::text::jsonb END
                ELSE '[]'::jsonb
            END) AS it
    ) src
    WHERE COALESCE(target_tenant, pg_temp.legacy_uuid(i."companyId"::text)) IS NOT NULL
      AND EXISTS (
          SELECT 1 FROM tenants t
          WHERE t.id = COALESCE(target_tenant,
                                pg_temp.legacy_uuid(i."companyId"::text)))
      AND EXISTS (
          SELECT 1 FROM users u
          WHERE u.tenant_id = COALESCE(target_tenant,
                                       pg_temp.legacy_uuid(i."companyId"::text))
            AND u.email = 'migration@system.local')
      AND NOT EXISTS (
          SELECT 1 FROM sales s
          WHERE s.id = pg_temp.legacy_uuid(i."id"::text));

    GET DIAGNOSTICS moved = ROW_COUNT;

    RAISE NOTICE '[009] invoices_legacy_v0: % total, % migrated to sales, % left unattributed',
        total_legacy, moved, unattributed;

    IF unattributed > 0 THEN
        RAISE WARNING '[009] % legacy invoice(s) have no companyId and were NOT migrated. They remain intact in invoices_legacy_v0. To attach them to a tenant, run: SET app.legacy_target_tenant = ''<tenant-uuid>''; then re-apply this migration.',
            unattributed;
    END IF;

    -- sale_items is deliberately not backfilled: the legacy JSON embeds whole
    -- product/batch objects whose prototype ids do not resolve to rows in
    -- products/batches, and sale_items.product_id is a FK. Fabricating catalogue
    -- rows to satisfy it would corrupt the product master. The JSON stays
    -- readable in invoices_legacy_v0 for anyone who needs the detail.
END $$;

DO $$
BEGIN
    RAISE NOTICE '[009] legacy backfill complete. All *_legacy_v0 rows are retained.';
END $$;
