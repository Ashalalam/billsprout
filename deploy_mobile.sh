#!/bin/bash

# LifeSprout Mobile Deployment Script
# Quick deployment to connected mobile devices

echo "🚀 LifeSprout Mobile Deployment"
echo "================================="
echo ""

# Check if Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found! Please install Flutter first."
    echo "   Visit: https://docs.flutter.dev/get-started/install"
    exit 1
fi

echo "✓ Flutter found"

# Check for connected devices
echo ""
echo "📱 Checking for connected devices..."
flutter devices

device_count=$(flutter devices | grep -c "^[A-Za-z0-9]" || true)
device_count=$((device_count - 1))

if [ "$device_count" -eq 0 ]; then
    echo ""
    echo "❌ No devices found!"
    echo ""
    echo "📋 Quick Setup:"
    echo "   Android: Enable USB Debugging in Developer Options"
    echo "   iOS: Trust this computer on your device"
    echo ""
    echo "   See MOBILE_DEPLOYMENT_GUIDE.md for detailed instructions"
    exit 1
fi

echo ""
echo "✓ Found $device_count device(s)"
echo ""

# Ask for build mode
echo "Select build mode:"
echo "  [1] Debug (default, hot reload enabled)"
echo "  [2] Release (optimized, production-ready)"
echo "  [3] Profile (performance profiling)"
echo ""

read -p "Enter choice (1-3) [default: 1]: " buildMode

if [ -z "$buildMode" ]; then
    buildMode="1"
fi

modeArg=""
case $buildMode in
    2)
        modeArg="--release"
        echo "🏗️  Building in RELEASE mode..."
        ;;
    3)
        modeArg="--profile"
        echo "🏗️  Building in PROFILE mode..."
        ;;
    *)
        echo "🏗️  Building in DEBUG mode..."
        ;;
esac

echo ""
echo "🔨 Running: flutter run $modeArg"
echo ""

# Run Flutter
flutter run $modeArg

echo ""
echo "✨ Deployment complete!"
echo ""
echo "📋 Next Steps:"
echo "   1. Navigate to Business Admin → Inventory"
echo "   2. Tap 'Scan Medicine' button"
echo "   3. Test camera scanning with real medicine packaging"
echo "   4. Try batch mode for multiple items"
echo "   5. Check scan history feature"
echo ""
echo "💡 Tip: See MOBILE_DEPLOYMENT_GUIDE.md for camera tips!"
