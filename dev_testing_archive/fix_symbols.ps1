$path = 'c:\Users\Administrator\Desktop\AUTOMATION\cutlist\AutoNestCut\AutoNestCut_Clean_Workspace\Extension\AutoNestCut'
$files = Get-ChildItem -Path $path -Recurse -Include '*.js', '*.rb'

foreach ($file in $files) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $modified = $false
    
    # Replace corrupted square meter symbols
    if ($content -match 'm²') {
        $content = $content -replace 'm²', 'm²'
        $modified = $true
        Write-Host "Replaced m² in $($file.Name)"
    }
    if ($content -match 'mm²') {
        $content = $content -replace 'mm²', 'mm²'
        $modified = $true
        Write-Host "Replaced mm² in $($file.Name)"
    }
    if ($content -match 'cm²') {
        $content = $content -replace 'cm²', 'cm²'
        $modified = $true
        Write-Host "Replaced cm��▓ in $($file.Name)"
    }
    if ($content -match 'in²') {
        $content = $content -replace 'in²', 'in²'
        $modified = $true
        Write-Host "Replaced in² in $($file.Name)"
    }
    if ($content -match 'ft²') {
        $content = $content -replace 'ft²', 'ft²'
        $modified = $true
        Write-Host "Replaced ft² in $($file.Name)"
    }
    
    if ($modified) {
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
        Write-Host "✓ Fixed: $($file.Name)" -ForegroundColor Green
    }
}

Write-Host "All files processed!" -ForegroundColor Green
