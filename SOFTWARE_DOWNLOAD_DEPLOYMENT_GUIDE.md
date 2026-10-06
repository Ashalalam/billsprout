# BillSprout Software Download & License Access System - Deployment Guide

## Overview

This guide covers the complete deployment of the software download and license access system for BillSprout ERP. The system enables Business Admins to download authorized software based on their subscription status, with Super Admin controls for software management and access suspension.

---

## System Architecture

### Key Components

1. **Database Layer** (Supabase PostgreSQL)
   - Enhanced tables: `tenants`, `subscriptions`, `software_versions`, `download_logs`
   - Authorization functions: `can_download_software()`, `get_download_authorization()`
   - Admin view: `business_admin_access_overview`

2. **Storage Layer** (Supabase Storage)
   - Private bucket: `software`
   - Signed URLs with 1-hour expiry
   - Platform-based organization: `software/{platform}/{filename}`

3. **Edge Functions** (Supabase Functions)
   - `download-software` - Generates authorized download URLs with authorization checks

4. **Frontend UI** (Flutter)
   - Super Admin: Software Management View (upload, version control, access management)
   - Business Admin: Software Download View (subscription status, authorized downloads)

---

## Prerequisites

Before deployment, ensure you have:

- ✅ Supabase project with database access
- ✅ Supabase CLI installed (`npm install -g supabase`)
- ✅ Flutter environment set up (for testing)
- ✅ Razorpay account configured (existing)
- ✅ Existing subscription system in place (migration 017)

---

## Step 1: Apply Database Migration

### Option A: Using Supabase SQL Editor (Recommended)

1. **Open Supabase Dashboard**
   - Navigate to: https://supabase.com/dashboard
   - Select your project
   - Go to **SQL Editor**

2. **Copy Migration SQL**
   - Open: `supabase/migrations/023_software_downloads_enhancement.sql`
   - Copy the entire contents

3. **Execute Migration**
   - Paste into SQL Editor
   - Click **Run**
   - Verify success message

### Option B: Using PowerShell Script

```powershell
# Run from project root
.\APPLY_SOFTWARE_MIGRATION.ps1
```

The script will:
- Prompt for your Supabase project URL and service role key
- Apply migration 023
- Display success/error messages

### Verify Migration Success

Run this query in SQL Editor to verify:

```sql
-- Check if access_status column exists
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'tenants' AND column_name = 'access_status';

-- Check if authorization function exists
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name = 'can_download_software';

-- Check if admin view exists
SELECT table_name 
FROM information_schema.views 
WHERE table_name = 'business_admin_access_overview';
```

Expected results:
- `access_status` column should exist in `tenants` table
- `can_download_software` function should exist
- `business_admin_access_overview` view should exist

---

## Step 2: Create Supabase Storage Bucket

### Create Private Storage Bucket

1. **Navigate to Storage**
   - Supabase Dashboard → Storage
   - Click **New bucket**

2. **Configure Bucket**
   - **Name:** `software`
   - **Public:** ❌ **UNCHECKED** (must be private!)
   - **File size limit:** 500 MB (adjust as needed)
   - **Allowed MIME types:** Leave empty (allow all)

3. **Set Bucket Policies**
   - Go to **Policies** tab for the `software` bucket
   - Click **New Policy**

**Policy 1: Super Admin Upload**
```sql
-- Name: Super Admin can upload software
-- Allowed operations: INSERT
-- Target roles: authenticated

CREATE POLICY "Super Admin can upload software"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'software' 
  AND auth.jwt() ->> 'role' = 'super_admin'
);
```

**Policy 2: Authorized Download via Edge Function**
```sql
-- Name: Authorized downloads via service role
-- Allowed operations: SELECT
-- Target roles: service_role

-- Note: This is automatically allowed for service_role
-- Edge Function uses service_role key to generate signed URLs
```

### Verify Storage Bucket

1. Try uploading a test file manually
2. Verify it's not publicly accessible
3. Delete the test file

---

## Step 3: Deploy Edge Function

### Deploy download-software Function

The Edge Function is already created at: `supabase/functions/download-software/index.ts`

**Deploy using Supabase CLI:**

```bash
# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Deploy the function
supabase functions deploy download-software

# Verify deployment
supabase functions list
```

### Set Environment Variables

The function needs access to your Supabase URL and service role key:

