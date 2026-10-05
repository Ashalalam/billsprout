-- =====================================================
-- BillSprout - Dynamic Medicine Packaging & Loose-Unit Sales Support
-- =====================================================
-- This migration enables selling medicines as individual tablets, partial strips,
-- complete strips, or combinations while maintaining existing pack-based functionality
-- 
-- Features:
-- 1. Fixes free_quantity stock deduction bug
-- 2. Adds loose-unit support fields to products and batches
-- 3. Adds compound quantity tracking to sale_items and purchase_items
-- 4. Updates triggers for loose-unit stock deduction
-- 5. Preserves all existing functionality and data
-- =====================================================

-- =====================================================
-- PART 1: FIX CRITICAL BUG - Free Quantity Stock Deduction
-- =====================================================
-- The existing update_stock_on_sale trigger only deducts NEW.quantity
-- but should deduct NEW.quantity + NEW.free_quantity to match client-side behavior

CREATE OR REPLACE FUNCTION update_stock_on_sale()
RETURNS TRIGGER AS $$
DECLARE
    v_total_deduction INTEGER;
BEGIN
    -- Calculate total quantity to deduct (paid + free)
    v_total_deduction := NEW.quantity + COALESCE(NEW.free_quantity, 0);
    
    -- Decrease stock quantity in batches table
    UPDATE batches
    SET stock_quantity = stock_quantity - v_total_deduction
    WHERE id = NEW.batch_id;
    
    -- Check if stock went negative (should not happen with proper validation)
    IF (SELECT stock_quantity FROM batches WHERE id = NEW.batch_id) < 0 THEN
        RAISE EXCEPTION 'Insufficient stock for batch % (tried to deduct % units)', 
                        NEW.batch_id, v_total_deduction;
    END IF;
    
    -- Create stock movement record with total quantity
    INSERT INTO stock_movements (
        tenant_id,
        product_id,
        batch_id,
        branch_id,
        movement_type,
        quantity,
        reference_id,
        notes,
        created_by
    )
    SELECT 
        s.tenant_id,
        NEW.product_id,
        NEW.batch_id,
        s.branch_id,
        'sale',
        -v_total_deduction,  -- Negative for stock reduction
        NEW.sale_id,
        'Sale invoice: ' || s.invoice_number || 
        CASE WHEN NEW.free_quantity > 0 
             THEN ' (includes ' || NEW.free_quantity || ' free)' 
             ELSE '' 
        END,
        s.created_by
    FROM sales s
    WHERE s.id = NEW.sale_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_stock_on_sale() IS 
    'Decreases stock (including free qty) and creates stock movement record when sale is made';

-- =====================================================
-- PART 2: ADD LOOSE-UNIT SUPPORT FIELDS TO PRODUCTS
-- =====================================================
-- These fields control whether and how a medicine can be sold in loose units

DO $$
BEGIN
    -- Allow loose sales flag (default based on dose type)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'products' AND column_name = 'allow_loose_sales') THEN
        ALTER TABLE products ADD COLUMN allow_loose_sales BOOLEAN DEFAULT false;
        RAISE NOTICE '[021] Added products.allow_loose_sales';
    END IF;
    
    -- Minimum sale unit (strip, tablet, capsule, ml, unit, pack)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'products' AND column_name = 'min_sale_unit') THEN
        ALTER TABLE products ADD COLUMN min_sale_unit VARCHAR(20) DEFAULT 'strip';
        RAISE NOTICE '[021] Added products.min_sale_unit';
    END IF;
    
    -- Base unit for inventory tracking (tablet, capsule, ml, gm, unit)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'products' AND column_name = 'base_unit') THEN
        ALTER TABLE products ADD COLUMN base_unit VARCHAR(20) DEFAULT 'tablet';
        RAISE NOTICE '[021] Added products.base_unit';
    END IF;
    
    -- Per-unit selling price (for loose sales)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'products' AND column_name = 'price_per_base_unit') THEN
        ALTER TABLE products ADD COLUMN price_per_base_unit DECIMAL(10, 2);
        RAISE NOTICE '[021] Added products.price_per_base_unit';
    END IF;
    
    -- Total base units per pack (for conversion calculations)
    -- This is the authoritative conversion value (not derived from packaging label)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'products' AND column_name = 'base_units_per_pack') THEN
        ALTER TABLE products ADD COLUMN base_units_per_pack INTEGER DEFAULT 10;
        RAISE NOTICE '[021] Added products.base_units_per_pack';
    END IF;
