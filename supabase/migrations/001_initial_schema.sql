-- =====================================================
-- BillSprout/LifeSprout ERP - Initial Schema Migration
-- =====================================================
-- This migration creates the core tables for the multi-tenant ERP system
-- Created: 2024
-- Description: Tenants, Branches, Users, Products, Batches, Customers, Suppliers, and Transaction tables

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. TENANTS TABLE (Business Accounts)
-- =====================================================
CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_name VARCHAR(255) NOT NULL,
    owner_name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    gstin VARCHAR(15),
    drug_license_no VARCHAR(50),
    drug_license_expiry DATE,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    pincode VARCHAR(10),
    logo_url TEXT,
    industry_type VARCHAR(50) CHECK (industry_type IN ('pharmacy', 'wholesale', 'retail', 'fmcg', 'manufacturing', 'hospitality')),
    business_mode VARCHAR(20) CHECK (business_mode IN ('retail', 'wholesale', 'both')),
    subscription_plan VARCHAR(50) DEFAULT 'trial',
    subscription_status VARCHAR(20) DEFAULT 'active' CHECK (subscription_status IN ('active', 'inactive', 'suspended', 'expired')),
    max_branches INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 2. BRANCHES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS branches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_name VARCHAR(255) NOT NULL,
    branch_code VARCHAR(50) NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    pincode VARCHAR(10),
    gstin VARCHAR(15), -- Optional, some branches may have separate GSTIN
    drug_license_no VARCHAR(50),
    drug_license_expiry DATE,
    phone VARCHAR(20),
    email VARCHAR(255),
    manager_name VARCHAR(255),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(tenant_id, branch_code)
);

-- =====================================================
-- 3. USERS TABLE (Staff, Pharmacists, etc.)
-- =====================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    role VARCHAR(50) NOT NULL CHECK (role IN ('super_admin', 'business_admin', 'pharmacist', 'cashier', 'customer')),
    license_no VARCHAR(50), -- For pharmacists
    pharmacist_pin_hash VARCHAR(255), -- Hashed PIN for pharmacist authorization
    assigned_branches UUID[], -- Array of branch IDs
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 4. SUPPLIERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    supplier_name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(20) NOT NULL,
    gstin VARCHAR(15),
    drug_license_no VARCHAR(50),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    pincode VARCHAR(10),
    credit_period_days INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 5. CUSTOMERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_name VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(255),
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    pincode VARCHAR(10),
    gstin VARCHAR(15), -- For wholesale customers
    drug_license_no VARCHAR(50), -- For wholesale customers
    customer_type VARCHAR(50) DEFAULT 'retail' CHECK (customer_type IN ('retail', 'wholesale', 'distributor')),
    credit_limit DECIMAL(15, 2) DEFAULT 0.00,
    outstanding_amount DECIMAL(15, 2) DEFAULT 0.00,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 6. PRODUCTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name VARCHAR(500) NOT NULL,
    generic_salt TEXT,
    composition TEXT,
    manufacturer VARCHAR(255),
    brand VARCHAR(255),
    category VARCHAR(100),
    dosage_form VARCHAR(50) CHECK (dosage_form IN ('tablet', 'capsule', 'syrup', 'injection', 'cream', 'ointment', 'drops', 'gel', 'powder', 'lotion', 'suspension', 'inhaler', 'spray', 'other')),
    packaging_type VARCHAR(50) CHECK (packaging_type IN ('strip', 'bottle', 'vial', 'box', 'tube', 'sachet', 'ampoule', 'pen', 'jar', 'other')),
    pack_size VARCHAR(50), -- e.g., "10x10", "60ml"
    hsn_code VARCHAR(20),
    gst_percent DECIMAL(5, 2) DEFAULT 0.00,
    is_schedule_h BOOLEAN DEFAULT false,
    is_schedule_h1 BOOLEAN DEFAULT false,
    is_narcotic BOOLEAN DEFAULT false,
    is_prescription_required BOOLEAN DEFAULT false,
    barcode VARCHAR(100),
    sku VARCHAR(100),
    reorder_level INTEGER DEFAULT 10,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(tenant_id, sku)
);

