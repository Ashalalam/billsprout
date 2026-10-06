# ============================================================================
# APPLY SOFTWARE DOWNLOAD SYSTEM MIGRATION
# ============================================================================

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host " APPLY SOFTWARE DOWNLOAD & LICENSE SYSTEM" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

$sqlFile = "supabase\migrations\023_software_downloads_enhancement.sql"

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
Write-Host " WHAT THIS MIGRATION DOES:" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Green
Write-Host ""
Write-Host "- Adds software file storage columns" -ForegroundColor Gray
Write-Host "- Adds access_status to tenants (for suspension)" -ForegroundColor Gray
Write-Host "- Adds license_key and license_status to subscriptions" -ForegroundColor Gray
Write-Host "- Creates can_download_software() function" -ForegroundColor Gray
Write-Host "- Creates get_download_authorization() function" -ForegroundColor Gray
Write-Host "- Creates business_admin_access_overview view" -ForegroundColor Gray
Write-Host "- Adds download tracking enhancements" -ForegroundColor Gray
Write-Host "- Updates RLS policies" -ForegroundColor Gray
Write-Host ""

Write-Host "Press any key to close..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