END $$;

-- Add check constraint for valid min_sale_unit values
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint 
                   WHERE conname = 'products_min_sale_unit_check') THEN
        ALTER TABLE products ADD CONSTRAINT products_min_sale_unit_check 
            CHECK (min_sale_unit IN ('strip', 'tablet', 'capsule', 'ml', 'gm', 'unit', 'pack', 'bottle', 'vial'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_constraint 
                   WHERE conname = 'products_base_unit_check') THEN
        ALTER TABLE products ADD CONSTRAINT products_base_unit_check 
            CHECK (base_unit IN ('tablet', 'capsule', 'ml', 'gm', 'unit', 'dose'));
    END IF;
END $$;

-- =====================================================
-- PART 3: ADD LOOSE-UNIT TRACKING TO BATCHES
-- =====================================================
-- Track opened packs (loose units available for sale)

DO $$
BEGIN
    -- Loose units available (tablets from opened strips, ml from opened bottles, etc.)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'batches' AND column_name = 'loose_units') THEN
        ALTER TABLE batches ADD COLUMN loose_units INTEGER DEFAULT 0;
        RAISE NOTICE '[021] Added batches.loose_units';
    END IF;
    
    -- Add check constraint: loose units cannot be negative
    IF NOT EXISTS (SELECT 1 FROM pg_constraint 
                   WHERE conname = 'batches_loose_units_check') THEN
        ALTER TABLE batches ADD CONSTRAINT batches_loose_units_check 
            CHECK (loose_units >= 0);
    END IF;
END $$;

-- =====================================================
-- PART 4: ADD COMPOUND QUANTITY FIELDS TO SALE_ITEMS
-- =====================================================
-- Track both pack quantity and loose quantity for each sale line

DO $$
BEGIN
    -- Selling unit used (strip, tablet, capsule, ml, etc.)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'sale_items' AND column_name = 'selling_unit') THEN
        ALTER TABLE sale_items ADD COLUMN selling_unit VARCHAR(20) DEFAULT 'strip';
        RAISE NOTICE '[021] Added sale_items.selling_unit';
    END IF;
    
    -- Number of loose units sold (tablets, capsules, ml, etc.)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'sale_items' AND column_name = 'loose_units_sold') THEN
        ALTER TABLE sale_items ADD COLUMN loose_units_sold INTEGER DEFAULT 0;
        RAISE NOTICE '[021] Added sale_items.loose_units_sold';
    END IF;
    
    -- Number of complete packs opened to fulfill loose units
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'sale_items' AND column_name = 'packs_opened') THEN
        ALTER TABLE sale_items ADD COLUMN packs_opened INTEGER DEFAULT 0;
        RAISE NOTICE '[021] Added sale_items.packs_opened';
    END IF;
    
    -- Price per base unit (for loose sales)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'sale_items' AND column_name = 'price_per_unit') THEN
        ALTER TABLE sale_items ADD COLUMN price_per_unit DECIMAL(10, 2);
        RAISE NOTICE '[021] Added sale_items.price_per_unit';
    END IF;
END $$;

-- =====================================================
-- PART 5: UPDATE STOCK DEDUCTION LOGIC FOR LOOSE UNITS
-- =====================================================
-- New trigger function that handles both pack and loose-unit sales

CREATE OR REPLACE FUNCTION update_stock_on_sale_with_loose_units()
RETURNS TRIGGER AS $$
DECLARE
    v_total_deduction INTEGER;
    v_loose_deduction INTEGER;
    v_pack_deduction INTEGER;
    v_base_units_per_pack INTEGER;
    v_current_loose_units INTEGER;
    v_packs_to_open INTEGER;
    v_remaining_loose INTEGER;