```bash
# Set secrets for the function
supabase secrets set SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
```

### Test Edge Function

Test the function using curl:

```bash
curl -X POST 'https://YOUR_PROJECT_REF.supabase.co/functions/v1/download-software' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{
    "tenant_id": "test-tenant-uuid",
    "version_id": "test-version-uuid"
  }'
```

Expected responses:
- ✅ **Success:** `{"download_url": "https://...", "expires_in": 3600}`
- ❌ **Unauthorized:** `{"error": "Not authorized to download software"}`
- ❌ **Not Found:** `{"error": "Software version not found"}`

---

## Step 4: Update Existing Tenants

### Add Default Access Status

All existing tenants need the `access_status` field populated:

```sql
-- Set all existing tenants to 'active' status
UPDATE tenants 
SET access_status = 'active' 
WHERE access_status IS NULL;
```

### Verify Active Subscriptions

Check which tenants have active subscriptions:

```sql
-- View subscription status for all tenants
SELECT 
  t.business_name,
  t.access_status,
  s.status as subscription_status,
  s.license_status,
  s.end_date
FROM tenants t
LEFT JOIN subscriptions s ON s.tenant_id = t.id
ORDER BY t.business_name;
```

---

## Step 5: Test Complete Flow

### Test Checklist

#### ✅ Super Admin Tests

1. **Login as Super Admin**
   - Navigate to **Software** tab in Super Admin dashboard

2. **Upload Software Version**
   - Click **Upload New Version**
   - Fill in: Version Number (e.g., `1.0.0`), Platform (`windows`), Release Notes
   - Select a test file (any file works for testing)
   - Mark as **Latest Version**
   - Click **Upload**
   - Verify: Version appears in the list

3. **Manage Business Admin Access**
   - Switch to **Business Admin Access** tab
   - Verify: All tenants listed with their access status
   - Test **Suspend Access** on a test tenant
   - Verify: Status changes to SUSPENDED
   - Test **Activate Access** to restore

4. **View Download History**
   - Switch to **Download History** tab
   - Verify: Shows empty list (no downloads yet)

#### ✅ Business Admin Tests

1. **Login as Business Admin** (with active subscription)
   - Navigate to **Software** in the side menu

2. **Verify Subscription Display**
   - Check: Subscription card shows plan name, status, end date
   - Check: License key is displayed and copyable
   - Verify: Authorization card shows "Download Authorized" (green)

3. **Test Authorized Download**
   - Find the software version in "Available Downloads"
   - Click **Download** button
   - Verify: Download starts in browser
   - Check: Success message appears

4. **Test Suspension Scenario**
   - Have Super Admin suspend this tenant
   - Refresh the Software Download page
   - Verify: Authorization card shows "Download Not Authorized" (red)
   - Try downloading: Should show error "You are not authorized to download software"

5. **Test Without Subscription**
   - Login as Business Admin without active subscription
   - Navigate to Software page
   - Verify: Shows "No Active Subscription" warning
   - Verify: "View Plans & Subscribe" button appears
   - Download buttons should be disabled

#### ✅ Database Verification

1. **Check Download Logs**
```sql
SELECT 
  dl.*,
  t.business_name,
  u.email as user_email,
  sv.version_number
FROM download_logs dl
JOIN tenants t ON t.id = dl.tenant_id
JOIN profiles u ON u.id = dl.user_id
JOIN software_versions sv ON sv.id = dl.version_id
ORDER BY dl.downloaded_at DESC
LIMIT 10;
```

2. **Check Authorization Function**
```sql
-- Test authorization for a specific tenant
SELECT * FROM get_download_authorization('tenant-uuid-here');
```

Expected response:
```json
{
  "authorized": true,
  "reason": "Access granted. Active subscription with valid license."
}
```

---

## Step 6: Flutter Build & Deploy

### Update Dependencies

Ensure these packages are in `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.0
  supabase_flutter: ^2.0.0
  intl: ^0.18.0
  url_launcher: ^6.2.0
  file_picker: ^6.0.0
```

Run:
```bash
flutter pub get
```

### Test Locally

```bash
# Run in debug mode
flutter run

# Or for web
flutter run -d chrome
```

### Build for Production

**Windows:**
```bash
flutter build windows --release
```

**Web:**
```bash
flutter build web --release
```

