# PowerShell script to download and install MinGW-w64

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MinGW-w64 Installation Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$mingwUrl = "https://github.com/niXman/mingw-builds-binaries/releases/download/13.2.0-rt_v11-rev1/x86_64-13.2.0-release-posix-seh-ucrt-rt_v11-rev1.7z"
$downloadPath = "$env:TEMP\mingw64.7z"
$installPath = "C:\mingw64"

# Check if already installed
if (Test-Path "$installPath\bin\g++.exe") {
    Write-Host "MinGW-w64 is already installed at $installPath" -ForegroundColor Green
    Write-Host ""
    & "$installPath\bin\g++.exe" --version
    Write-Host ""
    Write-Host "You can proceed to build the C++ solver!" -ForegroundColor Green
    exit 0
}

Write-Host "This script will:" -ForegroundColor Yellow
Write-Host "  1. Download MinGW-w64 (13.2.0)" -ForegroundColor Yellow
Write-Host "  2. Extract to C:\mingw64" -ForegroundColor Yellow
Write-Host "  3. Add to system PATH" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Continue? (Y/N)"
if ($confirm -ne "Y" -and $confirm -ne "y") {
    Write-Host "Installation cancelled." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Downloading MinGW-w64..." -ForegroundColor Cyan

try {
    # Download
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $mingwUrl -OutFile $downloadPath -UseBasicParsing
    Write-Host "Download complete!" -ForegroundColor Green
    
    # Check if 7-Zip is available
    $7zipPath = "C:\Program Files\7-Zip\7z.exe"
    if (-not (Test-Path $7zipPath)) {
        Write-Host ""
        Write-Host "ERROR: 7-Zip not found!" -ForegroundColor Red
        Write-Host "Please install 7-Zip from: https://www.7-zip.org/" -ForegroundColor Yellow
        Write-Host "Then run this script again." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Alternatively, manually extract $downloadPath to C:\mingw64" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "Extracting..." -ForegroundColor Cyan
    & $7zipPath x $downloadPath -o"C:\" -y | Out-Null
    
    if (Test-Path "$installPath\bin\g++.exe") {
        Write-Host "Extraction complete!" -ForegroundColor Green
        
        # Add to PATH
        Write-Host "Adding to system PATH..." -ForegroundColor Cyan
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($currentPath -notlike "*$installPath\bin*") {
            [Environment]::SetEnvironmentVariable("Path", "$currentPath;$installPath\bin", "Machine")
            Write-Host "Added to PATH successfully!" -ForegroundColor Green
        } else {
            Write-Host "Already in PATH." -ForegroundColor Green
        }
        
        # Cleanup
        Remove-Item $downloadPath -Force
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Installation Complete!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "IMPORTANT: Close and reopen your terminal/PowerShell" -ForegroundColor Yellow
        Write-Host "Then verify installation with: g++ --version" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Next step: Run build_mingw.bat to compile the solver" -ForegroundColor Cyan
        
    } else {
        Write-Host "ERROR: Extraction failed!" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual installation:" -ForegroundColor Yellow
    Write-Host "1. Download from: $mingwUrl" -ForegroundColor Yellow
    Write-Host "2. Extract to C:\mingw64" -ForegroundColor Yellow
    Write-Host "3. Add C:\mingw64\bin to system PATH" -ForegroundColor Yellow
    exit 1
}