BEGIN
    -- Get product configuration
    SELECT base_units_per_pack INTO v_base_units_per_pack
    FROM products WHERE id = NEW.product_id;
    
    -- Default to 10 if not configured
    v_base_units_per_pack := COALESCE(v_base_units_per_pack, 10);
    
    -- Calculate deductions
    v_pack_deduction := NEW.quantity + COALESCE(NEW.free_quantity, 0);
    v_loose_deduction := COALESCE(NEW.loose_units_sold, 0);
    
    -- Get current loose units available in batch
    SELECT loose_units INTO v_current_loose_units
    FROM batches WHERE id = NEW.batch_id;
    
    v_current_loose_units := COALESCE(v_current_loose_units, 0);
    
    -- Calculate how many packs need to be opened for loose sales
    IF v_loose_deduction > v_current_loose_units THEN
        -- Need to open packs
        v_packs_to_open := CEIL((v_loose_deduction - v_current_loose_units)::NUMERIC / v_base_units_per_pack);
        v_remaining_loose := (v_packs_to_open * v_base_units_per_pack) - 
                            (v_loose_deduction - v_current_loose_units);
        
        -- Update batch: decrease packs, adjust loose units
        UPDATE batches
        SET stock_quantity = stock_quantity - v_pack_deduction - v_packs_to_open,
            loose_units = v_remaining_loose
        WHERE id = NEW.batch_id;
    ELSE
        -- Sufficient loose units available
        UPDATE batches
        SET stock_quantity = stock_quantity - v_pack_deduction,
            loose_units = loose_units - v_loose_deduction
        WHERE id = NEW.batch_id;
        
        v_packs_to_open := 0;
    END IF;
    
    -- Check for negative stock
    IF (SELECT stock_quantity FROM batches WHERE id = NEW.batch_id) < 0 THEN
        RAISE EXCEPTION 'Insufficient pack stock for batch % (tried to deduct % packs + % loose units)', 
                        NEW.batch_id, v_pack_deduction, v_loose_deduction;
    END IF;
    
    IF (SELECT loose_units FROM batches WHERE id = NEW.batch_id) < 0 THEN
        RAISE EXCEPTION 'Insufficient loose units for batch % (tried to deduct % loose units)', 
                        NEW.batch_id, v_loose_deduction;
    END IF;
    
    -- Update sale_items with packs_opened count
    IF v_packs_to_open > 0 THEN
        UPDATE sale_items SET packs_opened = v_packs_to_open WHERE id = NEW.id;
    END IF;
    
    -- Create stock movement record
    v_total_deduction := v_pack_deduction + v_packs_to_open;
    
    INSERT INTO stock_movements (
        tenant_id,
        product_id,
        batch_id,
        branch_id,
        movement_type,
        quantity,
        reference_id,
        notes,
        created_by
    )
    SELECT 
        s.tenant_id,
        NEW.product_id,
        NEW.batch_id,
        s.branch_id,
        'sale',
        -v_total_deduction,
        NEW.sale_id,
        'Sale invoice: ' || s.invoice_number || 
        CASE 
            WHEN NEW.free_quantity > 0 AND v_loose_deduction > 0 
                THEN ' (' || v_pack_deduction || ' packs + ' || v_loose_deduction || ' loose, ' || 
                     NEW.free_quantity || ' free)'
            WHEN NEW.free_quantity > 0 
                THEN ' (includes ' || NEW.free_quantity || ' free)'
            WHEN v_loose_deduction > 0 
                THEN ' (' || v_pack_deduction || ' packs + ' || v_loose_deduction || ' loose)'
            ELSE ''
        END,
        s.created_by
    FROM sales s
    WHERE s.id = NEW.sale_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Replace the trigger to use new function
DROP TRIGGER IF EXISTS trigger_update_stock_on_sale ON sale_items;
CREATE TRIGGER trigger_update_stock_on_sale
    AFTER INSERT ON sale_items
    FOR EACH ROW
    EXECUTE FUNCTION update_stock_on_sale_with_loose_units();

COMMENT ON FUNCTION update_stock_on_sale_with_loose_units() IS 
    'Handles stock deduction for pack sales, loose-unit sales, and mixed sales with automatic pack opening';

