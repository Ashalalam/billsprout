# BillSprout - Multi-Tenant Pharmacy ERP

A comprehensive pharmacy and medical store management system built with Flutter (Windows/Web) and Supabase backend.

## 🚀 Features

### ✅ Completed Features

#### 💳 PayPal QR Code Payments
- QR code generation at POS checkout
- PayPal.Me link integration
- Real-time payment confirmation
- Copy-to-clipboard functionality

#### 🏥 Multi-Tenant Architecture
- Complete tenant isolation
- Branch management
- Role-based access control (Super Admin, Business Admin, Pharmacist, Cashier, Customer)
- Secure authentication with Supabase

#### 📦 Inventory Management
- Medicine/product catalog with batch tracking
- Expiry date monitoring
- Stock alerts and low-stock notifications
- Barcode scanning support
- Schedule H/H1/Narcotic drug controls
- Multi-packaging support (strips, boxes, cases)

#### 💰 Point of Sale (POS)
- Fast billing interface
- Multiple payment modes (Cash, Card, UPI, PayPal)
- Customer management
- Prescription tracking
- Invoice generation with GST

#### 📊 Business Intelligence
- Real-time dashboard analytics
- Sales reports and trends
- Top-selling products
- Revenue insights
- Inventory reports

#### 🔄 Data Sync
- Real-time Supabase synchronization
- Offline-capable local storage
- UUID-based data integrity
- Multi-tenant data isolation

## 🛠️ Tech Stack

- **Frontend**: Flutter 3.13+ (Web + Windows)
- **Backend**: Supabase (PostgreSQL + Auth + Storage)
- **Payment**: PayPal API
- **State Management**: Provider
- **Local Storage**: SharedPreferences
- **Charts**: FL Chart
- **QR Generation**: qr_flutter

## 🌐 Deployment

### Vercel (Web App)
```bash
# Deploy to Vercel
vercel --prod
```

### Windows Desktop
```bash
# Build for Windows
flutter build windows --release
```

## 🔑 Environment Variables

Create a `.env` file with:

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

# PayPal Configuration
PAYPAL_CLIENT_ID=your-client-id
PAYPAL_SECRET_KEY=your-secret-key
PAYPAL_ME_USERNAME=YourPayPalUsername
PAYPAL_SANDBOX=false

# Support
CUSTOMER_CARE_EMAIL=info@lifesproutcare.com
TECHNICAL_SUPPORT_EMAIL=support@billsprout.online
WHATSAPP_SUPPORT_NUMBER=+44 7747 571513
```

## 👥 Default Credentials

All users have password: `password123`

- **Super Admin**: superadmin@lifesprout.com
- **Business Admin**: admin@lifesproutcare.com
- **Pharmacist**: priya@medicare.com
- **Customer**: customer@lifesprout.com

**Pharmacist PIN**: `1234`

## 📱 Usage

### For Pharmacy Owners
1. Login with business admin credentials
2. Manage inventory and add medicines
3. Configure branches and staff
4. Process sales at POS
5. Accept PayPal QR payments
6. View analytics and reports

### For Customers
1. Browse products
2. Upload prescriptions
3. Track orders
4. Set up chronic refill reminders
5. Pay via PayPal QR code

## 🔧 Admin Tools

Located in `tool/` directory:

- `test_paypal_config.mjs` - Verify PayPal setup
- `verify_data_in_supabase.mjs` - Check database sync
- `reset_user_passwords.mjs` - Reset user passwords
- `list_users_with_credentials.mjs` - List all users
- `create_branch_for_tenant.mjs` - Create new branch

Run with: `node tool/[script-name].mjs`

## 📦 Installation

### Prerequisites
- Flutter SDK 3.13+
- Node.js 18+ (for admin tools)
- Supabase account
- PayPal Business account

### Setup
```bash
# Clone repository
git clone https://github.com/Ashalalam/billsprout.git
cd lifesprout

# Install dependencies
flutter pub get

# Run on web
flutter run -d chrome

# Run on Windows
flutter run -d windows
```

## 🗄️ Database

### Migrations
Located in `supabase/migrations/`

Apply via Supabase Dashboard or:
```bash
node tool/apply_migration_direct.mjs
```

### Tables
- `tenants` - Pharmacy/business entities
- `branches` - Store locations
- `users` - User accounts with roles
- `products` - Medicine catalog
- `batches` - Inventory batches
- `customers` - Customer records
- `sales` - Transaction history
- `invoices` - Billing records

## 🔐 Security

- Row Level Security (RLS) enabled on all tables
- Tenant isolation enforced at database level
- Secure authentication via Supabase
- Environment variables for sensitive data
- HTTPS enforced in production

## 📄 License

Proprietary - All Rights Reserved
© 2024 LifeSprout Care

## 🤝 Support

- **Email**: support@billsprout.online
- **WhatsApp**: +44 7747 571513
- **Website**: Coming Soon

## 🚧 Roadmap

- [ ] Mobile apps (iOS/Android)
- [ ] Supplier management
- [ ] Purchase orders
- [ ] Accounting integration
- [ ] Multi-language support
- [ ] SMS notifications
- [ ] Email marketing
- [ ] Loyalty programs

## 📸 Screenshots

Coming Soon

---

**Built with ❤️ by LifeSprout Care Team**
