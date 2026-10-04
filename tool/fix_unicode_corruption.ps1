# Fix double-encoded UTF-8 corruption in source files
# This occurs when UTF-8 bytes are misinterpreted as Latin-1/Windows-1252

Write-Host "=== Unicode Corruption Fix Script ===" -ForegroundColor Cyan
Write-Host "This will fix double-encoded UTF-8 characters in .dart files`n" -ForegroundColor Yellow

$files = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse

# Map of corrupted patterns to correct Unicode
# Pattern: UTF-8 character → interpreted as Latin-1 → becomes these bytes → displayed as corruption
$replacements = @{
    # Currency symbols
    'â‚¹' = '₹'      # Indian Rupee (E2 82 B9)
    'â‚¬' = '€'      # Euro (E2 82 AC)
    'Â£' = '£'       # Pound (C2 A3)
    'Â¥' = '¥'       # Yen (C2 A5)
    
    # Dashes and hyphens
    'â€"' = '—'      # Em dash (E2 80 94)
    'â€"' = '–'      # En dash (E2 80 93)
    'â€•' = '―'      # Horizontal bar (E2 80 95)
    
    # Quotes
    'â€˜' = '''      # Left single quote (E2 80 98)
    'â€™' = '''      # Right single quote/apostrophe (E2 80 99)
    'â€œ' = '"'      # Left double quote (E2 80 9C)
    'â€' = '"'       # Right double quote (E2 80 9D)
    'â€ž' = '„'      # Double low-9 quote (E2 80 9E)
    
    # Bullets and symbols
    'â€¢' = '•'      # Bullet (E2 80 A2)
    'â€¦' = '…'      # Ellipsis (E2 80 A6)
    'â€º' = '›'      # Single right angle quote (E2 80 BA)
    'â€¹' = '‹'      # Single left angle quote (E2 80 B9)
    'Â·' = '·'       # Middle dot (C2 B7)
    
    # Arrows
    'â†'' = '→'      # Right arrow (E2 86 92)
    'â†�' = '←'      # Left arrow (E2 86 90)
    'â†'' = '↑'      # Up arrow (E2 86 91)
    'â†"' = '↓'      # Down arrow (E2 86 93)
    
    # Math symbols
    'Ã—' = '×'       # Multiplication (C3 97)
    'Ã·' = '÷'       # Division (C3 B7)
    'â‰¤' = '≤'      # Less than or equal (E2 89 A4)
    'â‰¥' = '≥'      # Greater than or equal (E2 89 A5)
    'â‰ ' = '≠'      # Not equal (E2 89 A0)
    'Â±' = '±'       # Plus-minus (C2 B1)
    'Â°' = '°'       # Degree (C2 B0)
    
    # Box drawing characters (used in comments)
    'â"€' = '─'      # Box horizontal (E2 94 80)
    'â"�' = '│'      # Box vertical (E2 94 82)
    'â"Œ' = '┌'      # Box down-right (E2 94 8C)
    'â"�' = '┐'      # Box down-left (E2 94 90)
    'â""' = '└'      # Box up-right (E2 94 94)
    'â"˜' = '┘'      # Box up-left (E2 94 98)
    'â"œ' = '├'      # Box vertical-right (E2 94 9C)
    'â"¤' = '┤'      # Box vertical-left (E2 94 A4)
    
    # Other common corruptions
    'Â ' = ' '       # Non-breaking space that got corrupted (C2 A0 → A0 preserved)
    'Ã¡' = 'á'       # a with acute (C3 A1)
    'Ã©' = 'é'       # e with acute (C3 A9)
    'Ã­' = 'í'       # i with acute (C3 AD)
    'Ã³' = 'ó'       # o with acute (C3 B3)
    'Ãº' = 'ú'       # u with acute (C3 BA)
    'Ã±' = 'ñ'       # n with tilde (C3 B1)
    'Ã¼' = 'ü'       # u with umlaut (C3 BC)
    'Â©' = '©'       # Copyright (C2 A9)
    'Â®' = '®'       # Registered (C2 AE)
    'â„¢' = '™'      # Trademark (E2 84 A2)
}

$totalFiles = 0
$totalReplacements = 0
$filesFixed = @()

foreach ($file in $files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        $originalContent = $content
        $fileReplacements = 0
        
        foreach ($corrupted in $replacements.Keys) {
            $correct = $replacements[$corrupted]
            if ($content -match [regex]::Escape($corrupted)) {
                $count = ([regex]::Matches($content, [regex]::Escape($corrupted))).Count
                $content = $content -replace [regex]::Escape($corrupted), $correct
                $fileReplacements += $count
                Write-Host "  - Fixed $count occurrence(s) of '$corrupted' → '$correct'" -ForegroundColor Gray
            }
        }
        
        if ($content -ne $originalContent) {
            # Save with UTF-8 encoding (no BOM)
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($file.FullName, $content, $utf8NoBom)
            
            Write-Host "✓ Fixed $($file.FullName) ($fileReplacements replacements)" -ForegroundColor Green
            $filesFixed += $file.FullName
            $totalFiles++
            $totalReplacements += $fileReplacements
        }
    }
    catch {
        Write-Host "✗ Error processing $($file.Name): $_" -ForegroundColor Red
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Files fixed: $totalFiles" -ForegroundColor Green
Write-Host "Total replacements: $totalReplacements" -ForegroundColor Green

if ($filesFixed.Count -gt 0) {
    Write-Host "`nFixed files:" -ForegroundColor Yellow
    foreach ($f in $filesFixed) {
        Write-Host "  $f" -ForegroundColor Gray
    }
}

Write-Host "`n✓ Unicode corruption fix complete!" -ForegroundColor Green
Write-Host "All files are now saved with proper UTF-8 encoding." -ForegroundColor Cyan