-- =====================================================
-- PART 6: ADD LOOSE UNITS TO PURCHASE_ITEMS (OPTIONAL)
-- =====================================================
-- For recording loose units received (damaged boxes, promotional samples, etc.)

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'purchase_items' AND column_name = 'loose_units_received') THEN
        ALTER TABLE purchase_items ADD COLUMN loose_units_received INTEGER DEFAULT 0;
        RAISE NOTICE '[021] Added purchase_items.loose_units_received';
    END IF;
END $$;

-- Update purchase trigger to handle loose units received
CREATE OR REPLACE FUNCTION update_stock_on_purchase()
RETURNS TRIGGER AS $$
DECLARE
    v_batch_id UUID;
    v_tenant_id UUID;
    v_branch_id UUID;
    v_loose_received INTEGER;
BEGIN
    -- Get tenant_id and branch_id from purchase
    SELECT tenant_id, branch_id INTO v_tenant_id, v_branch_id
    FROM purchases WHERE id = NEW.purchase_id;
    
    v_loose_received := COALESCE(NEW.loose_units_received, 0);
    
    -- Check if batch already exists
    SELECT id INTO v_batch_id
    FROM batches
    WHERE product_id = NEW.product_id
      AND batch_number = NEW.batch_number
      AND branch_id = v_branch_id;
    
    IF v_batch_id IS NULL THEN
        -- Create new batch
        INSERT INTO batches (
            product_id,
            tenant_id,
            branch_id,
            batch_number,
            mfg_date,
            exp_date,
            purchase_price,
            ptr_price,
            mrp,
            selling_price,
            wholesale_price,
            stock_quantity,
            free_quantity,
            loose_units,
            supplier_id
        )
        SELECT 
            NEW.product_id,
            v_tenant_id,
            v_branch_id,
            NEW.batch_number,
            NEW.mfg_date,
            NEW.exp_date,
            NEW.purchase_price,
            NEW.ptr_price,
            NEW.mrp,
            NEW.mrp, -- Default selling price = MRP
            NEW.ptr_price, -- Default wholesale price = PTR
            NEW.quantity + NEW.free_quantity,
            NEW.free_quantity,
            v_loose_received,
            p.supplier_id
        FROM purchases p
        WHERE p.id = NEW.purchase_id
        RETURNING id INTO v_batch_id;
        
        -- Update purchase_items with the new batch_id
        UPDATE purchase_items SET batch_id = v_batch_id WHERE id = NEW.id;
    ELSE
        -- Update existing batch
        UPDATE batches
        SET 
            stock_quantity = stock_quantity + NEW.quantity + NEW.free_quantity,
            free_quantity = free_quantity + NEW.free_quantity,
            loose_units = loose_units + v_loose_received,
            purchase_price = NEW.purchase_price,
            ptr_price = COALESCE(NEW.ptr_price, ptr_price),
            mrp = NEW.mrp,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_batch_id;
        
        -- Update purchase_items with the existing batch_id
        UPDATE purchase_items SET batch_id = v_batch_id WHERE id = NEW.id;
    END IF;
    
    -- Create stock movement record
    INSERT INTO stock_movements (
        tenant_id,
        product_id,
        batch_id,
        branch_id,
        movement_type,
        quantity,
        reference_id,
        notes,
        created_by
    )
    SELECT 
        p.tenant_id,
        NEW.product_id,
        v_batch_id,
        p.branch_id,
        'purchase',
        NEW.quantity + NEW.free_quantity,
        NEW.purchase_id,
        'Purchase invoice: ' || p.purchase_number ||
        CASE WHEN v_loose_received > 0 
             THEN ' (includes ' || v_loose_received || ' loose units)' 
             ELSE '' 
        END,
        p.created_by
    FROM purchases p
    WHERE p.id = NEW.purchase_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_stock_on_purchase() IS 
    'Increases stock (packs and loose units) and creates stock movement record when purchase is made';

-- =====================================================
-- PART 7: BACKFILL DEFAULTS FOR EXISTING PRODUCTS
-- =====================================================
-- Set intelligent defaults based on dose type for existing medicines

