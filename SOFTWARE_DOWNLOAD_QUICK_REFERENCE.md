# BillSprout Software Download System - Quick Reference

## 🚀 Quick Start

### For Super Admin

1. **Upload Software:**
   - Dashboard → **Software** tab → **Upload New Version**
   - Fill version info → Select file → Upload

2. **Manage Access:**
   - **Business Admin Access** tab → Select tenant → **Suspend/Activate**

3. **View Activity:**
   - **Download History** tab → See all download attempts

### For Business Admin

1. **Download Software:**
   - Side menu → **Software**
   - Check subscription status → Click **Download**

2. **Copy License Key:**
   - Software page → License key shown → Click copy icon

---

## 📋 System Status Indicators

| Status | Color | Meaning |
|--------|-------|---------|
| ACTIVE | 🟢 Green | Authorized to download |
| SUSPENDED | 🔴 Red | Access suspended by admin |
| INACTIVE | ⚫ Grey | Subscription not active |
| LATEST | 🔵 Blue | Most recent version |

---

## 🔐 Authorization Requirements

Business Admin can download ONLY if ALL are true:
- ✅ Account Status = `active`
- ✅ Subscription Status = `active`
- ✅ License Status = `active`
- ✅ Payment verified
- ✅ Subscription end date ≥ today

---

## 🗂️ File Locations

### Code Files
```
lib/
├── services/
│   └── supabase_service.dart          # Software operations methods
├── views/
│   ├── super_admin/
│   │   └── software_management_view.dart  # Super Admin UI
│   └── business_admin/
│       └── software_download_view.dart    # Business Admin UI
└── widgets/
    └── status_badge.dart              # Status display widget
```

### Database Files
```
supabase/
├── migrations/
│   └── 023_software_downloads_enhancement.sql  # Migration SQL
└── functions/
    └── download-software/
        └── index.ts                    # Edge Function
```

---

## 🗄️ Database Tables

### Key Tables
- **tenants** - Added `access_status` column
- **subscriptions** - Added `license_key`, `license_status`
- **software_versions** - Software metadata
- **download_logs** - Download tracking

### Key Functions
- `can_download_software(tenant_id)` - Returns boolean
- `get_download_authorization(tenant_id)` - Returns detailed status

### Key Views
- `business_admin_access_overview` - Admin dashboard data

---

## 🌐 API Endpoints

### Edge Function
```
POST https://YOUR_PROJECT.supabase.co/functions/v1/download-software

Headers:
  Authorization: Bearer YOUR_ANON_KEY
  Content-Type: application/json

Body:
{
  "tenant_id": "uuid",
  "version_id": "uuid"
}

Response (Success):
{
  "download_url": "https://...",
  "expires_in": 3600
}

Response (Error):
{
  "error": "Not authorized to download software"
}
```

---

## 🔧 Common Commands

### Supabase CLI
```bash
# Deploy Edge Function
supabase functions deploy download-software

# Check function logs
supabase functions logs download-software

# List all functions
supabase functions list

# Set environment secrets
supabase secrets set SUPABASE_URL=...
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=...
```

### Flutter
```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Build for production (Windows)
flutter build windows --release

# Build for production (Web)
flutter build web --release

# Clear cache
flutter clean
```

### Database Queries
```sql
-- Check authorization for tenant
SELECT * FROM get_download_authorization('tenant-uuid');

-- View all software versions
SELECT * FROM software_versions ORDER BY release_date DESC;

-- View download history
SELECT * FROM download_logs ORDER BY downloaded_at DESC LIMIT 20;

-- List suspended tenants
SELECT business_name FROM tenants WHERE access_status = 'suspended';
```

---

## ⚠️ Troubleshooting Quick Fixes

| Problem | Quick Fix |
|---------|-----------|
| Download fails | Check Edge Function logs: `supabase functions logs download-software` |
| Cannot upload | Verify storage bucket exists and is private |
| No authorization | Run: `SELECT * FROM get_download_authorization('tenant-id')` |
| Menu not showing | Run: `flutter clean` then `flutter run` |
| Function error | Verify secrets: `supabase secrets list` |

---

## 📞 Support Contacts

- **Email:** arifsheik@lifesproutcare.com
- **Documentation:** SOFTWARE_DOWNLOAD_DEPLOYMENT_GUIDE.md
- **Edge Function Code:** supabase/functions/download-software/index.ts

---

## 🔢 Version Information

- **Migration:** 023_software_downloads_enhancement.sql
- **Edge Function:** download-software v1.0
- **UI Components:** software_management_view.dart, software_download_view.dart
- **API Methods:** 10+ new methods in supabase_service.dart

---

## ✅ Pre-Launch Checklist

- [ ] Migration 023 applied
- [ ] Storage bucket `software` created (private)
- [ ] Edge Function deployed
- [ ] Environment secrets set
- [ ] Test upload successful
- [ ] Test download successful
- [ ] Test suspension works
- [ ] Download logs captured
- [ ] All existing tenants have `access_status = 'active'`

---

*Last Updated: [Date]*
