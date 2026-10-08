# 🚀 BillSprout Supabase Setup Guide

## Step 1: Apply Database Schema

1. **Open Supabase Dashboard**: Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. **Select Your Project**: Click on your project `juvbhjqaioevpusnmonz`
3. **Open SQL Editor**: Navigate to "SQL Editor" → "New Query"
4. **Copy & Paste**: Copy the entire content from `supabase/APPLY_THIS_IN_SUPABASE.sql` and paste it in the query editor
5. **Run Query**: Click the "Run" button to apply the schema

## Step 2: Create Demo Users

Run this command from your BillSprout directory:

```bash
cd tool
node setup_demo_users.mjs
```

## Step 3: Login to Your App

Your app is running at: **Chrome Browser** (should be open automatically)

### 🔑 Login Credentials:

#### Super Admin (Full System Access)
- **Email**: `superadmin@billsprout.online`  
- **Password**: `SuperAdmin@123`
- **Access**: All tenants, system management, global admin features

#### Business Admin (LifeSprout Care)
- **Email**: `admin@lifesproutcare.com`
- **Password**: `admin123`
- **Access**: Full ERP/POS system for LifeSprout Care business

#### Customer Portal
- **Email**: `patient@lifesproutcare.com`
- **Password**: `patient123`  
- **Access**: Customer portal, purchase history, refill requests

## 🎉 What You Get

### Real-Time Features ✨
- **Live Database**: All data stored in PostgreSQL via Supabase
- **Real-Time Sync**: Multiple users, devices sync instantly
- **Cloud Storage**: Files, images, documents stored in Supabase Storage
- **Authentication**: Secure JWT-based auth with role permissions
- **Multi-Tenant**: Support for multiple businesses/pharmacies

### Business Features 💼
- **Point of Sale (POS)**: Complete billing system
- **Inventory Management**: Stock tracking, expiry alerts, batch management
- **Customer Management**: Patient records, purchase history, chronic medicine tracking  
- **Accounting**: Ledger entries, financial reporting
- **Pharmacy Compliance**: Schedule H/H1 drug logging, pharmacist PIN verification
- **Multi-Branch**: Support for multiple store locations
- **Subscription Management**: Software licensing and billing

### Admin Features ⚙️
- **Tenant Management**: Create/manage multiple businesses
- **User Roles**: Super Admin, Business Admin, Pharmacist, Cashier, Customer
- **Software Distribution**: Download management for desktop apps
- **Analytics**: Usage tracking, audit logs, security monitoring

## 🛠️ Troubleshooting

### Issue: "User not found in database"
**Solution**: Make sure you've run Step 2 (Create Demo Users) after applying the schema.

### Issue: "Row-level security policy violation"  
**Solution**: The database schema wasn't applied correctly. Re-run Step 1.

### Issue: "Authentication failed"
**Solution**: Use the exact credentials provided above. Check for typos.

## 📱 Next Steps

1. **Add Sample Data**: Run `dart run tool/seed_medicines.dart` to add sample medicines
2. **Test POS**: Create a test sale using the business admin account
3. **Explore Features**: Try customer portal, inventory management, reports
4. **Multi-User**: Login from different devices/browsers to see real-time sync

## 🔧 Development

- **Hot Reload**: Press `r` in the terminal to reload changes
- **Debug Tools**: Available at the DevTools URL shown in terminal
- **Database**: View data in Supabase Dashboard → Table Editor
- **Logs**: Check Supabase Dashboard → Logs for any database errors

---

**🎯 You now have a fully functional, real-time ERP/POS system with cloud database!**