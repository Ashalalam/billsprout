-- =====================================================
-- BillSprout/LifeSprout ERP - Performance Indexes
-- =====================================================
-- This migration creates indexes to optimize query performance
-- Created: 2024
-- Description: Indexes on foreign keys, tenant isolation, and search fields

-- =====================================================
-- 1. TENANTS TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_tenants_email ON tenants(email);
CREATE INDEX IF NOT EXISTS idx_tenants_subscription_status ON tenants(subscription_status);
CREATE INDEX IF NOT EXISTS idx_tenants_is_active ON tenants(is_active);
CREATE INDEX IF NOT EXISTS idx_tenants_created_at ON tenants(created_at);

-- =====================================================
-- 2. BRANCHES TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_branches_tenant_id ON branches(tenant_id);
CREATE INDEX IF NOT EXISTS idx_branches_branch_code ON branches(tenant_id, branch_code);
CREATE INDEX IF NOT EXISTS idx_branches_is_active ON branches(tenant_id, is_active);
CREATE INDEX IF NOT EXISTS idx_branches_created_at ON branches(created_at);

-- =====================================================
-- 3. USERS TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_users_tenant_id ON users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(tenant_id, is_active);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);

-- GIN index for array searching on assigned_branches
CREATE INDEX IF NOT EXISTS idx_users_assigned_branches ON users USING GIN (assigned_branches);

-- =====================================================
-- 4. SUPPLIERS TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_suppliers_tenant_id ON suppliers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_suppliers_supplier_name ON suppliers(tenant_id, supplier_name);
CREATE INDEX IF NOT EXISTS idx_suppliers_phone ON suppliers(phone);
CREATE INDEX IF NOT EXISTS idx_suppliers_gstin ON suppliers(gstin);
CREATE INDEX IF NOT EXISTS idx_suppliers_is_active ON suppliers(tenant_id, is_active);

-- Full-text search index for supplier names
CREATE INDEX IF NOT EXISTS idx_suppliers_name_search ON suppliers USING gin(to_tsvector('english', supplier_name));

-- =====================================================
-- 5. CUSTOMERS TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_customers_tenant_id ON customers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_customers_customer_type ON customers(tenant_id, customer_type);
CREATE INDEX IF NOT EXISTS idx_customers_gstin ON customers(gstin);

-- Full-text search index for customer names
CREATE INDEX IF NOT EXISTS idx_customers_name_search ON customers USING gin(to_tsvector('english', customer_name));

-- Composite index for outstanding amount queries
CREATE INDEX IF NOT EXISTS idx_customers_outstanding ON customers(tenant_id, outstanding_amount) WHERE outstanding_amount > 0;