DO $$
BEGIN
    -- Enable loose sales for tablets and capsules by default
    UPDATE products
    SET allow_loose_sales = true,
        min_sale_unit = 'tablet',
        base_unit = 'tablet',
        base_units_per_pack = COALESCE(packaging_units_per_strip, 10)
    WHERE dosage_form IN ('tablet', 'capsule')
      AND allow_loose_sales IS NULL;
    
    -- Capsules
    UPDATE products
    SET base_unit = 'capsule',
        min_sale_unit = 'capsule'
    WHERE dosage_form = 'capsule'
      AND allow_loose_sales = true;
    
    -- Syrups and drops (liquids - no loose sales)
    UPDATE products
    SET allow_loose_sales = false,
        min_sale_unit = 'bottle',
        base_unit = 'ml',
        base_units_per_pack = COALESCE(packaging_units_per_strip, 60)
    WHERE dosage_form IN ('syrup', 'drops', 'suspension')
      AND allow_loose_sales IS NULL;
    
    -- Injections
    UPDATE products
    SET allow_loose_sales = false,
        min_sale_unit = 'vial',
        base_unit = 'ml',
        base_units_per_pack = COALESCE(packaging_units_per_strip, 1)
    WHERE dosage_form = 'injection'
      AND allow_loose_sales IS NULL;
    
    -- Creams, ointments, gels (no loose sales)
    UPDATE products
    SET allow_loose_sales = false,
        min_sale_unit = 'tube',
        base_unit = 'gm',
        base_units_per_pack = 1
    WHERE dosage_form IN ('cream', 'ointment', 'gel', 'lotion')
      AND allow_loose_sales IS NULL;
    
    -- Powders, sachets
    UPDATE products
    SET allow_loose_sales = false,
        min_sale_unit = 'sachet',
        base_unit = 'unit',
        base_units_per_pack = 1
    WHERE dosage_form = 'powder'
      AND allow_loose_sales IS NULL;
    
    -- Inhalers, patches, suppositories (unit-based, no loose sales)
    UPDATE products
    SET allow_loose_sales = false,
        min_sale_unit = 'unit',
        base_unit = 'unit',
        base_units_per_pack = 1
    WHERE dosage_form IN ('inhaler', 'spray', 'patch', 'suppository')
      AND allow_loose_sales IS NULL;
    
    -- Any remaining products (default to strip/unit)
    UPDATE products
    SET allow_loose_sales = false,
        min_sale_unit = 'unit',
        base_unit = 'unit',
        base_units_per_pack = COALESCE(packaging_units_per_strip, 1)
    WHERE allow_loose_sales IS NULL;
    
    RAISE NOTICE '[021] Backfilled loose-unit defaults for existing products based on dosage_form';
END $$;

-- =====================================================
-- PART 8: HELPER FUNCTIONS FOR UNIT CONVERSION
-- =====================================================

-- Function to calculate total available units (for stock validation)
CREATE OR REPLACE FUNCTION get_total_available_units(
    p_batch_id UUID
)
RETURNS INTEGER AS $$
DECLARE
    v_pack_stock INTEGER;
    v_loose_units INTEGER;
    v_units_per_pack INTEGER;
    v_total_units INTEGER;
BEGIN
    SELECT 
        b.stock_quantity,
        b.loose_units,
        COALESCE(p.base_units_per_pack, 10)
    INTO v_pack_stock, v_loose_units, v_units_per_pack
    FROM batches b
    JOIN products p ON b.product_id = p.id
    WHERE b.id = p_batch_id;
    
    v_pack_stock := COALESCE(v_pack_stock, 0);
    v_loose_units := COALESCE(v_loose_units, 0);
    
    v_total_units := (v_pack_stock * v_units_per_pack) + v_loose_units;
    
    RETURN v_total_units;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_total_available_units(UUID) IS 
    'Calculates total available units (packs converted to units + loose units) for a batch';

-- Function to format stock display (e.g., "8 strips + 5 tablets")
CREATE OR REPLACE FUNCTION format_stock_display(
    p_batch_id UUID
)
RETURNS TEXT AS $$
DECLARE
    v_pack_stock INTEGER;
    v_loose_units INTEGER;
    v_pack_label TEXT;
    v_unit_label TEXT;
    v_result TEXT;