-- =====================================================
-- 7. BATCHES TABLE (Stock Management)
-- =====================================================
CREATE TABLE IF NOT EXISTS batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    batch_number VARCHAR(100) NOT NULL,
    mfg_date DATE,
    exp_date DATE NOT NULL,
    purchase_price DECIMAL(15, 2) NOT NULL,
    ptr_price DECIMAL(15, 2), -- Price to Retailer
    mrp DECIMAL(15, 2) NOT NULL,
    selling_price DECIMAL(15, 2) NOT NULL,
    wholesale_price DECIMAL(15, 2),
    stock_quantity INTEGER NOT NULL DEFAULT 0,
    free_quantity INTEGER DEFAULT 0,
    rack_location VARCHAR(50),
    supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(tenant_id, branch_id, product_id, batch_number)
);

-- =====================================================
-- 8. PRESCRIPTIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS prescriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    doctor_name VARCHAR(255),
    doctor_mci_no VARCHAR(100),
    prescription_file_url TEXT, -- Supabase Storage URL
    upload_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    verified_by UUID REFERENCES users(id) ON DELETE SET NULL,
    verification_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 9. SALES TABLE (Invoices)
-- =====================================================
CREATE TABLE IF NOT EXISTS sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    invoice_number VARCHAR(100) NOT NULL,
    invoice_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    customer_name VARCHAR(255),
    customer_phone VARCHAR(20),
    customer_gstin VARCHAR(15),
    billing_type VARCHAR(20) CHECK (billing_type IN ('retail', 'wholesale')),
    doctor_name VARCHAR(255),
    doctor_mci_no VARCHAR(100),
    prescription_id UUID REFERENCES prescriptions(id) ON DELETE SET NULL,
    subtotal DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    item_discount_total DECIMAL(15, 2) DEFAULT 0.00,
    invoice_discount DECIMAL(15, 2) DEFAULT 0.00,
    taxable_amount DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    cgst_amount DECIMAL(15, 2) DEFAULT 0.00,
    sgst_amount DECIMAL(15, 2) DEFAULT 0.00,
    igst_amount DECIMAL(15, 2) DEFAULT 0.00,
    total_gst DECIMAL(15, 2) DEFAULT 0.00,
    round_off DECIMAL(10, 2) DEFAULT 0.00,
    grand_total DECIMAL(15, 2) NOT NULL,
    payment_mode VARCHAR(50) CHECK (payment_mode IN ('cash', 'card', 'upi', 'split', 'credit', 'cheque', 'bank_transfer')),
    payment_status VARCHAR(50) DEFAULT 'paid' CHECK (payment_status IN ('paid', 'partial', 'pending')),
    pharmacist_authorized_by UUID REFERENCES users(id) ON DELETE SET NULL,
    is_synced BOOLEAN DEFAULT false,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(tenant_id, branch_id, invoice_number)
);

-- =====================================================
-- 10. SALE_ITEMS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE RESTRICT,
    product_name VARCHAR(500) NOT NULL,
    hsn_code VARCHAR(20),
    batch_number VARCHAR(100) NOT NULL,
    expiry_date DATE NOT NULL,
    quantity INTEGER NOT NULL,
    free_quantity INTEGER DEFAULT 0,
    unit_price DECIMAL(15, 2) NOT NULL,
    ptr_price DECIMAL(15, 2),
    mrp DECIMAL(15, 2) NOT NULL,
    line_discount DECIMAL(15, 2) DEFAULT 0.00,
    taxable_value DECIMAL(15, 2) NOT NULL,
    gst_percent DECIMAL(5, 2) DEFAULT 0.00,
    cgst_amount DECIMAL(15, 2) DEFAULT 0.00,
    sgst_amount DECIMAL(15, 2) DEFAULT 0.00,
    igst_amount DECIMAL(15, 2) DEFAULT 0.00,
    line_total DECIMAL(15, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 11. PURCHASES TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS purchases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    purchase_number VARCHAR(100) NOT NULL,
    purchase_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    supplier_id UUID NOT NULL REFERENCES suppliers(id) ON DELETE RESTRICT,
    supplier_name VARCHAR(255) NOT NULL,
    supplier_gstin VARCHAR(15),
    invoice_number VARCHAR(100), -- Supplier's invoice number
    subtotal DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    discount DECIMAL(15, 2) DEFAULT 0.00,
    taxable_amount DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    cgst_amount DECIMAL(15, 2) DEFAULT 0.00,
    sgst_amount DECIMAL(15, 2) DEFAULT 0.00,
    igst_amount DECIMAL(15, 2) DEFAULT 0.00,
    total_gst DECIMAL(15, 2) DEFAULT 0.00,
    grand_total DECIMAL(15, 2) NOT NULL,
    payment_status VARCHAR(50) DEFAULT 'pending' CHECK (payment_status IN ('paid', 'partial', 'pending')),
    payment_mode VARCHAR(50) CHECK (payment_mode IN ('cash', 'card', 'upi', 'credit', 'cheque', 'bank_transfer')),
    transport_details TEXT,
    created_by UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(tenant_id, branch_id, purchase_number)
);