-- =====================================================
-- 6. PRODUCTS TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_products_tenant_id ON products(tenant_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(tenant_id, category);
CREATE INDEX IF NOT EXISTS idx_products_manufacturer ON products(tenant_id, manufacturer);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(tenant_id, sku);
CREATE INDEX IF NOT EXISTS idx_products_hsn_code ON products(hsn_code);

-- Indexes for Schedule H/H1/Narcotic filtering
CREATE INDEX IF NOT EXISTS idx_products_is_schedule_h ON products(tenant_id, is_schedule_h) WHERE is_schedule_h = true;
CREATE INDEX IF NOT EXISTS idx_products_is_schedule_h1 ON products(tenant_id, is_schedule_h1) WHERE is_schedule_h1 = true;
CREATE INDEX IF NOT EXISTS idx_products_is_narcotic ON products(tenant_id, is_narcotic) WHERE is_narcotic = true;

-- Full-text search index for product names and generic salts
CREATE INDEX IF NOT EXISTS idx_products_name_search ON products USING gin(to_tsvector('english', name || ' ' || COALESCE(generic_salt, '') || ' ' || COALESCE(brand, '')));

-- =====================================================
-- 7. BATCHES TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_batches_tenant_id ON batches(tenant_id);
CREATE INDEX IF NOT EXISTS idx_batches_branch_id ON batches(branch_id);
CREATE INDEX IF NOT EXISTS idx_batches_product_id ON batches(product_id);
CREATE INDEX IF NOT EXISTS idx_batches_batch_number ON batches(batch_number);
CREATE INDEX IF NOT EXISTS idx_batches_exp_date ON batches(exp_date);
CREATE INDEX IF NOT EXISTS idx_batches_supplier_id ON batches(supplier_id);

-- Composite index for stock queries
CREATE INDEX IF NOT EXISTS idx_batches_branch_product ON batches(branch_id, product_id);
CREATE INDEX IF NOT EXISTS idx_batches_stock_quantity ON batches(tenant_id, branch_id, stock_quantity);

-- Index for near-expiry queries
CREATE INDEX IF NOT EXISTS idx_batches_near_expiry ON batches(branch_id, exp_date) WHERE stock_quantity > 0;

-- Index for low stock queries
CREATE INDEX IF NOT EXISTS idx_batches_low_stock ON batches(branch_id, product_id, stock_quantity);

-- =====================================================
-- 8. PRESCRIPTIONS TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_prescriptions_tenant_id ON prescriptions(tenant_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_customer_id ON prescriptions(customer_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_doctor_mci_no ON prescriptions(doctor_mci_no);
CREATE INDEX IF NOT EXISTS idx_prescriptions_upload_date ON prescriptions(upload_date);
CREATE INDEX IF NOT EXISTS idx_prescriptions_verified_by ON prescriptions(verified_by);

-- =====================================================
-- 9. SALES TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_sales_tenant_id ON sales(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sales_branch_id ON sales(branch_id);
CREATE INDEX IF NOT EXISTS idx_sales_invoice_number ON sales(tenant_id, branch_id, invoice_number);
CREATE INDEX IF NOT EXISTS idx_sales_invoice_date ON sales(invoice_date);
CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON sales(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_customer_phone ON sales(customer_phone);
CREATE INDEX IF NOT EXISTS idx_sales_billing_type ON sales(tenant_id, billing_type);
CREATE INDEX IF NOT EXISTS idx_sales_payment_status ON sales(tenant_id, payment_status);
CREATE INDEX IF NOT EXISTS idx_sales_created_by ON sales(created_by);
CREATE INDEX IF NOT EXISTS idx_sales_pharmacist_authorized_by ON sales(pharmacist_authorized_by);
CREATE INDEX IF NOT EXISTS idx_sales_prescription_id ON sales(prescription_id);
CREATE INDEX IF NOT EXISTS idx_sales_is_synced ON sales(tenant_id, is_synced) WHERE is_synced = false;

-- Composite indexes for reporting queries
CREATE INDEX IF NOT EXISTS idx_sales_date_branch ON sales(branch_id, invoice_date);
CREATE INDEX IF NOT EXISTS idx_sales_date_tenant ON sales(tenant_id, invoice_date);

-- Index for date range queries
CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at);

-- =====================================================
-- 10. SALE_ITEMS TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON sale_items(sale_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_product_id ON sale_items(product_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_batch_id ON sale_items(batch_id);
CREATE INDEX IF NOT EXISTS idx_sale_items_created_at ON sale_items(created_at);

-- =====================================================
-- 11. PURCHASES TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_purchases_tenant_id ON purchases(tenant_id);
CREATE INDEX IF NOT EXISTS idx_purchases_branch_id ON purchases(branch_id);
CREATE INDEX IF NOT EXISTS idx_purchases_purchase_number ON purchases(tenant_id, branch_id, purchase_number);
CREATE INDEX IF NOT EXISTS idx_purchases_purchase_date ON purchases(purchase_date);
CREATE INDEX IF NOT EXISTS idx_purchases_supplier_id ON purchases(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchases_invoice_number ON purchases(invoice_number);
CREATE INDEX IF NOT EXISTS idx_purchases_payment_status ON purchases(tenant_id, payment_status);
CREATE INDEX IF NOT EXISTS idx_purchases_created_by ON purchases(created_by);

-- Composite indexes for reporting
CREATE INDEX IF NOT EXISTS idx_purchases_date_branch ON purchases(branch_id, purchase_date);
CREATE INDEX IF NOT EXISTS idx_purchases_date_tenant ON purchases(tenant_id, purchase_date);
CREATE INDEX IF NOT EXISTS idx_purchases_created_at ON purchases(created_at);

-- =====================================================
-- 12. PURCHASE_ITEMS TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_purchase_items_purchase_id ON purchase_items(purchase_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_product_id ON purchase_items(product_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_batch_id ON purchase_items(batch_id);
CREATE INDEX IF NOT EXISTS idx_purchase_items_created_at ON purchase_items(created_at);

-- =====================================================
-- 13. RESTRICTED_DRUG_LOGS TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_restricted_drug_logs_tenant_id ON restricted_drug_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_restricted_drug_logs_sale_id ON restricted_drug_logs(sale_id);
CREATE INDEX IF NOT EXISTS idx_restricted_drug_logs_product_id ON restricted_drug_logs(product_id);
CREATE INDEX IF NOT EXISTS idx_restricted_drug_logs_pharmacist_id ON restricted_drug_logs(pharmacist_id);
CREATE INDEX IF NOT EXISTS idx_restricted_drug_logs_doctor_mci_no ON restricted_drug_logs(doctor_mci_no);
CREATE INDEX IF NOT EXISTS idx_restricted_drug_logs_auth_timestamp ON restricted_drug_logs(authorization_timestamp);
CREATE INDEX IF NOT EXISTS idx_restricted_drug_logs_prescription_id ON restricted_drug_logs(prescription_id);

-- Composite index for compliance reporting
CREATE INDEX IF NOT EXISTS idx_restricted_drug_logs_date ON restricted_drug_logs(tenant_id, authorization_timestamp);

-- =====================================================
-- 14. STOCK_MOVEMENTS TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_stock_movements_tenant_id ON stock_movements(tenant_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_product_id ON stock_movements(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_batch_id ON stock_movements(batch_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_branch_id ON stock_movements(branch_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_movement_type ON stock_movements(movement_type);
CREATE INDEX IF NOT EXISTS idx_stock_movements_reference_id ON stock_movements(reference_id);
CREATE INDEX IF NOT EXISTS idx_stock_movements_created_by ON stock_movements(created_by);
CREATE INDEX IF NOT EXISTS idx_stock_movements_created_at ON stock_movements(created_at);

-- Composite index for stock audit trails
CREATE INDEX IF NOT EXISTS idx_stock_movements_product_date ON stock_movements(product_id, created_at);
CREATE INDEX IF NOT EXISTS idx_stock_movements_branch_date ON stock_movements(branch_id, created_at);

-- =====================================================
-- 15. STOCK_TRANSFERS TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_stock_transfers_tenant_id ON stock_transfers(tenant_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_transfer_number ON stock_transfers(tenant_id, transfer_number);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_from_branch ON stock_transfers(from_branch_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_to_branch ON stock_transfers(to_branch_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_product_id ON stock_transfers(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_batch_id ON stock_transfers(batch_id);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_status ON stock_transfers(status);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_initiated_by ON stock_transfers(initiated_by);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_received_by ON stock_transfers(received_by);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_transfer_date ON stock_transfers(transfer_date);

-- Composite index for pending transfers by branch
CREATE INDEX IF NOT EXISTS idx_stock_transfers_pending ON stock_transfers(to_branch_id, status) WHERE status = 'pending';

-- =====================================================
-- 16. DEMO_REQUESTS TABLE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_demo_requests_mobile ON demo_requests(mobile);
CREATE INDEX IF NOT EXISTS idx_demo_requests_email ON demo_requests(email);
CREATE INDEX IF NOT EXISTS idx_demo_requests_status ON demo_requests(status);
CREATE INDEX IF NOT EXISTS idx_demo_requests_created_at ON demo_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_demo_requests_city ON demo_requests(city);
CREATE INDEX IF NOT EXISTS idx_demo_requests_business_type ON demo_requests(business_type);

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON INDEX idx_products_name_search IS 'Full-text search index for product names, generic salts, and brands';
COMMENT ON INDEX idx_customers_name_search IS 'Full-text search index for customer names';
COMMENT ON INDEX idx_suppliers_name_search IS 'Full-text search index for supplier names';
COMMENT ON INDEX idx_batches_near_expiry IS 'Optimizes near-expiry stock queries';
COMMENT ON INDEX idx_batches_low_stock IS 'Optimizes low stock alert queries';
COMMENT ON INDEX idx_sales_is_synced IS 'Partial index for unsynced sales (offline sync support)';
