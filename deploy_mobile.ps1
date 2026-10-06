# LifeSprout Mobile Deployment Script
# Quick deployment to connected mobile devices

Write-Host "🚀 LifeSprout Mobile Deployment" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is available
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Flutter not found! Please install Flutter first." -ForegroundColor Red
    Write-Host "   Visit: https://docs.flutter.dev/get-started/install" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Flutter found" -ForegroundColor Green

# Check for connected devices
Write-Host ""
Write-Host "📱 Checking for connected devices..." -ForegroundColor Yellow
flutter devices

$deviceCount = (flutter devices | Select-String -Pattern "^[A-Za-z0-9]" | Measure-Object).Count - 1

if ($deviceCount -eq 0) {
    Write-Host ""
    Write-Host "❌ No devices found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "📋 Quick Setup:" -ForegroundColor Yellow
    Write-Host "   Android: Enable USB Debugging in Developer Options" -ForegroundColor White
    Write-Host "   iOS: Trust this computer on your device" -ForegroundColor White
    Write-Host ""
    Write-Host "   See MOBILE_DEPLOYMENT_GUIDE.md for detailed instructions" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "✓ Found $deviceCount device(s)" -ForegroundColor Green
Write-Host ""

# Ask for build mode
Write-Host "Select build mode:" -ForegroundColor Yellow
Write-Host "  [1] Debug (default, hot reload enabled)" -ForegroundColor White
Write-Host "  [2] Release (optimized, production-ready)" -ForegroundColor White
Write-Host "  [3] Profile (performance profiling)" -ForegroundColor White
Write-Host ""

$buildMode = Read-Host "Enter choice (1-3) [default: 1]"

if ([string]::IsNullOrWhiteSpace($buildMode)) {
    $buildMode = "1"
}

$modeArg = ""
switch ($buildMode) {
    "2" { 
        $modeArg = "--release"
        Write-Host "🏗️  Building in RELEASE mode..." -ForegroundColor Cyan
    }
    "3" { 
        $modeArg = "--profile"
        Write-Host "🏗️  Building in PROFILE mode..." -ForegroundColor Cyan
    }
    default { 
        Write-Host "🏗️  Building in DEBUG mode..." -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "🔨 Running: flutter run $modeArg" -ForegroundColor Yellow
Write-Host ""

# Run Flutter
if ($modeArg) {
    flutter run $modeArg
} else {
    flutter run
}

Write-Host ""
Write-Host "✨ Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Navigate to Business Admin → Inventory" -ForegroundColor White
Write-Host "   2. Tap 'Scan Medicine' button" -ForegroundColor White
Write-Host "   3. Test camera scanning with real medicine packaging" -ForegroundColor White
Write-Host "   4. Try batch mode for multiple items" -ForegroundColor White
Write-Host "   5. Check scan history feature" -ForegroundColor White
Write-Host ""
Write-Host "💡 Tip: See MOBILE_DEPLOYMENT_GUIDE.md for camera tips!" -ForegroundColor Yellow
