@echo off
echo 🚀 BillSprout - Starting Development Server
echo ==========================================
echo.

REM Check if Flutter is available
flutter --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Flutter not found! Please install Flutter first.
    echo 📖 See INSTALL_FLUTTER_GUIDE.md for instructions
    echo.
    pause
    exit /b 1
)

echo ✅ Flutter found! Setting up BillSprout...
echo.

echo 📦 Installing dependencies...
flutter pub get

echo 🔨 Building and running the app...
echo 🌐 Your app will be available at: http://localhost:3000
echo.
echo 🔑 Login Credentials:
echo    Patient: patient@lifesproutcare.com / patient123
echo    Admin:   admin@lifesproutcare.com / admin123
echo.
echo Starting development server...
flutter run -d web-server --web-port=3000

pause