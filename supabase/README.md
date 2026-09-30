# BillSprout/LifeSprout ERP - Supabase Database Setup

This directory contains the database schema and migrations for the BillSprout/LifeSprout ERP system built on Supabase (PostgreSQL).

## Overview

The database schema implements a comprehensive multi-tenant ERP system with:

- **Multi-tenancy**: Complete tenant isolation with Row Level Security (RLS)
- **Pharmacy Management**: Products, batches, prescriptions, and regulatory compliance
- **Inventory**: Branch-level stock tracking with batch management
- **Sales & Purchases**: Complete invoicing with GST calculations
- **Compliance**: Schedule H/H1/Narcotic drug logging for regulatory requirements
- **Stock Transfers**: Inter-branch inventory movement tracking
- **Reporting**: Built-in functions for near-expiry, low stock, and sales analytics

## Migration Files

### 001_initial_schema.sql
Creates all core tables:
- `tenants` - Business accounts
- `branches` - Physical locations
- `users` - Staff and customers
- `suppliers` - Vendor management
- `customers` - Customer database
- `products` - Product master catalog
- `batches` - Batch-wise inventory
- `prescriptions` - Digital prescription storage
- `sales` / `sale_items` - Sales invoicing
- `purchases` / `purchase_items` - Purchase orders
- `restricted_drug_logs` - Regulatory compliance audit
- `stock_movements` - Complete stock audit trail
- `stock_transfers` - Inter-branch transfers
- `demo_requests` - Marketing leads

### 002_rls_policies.sql
Implements Row Level Security for tenant isolation:
- Helper functions for tenant access control
- Policies ensuring users can only access their tenant's data
- Super admin role with access to all data
- Secure multi-tenancy enforcement

### 003_indexes.sql
Performance optimization indexes:
- Foreign key indexes
- tenant_id indexes on all tables
- Full-text search indexes for products, customers, suppliers
- Date indexes for reporting queries
- Composite indexes for common query patterns
- Partial indexes for filtered queries (near-expiry, low stock, etc.)

### 004_functions_triggers.sql
Automated business logic:
- **Triggers**:
  - Auto-update `updated_at` timestamps
  - Stock reduction on sales
  - Stock increment on purchases
  - Automatic restricted drug logging
  - Inter-branch transfer handling
  
- **Functions**:
  - `get_near_expiry_items()` - Items expiring soon
  - `get_low_stock_items()` - Items below reorder level
  - `get_expired_items()` - Expired stock
  - `get_sales_summary()` - Sales analytics
  - `get_top_selling_products()` - Best sellers report

## Setup Instructions

