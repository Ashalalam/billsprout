# ============================================================================
# FIX CUSTOMER REGISTRATION - Apply Database Fix
# ============================================================================

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host " FIX CUSTOMER TENANT_ID CONSTRAINT" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

$sqlFile = "supabase\migrations\022_fix_customer_tenant_constraint.sql"

if (-not (Test-Path $sqlFile)) {
    Write-Host "ERROR: SQL file not found" -ForegroundColor Red
    exit 1
}

$sqlContent = Get-Content $sqlFile -Raw

Write-Host "Copying SQL to clipboard..." -ForegroundColor Green
Set-Clipboard -Value $sqlContent
Write-Host "   Done!" -ForegroundColor Green
Write-Host ""

Write-Host "Opening Supabase SQL Editor..." -ForegroundColor Green
Start-Process "https://supabase.com/dashboard/project/juvbhjqaioevpusnmonz/sql/new"
Write-Host "   Done!" -ForegroundColor Green
Write-Host ""

Write-Host "=" * 80 -ForegroundColor Yellow
Write-Host " IN THE BROWSER:" -ForegroundColor Yellow
Write-Host "=" * 80 -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Paste SQL (Ctrl+V)" -ForegroundColor White
Write-Host "2. Click RUN" -ForegroundColor White
Write-Host "3. Wait for 'Success'" -ForegroundColor White
Write-Host ""
Write-Host "=" * 80 -ForegroundColor Green
Write-Host " AFTER SQL RUNS SUCCESSFULLY:" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green
Write-Host ""
Write-Host "Test customer registration at:" -ForegroundColor White
Write-Host "  http://localhost:59650/#/customer-register" -ForegroundColor Cyan
Write-Host ""
Write-Host "Use a NEW email:" -ForegroundColor White
Write-Host "  Example: success_$(Get-Date -Format 'HHmmss')@gmail.com" -ForegroundColor Gray
Write-Host ""
Write-Host "Expected result:" -ForegroundColor Cyan
Write-Host "  - Account created successfully" -ForegroundColor Gray
Write-Host "  - No errors" -ForegroundColor Gray
Write-Host "  - User can access app immediately" -ForegroundColor Gray
Write-Host ""

Write-Host "Press any key to close..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
