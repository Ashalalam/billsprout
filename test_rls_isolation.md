# RLS Multi-Tenant Isolation Test Plan

## Test Objective
Verify that Row Level Security (RLS) policies correctly isolate tenant data and prevent unauthorized cross-tenant access.

## Test Prerequisites
1. Supabase instance configured and running
2. Migrations applied (001_initial_schema.sql, 002_rls_policies.sql)
3. Multiple test tenants created
4. Test users created for each tenant

## Test Scenario Setup

### Test Tenants
- **Tenant A**: "Pharmacy Alpha" (tenant_id: `a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1`)
- **Tenant B**: "Pharmacy Beta" (tenant_id: `b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2`)
- **Super Admin**: Cross-tenant access

### Test Users
1. **User A** (business_admin @ Tenant A)
   - Email: `admin-a@test.com`
   - Role: business_admin
   - tenant_id: Tenant A

2. **User B** (business_admin @ Tenant B)
   - Email: `admin-b@test.com`
   - Role: business_admin
   - tenant_id: Tenant B

3. **Super Admin**
   - Email: `superadmin@test.com`
   - Role: super_admin
   - tenant_id: NULL

## Critical Test Cases

### Test 1: Product Isolation
**Objective**: Verify User A cannot see User B's products

**Setup**:
1. User A creates Product X (tenant_id: A)
2. User B creates Product Y (tenant_id: B)

**Tests**:
- [ ] User A SELECT products → Should see only Product X
- [ ] User B SELECT products → Should see only Product Y
- [ ] Super Admin SELECT products → Should see both X and Y
- [ ] User A cannot UPDATE Product Y (RLS deny)
- [ ] User B cannot DELETE Product X (RLS deny)

**Expected SQL Behavior**:
```sql
-- As User A
SELECT * FROM products; 
-- Returns: Product X only (where tenant_id = A)

-- Try to access Product Y
SELECT * FROM products WHERE id = 'product_y_id';
-- Returns: 0 rows (RLS filters it out)

-- Try to update Product Y
UPDATE products SET name = 'Hacked' WHERE id = 'product_y_id';
-- Returns: 0 rows updated (RLS prevents access)
```

---

### Test 2: Sales/Invoice Isolation
**Objective**: Verify invoices are tenant-isolated

**Setup**:
1. User A creates Invoice INV-A-001 (tenant_id: A)
2. User B creates Invoice INV-B-001 (tenant_id: B)

**Tests**:
- [ ] User A SELECT sales → Should see only INV-A-001
- [ ] User B SELECT sales → Should see only INV-B-001
- [ ] User A cannot read sale_items from INV-B-001
- [ ] Revenue totals show only own tenant's sales

**Expected Behavior**:
```sql
-- As User A
SELECT COUNT(*) FROM sales;
-- Returns: 1 (only INV-A-001)

-- Try to read User B's invoice
SELECT * FROM sales WHERE invoice_number = 'INV-B-001';
-- Returns: 0 rows

-- Sale items should also be isolated
SELECT * FROM sale_items si
JOIN sales s ON s.id = si.sale_id;
-- Returns: Only items from INV-A-001
```

---

### Test 3: Customer Data Isolation
**Objective**: Verify customer records are tenant-isolated

**Setup**:
1. User A creates Customer "John Doe" (tenant_id: A)
2. User B creates Customer "Jane Smith" (tenant_id: B)

**Tests**:
- [ ] User A SELECT customers → Should see only John Doe
- [ ] User B SELECT customers → Should see only Jane Smith
- [ ] User A cannot view Jane Smith's phone/email
- [ ] Customer search only returns own tenant's customers

---

### Test 4: Batch/Inventory Isolation
**Objective**: Verify stock batches are tenant-isolated

**Setup**:
1. User A creates Batch A1 for Product P1 (tenant_id: A, branch_id: A-Branch-1)
2. User B creates Batch B1 for Product P2 (tenant_id: B, branch_id: B-Branch-1)

**Tests**:
- [ ] User A SELECT batches → Should see only Batch A1
- [ ] User B SELECT batches → Should see only Batch B1
- [ ] Stock counts are isolated per tenant
- [ ] Near-expiry queries don't leak cross-tenant data

---

### Test 5: Restricted Drug Logs Isolation
**Objective**: Verify Schedule H register is tenant-isolated

**Setup**:
1. User A creates restricted drug log (tenant_id: A)
2. User B creates restricted drug log (tenant_id: B)

**Tests**:
- [ ] User A SELECT restricted_drug_logs → See only Tenant A logs
- [ ] User B SELECT restricted_drug_logs → See only Tenant B logs
- [ ] Compliance reports don't leak data

---

### Test 6: Super Admin Cross-Tenant Access
**Objective**: Verify super admin can access all tenants

**Tests**:
- [ ] Super Admin SELECT products → See products from all tenants
- [ ] Super Admin SELECT sales → See all invoices
- [ ] Super Admin SELECT tenants → See all business accounts
- [ ] Super Admin can UPDATE any tenant's data
- [ ] Super Admin can INSERT for any tenant

---

### Test 7: Anonymous/Unauthenticated Access
**Objective**: Verify anonymous users cannot access tenant data

**Tests**:
- [ ] Anonymous SELECT products → RLS denies (0 rows)
- [ ] Anonymous SELECT sales → RLS denies (0 rows)
- [ ] Anonymous INSERT demo_requests → Allowed (public form)
- [ ] Anonymous SELECT demo_requests → RLS denies

---

### Test 8: Helper Functions
**Objective**: Verify RLS helper functions work correctly

