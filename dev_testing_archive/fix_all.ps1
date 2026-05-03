$basePath = "c:\Users\Administrator\Desktop\AUTOMATION\cutlist\AutoNestCut\AutoNestCut_Clean_Workspace"
Set-Location $basePath

$files = @(
    'diagrams_report_from_git.js',
    'diagrams_report_working.js',
    'Extension\AutoNestCut\ui\html\diagrams_report.js',
    'Extension\AutoNestCut\ui\html\diagrams_report_FIXED.js',
    'Extension\AutoNestCut\exporters\report_generator.rb',
    'Extension\AutoNestCut\ui\dialog_manager_backup.rb',
    'temp_old_report_gen.rb'
)

$count = 0

foreach ($f in $files) {
    if (Test-Path $f) {
        $content = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)
        $original = $content
        
        $content = $content -replace 'm┬▓', 'm²'
        $content = $content -replace 'mm┬▓', 'mm²'
        $content = $content -replace 'cm┬▓', 'cm²'
        $content = $content -replace 'in┬▓', 'in²'
        $content = $content -replace 'ft┬▓', 'ft²'
        
        if ($content -ne $original) {
            [System.IO.File]::WriteAllText($f, $content, [System.Text.Encoding]::UTF8)
            Write-Host "FIXED: $f"
            $count++
        }
    }
}

Write-Host ""
Write-Host "Files processed: $count"
Write-Host "All corrupted symbols have been fixed!"
