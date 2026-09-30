-- =====================================================
-- BillSprout/LifeSprout ERP - Functions and Triggers
-- =====================================================
-- This migration creates database functions and triggers for automation
-- Created: 2024
-- Description: Triggers for updated_at, stock management, and reporting functions

-- =====================================================
-- 1. UPDATED_AT TIMESTAMP TRIGGER FUNCTION
-- =====================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to all relevant tables
DROP TRIGGER IF EXISTS set_updated_at_tenants ON tenants;
CREATE TRIGGER set_updated_at_tenants
    BEFORE UPDATE ON tenants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_updated_at_branches ON branches;
CREATE TRIGGER set_updated_at_branches
    BEFORE UPDATE ON branches
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_updated_at_users ON users;
CREATE TRIGGER set_updated_at_users
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_updated_at_suppliers ON suppliers;
CREATE TRIGGER set_updated_at_suppliers
    BEFORE UPDATE ON suppliers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_updated_at_customers ON customers;
CREATE TRIGGER set_updated_at_customers
    BEFORE UPDATE ON customers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_updated_at_products ON products;
CREATE TRIGGER set_updated_at_products
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_updated_at_batches ON batches;
CREATE TRIGGER set_updated_at_batches
    BEFORE UPDATE ON batches
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_updated_at_sales ON sales;
CREATE TRIGGER set_updated_at_sales
    BEFORE UPDATE ON sales
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_updated_at_purchases ON purchases;
CREATE TRIGGER set_updated_at_purchases
    BEFORE UPDATE ON purchases
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_updated_at_stock_transfers ON stock_transfers;
CREATE TRIGGER set_updated_at_stock_transfers
    BEFORE UPDATE ON stock_transfers
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 2. STOCK MANAGEMENT - SALE TRIGGERS
-- =====================================================
-- Function to update stock on sale item insert
CREATE OR REPLACE FUNCTION update_stock_on_sale()
RETURNS TRIGGER AS $$
BEGIN
    -- Decrease stock quantity in batches table
    UPDATE batches
    SET stock_quantity = stock_quantity - NEW.quantity
    WHERE id = NEW.batch_id;
    
    -- Check if stock went negative (should not happen with proper validation)
    IF (SELECT stock_quantity FROM batches WHERE id = NEW.batch_id) < 0 THEN
        RAISE EXCEPTION 'Insufficient stock for batch %', NEW.batch_id;
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
        s.tenant_id,
        NEW.product_id,
        NEW.batch_id,
        s.branch_id,
        'sale',
        -NEW.quantity,
        NEW.sale_id,
        'Sale invoice: ' || s.invoice_number,
        s.created_by
    FROM sales s
    WHERE s.id = NEW.sale_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_stock_on_sale ON sale_items;
CREATE TRIGGER trigger_update_stock_on_sale
    AFTER INSERT ON sale_items
    FOR EACH ROW
    EXECUTE FUNCTION update_stock_on_sale();

-- =====================================================
-- 3. STOCK MANAGEMENT - PURCHASE TRIGGERS
-- =====================================================
-- Function to update/create stock on purchase item insert
CREATE OR REPLACE FUNCTION update_stock_on_purchase()
RETURNS TRIGGER AS $$
DECLARE
    v_batch_id UUID;
    v_tenant_id UUID;
    v_branch_id UUID;
BEGIN
    -- Get tenant_id and branch_id from purchase
    SELECT tenant_id, branch_id INTO v_tenant_id, v_branch_id
    FROM purchases WHERE id = NEW.purchase_id;
    
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
        'Purchase invoice: ' || p.purchase_number,
        p.created_by
    FROM purchases p
    WHERE p.id = NEW.purchase_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_stock_on_purchase ON purchase_items;
CREATE TRIGGER trigger_update_stock_on_purchase
    AFTER INSERT ON purchase_items
    FOR EACH ROW
    EXECUTE FUNCTION update_stock_on_purchase();

-- =====================================================
-- 4. RESTRICTED DRUG LOG TRIGGER
-- =====================================================
-- Function to automatically log Schedule H/H1/Narcotic sales
CREATE OR REPLACE FUNCTION log_restricted_drug_sale()
RETURNS TRIGGER AS $$
DECLARE
    v_is_restricted BOOLEAN;
    v_product_name VARCHAR(500);
    v_sale_record RECORD;
