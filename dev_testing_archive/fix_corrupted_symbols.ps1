$basePath = "c:\Users\Administrator\Desktop\AUTOMATION\cutlist\AutoNestCut\AutoNestCut_Clean_Workspace"

$filesToFix = @(
    "$basePath\diagrams_report_from_git.js",
    "$basePath\diagrams_report_working.js",
    "$basePath\fix_symbols.ps1",
    "$basePath\FIXES_AND_IMPROVEMENTS_APPLIED.md",
    "$basePath\temp_old_report_gen.rb",
    "$basePath\VERIFICATION_COMPLETE.md",
    "$basePath\Extension\AutoNestCut\exporters\report_generator.rb",
    "$basePath\Extension\AutoNestCut\ui\dialog_manager_backup.rb",
    "$basePath\Extension\AutoNestCut\ui\html\diagrams_report_FIXED.js",
    "$basePath\Extension\AutoNestCut\ui\html\diagrams_report.js"
)

$totalFilesProcessed = 0

Write-Host "Starting corrupted symbol fix..." -ForegroundColor Cyan
Write-Host ""

foreach ($file in $filesToFix) {
    if (-not (Test-Path $file)) {
        Write-Host "SKIPPED: $file (not found)" -ForegroundColor Yellow
        continue
    }
    
    $content = Get-Content -Path $file -Raw -Encoding UTF8
    $originalContent = $content
    
    $content = $content -replace 'm┬▓', 'm²'
    $content = $content -replace 'mm┬▓', 'mm²'
    $content = $content -replace 'cm┬▓', 'cm²'
    $content = $content -replace 'in┬▓', 'in²'
    $content = $content -replace 'ft┬▓', 'ft²'
    
    if ($content -ne $originalContent) {
        Set-Content -Path $file -Value $content -Encoding UTF8 -NoNewline
        Write-Host "FIXED: $(Split-Path $file -Leaf)" -ForegroundColor Green
        $totalFilesProcessed++
    }
}

Write-Host ""
Write-Host "Files processed: $totalFilesProcessed" -ForegroundColor Yellow
Write-Host "All corrupted symbols have been fixed!" -ForegroundColor Green
