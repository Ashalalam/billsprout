# LifeSprout / BillSprout - User Roles & Operations Guide

## 📋 Overview
BillSprout is a comprehensive Smart ERP & Billing System for pharmacy and retail businesses. It supports three distinct user roles, each with specific functionalities.

---

## 🔐 1. SUPER ADMIN PORTAL

**Login Email:** `superadmin@billsprout.online`

### Purpose
SaaS platform management console for managing multiple business tenants (stores/pharmacies).

### Main Features

#### 📊 **Overview Dashboard**
- **Platform Metrics:**
  - Active client companies count
  - Platform revenue monitoring
  - Total invoices across all tenants
  - OTA (Over-The-Air) update status
  
- **Tenant Management:**
  - Create new business tenant accounts
  - View recently provisioned tenants
  - Monitor tenant activity status
  
- **System Health:**
  - Supabase PostgreSQL connection status
  - Real-time replication monitoring
  - Backend configuration management

#### 🏢 **Tenant Accounts Tab**
- **Complete Tenant List:**
  - Business name & owner details
  - Email & phone contacts
  - GSTIN & Drug License numbers
  - Industry type classification (Pharma, Retail, Wholesale, FMCG)
  - Account creation dates
  
- **Tenant Operations:**
  - Add new tenant accounts
  - Toggle tenant active/inactive status
  - View full tenant details
  - Manage subscriptions
  
- **Industries Supported:**
  - Pharma (pharmacy/medical)
  - Retail Supermarket
  - Wholesale Distribution
  - FMCG & Manufacturing

#### 📈 **Analytics Tab**
- **Revenue Analytics:**
  - Monthly platform revenue trends (12-month bar chart)
  - Real-time POS data integration
  - Revenue progression tracking (Oct 2025 - Sep 2026)
  
- **Industry Breakdown:**
  - Tenant distribution by industry type (pie chart)
  - Market segment analysis
  
- **Live Data Integration:**
  - Real invoice counts
  - Actual revenue from accounting ledger
  - Synced with business admin POS transactions

#### ⚙️ **Additional Capabilities**
- Configure Supabase backend credentials
- Apply OTA updates to platform
- Access support desk
- Manage system version information

---

## 🏪 2. BUSINESS ADMIN / STAFF PORTAL

**Login Email:** `admin@lifesproutcare.com`

### Purpose
Complete store/pharmacy management system for day-to-day business operations.

### Main Features

#### 📊 **1. Sales Dashboard**
- Daily/weekly/monthly sales overview
- Revenue analytics and trends
- Top-selling products
- Performance metrics
- Real-time business insights

#### 💳 **2. POS Billing System**
- **Complete Point of Sale:**
  - Product search with barcode scanner
  - Cart management
  - Real-time inventory checking
  - Multiple payment modes (Cash, Card, UPI, Digital Wallet)
  - Customer selection/creation
  - Doctor prescription linking
  
- **Restricted Drug Authorization:**
  - Schedule H / H1 / Narcotic medication detection
  - Pharmacist PIN verification (default: 1234)
  - Legal compliance enforcement
  - Prescription requirement validation
  
- **Invoice Generation:**
  - GST-compliant billing
  - Tax calculations (CGST, SGST, IGST)
  - Discount management
  - PDF invoice generation
  - QR code for payment
  - WhatsApp sharing

#### 📦 **3. Inventory Management**
- **Product Catalog:**
  - Add/edit/delete products
  - Medicine information (name, composition, manufacturer)
  - Stock levels tracking
  - Batch number management
  - Expiry date monitoring
  - MRP, purchase price, selling price
  - HSN/SAC codes for GST
  
- **Stock Operations:**
  - Stock updates
  - Reorder level alerts
  - Low stock notifications
  - Barcode generation and scanning
  
- **Drug Classification:**
  - Schedule H / H1 / Narcotic flags
  - OTC (Over-the-counter) vs Prescription
  - Chronic medication markers

#### 🔒 **4. Schedule H Register**
- **Legal Compliance:**
  - Complete record of restricted drug sales
  - Date, time, invoice number
  - Product details (name, batch, quantity)
  - Customer information
  - Doctor details (name, MCI registration)
  - Prescription reference
  - Pharmacist authorization trail
  
- **Reporting:**
  - Searchable register
  - Export capabilities
  - Regulatory audit trail
  - Government compliance reports

#### 💰 **5. GST Accounting**
- **Tax Management:**
  - GSTR-1 data preparation
  - GSTR-3B summary
  - Tax liability calculations
  - Input tax credit tracking
  
