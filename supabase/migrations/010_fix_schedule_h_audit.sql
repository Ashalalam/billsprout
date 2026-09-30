-- =====================================================
-- Fix Schedule H audit logging (blocking production bug)
-- =====================================================
-- FOUND BY EXECUTION, not inspection:
--
-- 1. `sales.pharmacist_authorized_by` is UUID REFERENCES users(id), but the app
--    writes a human label there ('Dr Rao (PIN verified)'). That is a type error
--    on every authorised sale.
--
-- 2. The 004 trigger log_restricted_drug_sale() copies that value into
--    `restricted_drug_logs.pharmacist_id`, which is NOT NULL. When the value is
--    NULL the INSERT aborts, and because the trigger fires AFTER INSERT ON
--    sale_items the whole sale is rolled back. Net effect: selling ANY
--    Schedule H / H1 / narcotic product is impossible.
--
-- FIX
--   * add sales.authorized_pharmacist_id -> pharmacists(id), the real authoriser
--   * add sales.pharmacist_authorized_name TEXT for the display label
--   * make restricted_drug_logs.pharmacist_id nullable and add
--     pharmacist_ref + pharmacist_name so the audit trail records identity even
--     when the authoriser is a pharmacists row rather than a users row
--   * rewrite the trigger to resolve identity from either source and never abort
--     a legitimate sale
--
-- Compliance note: the log still refuses to record a restricted sale with no
-- authorising identity at all. It raises a clear exception in that case instead
-- of silently writing an unattributed Schedule H record.
-- =====================================================

-- ── 1. Sales columns ─────────────────────────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='public' AND table_name='sales'
                     AND column_name='authorized_pharmacist_id') THEN
        ALTER TABLE sales ADD COLUMN authorized_pharmacist_id UUID
            REFERENCES pharmacists(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='public' AND table_name='sales'
                     AND column_name='pharmacist_authorized_name') THEN
        ALTER TABLE sales ADD COLUMN pharmacist_authorized_name TEXT;
    END IF;
END $$;

-- ── 2. Audit log columns ─────────────────────────────────────────────────────
DO $$
BEGIN
    -- Relax NOT NULL so a pharmacists-table authoriser does not abort the sale.
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema='public' AND table_name='restricted_drug_logs'
                 AND column_name='pharmacist_id' AND is_nullable='NO') THEN
        ALTER TABLE restricted_drug_logs ALTER COLUMN pharmacist_id DROP NOT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='public' AND table_name='restricted_drug_logs'
                     AND column_name='pharmacist_ref') THEN
        ALTER TABLE restricted_drug_logs ADD COLUMN pharmacist_ref UUID
            REFERENCES pharmacists(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='public' AND table_name='restricted_drug_logs'
                     AND column_name='pharmacist_name') THEN
        ALTER TABLE restricted_drug_logs ADD COLUMN pharmacist_name TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema='public' AND table_name='restricted_drug_logs'
                     AND column_name='branch_id') THEN
        ALTER TABLE restricted_drug_logs ADD COLUMN branch_id UUID
            REFERENCES branches(id) ON DELETE SET NULL;
    END IF;
END $$;

-- ── 3. Rewrite the trigger ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION log_restricted_drug_sale()
RETURNS TRIGGER AS $$
DECLARE
    v_is_restricted BOOLEAN;
    v_product_name  VARCHAR(500);
    v_sale          RECORD;
    v_ph_name       TEXT;
