# Build script for BillSprout web version with environment variables
# This ensures PayPal configuration is embedded at compile time

Write-Host "🚀 Building BillSprout Web Version..." -ForegroundColor Cyan
Write-Host ""

# Get PayPal username from .env file if it exists
$paypalUsername = "LifeSproutCare"  # Default value

if (Test-Path ".env") {
    Write-Host "📄 Reading .env file..." -ForegroundColor Yellow
    $envContent = Get-Content ".env"
    foreach ($line in $envContent) {
        if ($line -match "^PAYPAL_ME_USERNAME=(.+)$") {
            $paypalUsername = $Matches[1]
            Write-Host "✅ Found PayPal username: $paypalUsername" -ForegroundColor Green
        }
    }
}

# Build web with environment variables
Write-Host ""
Write-Host "🔨 Running Flutter build..." -ForegroundColor Cyan
Write-Host "   Using PayPal username: $paypalUsername" -ForegroundColor Gray
Write-Host ""

flutter build web --release --dart-define=PAYPAL_ME_USERNAME=$paypalUsername

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Build completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📦 Build output: build\web" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📤 Next steps:" -ForegroundColor Yellow
    Write-Host "   1. Test locally: flutter run -d chrome" -ForegroundColor Gray
    Write-Host "   2. Deploy to hosting (Vercel/Netlify/Firebase)" -ForegroundColor Gray
    Write-Host "   3. Or commit and push to GitHub" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "❌ Build failed! Check errors above." -ForegroundColor Red
    exit 1
}