- **Financial Reports:**
  - Sales register
  - Purchase register
  - HSN-wise summary
  - Tax payable/receivable
  - Period-wise breakdowns

#### ⚠️ **6. Near Expiry Management**
- Products expiring within 90 days
- Expiry date monitoring
- Batch tracking
- Stock clearance alerts
- Return/replacement planning
- Supplier coordination

#### 🔄 **7. Stock Transfer**
- **Multi-location Support:**
  - Transfer between branches/stores
  - Transfer request creation
  - Approval workflows
  - Transit tracking
  - Receipt confirmation
  
- **Documentation:**
  - Transfer notes
  - Quantity verification
  - Batch validation
  - Cost tracking

#### 🛒 **8. Purchase Orders**
- **Vendor Management:**
  - Supplier database
  - Contact information
  - Credit terms
  
- **Order Processing:**
  - PO creation and management
  - Order status tracking
  - Goods receipt
  - Invoice matching
  - Payment tracking
  
- **Inventory Integration:**
  - Automatic stock updates
  - Batch entry
  - Expiry date capture
  - Cost price updates

#### 🏦 **9. Bank Reconciliation**
- **Financial Management:**
  - Bank statement matching
  - Transaction verification
  - Discrepancy identification
  - Outstanding items tracking
  
- **Payment Modes:**
  - Cash management
  - Card settlements
  - UPI reconciliation
  - Digital wallet tracking
  
- **Reports:**
  - Daily cash summary
  - Bank deposit tracking
  - Unmatched transactions
  - Reconciliation statements

#### ⚙️ **10. Settings**
- **Company Profile:**
  - Business name & logo
  - Address & contact details
  - GSTIN & Drug License
  - License validity tracking
  
- **Pharmacist PIN Management:**
  - Set/change authorization PIN
  - PIN recovery
  - Security settings
  
- **Industry Mode Switch:**
  - Pharma Mode (default)
  - Retail Supermarket
  - Wholesale Distribution
  - FMCG & Manufacturing
  - Restaurant & Hospitality
  
- **System Configuration:**
  - Invoice numbering
  - Tax settings
  - Printer configuration
  - Backup settings

### Additional Features
- **Offline Mode Support:**
  - Offline queue for transactions
  - Auto-sync when online
  - Connectivity detection
  
- **Sync Status:**
  - Real-time sync indicators
  - Pending transaction count
  - Supabase connection status
  
- **OTA Updates:**
  - Version checking
  - Update notifications
  - One-click updates
  - Release notes viewing
  
- **Support Integration:**
  - In-app support desk
  - WhatsApp support (+44 7747 571513)
  - Email support
  - Technical assistance

---

## 👤 3. CUSTOMER / PATIENT PORTAL

**Login Email:** `patient@lifesproutcare.com`

### Purpose
Patient-facing portal for medication management and purchase tracking.

### Main Features

#### 💊 **1. Chronic Refill Reminders**
- **Medication Tracking:**
  - Chronic medication list
  - Medicine names
  - Refill interval tracking (days)
  - Next refill due dates
  
- **Smart Alerts:**
  - Overdue medication warnings
  - Days-until-refill countdown
  - Visual indicators (color-coded)
  
- **1-Click Reorder:**
  - Direct WhatsApp ordering
  - Pre-filled order message
  - Quick refill requests
  - Auto-generated reminders

#### 📋 **2. Prescriptions Management**
- **Upload Doctor Prescriptions:**
  - Photo/PDF upload
  - Doctor details capture (name, MCI registration)
  - Prescribed medications list
  - Upload date tracking
  
- **Prescription History:**
  - All uploaded Rx files
  - Doctor information
  - Medication details
  - View/download prescriptions
  
- **Supported Formats:**
  - JPG images
  - PNG images
  - PDF documents
  - Max size: 5 MB

#### 🧾 **3. Purchase History**
- **Invoice Management:**
  - Complete purchase history
  - Invoice numbers & dates
  - Items purchased per transaction
  - Payment mode information
  - Total amounts
  
- **Summary Statistics:**
  - Total invoices count
  - Total amount spent
  - Last purchase date
  - Spending analytics
  
- **Invoice Details:**
  - Medicine names
  - Quantities purchased
  - Item-wise pricing
  - GST breakdown
  - Doctor prescription reference (if applicable)
  - Sync status indicators
  
- **Actions:**
  - Download PDF receipts
  - Share via WhatsApp
  - View detailed breakdowns
  - Track payment methods

