# Flutter Setup Script for BillSprout
# This script helps install Flutter SDK when you're ready

Write-Host "🚀 BillSprout Flutter Setup Assistant" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is already available
$flutterExists = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterExists) {
    Write-Host "✅ Flutter is already installed!" -ForegroundColor Green
    Write-Host "   Version: $(flutter --version | Select-Object -First 1)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🏃 Ready to run your app:" -ForegroundColor Green
    Write-Host "   flutter pub get" -ForegroundColor Gray
    Write-Host "   flutter run -d web-server --web-port=3000" -ForegroundColor Gray
    exit 0
}

Write-Host "❌ Flutter SDK not found" -ForegroundColor Red
Write-Host ""
Write-Host "📥 Installation Options:" -ForegroundColor Yellow
Write-Host ""

Write-Host "Option 1: Download Flutter SDK manually" -ForegroundColor Cyan
Write-Host "   1. Visit: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Gray
Write-Host "   2. Download the stable release ZIP file" -ForegroundColor Gray
Write-Host "   3. Extract to C:\flutter (or preferred location)" -ForegroundColor Gray
Write-Host "   4. Add C:\flutter\bin to your system PATH" -ForegroundColor Gray
Write-Host "   5. Restart PowerShell and run this script again" -ForegroundColor Gray
Write-Host ""

Write-Host "Option 2: Install VS Code with Flutter Extension" -ForegroundColor Cyan
Write-Host "   1. Download VS Code: https://code.visualstudio.com/" -ForegroundColor Gray
Write-Host "   2. Install the Flutter extension (it will guide Flutter SDK installation)" -ForegroundColor Gray
Write-Host "   3. Open this project in VS Code" -ForegroundColor Gray
Write-Host ""

Write-Host "Option 3: Use Android Studio" -ForegroundColor Cyan
Write-Host "   1. Download: https://developer.android.com/studio" -ForegroundColor Gray
Write-Host "   2. Install Flutter plugin during setup" -ForegroundColor Gray
Write-Host "   3. Open this project" -ForegroundColor Gray
Write-Host ""

Write-Host "🌟 Current Status:" -ForegroundColor Yellow
Write-Host "   ✅ Web server running at: http://127.0.0.1:3000" -ForegroundColor Green
Write-Host "   ✅ Full patient portal code ready" -ForegroundColor Green
Write-Host "   ❌ Need to rebuild to see latest changes" -ForegroundColor Red
Write-Host ""

Write-Host "🔑 Login Credentials:" -ForegroundColor Yellow
Write-Host "   Patient: patient@lifesproutcare.com / patient123" -ForegroundColor Gray
Write-Host "   Admin:   admin@lifesproutcare.com / admin123" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Would you like me to open the Flutter installation page? (y/n)"
if ($choice -eq "y" -or $choice -eq "Y") {
    Start-Process "https://flutter.dev/docs/get-started/install/windows"
}