**Android:**
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

---

## Step 7: Configure Environment Variables

### Update .env File

Ensure your `.env` file includes:

```env
# Supabase Configuration
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here

# Razorpay Configuration (existing)
RAZORPAY_KEY_ID=your_razorpay_key_id
RAZORPAY_KEY_SECRET=your_razorpay_key_secret

# Email Configuration (existing)
RESEND_API_KEY=your_resend_api_key
```

**Security Note:** Never commit `.env` to version control. Ensure it's in `.gitignore`.

---

## Usage Workflows

### Workflow 1: Business Admin Downloads Software

```
1. Business Admin visits Pricing Page
2. Selects subscription plan → Clicks "Buy Now"
3. Razorpay checkout opens → Completes payment
4. Payment verified → Subscription activated
5. License key auto-generated and stored
6. Business Admin navigates to Software menu
7. Views subscription status (Active)
8. Sees license key (copyable)
9. Clicks Download on desired version
10. Authorization checked server-side
11. Signed URL generated (1-hour expiry)
12. Download starts in browser
13. Download logged in database
```

### Workflow 2: Super Admin Suspends Access

```
1. Super Admin opens Software Management
2. Switches to "Business Admin Access" tab
3. Finds tenant to suspend
4. Clicks "Suspend Access"
5. Confirms action
6. Tenant access_status → 'suspended'
7. Business Admin immediately cannot download
8. Existing downloads continue (signed URL valid until expiry)
9. Super Admin can reactivate anytime
```

### Workflow 3: Super Admin Uploads New Version

```
1. Super Admin opens Software Management
2. Clicks "Upload New Version"
3. Fills in: Version Number, Platform, Release Notes
4. Selects software file from computer
5. Optionally marks as "Latest Version"
6. Clicks Upload
7. File uploaded to Supabase Storage (software bucket)
8. Database record created in software_versions
9. Version immediately available to authorized Business Admins
10. Download count tracked automatically
```

---

## Authorization Rules Summary

| Condition | Can Download? | Reason |
|-----------|--------------|--------|
| Active subscription + Active license + Active access | ✅ Yes | Fully authorized |
| Active subscription + Inactive license | ❌ No | License not activated |
| Active subscription + Suspended access | ❌ No | Admin suspended access |
| Expired subscription | ❌ No | Subscription expired |
| No subscription | ❌ No | No subscription found |
| Pending payment | ❌ No | Payment not verified |

---

## Security Considerations

### ✅ Implemented Security Measures

1. **Private Storage Bucket**
   - Software files NOT publicly accessible
   - Requires signed URL with authorization

2. **Server-Side Authorization**
   - Edge Function verifies: user identity, tenant access, subscription status, license status
   - Frontend cannot bypass authorization

3. **Time-Limited URLs**
   - Signed URLs expire in 1 hour
   - Cannot be reused after expiry
   - New authorization required for each download

4. **Download Logging**
   - Every download attempt logged (authorized or denied)
   - Tracks: user, tenant, version, IP, timestamp, authorization status

5. **Role-Based Access**
   - Only Super Admins can upload software
   - Only Super Admins can suspend access
   - Business Admins can only download (if authorized)

### 🔒 Additional Recommendations

1. **Enable RLS Policies**
   - Ensure Row Level Security is enabled on all tables
   - Verify policies restrict access appropriately

2. **Monitor Download Logs**
   - Set up alerts for repeated failed download attempts
   - Review unauthorized access attempts

3. **Backup Software Files**
   - Regularly backup Supabase Storage bucket
   - Store master copies externally

4. **Version Control**
   - Keep software versions documented
   - Maintain changelog for each release

---

## Troubleshooting

### Issue: "Download authorization failed"

**Possible Causes:**
- Edge Function not deployed
- Function environment variables not set
- Tenant access suspended
- Subscription expired

**Solution:**
```bash
# Check function logs
supabase functions logs download-software

# Verify function is deployed
supabase functions list

# Test authorization function
SELECT * FROM get_download_authorization('tenant-uuid');
```

---

### Issue: "Software file not found"

**Possible Causes:**
- File not uploaded to storage
- File path mismatch
- Storage bucket permissions incorrect

**Solution:**
```sql
-- Check file path in database
SELECT file_path FROM software_versions WHERE id = 'version-uuid';

-- Verify file exists in storage bucket
-- Go to Supabase Dashboard → Storage → software bucket
```

