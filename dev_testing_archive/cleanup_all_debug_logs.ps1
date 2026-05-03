# Comprehensive Debug Log Cleanup Script
# Removes all debug logging from Ruby and JavaScript files

Write-Host "Starting comprehensive debug log cleanup..." -ForegroundColor Green

# Files to clean
$files = @(
    "Extension/AutoNestCut/models/part.rb",
    "Extension/AutoNestCut/exporters/report_generator.rb",
    "Extension/AutoNestCut/exporters/assembly_exporter.rb",
    "Extension/AutoNestCut/ui/dialog_manager.rb",
    "Extension/AutoNestCut/ui/view_export_ui.rb"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "Cleaning $file..." -ForegroundColor Yellow
        
        $content = Get-Content $file -Raw
        
        # Remove all puts statements with DEBUG, emojis, or verbose markers
        $content = $content -replace 'puts\s+"DEBUG[^"]*"[^\n]*\n', ''
        $content = $content -replace 'puts\s+''DEBUG[^'']*''[^\n]*\n', ''
        $content = $content -replace 'puts\s+"[🔍💰📊🔧✅❌⚠️📦📏🔎📋📐💵💱][^"]*"[^\n]*\n', ''
        $content = $content -replace 'puts\s+''[🔍💰📊🔧✅❌⚠️📦📏🔎📋📐💵💱][^'']*''[^\n]*\n', ''
        $content = $content -replace 'puts\s+"\n"\s*\+\s*"="\*\d+[^\n]*\n', ''
        $content = $content -replace 'puts\s+"="\*\d+[^\n]*\n', ''
        $content = $content -replace 'puts\s+"[🔍]"\*\d+[^\n]*\n', ''
        
        # Remove console.log with DEBUG or emojis
        $content = $content -replace 'console\.log\([^)]*DEBUG[^)]*\);?\n', ''
        $content = $content -replace 'console\.log\([^)]*[🔍💰📊🔧✅❌⚠️][^)]*\);?\n', ''
        
        # Save cleaned content
        Set-Content -Path $file -Value $content -NoNewline
        
        Write-Host "  ✓ Cleaned $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ File not found: $file" -ForegroundColor Red
    }
}

Write-Host "`nDebug log cleanup complete!" -ForegroundColor Green
Write-Host "Please reload the extension in SketchUp to see the clean console output." -ForegroundColor Cyan