#### 🆘 **Support Features**
- **Integrated Support:**
  - WhatsApp support button (+44 7747 571513)
  - Email support (info@lifesproutcare.com)
  - Technical support desk
  - Direct messaging

- **Profile Information:**
  - Patient name display
  - Contact details (phone, email)
  - Welcome personalization
  - Account management

---

## 🔄 SHARED FEATURES (All Portals)

### Authentication
- Email-based login
- Role-based access control
- Supabase authentication
- Demo mode support (no password required in demo)
- Secure logout

### Support System
- Multi-channel support desk
- WhatsApp integration (+44 7747 571513)
- Email support contacts
- In-app support modal

### Data Synchronization
- Real-time Supabase sync
- Offline queue management
- Auto-sync when online
- Sync status indicators
- Conflict resolution

### Responsive Design
- Mobile-friendly layouts
- Tablet optimization
- Desktop full-screen experience
- Navigation rail (desktop)
- Bottom navigation (mobile)
- Hamburger menu (mobile)

---

## 📊 KEY BUSINESS FLOWS

### 1. **Complete Sales Transaction (Business Admin)**
```
Product Selection → Cart Management → Customer Selection → 
Payment Mode → Restricted Drug Check → Pharmacist PIN (if needed) → 
Invoice Generation → Print/Share → Stock Update → Accounting Entry
```

### 2. **Patient Refill Order (Customer Portal)**
```
View Chronic Refills → Check Due Date → 1-Click Refill Order → 
WhatsApp Pre-filled Message → Pharmacy Receives Order → 
POS Billing → Invoice Generated → Added to Purchase History
```

### 3. **Prescription-based Purchase (Business + Customer)**
```
Customer: Upload Rx → Pharmacy: Verify Rx → POS: Link to Invoice → 
Restricted Drug Check → Pharmacist Authorization → 
Complete Sale → Update Schedule H Register → 
Customer: View in Purchase History
```

### 4. **Multi-Tenant Management (Super Admin)**
```
Create Tenant Account → Configure Business Details → 
Activate Account → Tenant Uses Business Portal → 
Super Admin Monitors Revenue → Analytics Dashboard → 
Generate Reports
```

---

## 🔒 SECURITY & COMPLIANCE

### Legal Compliance
- Schedule H / H1 / Narcotic drug tracking
- Pharmacist PIN authorization
- Doctor prescription requirements
- MCI registration verification
- Schedule H register maintenance
- GST compliance

### Data Security
- Supabase PostgreSQL backend
- Role-based access control
- Secure authentication
- Encrypted data transmission
- Regular backups

### Audit Trail
- Complete transaction history
- User action logging
- Pharmacist authorization records
- Stock movement tracking
- Financial transaction trail

---

## 📱 TECHNOLOGY STACK

### Frontend
- **Framework:** Flutter (Web, Mobile, Desktop)
- **State Management:** Provider
- **UI Components:** Material Design

### Backend
- **Database:** Supabase (PostgreSQL)
- **Authentication:** Supabase Auth
- **Real-time Sync:** Supabase Real-time
- **Storage:** Supabase Storage (for Rx uploads)

### Integrations
- **Barcode:** Mobile Scanner (camera-based)
- **PDF Generation:** pdf package
- **QR Codes:** qr_flutter
- **Charts:** fl_chart
- **Connectivity:** connectivity_plus
- **Printing:** printing package
- **WhatsApp:** url_launcher

---

## 📞 SUPPORT CONTACTS

- **Customer Care:** info@lifesproutcare.com
- **Technical Support:** Support@billsprout.online
- **WhatsApp:** +44 7747 571513
- **WhatsApp Link:** https://wa.me/447747571513

---

## 🎯 SYSTEM HIGHLIGHTS

### For Pharmacies
✅ Complete POS billing system
✅ Legal compliance for restricted drugs
✅ Inventory management with expiry tracking
✅ GST-compliant accounting
✅ Schedule H register maintenance
✅ Multi-location support

### For Patients
✅ Chronic medication reminders
✅ Prescription management
✅ Purchase history tracking
✅ 1-click reorder functionality
✅ WhatsApp integration

### For Platform Owners
✅ Multi-tenant SaaS architecture
✅ Revenue analytics & tracking
✅ Tenant account management
✅ OTA update system
✅ Industry-agnostic design

---

**Version:** v1.3.0+1 (OTA Ready)
**Last Updated:** 2026
**Company:** LIFESPROUT Care
