# 📦 How to Add Medicines to LifeSprout Inventory

## 🔐 Prerequisites
- You must be logged in as **Business Admin** or **Staff**
- Login Email: `admin@lifesproutcare.com`
- Navigate to the **Inventory** module from the main menu

---

## ✅ METHOD 1: Add Completely New Medicine

### Step-by-Step Process:

#### 1️⃣ **Access Inventory Module**
- From the Business Admin dashboard, click on **"Inventory"** in the navigation menu
- You'll see the **"FEFO Stock & Batches"** tab (first tab)

#### 2️⃣ **Click "Add New Medicine" Button**
- Look for the green button at the top right: **"+ Add New Medicine"**
- This opens the "Add New Medicine / Product" dialog

#### 3️⃣ **Fill in Product Details Section**

**Required Fields (*)**

| Field | Description | Example |
|-------|-------------|---------|
| **Medicine / Product Name** * | Full name of the medicine | `Amoxicillin 500mg Capsules` |
| **Generic Salt / Composition** * | Active pharmaceutical ingredient | `Amoxicillin Trihydrate` |
| **Barcode / SKU** | Product barcode (optional) | `8901234567890` |
| **HSN Code** | GST classification code | `30049099` (default) |
| **Manufacturer Name** | Company that manufactures | `Cipla Ltd.` |

**Dose Type / Form** * (Dropdown)
- Tablet
- Capsule
- Syrup/Suspension
- Injection
- Drops
- Ointment/Cream
- Inhaler
- Sachet/Powder
- Other

**Packaging Configuration** (Dropdown - auto-updates based on Dose Type)
- For Tablets: Strip 10, Strip 15, Bottle 30, Bottle 100, etc.
- For Syrup: Bottle 60ml, Bottle 100ml, Bottle 200ml
- For Injections: Vial (single), Box of 5, Box of 10
- For Ointment: Tube 10g, Tube 15g, Tube 30g

#### 4️⃣ **Set Tax & Regulatory Information**

**GST Tax Percent** (Dropdown)
- 0% (Exempt)
- 5%
- 12% (default for most medicines)
- 18%
- 28%

**Drug Classification Checkboxes:**
- ☐ **Schedule H** - Prescription-only medicine
- ☐ **Schedule H1** - Restricted prescription medicine (requires pharmacist PIN)
- ☐ **Narcotic/Psychotropic** - Controlled substance (requires pharmacist PIN)

**Important Notes:**
- If you check Schedule H1 or Narcotic, pharmacist PIN (1234) will be required at POS checkout
- These are tracked in the Schedule H Register for legal compliance

#### 5️⃣ **Add First Batch Details**

**Batch Information:**

| Field | Description | Example |
|-------|-------------|---------|
| **Batch Number** * | Manufacturer's batch code | `BT2024A1234` |
| **MRP (Maximum Retail Price)** * | Printed MRP on package | `₹150.00` |
| **Wholesale Rate (WSR)** | Wholesale price | `₹90.00` |
| **Purchase Price (PP)** | Your purchase cost | `₹85.00` |
| **PTR (Price to Retailer)** | Distributor price | `₹95.00` |
| **Opening Stock Quantity** * | Initial stock count | `100` |
| **Rack Location** | Physical location in store | `Rack A3 - Antibiotics` |

**Dates:**
| Field | Format | Example |
|-------|--------|---------|
| **Manufacturing Date** | MM/YYYY | `01/2024` |
| **Expiry Date** * | MM/YYYY | `12/2026` |

⚠️ **FEFO Alert:** System will automatically flag batches expiring within 90 days

#### 6️⃣ **Click "Add Medicine & Batch"**
- The system will:
  - Create the new product in inventory
  - Add the first batch with FEFO tracking
  - Make it available for POS billing immediately
  - Generate automatic barcode if not provided

---

## ✅ METHOD 2: Add Stock to Existing Medicine

### When to Use:
- Medicine already exists in inventory
- You received a new batch from supplier
- Adding stock from purchase order

### Step-by-Step Process:

#### 1️⃣ **Click "Add Stock / New Batch" Button**
- Blue button at the top right: **"+ Add Stock / New Batch"**
- Or click the **green "+" icon** next to any existing product in the list

#### 2️⃣ **Select Existing Product**
- Dropdown shows all existing medicines
- Search/select the medicine you want to add stock to

#### 3️⃣ **Fill in Batch Details Only**
- Same batch fields as above:
  - Batch Number
  - MRP, WSR, PP, PTR
  - Stock Quantity
  - Manufacturing & Expiry Dates
  - Rack Location

#### 4️⃣ **Click "Add Batch"**
- New batch is added to the existing product
- FEFO system automatically sorts batches by expiry date
- Oldest expiring batch will be used first at POS

---

## 📊 FEFO (First Expiry, First Out) System

### How It Works:
1. **Automatic Sorting:** All batches are sorted by expiry date
2. **POS Selection:** When billing, the system automatically picks the batch expiring soonest
3. **Near Expiry Alerts:** Orange warning banner shows medicines expiring within 90 days
4. **Batch Visibility:** Expand any product to see all batches with expiry dates

