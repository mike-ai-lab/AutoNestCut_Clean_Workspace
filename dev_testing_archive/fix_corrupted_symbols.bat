@echo off
setlocal enabledelayedexpansion

cd /d "c:\Users\Administrator\Desktop\AUTOMATION\cutlist\AutoNestCut\AutoNestCut_Clean_Workspace"

echo Starting corrupted symbol fix...
echo.

REM Use PowerShell to do the replacements
powershell -NoProfile -Command ^
"$files = @( ^
    'diagrams_report_from_git.js', ^
    'diagrams_report_working.js', ^
    'fix_symbols.ps1', ^
    'FIXES_AND_IMPROVEMENTS_APPLIED.md', ^
    'temp_old_report_gen.rb', ^
    'VERIFICATION_COMPLETE.md', ^
    'Extension\AutoNestCut\exporters\report_generator.rb', ^
    'Extension\AutoNestCut\ui\dialog_manager_backup.rb', ^
    'Extension\AutoNestCut\ui\html\diagrams_report_FIXED.js', ^
    'Extension\AutoNestCut\ui\html\diagrams_report.js' ^
); ^
$count = 0; ^
foreach ($f in $files) { ^
    if (Test-Path $f) { ^
        $content = [System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8); ^
        $original = $content; ^
        $content = $content -replace 'm┬▓', 'm²'; ^
        $content = $content -replace 'mm┬▓', 'mm²'; ^
        $content = $content -replace 'cm┬▓', 'cm²'; ^
        $content = $content -replace 'in┬▓', 'in²'; ^
        $content = $content -replace 'ft┬▓', 'ft²'; ^
        if ($content -ne $original) { ^
            [System.IO.File]::WriteAllText($f, $content, [System.Text.Encoding]::UTF8); ^
            Write-Host 'FIXED: '$f -ForegroundColor Green; ^
            $count++; ^
        } ^
    } ^
}; ^
Write-Host ''; ^
Write-Host 'Files processed: '$count -ForegroundColor Yellow; ^
Write-Host 'All corrupted symbols have been fixed!' -ForegroundColor Green"

echo.
echo Done!
pause
