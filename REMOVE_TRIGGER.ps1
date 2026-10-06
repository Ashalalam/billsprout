# ============================================================================
# REMOVE THE PROBLEMATIC AUTO-CONFIRM TRIGGER
# ============================================================================
# The trigger we applied is blocking ALL signups from working
# This script will help you remove it
# ============================================================================

Write-Host "================================================================" -ForegroundColor Red
Write-Host " REMOVE PROBLEMATIC TRIGGER" -ForegroundColor Red
Write-Host "================================================================" -ForegroundColor Red
Write-Host ""
Write-Host "The auto-confirm trigger is BLOCKING signup completely." -ForegroundColor Yellow
Write-Host "We need to remove it and use Supabase's native email setting instead." -ForegroundColor Yellow
Write-Host ""

# Read the SQL migration file
$sqlFile = "supabase\migrations\021_remove_auto_confirm_trigger.sql"

if (-not (Test-Path $sqlFile)) {
    Write-Host "ERROR: Migration file not found at: $sqlFile" -ForegroundColor Red
    pause
    exit 1
}

$sqlContent = Get-Content $sqlFile -Raw

Write-Host "Step 1: Copying SQL to clipboard..." -ForegroundColor Green
Set-Clipboard -Value $sqlContent
Write-Host "   SQL copied!" -ForegroundColor Green
Write-Host ""

Write-Host "Step 2: Opening Supabase SQL Editor..." -ForegroundColor Green
$supabaseUrl = "https://supabase.com/dashboard/project/juvbhjqaioevpusnmonz/sql/new"
Start-Process $supabaseUrl
Write-Host "   Browser opened!" -ForegroundColor Green
Write-Host ""

Write-Host "================================================================" -ForegroundColor Yellow
Write-Host " ACTION REQUIRED IN BROWSER" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Paste the SQL (Ctrl+V)" -ForegroundColor White
Write-Host "2. Click RUN" -ForegroundColor White
Write-Host "3. Wait for success message" -ForegroundColor White
Write-Host ""
Write-Host "Then return here and press any key..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " NOW DISABLE EMAIL CONFIRMATION IN SUPABASE" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Opening Supabase Authentication Providers..." -ForegroundColor Green
$authUrl = "https://supabase.com/dashboard/project/juvbhjqaioevpusnmonz/auth/providers"
Start-Process $authUrl
Write-Host ""
Write-Host "In the browser:" -ForegroundColor Yellow
Write-Host "1. Find 'Email' provider" -ForegroundColor White
Write-Host "2. Turn OFF 'Confirm email' toggle" -ForegroundColor White
Write-Host "3. Click SAVE" -ForegroundColor White
Write-Host ""
Write-Host "This is the CORRECT way to disable email confirmation." -ForegroundColor Cyan
Write-Host "Triggers on auth.users interfere with Supabase's internal auth." -ForegroundColor Cyan
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host " AFTER BOTH STEPS COMPLETE" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Test registration with a NEW email:" -ForegroundColor White
Write-Host "  Example: finaltest_$(Get-Date -Format 'HHmmss')@gmail.com" -ForegroundColor Gray
Write-Host ""
Write-Host "Expected:" -ForegroundColor Cyan
Write-Host "  - Registration succeeds" -ForegroundColor Gray
Write-Host "  - No HTTP 500" -ForegroundColor Gray
Write-Host "  - No database error" -ForegroundColor Gray
Write-Host "  - User can log in immediately" -ForegroundColor Gray
Write-Host ""

Write-Host "Press any key to close..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