### Prerequisites
1. A Supabase project ([https://supabase.com](https://supabase.com))
2. Supabase CLI installed ([https://supabase.com/docs/guides/cli](https://supabase.com/docs/guides/cli))
3. Project connection details (URL, API keys)

### Option 1: Using Supabase CLI (Recommended)

```bash
# Install Supabase CLI (if not already installed)
npm install -g supabase

# Login to Supabase
supabase login

# Link your project
supabase link --project-ref <your-project-ref>

# Run migrations
supabase db push
```

### Option 2: Manual Migration via Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Run each migration file in order:
   - Execute `001_initial_schema.sql`
   - Execute `002_rls_policies.sql`
   - Execute `003_indexes.sql`
   - Execute `004_functions_triggers.sql`

### Option 3: Using psql

```bash
# Set your database connection string
export DATABASE_URL="postgresql://postgres:[password]@db.[project-ref].supabase.co:5432/postgres"

# Run migrations in order
psql $DATABASE_URL -f migrations/001_initial_schema.sql
psql $DATABASE_URL -f migrations/002_rls_policies.sql
psql $DATABASE_URL -f migrations/003_indexes.sql
psql $DATABASE_URL -f migrations/004_functions_triggers.sql
```

## Configuration

### Setting Up Tenant Context

The RLS policies use the `app.tenant_id` session variable for tenant isolation. Your application should set this on each connection:

```sql
-- Set tenant context for current session
SET app.tenant_id = '<tenant-uuid>';
```

Or use Supabase client with custom headers:

```dart
// Flutter/Dart example
final supabase = Supabase.instance.client;
await supabase.rpc('set_config', params: {
  'setting': 'app.tenant_id',
  'value': tenantId,
  'is_local': true,
});
```

### Super Admin Setup

To create a super admin user:

```sql
-- After user signs up through Supabase Auth
INSERT INTO users (id, tenant_id, name, email, role, is_active)
VALUES (
  '<auth-user-id>',
  NULL, -- Super admins don't belong to a specific tenant
  'Admin Name',
  'admin@example.com',
  'super_admin',
  true
);
```

## Usage Examples

### Query Near Expiry Items

```sql
SELECT * FROM get_near_expiry_items(
  '<tenant-id>',     -- Required
  '<branch-id>',     -- Optional (NULL for all branches)
  60                 -- Days threshold (default: 90)
);
```

### Query Low Stock Items

```sql
SELECT * FROM get_low_stock_items(
  '<tenant-id>',     -- Required
  '<branch-id>'      -- Optional (NULL for all branches)
);
```

### Get Sales Summary

```sql
SELECT * FROM get_sales_summary(
  '<tenant-id>',                    -- Required
  '<branch-id>',                    -- Optional (NULL for all branches)
  '2024-01-01T00:00:00Z'::timestamptz,  -- Start date (NULL for current month)
  '2024-01-31T23:59:59Z'::timestamptz   -- End date (NULL for now)
);
```

### Top Selling Products

```sql
SELECT * FROM get_top_selling_products(
  '<tenant-id>',                    -- Required
  '<branch-id>',                    -- Optional (NULL for all branches)
  '2024-01-01T00:00:00Z'::timestamptz,  -- Start date (NULL for current month)
  '2024-01-31T23:59:59Z'::timestamptz,  -- End date (NULL for now)
  10                                -- Limit (default: 10)
);
```

## Security Notes

1. **RLS is Enabled**: All tables have Row Level Security enabled. Users can only access their tenant's data.
2. **Tenant Isolation**: The `tenant_id` column and RLS policies ensure complete data isolation between businesses.
3. **Super Admin Access**: Only users with `role = 'super_admin'` can access data across all tenants.
4. **Auth Integration**: The `users` table references `auth.users` from Supabase Auth for authentication.

## Data Flow

### Sales Transaction Flow
1. Sale record created in `sales` table
2. Items inserted into `sale_items`
3. **Trigger**: Stock automatically reduced in `batches`
4. **Trigger**: Stock movement logged in `stock_movements`
5. **Trigger**: Restricted drugs logged in `restricted_drug_logs` (if applicable)

### Purchase Transaction Flow
1. Purchase record created in `purchases` table
2. Items inserted into `purchase_items`
3. **Trigger**: New batch created or existing batch updated in `batches`
4. **Trigger**: Stock movement logged in `stock_movements`

### Inter-Branch Transfer Flow
1. Transfer initiated in `stock_transfers` (status: 'pending')
2. Status updated to 'received'
3. **Trigger**: Stock reduced from source branch
4. **Trigger**: Stock added to destination branch
5. **Trigger**: Two stock movements logged (transfer_out, transfer_in)

## Maintenance

### Backing Up Data

```bash
# Using Supabase CLI
supabase db dump -f backup.sql

# Using pg_dump
pg_dump $DATABASE_URL > backup.sql
```

### Monitoring Performance

Check slow queries in Supabase Dashboard:
- Go to **Database** → **Query Performance**
- Monitor index usage
- Review RLS policy performance

### Cleaning Up Old Data

```sql
-- Archive old sales (example: move to archive table)
-- Delete expired items with zero value
DELETE FROM batches 
WHERE exp_date < CURRENT_DATE - INTERVAL '1 year' 
  AND stock_quantity = 0;
```

## Troubleshooting

### RLS Policy Issues
If queries return no results:
```sql
-- Check if tenant_id is set
SHOW app.tenant_id;

-- Verify user's tenant_id
SELECT tenant_id, role FROM users WHERE id = auth.uid();
```

### Stock Sync Issues
If stock doesn't update:
```sql
-- Check trigger status
SELECT * FROM pg_trigger WHERE tgname LIKE '%stock%';

-- Manually create stock movement if needed
INSERT INTO stock_movements (...) VALUES (...);
```

## Support

For issues or questions:
1. Check Supabase documentation: [https://supabase.com/docs](https://supabase.com/docs)
2. Review migration comments in SQL files
3. Check function descriptions: `\df+ function_name` in psql

## Version

- **Schema Version**: 1.0
- **Created**: 2024
- **Database**: PostgreSQL 15+ (Supabase)
- **Compatible With**: Flutter/Dart, React, Node.js, Python, and any PostgreSQL client
