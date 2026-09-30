-- =====================================================
-- Product master completeness + pharmacist PIN alignment
-- =====================================================
-- Adds the product master fields the billing UI collects but 001 never stored,
-- so no UI field exists without a column behind it:
--
--   products.is_chronic            chronic / long-term medication flag
--   products.dose_type             app-side DoseType enum name
--   products.packaging_units_per_strip / packaging_strips_per_box
--                                  flexible pack config (10x10, 10x15, 100ml…)
--   products.default_mrp / default_ptr / default_selling_price /
--   products.default_wholesale_price / default_purchase_price
--                                  catalogue-level defaults; per-batch prices in
--                                  `batches` stay authoritative for billing
--
-- Also aligns the pharmacists table with PharmacistModel, which serialises the
-- hash under `pharmacist_pin_hash` while 007 created `pin_hash`.
--
-- Idempotent: all adds are guarded, safe to re-run.
-- =====================================================

-- ── 1. Product master fields ─────────────────────────────────────────────────
DO $$
DECLARE
    col RECORD;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = 'public' AND table_name = 'products') THEN
        RAISE NOTICE '[008] products table absent; run 001 first';
        RETURN;
    END IF;

    FOR col IN
        SELECT * FROM (VALUES
            ('is_chronic',                 'BOOLEAN DEFAULT false'),
            ('dose_type',                  'VARCHAR(30) DEFAULT ''tablet'''),
            ('packaging_units_per_strip',  'INTEGER'),
            ('packaging_strips_per_box',   'INTEGER DEFAULT 1'),
            ('packaging_label',            'VARCHAR(50)'),
            ('default_purchase_price',     'DECIMAL(15, 2)'),
            ('default_ptr',                'DECIMAL(15, 2)'),
            ('default_mrp',                'DECIMAL(15, 2)'),
            ('default_selling_price',      'DECIMAL(15, 2)'),
            ('default_wholesale_price',    'DECIMAL(15, 2)')
        ) AS v(name, definition)
    LOOP
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                       WHERE table_schema = 'public'
                         AND table_name = 'products'
                         AND column_name = col.name) THEN
            EXECUTE format('ALTER TABLE products ADD COLUMN %I %s',
                           col.name, col.definition);
            RAISE NOTICE '[008] products.% added', col.name;
        END IF;
    END LOOP;
END $$;

-- 001 constrains dosage_form to a fixed list that omits 'patch' and
-- 'suppository', both of which DoseType offers. Widen it so the app cannot write
-- a value the constraint rejects.
DO $$
DECLARE
    con_name TEXT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = 'products'
                     AND column_name = 'dosage_form') THEN
        RETURN;
    END IF;

    SELECT conname INTO con_name
    FROM pg_constraint
    WHERE conrelid = 'public.products'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%dosage_form%'
    LIMIT 1;

    IF con_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE products DROP CONSTRAINT %I', con_name);
    END IF;

    ALTER TABLE products ADD CONSTRAINT products_dosage_form_check
        CHECK (dosage_form IS NULL OR dosage_form IN (
            'tablet', 'capsule', 'syrup', 'injection', 'cream', 'ointment',
            'drops', 'gel', 'powder', 'lotion', 'suspension', 'inhaler',
            'spray', 'patch', 'suppository', 'other'
        ));
    RAISE NOTICE '[008] products.dosage_form constraint widened';
END $$;

-- packaging_type likewise needs 'blister' and 'unit' for flexible pack configs.
DO $$
DECLARE
    con_name TEXT;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = 'products'
                     AND column_name = 'packaging_type') THEN
        RETURN;
    END IF;

    SELECT conname INTO con_name
    FROM pg_constraint
    WHERE conrelid = 'public.products'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%packaging_type%'
    LIMIT 1;

    IF con_name IS NOT NULL THEN
        EXECUTE format('ALTER TABLE products DROP CONSTRAINT %I', con_name);
    END IF;

    ALTER TABLE products ADD CONSTRAINT products_packaging_type_check
        CHECK (packaging_type IS NULL OR packaging_type IN (
            'strip', 'blister', 'bottle', 'vial', 'box', 'tube', 'sachet',
            'ampoule', 'pen', 'jar', 'unit', 'other'
        ));
    RAISE NOTICE '[008] products.packaging_type constraint widened';
END $$;

-- ── 2. Pharmacist PIN column alignment ───────────────────────────────────────
-- PharmacistModel.toJson writes `pharmacist_pin_hash`; 007 created `pin_hash`.
-- Add the model's column name and keep both in step, so neither the Dart model
-- nor any existing SQL breaks.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema = 'public' AND table_name = 'pharmacists') THEN
        RAISE NOTICE '[008] pharmacists table absent; run 007 first';
        RETURN;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = 'pharmacists'
                     AND column_name = 'pharmacist_pin_hash') THEN
        ALTER TABLE pharmacists ADD COLUMN pharmacist_pin_hash VARCHAR(255);
        UPDATE pharmacists SET pharmacist_pin_hash = pin_hash
        WHERE pin_hash IS NOT NULL AND pharmacist_pin_hash IS NULL;
        RAISE NOTICE '[008] pharmacists.pharmacist_pin_hash added and seeded';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = 'public' AND table_name = 'pharmacists'
                     AND column_name = 'role') THEN
        ALTER TABLE pharmacists ADD COLUMN role VARCHAR(30) DEFAULT 'pharmacist';
    END IF;
END $$;

-- Keep pin_hash and pharmacist_pin_hash consistent regardless of which name the
-- writer used, so PIN verification cannot read a stale hash.
CREATE OR REPLACE FUNCTION sync_pharmacist_pin_hash()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.pharmacist_pin_hash IS DISTINCT FROM OLD.pharmacist_pin_hash
       AND NEW.pharmacist_pin_hash IS NOT NULL THEN
        NEW.pin_hash := NEW.pharmacist_pin_hash;
    ELSIF NEW.pin_hash IS DISTINCT FROM OLD.pin_hash
       AND NEW.pin_hash IS NOT NULL THEN
        NEW.pharmacist_pin_hash := NEW.pin_hash;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = 'public' AND table_name = 'pharmacists') THEN
        DROP TRIGGER IF EXISTS trg_sync_pharmacist_pin_hash ON pharmacists;
CREATE TRIGGER trg_sync_pharmacist_pin_hash
    BEFORE INSERT OR UPDATE ON pharmacists
        FOR EACH ROW EXECUTE FUNCTION sync_pharmacist_pin_hash();
    END IF;
END $$;

-- ── 3. Indexes for the new lookup paths ──────────────────────────────────────
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public' AND table_name = 'products'
                 AND column_name = 'is_chronic') THEN
        CREATE INDEX IF NOT EXISTS idx_products_tenant_chronic
            ON products(tenant_id, is_chronic) WHERE is_chronic = true;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'public' AND table_name = 'products'
                 AND column_name = 'barcode') THEN
        -- Barcode scanning looks up by tenant + barcode on every scan.
        CREATE INDEX IF NOT EXISTS idx_products_tenant_barcode
            ON products(tenant_id, barcode) WHERE barcode IS NOT NULL;
    END IF;
END $$;

COMMENT ON COLUMN products.is_chronic IS 'Chronic / long-term medication flag';
COMMENT ON COLUMN products.default_ptr IS 'Catalogue default PTR; per-batch ptr_price is authoritative for billing';