BEGIN
    SELECT (is_schedule_h OR is_schedule_h1 OR is_narcotic), name
      INTO v_is_restricted, v_product_name
      FROM products WHERE id = NEW.product_id;

    IF NOT COALESCE(v_is_restricted, false) THEN
        RETURN NEW;
    END IF;

    SELECT * INTO v_sale FROM sales WHERE id = NEW.sale_id;

    -- Resolve the authoriser's display name from whichever source is populated.
    v_ph_name := COALESCE(
        v_sale.pharmacist_authorized_name,
        (SELECT p.name FROM pharmacists p WHERE p.id = v_sale.authorized_pharmacist_id),
        (SELECT u.name FROM users u WHERE u.id = v_sale.pharmacist_authorized_by)
    );

    -- A restricted sale with no authorising identity is a compliance failure.
    -- Fail loudly rather than writing an unattributable Schedule H record.
    IF v_sale.authorized_pharmacist_id IS NULL
       AND v_sale.pharmacist_authorized_by IS NULL
       AND v_ph_name IS NULL THEN
        RAISE EXCEPTION
            'Schedule H/H1/narcotic item "%" requires pharmacist authorisation on sale %',
            v_product_name, NEW.sale_id
            USING HINT = 'Set authorized_pharmacist_id (or pharmacist_authorized_by) before inserting sale items';
    END IF;

    INSERT INTO restricted_drug_logs (
        tenant_id, branch_id, sale_id, product_id, product_name, batch_number,
        quantity, customer_name, doctor_name, doctor_mci_no,
        pharmacist_id, pharmacist_ref, pharmacist_name, prescription_id
    )
    VALUES (
        v_sale.tenant_id, v_sale.branch_id, NEW.sale_id, NEW.product_id,
        v_product_name, NEW.batch_number, NEW.quantity, v_sale.customer_name,
        v_sale.doctor_name, v_sale.doctor_mci_no,
        v_sale.pharmacist_authorized_by,
        v_sale.authorized_pharmacist_id,
        v_ph_name,
        v_sale.prescription_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_log_restricted_drug_sale ON sale_items;
CREATE TRIGGER trigger_log_restricted_drug_sale
    AFTER INSERT ON sale_items
    FOR EACH ROW EXECUTE FUNCTION log_restricted_drug_sale();

-- ── 4. Guard the money invariant in the database ─────────────────────────────
-- The Dart layer clamps the discount, but a stale client or a direct API call
-- must not be able to persist a negative payable.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conrelid='public.sales'::regclass
                     AND conname='sales_grand_total_non_negative') THEN
        ALTER TABLE sales ADD CONSTRAINT sales_grand_total_non_negative
            CHECK (grand_total >= 0);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conrelid='public.sales'::regclass
                     AND conname='sales_invoice_discount_non_negative') THEN
        ALTER TABLE sales ADD CONSTRAINT sales_invoice_discount_non_negative
            CHECK (invoice_discount >= 0);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_constraint
                   WHERE conrelid='public.batches'::regclass
                     AND conname='batches_stock_non_negative') THEN
        -- Overselling a batch into negative stock is always a bug.
        ALTER TABLE batches ADD CONSTRAINT batches_stock_non_negative
            CHECK (stock_quantity >= 0);
    END IF;
END $$;

COMMENT ON COLUMN sales.authorized_pharmacist_id IS
    'Pharmacist who authorised a Schedule H/H1/narcotic sale (pharmacists.id)';
COMMENT ON COLUMN sales.pharmacist_authorized_name IS
    'Display name of the authorising pharmacist, captured at sale time';
COMMENT ON COLUMN restricted_drug_logs.pharmacist_name IS
    'Authoriser identity for the Schedule H register; never stores a PIN';

-- =====================================================
-- 5. Fix stock deduction to include free quantity
-- =====================================================
-- FOUND BY EXECUTION: update_stock_on_sale() in 004 deducts only NEW.quantity.
-- Free goods are physically handed to the customer, so a scheme sale of
-- "10 + 2 free" removed 10 units while 12 left the shelf. Inventory drifted
-- upward by the free amount on every scheme sale, and the stock_movements
-- ledger recorded the wrong figure too.
--
-- Deduct quantity + free_quantity, and record both parts in the movement notes
-- so the ledger explains the number.
CREATE OR REPLACE FUNCTION update_stock_on_sale()
RETURNS TRIGGER AS $$
DECLARE
    v_total      INTEGER := NEW.quantity + COALESCE(NEW.free_quantity, 0);
    v_remaining  INTEGER;
BEGIN
    UPDATE batches
    SET stock_quantity = stock_quantity - v_total
    WHERE id = NEW.batch_id
    RETURNING stock_quantity INTO v_remaining;

    IF v_remaining IS NULL THEN
        RAISE EXCEPTION 'Batch % not found for sale item', NEW.batch_id;
    END IF;

    IF v_remaining < 0 THEN
        RAISE EXCEPTION
            'Insufficient stock for batch %: need % (incl. % free), short by %',
            NEW.batch_id, v_total, COALESCE(NEW.free_quantity, 0), abs(v_remaining);
    END IF;

    INSERT INTO stock_movements (
        tenant_id, product_id, batch_id, branch_id, movement_type,
        quantity, reference_id, notes, created_by
    )
    SELECT
        s.tenant_id, NEW.product_id, NEW.batch_id, s.branch_id, 'sale',
        -v_total, NEW.sale_id,
        'Sale invoice: ' || s.invoice_number ||
          CASE WHEN COALESCE(NEW.free_quantity, 0) > 0
               THEN format(' (%s billed + %s free)', NEW.quantity, NEW.free_quantity)
               ELSE '' END,
        s.created_by
    FROM sales s
    WHERE s.id = NEW.sale_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_stock_on_sale ON sale_items;
CREATE TRIGGER trigger_update_stock_on_sale
    AFTER INSERT ON sale_items
    FOR EACH ROW EXECUTE FUNCTION update_stock_on_sale();

COMMENT ON FUNCTION update_stock_on_sale() IS
    'Deducts billed + free quantity from batch stock and records the movement';
