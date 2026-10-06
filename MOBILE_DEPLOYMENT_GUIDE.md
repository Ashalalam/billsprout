# 📱 Mobile Deployment Guide - Medicine Scanner

This guide will help you deploy the LifeSprout app with the medicine scanning feature to physical mobile devices for full camera testing.

---

## 🎯 Quick Start

### For Android Device (Recommended for Testing)

1. **Enable Developer Mode on your Android phone:**
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
   - Go back to Settings → Developer Options
   - Enable "USB Debugging"

2. **Connect your phone via USB cable to your computer**

3. **Verify connection:**
   ```bash
   flutter devices
   ```
   You should see your device listed.

4. **Run the app:**
   ```bash
   flutter run
   ```
   The app will install and launch on your phone!

---

## 🍎 For iOS Device

### Prerequisites
- macOS computer
- Xcode installed
- Apple Developer Account (free account works for testing)
- iOS device with cable

### Steps

1. **Open Xcode:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Configure signing:**
   - Select "Runner" in project navigator
   - Go to "Signing & Capabilities"
   - Select your Team (Apple ID)
   - Xcode will automatically create a provisioning profile

3. **Trust your developer certificate on iPhone:**
   - Settings → General → VPN & Device Management
   - Trust your developer certificate

4. **Connect iPhone and run:**
   ```bash
   flutter run
   ```

---

## 🔧 Build Release APK (Android)

For sharing with others or testing performance:

```bash
# Build release APK
flutter build apk --release

# Output will be at:
# build/app/outputs/flutter-apk/app-release.apk
```

Install on any Android device via USB or file transfer!

---

## 🧪 Testing the Medicine Scanner

Once the app is running on your mobile device:

### Single Scan Mode
1. Navigate to **Business Admin → Inventory**
2. Tap the **"Scan Medicine"** button (blue with camera icon)
3. Tap **"Take Photo"**
4. Point camera at medicine packaging with clear text
5. Capture the image
6. Review extracted data with confidence indicators
7. Edit any fields if needed
8. Tap **"Continue"** to add to inventory

### Batch Scan Mode
1. From Inventory, tap **"Scan Medicine"**
2. Enable batch mode (if available) or scan multiple times
3. Switch to **"Batch"** tab to see all scanned items
4. Tap **"Scan More"** to continue adding items
5. Review each item's confidence score
6. Remove any incorrect items
7. Tap **"Done"** to process all items

### Scan History
1. Open scanner dialog
2. Switch to **"History"** tab
3. View your last 20 scans
4. Tap the redo icon to reuse previous scan data

---

## 📸 Camera Testing Tips

For best OCR results:

✅ **Good Practices:**
- Good lighting (natural light works best)
- Hold phone steady (avoid blur)
- Fill frame with medicine box/label
- Ensure text is in focus
- Flat surface if possible

❌ **Avoid:**
- Low light or shadows
- Blurry/shaky images
- Text at extreme angles
- Reflective/glossy surfaces causing glare
- Very small text (zoom in)

---

## 🆕 New Features in Enhanced Scanner

### 1. **Confidence Indicators**
Each extracted field shows a confidence score:
- 🟢 **Green (75%+)**: High confidence - likely accurate
- 🟠 **Orange (50-75%)**: Medium confidence - review carefully
- 🔴 **Red (<50%)**: Low confidence - verify manually

### 2. **Batch Scanning**
Scan multiple medicines in one session:
- Add items to batch list
- Review all items before submission
- Remove incorrect scans
- Process all at once

### 3. **Scan History**
- Last 20 scans saved automatically
- Reuse previous scan data
- Quick access to common medicines
- Timestamp for each scan

### 4. **Editable Review Dialog**
- Edit any field before adding
- See confidence for each field
- View captured image
- Validate before submission

### 5. **Barcode Detection**
- Automatically detects barcodes in images
- Supports multiple formats (EAN, UPC, QR, etc.)
- Merged with OCR data

---

## 🐛 Troubleshooting

### "No devices found"
```bash
# Check connected devices
flutter devices

# For Android, ensure USB debugging is enabled
# For iOS, ensure device is trusted
```

### "Camera permission denied"
- On Android: Settings → Apps → LifeSprout → Permissions → Enable Camera
- On iOS: Settings → LifeSprout → Enable Camera

### "ML Kit not working"
ML Kit plugins work automatically on mobile devices. The warnings you see on web are expected and can be ignored.

### Build errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Performance issues
```bash
# Build in release mode for better performance
flutter run --release
```

---

## 📊 Performance Notes

- **Debug mode**: Slower, larger app size, useful for development
- **Release mode**: Optimized, smaller size, production-ready
- **Profile mode**: Performance profiling enabled

```bash
# Run in release mode
flutter run --release

# Run in profile mode
flutter run --profile
```

---

## 🚀 Next Steps

After successful mobile deployment:

1. **Test all scanning features** thoroughly
2. **Try different medicine types** (tablets, syrups, injections)
3. **Test in various lighting conditions**
4. **Verify barcode scanning** with different formats
5. **Check batch scanning workflow**
6. **Review scan history** functionality

---

## 💡 Pro Tips

1. **Clean Camera Lens**: Ensure phone camera lens is clean for best OCR accuracy

2. **Portrait Mode**: Hold phone in portrait orientation for most medicine labels

3. **Multiple Angles**: If OCR misses text, try capturing from a different angle

4. **Batch Processing**: Use batch mode when receiving new stock to save time

5. **History Feature**: For frequently restocked medicines, use scan history instead of re-scanning

---

## 📞 Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review Flutter documentation: https://docs.flutter.dev/deployment
3. Check console logs for error details

---

**Happy Testing! 🎉**

Your medicine scanning feature is production-ready and waiting to streamline your inventory management!