BEGIN
    SELECT 
        b.stock_quantity,
        b.loose_units,
        COALESCE(p.packaging_type, 'strip'),
        COALESCE(p.base_unit, 'unit')
    INTO v_pack_stock, v_loose_units, v_pack_label, v_unit_label
    FROM batches b
    JOIN products p ON b.product_id = p.id
    WHERE b.id = p_batch_id;
    
    v_pack_stock := COALESCE(v_pack_stock, 0);
    v_loose_units := COALESCE(v_loose_units, 0);
    
    IF v_pack_stock > 0 AND v_loose_units > 0 THEN
        v_result := v_pack_stock || ' ' || v_pack_label || 
                   CASE WHEN v_pack_stock > 1 THEN 's' ELSE '' END ||
                   ' + ' || v_loose_units || ' ' || v_unit_label ||
                   CASE WHEN v_loose_units > 1 AND v_unit_label IN ('tablet', 'capsule') 
                        THEN 's' ELSE '' END;
    ELSIF v_pack_stock > 0 THEN
        v_result := v_pack_stock || ' ' || v_pack_label ||
                   CASE WHEN v_pack_stock > 1 THEN 's' ELSE '' END;
    ELSIF v_loose_units > 0 THEN
        v_result := v_loose_units || ' ' || v_unit_label ||
                   CASE WHEN v_loose_units > 1 AND v_unit_label IN ('tablet', 'capsule') 
                        THEN 's' ELSE '' END;
    ELSE
        v_result := 'Out of stock';
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION format_stock_display(UUID) IS 
    'Returns formatted stock display like "8 strips + 5 tablets" or "60 ml"';

-- =====================================================
-- PART 9: INDEXES FOR PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_products_loose_sales 
    ON products(tenant_id, allow_loose_sales) 
    WHERE allow_loose_sales = true;

CREATE INDEX IF NOT EXISTS idx_batches_loose_units 
    ON batches(product_id, branch_id, loose_units) 
    WHERE loose_units > 0;

CREATE INDEX IF NOT EXISTS idx_sale_items_loose_units 
    ON sale_items(product_id, selling_unit) 
    WHERE loose_units_sold > 0;

-- =====================================================
-- PART 10: COMMENTS AND DOCUMENTATION
-- =====================================================

COMMENT ON COLUMN products.allow_loose_sales IS 
    'Whether this product can be sold in individual units (tablets, capsules, ml) rather than complete packs';
    
COMMENT ON COLUMN products.min_sale_unit IS 
    'Minimum unit in which this product can be sold (strip, tablet, capsule, ml, unit, bottle, vial)';
    
COMMENT ON COLUMN products.base_unit IS 
    'Base unit for inventory tracking (tablet, capsule, ml, gm, unit, dose)';
    
COMMENT ON COLUMN products.price_per_base_unit IS 
    'Selling price per base unit for loose sales (e.g., price per tablet)';
    
COMMENT ON COLUMN products.base_units_per_pack IS 
    'Total base units in one pack - authoritative conversion value (e.g., 10 tablets per strip, 60ml per bottle)';
    
COMMENT ON COLUMN batches.loose_units IS 
    'Number of loose units available (tablets from opened strips, ml from opened bottles, etc.)';
    
COMMENT ON COLUMN sale_items.selling_unit IS 
    'Unit used for this sale line (strip, tablet, capsule, ml, bottle, vial, unit)';
    
COMMENT ON COLUMN sale_items.loose_units_sold IS 
    'Number of loose units sold (tablets, capsules, ml, etc.) separate from complete packs';
    
COMMENT ON COLUMN sale_items.packs_opened IS 
    'Number of complete packs that were opened to fulfill loose-unit requirement';
    
COMMENT ON COLUMN sale_items.price_per_unit IS 
    'Price per base unit for this sale (calculated from pack price or configured per-unit price)';
    
COMMENT ON COLUMN purchase_items.loose_units_received IS 
    'Number of loose units received (from damaged boxes, promotional samples, etc.)';

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================
-- This migration adds comprehensive loose-unit sales support while:
-- ✅ Fixing the free_quantity stock deduction bug
-- ✅ Preserving all existing data and functionality
-- ✅ Using additive, backward-compatible changes
-- ✅ Providing intelligent defaults based on product type
-- ✅ Enabling flexible unit-based billing for tablets/capsules
-- ✅ Maintaining strict stock validation
-- ✅ Creating proper audit trails
-- =====================================================