---

### Issue: "Cannot upload software"

**Possible Causes:**
- Storage bucket doesn't exist
- Bucket is public (should be private)
- Super Admin role not set correctly

**Solution:**
1. Verify bucket exists and is private
2. Check Super Admin role in database:
```sql
SELECT id, email, role FROM profiles WHERE role = 'super_admin';
```

---

### Issue: "Business Admin cannot see Software menu"

**Possible Causes:**
- Navigation not updated
- Cache issue

**Solution:**
1. Clear Flutter build cache: `flutter clean`
2. Rebuild: `flutter run`
3. Hard refresh browser (Ctrl+Shift+R)

---

## Monitoring & Maintenance

### Regular Tasks

**Daily:**
- Monitor download logs for errors
- Check Edge Function logs for issues

**Weekly:**
- Review Business Admin access statuses
- Verify all active subscriptions have valid licenses

**Monthly:**
- Backup software files from Supabase Storage
- Clean up old software versions (archive obsolete versions)
- Review download statistics

### SQL Queries for Monitoring

**Download Statistics:**
```sql
-- Total downloads by version
SELECT 
  sv.version_number,
  sv.platform,
  COUNT(*) as download_count,
  COUNT(*) FILTER (WHERE dl.was_authorized = true) as authorized_downloads,
  COUNT(*) FILTER (WHERE dl.was_authorized = false) as denied_downloads
FROM software_versions sv
LEFT JOIN download_logs dl ON dl.version_id = sv.id
GROUP BY sv.id, sv.version_number, sv.platform
ORDER BY download_count DESC;
```

**Active Subscriptions:**
```sql
-- Business Admins with active subscriptions
SELECT COUNT(*) as active_subscription_count
FROM subscriptions
WHERE status = 'active' 
  AND license_status = 'active'
  AND end_date >= CURRENT_DATE;
```

**Suspended Tenants:**
```sql
-- List of suspended tenants
SELECT business_name, access_status, created_at
FROM tenants
WHERE access_status = 'suspended'
ORDER BY business_name;
```

---

## Rollback Plan

If issues arise after deployment, follow this rollback procedure:

### Step 1: Revert Database Migration

```sql
-- Remove added columns
ALTER TABLE tenants DROP COLUMN IF EXISTS access_status;
ALTER TABLE subscriptions DROP COLUMN IF EXISTS license_key;
ALTER TABLE subscriptions DROP COLUMN IF EXISTS license_status;
ALTER TABLE software_versions DROP COLUMN IF EXISTS file_path;

-- Drop functions
DROP FUNCTION IF EXISTS can_download_software(UUID);
DROP FUNCTION IF EXISTS get_download_authorization(UUID);

-- Drop view
DROP VIEW IF EXISTS business_admin_access_overview;
```

### Step 2: Remove Storage Bucket

1. Supabase Dashboard → Storage
2. Select `software` bucket
3. **Delete bucket** (backup files first!)

### Step 3: Remove Edge Function

```bash
supabase functions delete download-software
```

### Step 4: Revert Code Changes

```bash
git revert HEAD~1  # Revert last commit
# or
git checkout main  # Checkout main branch
```

---

## Support & Contact

For issues or questions:

- **Technical Support:** arifsheik@lifesproutcare.com
- **Documentation:** This file
- **GitHub Issues:** [Create issue in repository]

---

## Changelog

### Version 1.0.0 (Initial Release)
- ✅ Database schema enhancement (migration 023)
- ✅ Supabase Storage integration
- ✅ Edge Function for authorized downloads
- ✅ Super Admin software management UI
- ✅ Business Admin software download UI
- ✅ Authorization and access control
- ✅ Download logging and analytics

---

## Next Steps After Deployment

1. ✅ Upload first software version via Super Admin UI
2. ✅ Test complete flow with test Business Admin account
3. ✅ Notify existing Business Admins about new software download feature
4. ✅ Monitor download logs for first week
5. ✅ Gather user feedback
6. 🔄 Plan future enhancements (auto-updates, version notifications, etc.)

---

**Deployment Date:** _To be filled after successful deployment_  
**Deployed By:** _To be filled_  
**Production URL:** _To be filled_

---

*End of Deployment Guide*
