# ============================================================================
# APPLY AUTO-CONFIRM EMAIL MIGRATION TO SUPABASE
# ============================================================================
# This script helps you apply the migration to fix customer registration
# Run this script and follow the instructions
# ============================================================================

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " FIX CUSTOMER REGISTRATION - APPLY MIGRATION" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Read the SQL migration file
$sqlFile = "supabase\migrations\020_auto_confirm_emails.sql"

if (-not (Test-Path $sqlFile)) {
    Write-Host "ERROR: Migration file not found at: $sqlFile" -ForegroundColor Red
    Write-Host "Please run this script from the project root directory." -ForegroundColor Yellow
    pause
    exit 1
}

$sqlContent = Get-Content $sqlFile -Raw

Write-Host "Step 1: Copying SQL migration to clipboard..." -ForegroundColor Green
Set-Clipboard -Value $sqlContent
Write-Host "   SQL migration copied to clipboard!" -ForegroundColor Green
Write-Host ""

Write-Host "Step 2: Opening Supabase SQL Editor in browser..." -ForegroundColor Green
$supabaseUrl = "https://supabase.com/dashboard/project/juvbhjqaioevpusnmonz/sql/new"
Start-Process $supabaseUrl
Write-Host "   Browser opened!" -ForegroundColor Green
Write-Host ""

Write-Host "================================================================" -ForegroundColor Yellow
Write-Host " MANUAL STEPS - PLEASE COMPLETE IN YOUR BROWSER" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Wait for the Supabase SQL Editor to load" -ForegroundColor White
Write-Host "2. Click in the SQL editor text area" -ForegroundColor White
Write-Host "3. Press Ctrl+V to paste the SQL (already copied!)" -ForegroundColor White
Write-Host "4. Click the 'RUN' button or press Ctrl+Enter" -ForegroundColor White
Write-Host "5. Wait for the success message" -ForegroundColor White
Write-Host ""
Write-Host "Expected result:" -ForegroundColor Cyan
Write-Host "  - Function created: public.auto_confirm_user()" -ForegroundColor Gray
Write-Host "  - Trigger created: on_auth_user_created_auto_confirm" -ForegroundColor Gray
Write-Host "  - Function created: public.confirm_user_email(UUID)" -ForegroundColor Gray
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host " AFTER APPLYING THE MIGRATION" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Test customer registration with a NEW email address:" -ForegroundColor White
Write-Host "  Example: testuser_$(Get-Date -Format 'yyyyMMddHHmmss')@example.com" -ForegroundColor Gray
Write-Host ""
Write-Host "Expected behavior:" -ForegroundColor Cyan
Write-Host "  - No more 'Database error loading user after sign-up'" -ForegroundColor Gray
Write-Host "  - Registration completes successfully" -ForegroundColor Gray
Write-Host "  - User can immediately log in" -ForegroundColor Gray
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Keep the window open
Write-Host "Press any key to close this window after you've applied the migration..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
