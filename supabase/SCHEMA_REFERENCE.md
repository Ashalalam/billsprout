# Database Schema Quick Reference

## Table Relationships

```
tenants (1) ─────┬─────> (many) branches
                 ├─────> (many) users
                 ├─────> (many) suppliers
                 ├─────> (many) customers
                 ├─────> (many) products
                 ├─────> (many) sales
                 ├─────> (many) purchases
                 └─────> (many) stock_movements

products (1) ───> (many) batches
batches (1) ────> (many) sale_items
batches (1) ────> (many) purchase_items

sales (1) ──────> (many) sale_items
purchases (1) ──> (many) purchase_items

branches (1) ───> (many) batches (stock is per branch)
```

## Core Tables

### tenants
Primary key for multi-tenancy. Every business is a tenant.
- **Key Fields**: `id`, `business_name`, `email`, `industry_type`, `subscription_status`
- **Use Case**: Business account management, subscription tracking

### branches
Physical locations/stores of each tenant.
- **Key Fields**: `id`, `tenant_id`, `branch_name`, `branch_code`, `drug_license_no`
- **Use Case**: Multi-location inventory management

### users
All system users (admins, pharmacists, cashiers, customers).
- **Key Fields**: `id`, `tenant_id`, `role`, `license_no`, `pharmacist_pin_hash`
- **Roles**: `super_admin`, `business_admin`, `pharmacist`, `cashier`, `customer`
- **Use Case**: Authentication, authorization, pharmacist verification

### products
Master product catalog per tenant.
- **Key Fields**: `id`, `tenant_id`, `name`, `generic_salt`, `hsn_code`, `gst_percent`
- **Compliance Fields**: `is_schedule_h`, `is_schedule_h1`, `is_narcotic`, `is_prescription_required`
- **Use Case**: Product master data, compliance tracking

### batches
Batch-wise stock management (per branch).
- **Key Fields**: `id`, `product_id`, `batch_number`, `exp_date`, `stock_quantity`, `branch_id`
- **Price Fields**: `purchase_price`, `ptr_price`, `mrp`, `selling_price`, `wholesale_price`
- **Use Case**: Inventory tracking, batch expiry management, pricing

### suppliers
Vendor/supplier master data.
- **Key Fields**: `id`, `tenant_id`, `supplier_name`, `gstin`, `credit_period_days`
- **Use Case**: Purchase management, vendor tracking

### customers
Customer database (retail and wholesale).
- **Key Fields**: `id`, `tenant_id`, `customer_name`, `phone`, `customer_type`, `gstin`
- **Types**: `retail`, `wholesale`, `distributor`
- **Use Case**: Customer management, credit tracking

### sales
Sales invoice headers.
- **Key Fields**: `id`, `invoice_number`, `branch_id`, `customer_id`, `grand_total`
- **Tax Fields**: `cgst_amount`, `sgst_amount`, `igst_amount`, `total_gst`
- **Compliance Fields**: `doctor_name`, `doctor_mci_no`, `prescription_id`, `pharmacist_authorized_by`
- **Use Case**: Sales invoicing, revenue tracking

### sale_items
Line items for each sale.
- **Key Fields**: `id`, `sale_id`, `product_id`, `batch_id`, `quantity`, `line_total`
- **Use Case**: Invoice line items, product sales tracking

### purchases
Purchase invoice headers.
- **Key Fields**: `id`, `purchase_number`, `branch_id`, `supplier_id`, `grand_total`
- **Use Case**: Purchase management, inventory inward

### purchase_items
Line items for each purchase.
- **Key Fields**: `id`, `purchase_id`, `product_id`, `batch_id`, `quantity`, `line_total`
- **Use Case**: Purchase order details, cost tracking

### prescriptions
Digital prescription storage.
- **Key Fields**: `id`, `customer_id`, `doctor_name`, `prescription_file_url`, `verified_by`
- **Use Case**: Prescription management, compliance documentation

### restricted_drug_logs
Audit log for Schedule H/H1/Narcotic drugs (regulatory compliance).
- **Key Fields**: `id`, `sale_id`, `product_id`, `pharmacist_id`, `doctor_mci_no`, `prescription_id`
- **Use Case**: Legal compliance, regulatory audits

### stock_movements
Complete audit trail of all stock changes.
- **Key Fields**: `id`, `batch_id`, `movement_type`, `quantity`, `reference_id`
- **Movement Types**: `purchase`, `sale`, `transfer_in`, `transfer_out`, `adjustment`, `return`, `damage`, `expired`
- **Use Case**: Stock audit trail, inventory reconciliation

### stock_transfers
Inter-branch stock transfers.
- **Key Fields**: `id`, `transfer_number`, `from_branch_id`, `to_branch_id`, `status`
- **Status**: `pending`, `in_transit`, `received`, `cancelled`
- **Use Case**: Branch-to-branch inventory movement

## Enums & Constraints