**Tests**:
```sql
-- As User A
SELECT get_current_tenant_id();
-- Returns: a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1

SELECT is_super_admin();
-- Returns: false

SELECT user_has_tenant_access('a1a1a1a1-a1a1-a1a1-a1a1-a1a1a1a1a1a1');
-- Returns: true

SELECT user_has_tenant_access('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2');
-- Returns: false

-- As Super Admin
SELECT is_super_admin();
-- Returns: true

SELECT user_has_tenant_access('b2b2b2b2-b2b2-b2b2-b2b2-b2b2b2b2b2b2');
-- Returns: true (super admin bypasses)
```

---

### Test 9: INSERT with Wrong Tenant ID
**Objective**: Verify users cannot insert data for other tenants

**Tests**:
```sql
-- As User A (tenant_id: A)
INSERT INTO products (id, tenant_id, name, ...) 
VALUES ('prod_x', 'b2b2b2b2-...', 'Product X', ...);
-- Expected: RLS deny / WITH CHECK violation

-- Should only allow insert with own tenant_id
INSERT INTO products (id, tenant_id, name, ...) 
VALUES ('prod_x', 'a1a1a1a1-...', 'Product X', ...);
-- Expected: Success
```

---

### Test 10: JOIN Queries
**Objective**: Verify RLS applies to JOIN queries

**Tests**:
```sql
-- As User A
SELECT s.*, si.* 
FROM sales s
JOIN sale_items si ON s.id = si.sale_id
WHERE s.invoice_number = 'INV-B-001'; -- Tenant B's invoice
-- Expected: 0 rows (RLS filters out Tenant B's data)

-- Complex query with multiple joins
SELECT 
  s.invoice_number,
  c.name as customer_name,
  p.name as product_name
FROM sales s
JOIN customers c ON c.id = s.customer_id
JOIN sale_items si ON si.sale_id = s.id
JOIN products p ON p.id = si.product_id;
-- Expected: Only returns data from Tenant A (all tables filtered by RLS)
```

---

## Test Execution Methods

### Method 1: SQL Script (Manual)
Run SQL commands in Supabase SQL Editor with different authenticated users.

### Method 2: Automated Test Script
Create a Node.js script using Supabase client library:

```javascript
// test_rls.mjs
import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = 'https://your-project.supabase.co';
const SUPABASE_KEY = 'your-service-role-key';

async function testRLS() {
  // Create clients for different users
  const userAClient = createClient(SUPABASE_URL, SUPABASE_KEY);
  const userBClient = createClient(SUPABASE_URL, SUPABASE_KEY);
  
  // Sign in as User A
  await userAClient.auth.signInWithPassword({
    email: 'admin-a@test.com',
    password: 'test123'
  });
  
  // Test: User A tries to read all products
  const { data: productsA } = await userAClient
    .from('products')
    .select('*');
  
  console.log('User A sees products:', productsA.length);
  console.assert(
    productsA.every(p => p.tenant_id === TENANT_A_ID),
    'User A should only see Tenant A products'
  );
  
  // More tests...
}

testRLS();
```

### Method 3: Application-Level Test
Test through the Flutter app by:
1. Login as User A
2. Create products, invoices
3. Logout
4. Login as User B
5. Verify User B cannot see User A's data

---

## Expected Results Summary

| Test Case | User A Access | User B Access | Super Admin Access |
|-----------|---------------|---------------|-------------------|
| Tenant A Products | ✅ See all | ❌ See none | ✅ See all |
| Tenant B Products | ❌ See none | ✅ See all | ✅ See all |
| Tenant A Sales | ✅ See all | ❌ See none | ✅ See all |
| Tenant B Customers | ❌ See none | ✅ See all | ✅ See all |
| Demo Requests | ❌ See none | ❌ See none | ✅ See all |

---

## Known Issues / Limitations

### From IMPLEMENTATION_STATUS.md:
- ⚠️ RLS policies are written but **NOT YET TESTED** in production
- ⚠️ Need to verify policies work with real multi-tenant data
- ⚠️ Migration testing required before production deployment

---

## Remediation Plan (If RLS Fails)

### If Tenant Isolation Fails:
1. Check `get_current_tenant_id()` returns correct UUID
2. Verify `auth.uid()` is set when user is authenticated
3. Check that `users.tenant_id` is populated correctly
4. Verify all tables have `tenant_id` column
5. Ensure RLS is enabled: `ALTER TABLE table_name ENABLE ROW LEVEL SECURITY;`
6. Check policy conditions use `user_has_tenant_access(tenant_id)`

### If Super Admin Cannot Access All Data:
1. Verify `is_super_admin()` function works
2. Check `users.role = 'super_admin'` for the user
3. Ensure policies include `is_super_admin()` in USING clause

### Common RLS Gotchas:
- **Missing tenant_id on INSERT**: WITH CHECK fails silently → 0 rows inserted
- **NULL tenant_id**: RLS denies access (NULL != UUID comparison)
- **Anonymous access**: Need `TO anon` in GRANT and policy
- **Service role bypasses RLS**: Don't use service_role_key in app!

---

## Test Completion Checklist

- [ ] All 10 test cases executed
- [ ] All assertions pass
- [ ] Cross-tenant access denied for regular users
- [ ] Super admin can access all tenants
- [ ] No data leakage in JOIN queries
- [ ] Helper functions return correct values
- [ ] Performance is acceptable (RLS adds minimal overhead)
- [ ] Documented any issues found
- [ ] Remediation applied if needed
- [ ] Production deployment approved

---

## Recommendation

**CRITICAL**: Do NOT deploy to production with multiple real tenants until RLS testing is complete and passing.

**Current Status**: ⚠️ **TESTING REQUIRED**
- RLS policies exist and look correct
- No production testing has been done
- Need to verify with actual tenant data

**Next Steps**:
1. Create test tenants and users in Supabase
2. Run Test Cases 1-10
3. Fix any issues found
4. Document test results
5. Get approval for production deployment