### Example:
```
Product: Paracetamol 500mg
├─ Batch A (Exp: 03/2024) ← Will be used FIRST
├─ Batch B (Exp: 08/2024)
└─ Batch C (Exp: 12/2024) ← Will be used LAST
```

---

## 🏷️ Quick Reference: Common Medicine Examples

### Example 1: Basic OTC Medicine
```
Name: Paracetamol 500mg Tablet
Salt: Paracetamol
HSN: 30049099
Tax: 12%
Schedule H: No
Dose: Tablet
Package: Strip 10
Batch: PT2024001
MRP: ₹15.00
Stock: 500
Expiry: 12/2026
```

### Example 2: Prescription Medicine (Schedule H)
```
Name: Amoxicillin 500mg Capsule
Salt: Amoxicillin Trihydrate
HSN: 30049099
Tax: 12%
Schedule H: Yes ✓
Dose: Capsule
Package: Strip 10
Batch: AM2024ABC
MRP: ₹120.00
Stock: 200
Expiry: 06/2025
Rack: Antibiotics Section A3
```

### Example 3: Restricted Drug (Schedule H1/Narcotic)
```
Name: Alprazolam 0.5mg Tablet
Salt: Alprazolam
HSN: 30049099
Tax: 12%
Schedule H1: Yes ✓
Narcotic: Yes ✓
Dose: Tablet
Package: Strip 10
Batch: ALP2024X
MRP: ₹85.00
Stock: 50
Expiry: 09/2025
Rack: Locked Cabinet - Psychotropics
```
⚠️ **Requires Pharmacist PIN (1234) at checkout**

### Example 4: Liquid Medicine (Syrup)
```
Name: Ambroxol Hydrochloride Syrup 100ml
Salt: Ambroxol Hydrochloride 15mg/5ml
HSN: 30049099
Tax: 12%
Schedule H: No
Dose: Syrup/Suspension
Package: Bottle 100ml
Batch: SYR100ML24
MRP: ₹95.00
Stock: 150
Expiry: 08/2026
```

---

## 🔍 After Adding Medicine

### Where to Find It:

1. **Inventory Tab:**
   - All medicines listed with expandable batch details
   - Click on any product to see all batches
   - Stock counts shown in real-time

2. **POS Billing:**
   - Search by medicine name or barcode
   - System automatically selects FEFO batch
   - Batch details shown on invoice

3. **Schedule H Register:**
   - Schedule H/H1/Narcotic medicines tracked separately
   - Legal compliance audit trail
   - Doctor prescription linkage

---

## 📱 Barcode Scanning

### Adding via Barcode:
1. Click barcode icon in POS or Inventory
2. Scan product barcode using camera
3. If product exists: Adds to cart/updates stock
4. If new product: Pre-fills barcode field in Add Medicine dialog

---

## 🎯 Best Practices

### ✅ DO:
- ✓ Always enter expiry dates accurately
- ✓ Use consistent batch numbering from supplier
- ✓ Mark Schedule H/H1/Narcotics correctly
- ✓ Keep rack locations updated for faster picking
- ✓ Check near-expiry alerts regularly
- ✓ Add stock as soon as purchase order arrives

### ❌ DON'T:
- ✗ Skip expiry dates (required for FEFO)
- ✗ Forget to mark restricted drugs
- ✗ Use duplicate batch numbers
- ✗ Leave stock quantity as 0
- ✗ Mix different MRPs in same batch

---

## 🚨 Common Issues & Solutions

### Issue: "Medicine already exists"
**Solution:** Use "Add Stock / New Batch" instead of "Add New Medicine"

### Issue: "Batch number duplicate"
**Solution:** Each batch must have unique batch number per product

### Issue: "Cannot sell at POS"
**Solution:** Check that:
- Stock quantity > 0
- Product is not expired
- All required fields are filled

### Issue: "Pharmacist PIN required"
**Solution:** Medicine is marked as Schedule H1/Narcotic
- Use default PIN: **1234**
- Or change in Settings → Pharmacist PIN

---

## 💡 Pro Tips

### Bulk Import (Coming Soon)
- Excel/CSV upload for multiple medicines
- Useful for initial inventory setup
- Template download available in Settings

### Stock Auditing
- Regular stock counts vs system counts
- Discrepancy reports
- Adjustment entries

### Supplier Integration
- Link products to suppliers
- Auto-generate purchase orders
- Track supplier performance

---

## 📞 Need Help?

- **WhatsApp Support:** +44 7747 571513
- **Email:** Support@billsprout.online
- **In-App:** Click Support Desk icon in menu

---

## 🎬 Quick Video Guide

### Add New Medicine (Under 2 minutes):
1. Inventory → Add New Medicine (0:10)
2. Fill Product Details (0:30)
3. Set Tax & Classification (0:15)
4. Add First Batch (0:45)
5. Save & Verify (0:20)

**Total Time:** 2 minutes per medicine

### Add Stock to Existing (Under 1 minute):
1. Inventory → Add Stock (0:05)
2. Select Product (0:10)
3. Fill Batch Details (0:30)
4. Save (0:10)

**Total Time:** 55 seconds per batch

---

**Last Updated:** 2026
**System Version:** v1.3.0+1
**Module:** Business Admin - Inventory Management
