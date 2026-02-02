#SingleInstance Force
#Requires AutoHotkey v2.0

; QR Code to Clipboard - Simple & Reliable
; Win+Alt+Q to scan QR code from screen
; Result automatically copied to clipboard

SetWorkingDir(A_ScriptDir)

; System tray setup
A_IconTip := "QR to Clipboard`nPress Win+Alt+Q to scan"
Tray := A_TrayMenu
Tray.Delete()
Tray.Add("📷 Scan QR Code", ScanQR)
Tray.Add()
Tray.Add("❌ Exit", (*) => ExitApp())
Tray.Default := "📷 Scan QR Code"

; Show startup message
TrayTip("QR Scanner Ready", "Press Win+Alt+Q to scan QR codes", 2)
SetTimer(() => TrayTip(), -2000)

; Hotkey: Win+Alt+Q
#!q::ScanQR()

ScanQR(*) {
    ; Backup current clipboard
    SavedClip := ClipboardAll()
    A_Clipboard := ""
    
    ; Launch Windows Snipping Tool
    Run("ms-screenclip:")
    
    ; Wait for user to capture screenshot (max 60 seconds)
    if !ClipWait(60, 1) {
        ; User cancelled or timeout
        A_Clipboard := SavedClip
        return
    }
    
    ; Create temp file path
    TempFile := A_Temp "\qr_temp_" A_TickCount ".png"
    ResultFile := A_Temp "\qr_result_" A_TickCount ".txt"
    
    ; PowerShell script to decode QR
    PSScript := '
    (
        $ErrorActionPreference = "Stop"
        
        try {
            # Load required assemblies
            Add-Type -AssemblyName System.Drawing
            Add-Type -AssemblyName System.Windows.Forms
            
            # Get image from clipboard
            $image = [System.Windows.Forms.Clipboard]::GetImage()
            
            if ($null -eq $image) {
                "ERROR:No image found"
                exit 1
            }
            
            # Save to temp file
            $image.Save("' TempFile '", [System.Drawing.Imaging.ImageFormat]::Png)
            
            # Load ZXing library
            $zxingPath = "' A_ScriptDir '\QR-Code-Reader\Source\zxing.dll"
            if (-not (Test-Path $zxingPath)) {
                "ERROR:ZXing library not found"
                exit 1
            }
            
            Add-Type -Path $zxingPath
            
            # Decode QR code
            $reader = New-Object ZXing.BarcodeReader
            $bitmap = New-Object System.Drawing.Bitmap("' TempFile '")
            $result = $reader.Decode($bitmap)
            
            # Cleanup
            $bitmap.Dispose()
            $image.Dispose()
            
            if ($null -ne $result -and $result.Text) {
                # Output the decoded text
                $result.Text
            } else {
                "ERROR:No QR code detected in image"
                exit 1
            }
            
            # Delete screenshot from Screenshots folder
            try {
                $screenshotDir = [System.Environment]::GetFolderPath("MyPictures") + "\Screenshots"
                Get-ChildItem -Path $screenshotDir -ErrorAction SilentlyContinue |
                    Where-Object { $_.CreationTime -gt (Get-Date).AddSeconds(-10) } |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            } catch {
                # Ignore cleanup errors
            }
            
        } catch {
            "ERROR:" + $_.Exception.Message
            exit 1
        } finally {
            # Cleanup temp file
            if (Test-Path "' TempFile '") {
                Remove-Item "' TempFile '" -Force -ErrorAction SilentlyContinue
            }
        }
    )'
    
    ; Execute PowerShell and capture output
    try {
        ; Run PowerShell hidden
        RunWait('powershell.exe -WindowStyle Hidden -NoProfile -Command "' PSScript '" > "' ResultFile '"', , "Hide")
        
        ; Read result
        if FileExist(ResultFile) {
            result := FileRead(ResultFile)
            FileDelete(ResultFile)
        } else {
            result := "ERROR:No output from decoder"
        }
        
        ; Process result
        result := Trim(result)
        
        if InStr(result, "ERROR:") {
            ; Error occurred
            errorMsg := StrReplace(result, "ERROR:", "")
            TrayTip("QR Scan Failed", errorMsg, 3)
            A_Clipboard := SavedClip
        } else if result != "" {
            ; Success - copy to clipboard
            A_Clipboard := result
            TrayTip("✓ QR Code Scanned", "Data copied to clipboard!", 2)
            SetTimer(() => TrayTip(), -2000)
        } else {
            ; Empty result
            TrayTip("QR Scan Failed", "No data received", 3)
            A_Clipboard := SavedClip
        }
        
    } catch as err {
        ; Script error
        TrayTip("Error", "Failed to decode: " err.Message, 3)
        A_Clipboard := SavedClip
    }
}
