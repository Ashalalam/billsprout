# Fix UTF-8 encoding issues in Dart files

$files = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse

$replacements = @{
    'â€"' = '-'      # em dash
    'â€˜' = "'"      # left single quote
    'â€™' = "'"      # right single quote
    'â€œ' = '"'      # left double quote
    'â€' = '"'       # right double quote
    'â€¢' = '•'      # bullet
    'â†'' = '→'      # right arrow
    'â†�' = '←'      # left arrow
    'â€¦' = '...'    # ellipsis
    'â‰¤' = '<='     # less than or equal
    'â‰¥' = '>='     # greater than or equal
    'Â°' = '°'       # degree symbol
    'â"€' = '-'      # box drawing horizontal
}

$totalFixed = 0

foreach ($file in $files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        $originalContent = $content
        
        foreach ($key in $replacements.Keys) {
            if ($content -match [regex]::Escape($key)) {
                $content = $content -replace [regex]::Escape($key), $replacements[$key]
                $totalFixed++
            }
        }
        
        if ($content -ne $originalContent) {
            Set-Content -Path $file.FullName -Value $content -Encoding UTF8 -NoNewline
            Write-Host "Fixed: $($file.Name)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "Error processing $($file.Name): $_" -ForegroundColor Red
    }
}

Write-Host "`nTotal fixes applied: $totalFixed" -ForegroundColor Cyan
Write-Host "Encoding fix complete!" -ForegroundColor Green