-- =====================================================
-- 12. PURCHASE_ITEMS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS purchase_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    purchase_id UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    batch_id UUID REFERENCES batches(id) ON DELETE SET NULL, -- Created during purchase
    product_name VARCHAR(500) NOT NULL,
    hsn_code VARCHAR(20),
    batch_number VARCHAR(100) NOT NULL,
    mfg_date DATE,
    exp_date DATE NOT NULL,
    quantity INTEGER NOT NULL,
    free_quantity INTEGER DEFAULT 0,
    purchase_price DECIMAL(15, 2) NOT NULL,
    ptr_price DECIMAL(15, 2),
    mrp DECIMAL(15, 2) NOT NULL,
    line_discount DECIMAL(15, 2) DEFAULT 0.00,
    gst_percent DECIMAL(5, 2) DEFAULT 0.00,
    cgst_amount DECIMAL(15, 2) DEFAULT 0.00,
    sgst_amount DECIMAL(15, 2) DEFAULT 0.00,
    igst_amount DECIMAL(15, 2) DEFAULT 0.00,
    line_total DECIMAL(15, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 13. RESTRICTED_DRUG_LOGS TABLE (Schedule H/H1 Compliance)
-- =====================================================
CREATE TABLE IF NOT EXISTS restricted_drug_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    product_name VARCHAR(500) NOT NULL,
    batch_number VARCHAR(100) NOT NULL,
    quantity INTEGER NOT NULL,
    customer_name VARCHAR(255) NOT NULL,
    doctor_name VARCHAR(255),
    doctor_mci_no VARCHAR(100),
    pharmacist_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    authorization_timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    prescription_id UUID REFERENCES prescriptions(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 14. STOCK_MOVEMENTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
    movement_type VARCHAR(50) NOT NULL CHECK (movement_type IN ('purchase', 'sale', 'transfer_in', 'transfer_out', 'adjustment', 'return', 'damage', 'expired')),
    quantity INTEGER NOT NULL, -- Positive for IN, Negative for OUT
    reference_id UUID, -- sale_id, purchase_id, or transfer_id
    notes TEXT,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- 15. STOCK_TRANSFERS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS stock_transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    transfer_number VARCHAR(100) NOT NULL,
    from_branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    to_branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE RESTRICT,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    transfer_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'in_transit', 'received', 'cancelled')),
    initiated_by UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    received_by UUID REFERENCES users(id) ON DELETE SET NULL,
    received_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(tenant_id, transfer_number)
);

-- =====================================================
-- 16. DEMO_REQUESTS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS demo_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    business_name VARCHAR(255),
    mobile VARCHAR(20) NOT NULL,
    email VARCHAR(255),
    city VARCHAR(100),
    pincode VARCHAR(10),
    business_type VARCHAR(100),
    num_branches INTEGER DEFAULT 1,
    message TEXT,
    status VARCHAR(50) DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'converted', 'closed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- COMMENTS
-- =====================================================
COMMENT ON TABLE tenants IS 'Business/Organization accounts in the multi-tenant system';
COMMENT ON TABLE branches IS 'Physical locations/branches of each tenant business';
COMMENT ON TABLE users IS 'All users including admins, pharmacists, cashiers, and customers';
COMMENT ON TABLE products IS 'Master product catalog for each tenant';
COMMENT ON TABLE batches IS 'Batch-wise stock management with branch-level inventory';
COMMENT ON TABLE suppliers IS 'Supplier/vendor master data';
COMMENT ON TABLE customers IS 'Customer master data (retail and wholesale)';
COMMENT ON TABLE prescriptions IS 'Digital prescription storage and tracking';
COMMENT ON TABLE sales IS 'Sales invoice headers';
COMMENT ON TABLE sale_items IS 'Line items for each sale';
COMMENT ON TABLE purchases IS 'Purchase invoice headers';
COMMENT ON TABLE purchase_items IS 'Line items for each purchase';
COMMENT ON TABLE restricted_drug_logs IS 'Audit log for Schedule H/H1/Narcotic drug sales (regulatory compliance)';
COMMENT ON TABLE stock_movements IS 'Complete audit trail of all stock movements';
COMMENT ON TABLE stock_transfers IS 'Inter-branch stock transfers';
COMMENT ON TABLE demo_requests IS 'Demo request leads from website/marketing';
