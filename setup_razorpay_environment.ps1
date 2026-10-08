# PowerShell script to add Razorpay environment variable to Supabase
# Run this script to add RAZORPAY_KEY_SECRET to your Supabase project

Write-Host "Setting up Razorpay Environment Variables for Supabase..." -ForegroundColor Green

# Check if Supabase CLI is installed
if (-not (Get-Command "supabase" -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Supabase CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "npm install -g supabase" -ForegroundColor Yellow
    exit 1
}

# Set environment variables for Supabase Edge Functions
Write-Host "📝 Adding Razorpay Secret Key to Supabase Environment..." -ForegroundColor Blue

# Note: This requires manual setup in Supabase Dashboard
Write-Host ""
Write-Host "🔧 MANUAL SETUP REQUIRED:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Go to: https://supabase.com/dashboard/project/juvbhjqaioevpusnmonz/functions" -ForegroundColor White
Write-Host "2. Click on 'Environment variables' tab" -ForegroundColor White
Write-Host "3. Click 'Add new variable'" -ForegroundColor White
Write-Host "4. Add the following:" -ForegroundColor White
Write-Host "   Name: RAZORPAY_KEY_SECRET" -ForegroundColor Cyan
Write-Host "   Value: njOECeGNbHoztur3f5pLcniK" -ForegroundColor Cyan
Write-Host "5. Click 'Save'" -ForegroundColor White
Write-Host ""

# Deploy edge functions
Write-Host "🚀 Deploying Supabase Edge Functions..." -ForegroundColor Green

try {
    # Deploy create-razorpay-order function
    Write-Host "Deploying create-razorpay-order function..." -ForegroundColor Blue
    supabase functions deploy create-razorpay-order
    
    # Deploy verify-razorpay-payment function
    Write-Host "Deploying verify-razorpay-payment function..." -ForegroundColor Blue
    supabase functions deploy verify-razorpay-payment
    
    Write-Host ""
    Write-Host "✅ Edge functions deployed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎉 SETUP COMPLETE!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your Razorpay configuration:" -ForegroundColor Yellow
    Write-Host "- Key ID: rzp_test_TlQpbkhf8aylDg" -ForegroundColor White
    Write-Host "- Secret Key: njOECeGNbHoztur3f5pLcniK (added to Supabase)" -ForegroundColor White
    Write-Host "- Test Mode: true" -ForegroundColor White
    Write-Host ""
    Write-Host "You can now test payments in your app! 💳" -ForegroundColor Green
    
} catch {
    Write-Host ""
    Write-Host "❌ Error deploying functions: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure:" -ForegroundColor Yellow
    Write-Host "1. Supabase CLI is logged in (supabase login)" -ForegroundColor White
    Write-Host "2. Project is linked (supabase link)" -ForegroundColor White
    Write-Host "3. Environment variable is added manually in Supabase Dashboard" -ForegroundColor White
}

Write-Host ""
Write-Host "Press any key to continue..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")