### Industry Types
- `pharmacy`, `wholesale`, `retail`, `fmcg`, `manufacturing`, `hospitality`

### Business Modes
- `retail`, `wholesale`, `both`

### User Roles
- `super_admin`, `business_admin`, `pharmacist`, `cashier`, `customer`

### Dosage Forms
- `tablet`, `capsule`, `syrup`, `injection`, `cream`, `ointment`, `drops`, `gel`, `powder`, `lotion`, `suspension`, `inhaler`, `spray`, `other`

### Packaging Types
- `strip`, `bottle`, `vial`, `box`, `tube`, `sachet`, `ampoule`, `pen`, `jar`, `other`

### Customer Types
- `retail`, `wholesale`, `distributor`

### Billing Types
- `retail`, `wholesale`

### Payment Modes
- `cash`, `card`, `upi`, `split`, `credit`, `cheque`, `bank_transfer`

### Payment Status
- `paid`, `partial`, `pending`

### Movement Types
- `purchase`, `sale`, `transfer_in`, `transfer_out`, `adjustment`, `return`, `damage`, `expired`

### Transfer Status
- `pending`, `in_transit`, `received`, `cancelled`

## Key Functions

### Inventory Management
```sql
-- Near expiry items (expiring in next 90 days by default)
SELECT * FROM get_near_expiry_items(tenant_id, branch_id, days_threshold);

-- Low stock items (below reorder level)
SELECT * FROM get_low_stock_items(tenant_id, branch_id);

-- Expired items still in stock
SELECT * FROM get_expired_items(tenant_id, branch_id);
```

### Sales Analytics
```sql
-- Sales summary for date range
SELECT * FROM get_sales_summary(tenant_id, branch_id, start_date, end_date);

-- Top selling products
SELECT * FROM get_top_selling_products(tenant_id, branch_id, start_date, end_date, limit);
```

### Tenant Access Control
```sql
-- Get current user's tenant
SELECT get_current_tenant_id();

-- Check if user is super admin
SELECT is_super_admin();

-- Check tenant access
SELECT user_has_tenant_access(tenant_id);
```

## Automatic Behaviors (Triggers)

1. **Auto-update timestamps**: `updated_at` automatically set on UPDATE
2. **Stock reduction on sale**: When `sale_items` inserted → `batches.stock_quantity` decreased
3. **Stock increase on purchase**: When `purchase_items` inserted → `batches.stock_quantity` increased
4. **Restricted drug logging**: Schedule H/H1/Narcotic sales automatically logged
5. **Stock transfer handling**: When transfer status = 'received' → stock moved between branches
6. **Stock movement audit**: All stock changes automatically logged in `stock_movements`

## Common Queries

### Get current stock for a product in a branch
```sql
SELECT 
    p.name,
    b.batch_number,
    b.exp_date,
    b.stock_quantity,
    b.mrp,
    b.selling_price
FROM batches b
JOIN products p ON b.product_id = p.id
WHERE b.branch_id = '<branch-id>'
  AND p.id = '<product-id>'
  AND b.stock_quantity > 0
ORDER BY b.exp_date ASC;
```

### Get total stock value by branch
```sql
SELECT 
    br.branch_name,
    SUM(b.stock_quantity * b.purchase_price) as stock_value_at_cost,
    SUM(b.stock_quantity * b.mrp) as stock_value_at_mrp
FROM batches b
JOIN branches br ON b.branch_id = br.id
WHERE b.tenant_id = '<tenant-id>'
GROUP BY br.id, br.branch_name;
```

### Get customer outstanding report
```sql
SELECT 
    customer_name,
    phone,
    credit_limit,
    outstanding_amount,
    (credit_limit - outstanding_amount) as available_credit
FROM customers
WHERE tenant_id = '<tenant-id>'
  AND outstanding_amount > 0
ORDER BY outstanding_amount DESC;
```

### Daily sales report
```sql
SELECT 
    DATE(invoice_date) as sale_date,
    COUNT(*) as num_invoices,
    SUM(grand_total) as total_sales,
    SUM(total_gst) as total_gst_collected,
    SUM(CASE WHEN payment_mode = 'cash' THEN grand_total ELSE 0 END) as cash_sales,
    SUM(CASE WHEN payment_mode = 'credit' THEN grand_total ELSE 0 END) as credit_sales
FROM sales
WHERE branch_id = '<branch-id>'
  AND invoice_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(invoice_date)
ORDER BY sale_date DESC;
```

## Indexes for Performance

All tables have indexes on:
- `tenant_id` (critical for multi-tenant queries)
- Foreign keys
- Search fields (names, phone numbers, barcodes)
- Date fields (for reporting)
- Full-text search on product names, customer names, supplier names

See `003_indexes.sql` for complete list.

## Security (RLS)

Every table has Row Level Security enabled:
- Users can only access their tenant's data
- Super admins can access all data
- `app.tenant_id` session variable enforces isolation
- All queries automatically filtered by tenant

See `002_rls_policies.sql` for policy details.