BEGIN
    -- Check if product is restricted
    SELECT 
        (is_schedule_h OR is_schedule_h1 OR is_narcotic),
        name
    INTO v_is_restricted, v_product_name
    FROM products
    WHERE id = NEW.product_id;
    
    IF v_is_restricted THEN
        -- Get sale information
        SELECT * INTO v_sale_record FROM sales WHERE id = NEW.sale_id;
        
        -- Insert into restricted_drug_logs
        INSERT INTO restricted_drug_logs (
            tenant_id,
            sale_id,
            product_id,
            product_name,
            batch_number,
            quantity,
            customer_name,
            doctor_name,
            doctor_mci_no,
            pharmacist_id,
            prescription_id
        )
        VALUES (
            v_sale_record.tenant_id,
            NEW.sale_id,
            NEW.product_id,
            v_product_name,
            NEW.batch_number,
            NEW.quantity,
            v_sale_record.customer_name,
            v_sale_record.doctor_name,
            v_sale_record.doctor_mci_no,
            v_sale_record.pharmacist_authorized_by,
            v_sale_record.prescription_id
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_log_restricted_drug_sale ON sale_items;
CREATE TRIGGER trigger_log_restricted_drug_sale
    AFTER INSERT ON sale_items
    FOR EACH ROW
    EXECUTE FUNCTION log_restricted_drug_sale();

-- =====================================================
-- 5. STOCK TRANSFER TRIGGERS
-- =====================================================
-- Function to handle stock transfer on status change
CREATE OR REPLACE FUNCTION handle_stock_transfer()
RETURNS TRIGGER AS $$
BEGIN
    -- When transfer is received, update stock
    IF NEW.status = 'received' AND OLD.status != 'received' THEN
        -- Decrease stock from source branch
        UPDATE batches
        SET stock_quantity = stock_quantity - NEW.quantity
        WHERE id = NEW.batch_id
          AND branch_id = NEW.from_branch_id;
        
        -- Check if we have enough stock
        IF (SELECT stock_quantity FROM batches WHERE id = NEW.batch_id AND branch_id = NEW.from_branch_id) < 0 THEN
            RAISE EXCEPTION 'Insufficient stock in source branch for transfer %', NEW.transfer_number;
        END IF;
        
        -- Create or update stock in destination branch
        DECLARE
            v_dest_batch_id UUID;
            v_batch_record RECORD;
        BEGIN
            -- Get batch details
            SELECT * INTO v_batch_record FROM batches WHERE id = NEW.batch_id;
            
            -- Check if batch exists in destination branch
            SELECT id INTO v_dest_batch_id
            FROM batches
            WHERE product_id = NEW.product_id
              AND batch_number = v_batch_record.batch_number
              AND branch_id = NEW.to_branch_id;
            
            IF v_dest_batch_id IS NULL THEN
                -- Create new batch in destination branch
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
                    supplier_id
                )
                VALUES (
                    v_batch_record.product_id,
                    v_batch_record.tenant_id,
                    NEW.to_branch_id,
                    v_batch_record.batch_number,
                    v_batch_record.mfg_date,
                    v_batch_record.exp_date,
                    v_batch_record.purchase_price,
                    v_batch_record.ptr_price,
                    v_batch_record.mrp,
                    v_batch_record.selling_price,
                    v_batch_record.wholesale_price,
                    NEW.quantity,
                    v_batch_record.supplier_id
                );
            ELSE
                -- Update existing batch
                UPDATE batches
                SET stock_quantity = stock_quantity + NEW.quantity
                WHERE id = v_dest_batch_id;
            END IF;
        END;
        
        -- Create stock movement records
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
        VALUES (
            NEW.tenant_id,
            NEW.product_id,
            NEW.batch_id,
            NEW.from_branch_id,
            'transfer_out',
            -NEW.quantity,
            NEW.id,
            'Transfer to branch: ' || NEW.transfer_number,
            NEW.initiated_by
        );
        
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
        VALUES (
            NEW.tenant_id,
            NEW.product_id,
            NEW.batch_id,
            NEW.to_branch_id,
            'transfer_in',
            NEW.quantity,
            NEW.id,
            'Transfer from branch: ' || NEW.transfer_number,
            NEW.received_by
        );
        
        -- Set received_at timestamp
        NEW.received_at = CURRENT_TIMESTAMP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_handle_stock_transfer ON stock_transfers;
