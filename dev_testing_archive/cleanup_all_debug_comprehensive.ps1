# Comprehensive Debug Log Cleanup Script
# Removes all DEBUG logs, emoji logs, and verbose dividers from Ruby files

$files = @(
    "Extension/AutoNestCut/exporters/report_generator.rb",
    "Extension/AutoNestCut/exporters/assembly_exporter.rb",
    "Extension/AutoNestCut/ui/dialog_manager.rb",
    "Extension/AutoNestCut/ui/view_export_ui.rb",
    "Extension/AutoNestCut/models/board.rb"
)

$patterns = @(
    'puts "DEBUG.*?"',
    'puts "🔍.*?"',
    'puts "💰.*?"',
    'puts "📊.*?"',
    'puts "🔧.*?"',
    'puts "✅.*?"',
    'puts "❌.*?"',
    'puts "⚠️.*?"',
    'puts "📦.*?"',
    'puts "📏.*?"',
    'puts "🔎.*?"',
    'puts "📋.*?"',
    'puts "📐.*?"',
    'puts "💵.*?"',
    'puts "💱.*?"',
    'puts "🔗.*?"',
    'puts "🦟.*?"',
    'puts "\s*=+\s*"',
    'puts "={80}"',
    'puts "=" \* 80',
    'puts "🔍" \* 40',
    'puts "\n" \+ "🔍"\*40'
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "Processing: $file" -ForegroundColor Cyan
        
        $content = Get-Content $file -Raw -Encoding UTF8
        $originalLength = $content.Length
        
        # Remove each pattern
        foreach ($pattern in $patterns) {
            $content = $content -replace "(?m)^\s*$pattern\s*$", ""
        }
        
        # Remove empty lines that were left behind (max 2 consecutive)
        $content = $content -replace "(?m)^\s*\r?\n(\s*\r?\n){2,}", "`r`n`r`n"
        
        # Save cleaned content
        Set-Content -Path $file -Value $content -Encoding UTF8 -NoNewline
        
        $newLength = $content.Length
        $removed = $originalLength - $newLength
        Write-Host "  Removed $removed characters" -ForegroundColor Green
    } else {
        Write-Host "File not found: $file" -ForegroundColor Red
    }
}

Write-Host "`nCleanup complete!" -ForegroundColor Green
