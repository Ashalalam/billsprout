# 🚀 Medicine Scanner - Quick Start Guide

Get up and running with the medicine scanner in 5 minutes!

---

## 📱 Deploy to Mobile Device

### Option 1: Quick Deploy (Recommended)

**Windows:**
```powershell
.\deploy_mobile.ps1
```

**Mac/Linux:**
```bash
chmod +x deploy_mobile.sh
./deploy_mobile.sh
```

### Option 2: Manual Deploy

1. **Connect your device** via USB
2. **Enable USB debugging** (Android) or **Trust computer** (iOS)
3. **Run the app:**
   ```bash
   flutter run
   ```

---

## 🎯 First Scan in 3 Steps

### Step 1: Navigate to Scanner
1. Open the app
2. Login as **business_admin**
3. Go to **Business Admin → Inventory**
4. Tap the blue **"Scan Medicine"** button

### Step 2: Capture Image
1. Tap **"Take Photo"**
2. Point camera at medicine box/label
3. Ensure text is clear and in focus
4. Capture the image

### Step 3: Review & Save
1. Check the extracted information
2. See confidence scores (Green = good!)
3. Edit any incorrect fields
4. Tap **"Continue"** to add to inventory

**Done! 🎉**

---

## 🔥 Quick Features Overview

### Single Scan Mode (Default)
- Quick one-off medicine scanning
- Immediate review and submission
- Perfect for: Adding new items on-the-fly

### Batch Scan Mode
Enable for multiple items:
```dart
await showMedicineScannerDialog(context, batchMode: true);
```
- Scan multiple medicines in one session
- Review all before submitting
- Perfect for: Stock deliveries, bulk intake

### History Feature
- Automatic saving of last 20 scans
- Switch to **History** tab
- Tap reuse icon to apply previous scan
- Perfect for: Regular restocking

---

## 💡 Pro Tips

### For Best Results:

1. **Lighting**: Use natural daylight
2. **Angle**: Hold phone parallel to label
3. **Focus**: Wait for autofocus to lock
4. **Distance**: Fill 70% of frame with text
5. **Steady**: Hold still for 1 second

### Confidence Indicators:

- 🟢 **Green (75%+)**: Trust and proceed
- 🟠 **Orange (50-75%)**: Quick review recommended
- 🔴 **Red (<50%)**: Manual entry may be faster

---

## 🐛 Troubleshooting

### Camera not working?
✅ Check app permissions in device settings

### Low accuracy?
✅ Improve lighting and focus
✅ Try different angle
✅ Clean camera lens

### App won't install?
✅ Check USB connection
✅ Verify USB debugging enabled
✅ Run: `flutter devices`

---

## 📚 Documentation

- **Full Deployment Guide**: `MOBILE_DEPLOYMENT_GUIDE.md`
- **All Features**: `SCANNER_FEATURES.md`
- **Changelog**: `CHANGELOG_SCANNER.md`

---

## ⚡ Keyboard Shortcuts

While testing on desktop:

- `r` - Hot reload
- `R` - Hot restart
- `q` - Quit
- `h` - Help

---

## 🎯 Success Checklist

- [ ] App installed on mobile device
- [ ] Logged in as business_admin
- [ ] Found "Scan Medicine" button in Inventory
- [ ] Successfully scanned first medicine
- [ ] Reviewed confidence scores
- [ ] Added item to inventory
- [ ] Tested batch mode
- [ ] Checked scan history

---

**Need more help?** Check `MOBILE_DEPLOYMENT_GUIDE.md` for detailed instructions!

**Ready to scan!** 📸💊✨