CREATE TRIGGER trigger_handle_stock_transfer
    BEFORE UPDATE ON stock_transfers
    FOR EACH ROW
    EXECUTE FUNCTION handle_stock_transfer();

-- =====================================================
-- 6. REPORTING FUNCTIONS
-- =====================================================

-- Function to get near-expiry items (expiring within N days)
CREATE OR REPLACE FUNCTION get_near_expiry_items(
    p_tenant_id UUID,
    p_branch_id UUID DEFAULT NULL,
    p_days_threshold INTEGER DEFAULT 90
)
RETURNS TABLE (
    batch_id UUID,
    product_id UUID,
    product_name VARCHAR,
    batch_number VARCHAR,
    exp_date DATE,
    days_to_expiry INTEGER,
    stock_quantity INTEGER,
    branch_name VARCHAR,
    value_at_cost DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id as batch_id,
        p.id as product_id,
        p.name as product_name,
        b.batch_number,
        b.exp_date,
        (b.exp_date - CURRENT_DATE)::INTEGER as days_to_expiry,
        b.stock_quantity,
        br.branch_name,
        (b.stock_quantity * b.purchase_price) as value_at_cost
    FROM batches b
    JOIN products p ON b.product_id = p.id
    JOIN branches br ON b.branch_id = br.id
    WHERE b.tenant_id = p_tenant_id
      AND (p_branch_id IS NULL OR b.branch_id = p_branch_id)
      AND b.stock_quantity > 0
      AND b.exp_date <= CURRENT_DATE + p_days_threshold
      AND b.exp_date > CURRENT_DATE
    ORDER BY b.exp_date ASC, p.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get low stock items
CREATE OR REPLACE FUNCTION get_low_stock_items(
    p_tenant_id UUID,
    p_branch_id UUID DEFAULT NULL
)
RETURNS TABLE (
    product_id UUID,
    product_name VARCHAR,
    category VARCHAR,
    reorder_level INTEGER,
    current_stock BIGINT,
    branch_name VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as product_id,
        p.name as product_name,
        p.category,
        p.reorder_level,
        COALESCE(SUM(b.stock_quantity), 0) as current_stock,
        br.branch_name
    FROM products p
    JOIN branches br ON br.tenant_id = p.tenant_id
    LEFT JOIN batches b ON b.product_id = p.id AND b.branch_id = br.id
    WHERE p.tenant_id = p_tenant_id
      AND (p_branch_id IS NULL OR br.id = p_branch_id)
    GROUP BY p.id, p.name, p.category, p.reorder_level, br.branch_name
    HAVING COALESCE(SUM(b.stock_quantity), 0) <= p.reorder_level
    ORDER BY current_stock ASC, p.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get expired items
CREATE OR REPLACE FUNCTION get_expired_items(
    p_tenant_id UUID,
    p_branch_id UUID DEFAULT NULL
)
RETURNS TABLE (
    batch_id UUID,
    product_id UUID,
    product_name VARCHAR,
    batch_number VARCHAR,
    exp_date DATE,
    days_expired INTEGER,
    stock_quantity INTEGER,
    branch_name VARCHAR,
    value_at_cost DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        b.id as batch_id,
        p.id as product_id,
        p.name as product_name,
        b.batch_number,
        b.exp_date,
        (CURRENT_DATE - b.exp_date)::INTEGER as days_expired,
        b.stock_quantity,
        br.branch_name,
        (b.stock_quantity * b.purchase_price) as value_at_cost
    FROM batches b
    JOIN products p ON b.product_id = p.id
    JOIN branches br ON b.branch_id = br.id
    WHERE b.tenant_id = p_tenant_id
      AND (p_branch_id IS NULL OR b.branch_id = p_branch_id)
      AND b.stock_quantity > 0
      AND b.exp_date < CURRENT_DATE
    ORDER BY b.exp_date DESC, p.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get sales summary for date range
CREATE OR REPLACE FUNCTION get_sales_summary(
    p_tenant_id UUID,
    p_branch_id UUID DEFAULT NULL,
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS TABLE (
    total_sales BIGINT,
    total_amount DECIMAL,
    total_gst DECIMAL,
    cash_sales DECIMAL,
    card_sales DECIMAL,
    upi_sales DECIMAL,
    credit_sales DECIMAL,
    pending_amount DECIMAL
) AS $$
BEGIN
    -- Default to current month if dates not provided
    p_start_date := COALESCE(p_start_date, date_trunc('month', CURRENT_DATE));
    p_end_date := COALESCE(p_end_date, CURRENT_TIMESTAMP);
    
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT as total_sales,
        COALESCE(SUM(grand_total), 0) as total_amount,
        COALESCE(SUM(total_gst), 0) as total_gst,
        COALESCE(SUM(CASE WHEN payment_mode = 'cash' THEN grand_total ELSE 0 END), 0) as cash_sales,
        COALESCE(SUM(CASE WHEN payment_mode = 'card' THEN grand_total ELSE 0 END), 0) as card_sales,
        COALESCE(SUM(CASE WHEN payment_mode = 'upi' THEN grand_total ELSE 0 END), 0) as upi_sales,
        COALESCE(SUM(CASE WHEN payment_mode = 'credit' THEN grand_total ELSE 0 END), 0) as credit_sales,
        COALESCE(SUM(CASE WHEN payment_status IN ('pending', 'partial') THEN grand_total ELSE 0 END), 0) as pending_amount
    FROM sales
    WHERE tenant_id = p_tenant_id
      AND (p_branch_id IS NULL OR branch_id = p_branch_id)
      AND invoice_date >= p_start_date
      AND invoice_date <= p_end_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get top selling products
CREATE OR REPLACE FUNCTION get_top_selling_products(
    p_tenant_id UUID,
    p_branch_id UUID DEFAULT NULL,
    p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_limit INTEGER DEFAULT 10
)
RETURNS TABLE (
    product_id UUID,
    product_name VARCHAR,
    category VARCHAR,
    total_quantity BIGINT,
    total_sales DECIMAL,
    sale_count BIGINT
) AS $$
BEGIN
    -- Default to current month if dates not provided
    p_start_date := COALESCE(p_start_date, date_trunc('month', CURRENT_DATE));
    p_end_date := COALESCE(p_end_date, CURRENT_TIMESTAMP);
    
    RETURN QUERY
    SELECT 
        p.id as product_id,
        p.name as product_name,
        p.category,
        SUM(si.quantity)::BIGINT as total_quantity,
        SUM(si.line_total) as total_sales,
        COUNT(DISTINCT si.sale_id)::BIGINT as sale_count
    FROM sale_items si
    JOIN products p ON si.product_id = p.id
    JOIN sales s ON si.sale_id = s.id
    WHERE s.tenant_id = p_tenant_id
      AND (p_branch_id IS NULL OR s.branch_id = p_branch_id)
      AND s.invoice_date >= p_start_date
      AND s.invoice_date <= p_end_date
    GROUP BY p.id, p.name, p.category
    ORDER BY total_sales DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON FUNCTION update_updated_at_column() IS 'Automatically updates the updated_at timestamp on row updates';
COMMENT ON FUNCTION update_stock_on_sale() IS 'Decreases stock and creates stock movement record when sale is made';
COMMENT ON FUNCTION update_stock_on_purchase() IS 'Increases stock and creates stock movement record when purchase is made';
COMMENT ON FUNCTION log_restricted_drug_sale() IS 'Automatically logs sales of Schedule H/H1/Narcotic drugs for compliance';
COMMENT ON FUNCTION handle_stock_transfer() IS 'Handles stock movement between branches when transfer is received';
COMMENT ON FUNCTION get_near_expiry_items(UUID, UUID, INTEGER) IS 'Returns items expiring within specified days threshold';
COMMENT ON FUNCTION get_low_stock_items(UUID, UUID) IS 'Returns items with stock below reorder level';
COMMENT ON FUNCTION get_expired_items(UUID, UUID) IS 'Returns expired items still in stock';
COMMENT ON FUNCTION get_sales_summary(UUID, UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) IS 'Returns sales summary for given date range';
COMMENT ON FUNCTION get_top_selling_products(UUID, UUID, TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE, INTEGER) IS 'Returns top selling products by revenue';
