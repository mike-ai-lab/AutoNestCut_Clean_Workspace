#SingleInstance Force
#Requires AutoHotkey v2.0

; Simple QR Scanner for AutoNestCut
; Press Win+Alt+Q to scan, result goes directly to clipboard

SetWorkingDir(A_ScriptDir)

; Tray menu
A_IconTip := "QR Scanner (Win+Alt+Q)"
Tray := A_TrayMenu
Tray.Delete()
Tray.Add("Scan QR Code", ScanQR)
Tray.Add("Exit", (*) => ExitApp())
Tray.Default := "Scan QR Code"

; Keyboard shortcut
#!q::ScanQR()

ScanQR(*) {
    ; Save current clipboard
    OldClip := ClipboardAll()
    A_Clipboard := ""
    
    ; Open snipping tool
    Run("ms-screenclip:")
    
    ; Wait for screenshot (60 second timeout)
    if !ClipWait(60, 1) {
        A_Clipboard := OldClip
        ToolTip("Scan cancelled")
        SetTimer(() => ToolTip(), -2000)
        return
    }
    
    ; Save screenshot to temp file
    TempImg := A_Temp "\qr_scan_" A_TickCount ".png"
    
    ; Use PowerShell to save image and decode QR
    PS := '
    (
        Add-Type -AssemblyName System.Drawing
        Add-Type -AssemblyName System.Windows.Forms
        
        # Save clipboard image to file
        $img = [Windows.Forms.Clipboard]::GetImage()
        if ($img) {
            $img.Save("' TempImg '", [System.Drawing.Imaging.ImageFormat]::Png)
            
            # Load ZXing and decode
            Add-Type -Path "' A_ScriptDir '\QR-Code-Reader\Source\zxing.dll"
            $reader = New-Object ZXing.BarcodeReader
            $bitmap = New-Object System.Drawing.Bitmap("' TempImg '")
            $result = $reader.Decode($bitmap)
            
            if ($result) {
                Write-Output $result.Text
            } else {
                Write-Output "ERROR:No QR code found"
            }
            
            # Cleanup
            $bitmap.Dispose()
            Remove-Item "' TempImg '" -Force -ErrorAction SilentlyContinue
            
            # Delete screenshot from Screenshots folder
            $screenshotPath = [Environment]::GetFolderPath("MyPictures") + "\Screenshots"
            Get-ChildItem $screenshotPath -ErrorAction SilentlyContinue | 
                Where-Object {$_.CreationTime -gt (Get-Date).AddSeconds(-5)} | 
                Remove-Item -Force -ErrorAction SilentlyContinue
        } else {
            Write-Output "ERROR:No image in clipboard"
        }
    )'
    
    ; Run PowerShell and get result
    shell := ComObject("WScript.Shell")
    exec := shell.Exec('powershell.exe -WindowStyle Hidden -Command "' PS '"')
    result := exec.StdOut.ReadAll()
    
    ; Process result
    result := Trim(result)
    
    if InStr(result, "ERROR:") {
        A_Clipboard := OldClip
        msg := StrReplace(result, "ERROR:", "")
        ToolTip(msg)
        SetTimer(() => ToolTip(), -3000)
    } else if result != "" {
        A_Clipboard := result
        ToolTip("✓ Copied to clipboard!")
        SetTimer(() => ToolTip(), -1500)
    } else {
        A_Clipboard := OldClip
        ToolTip("No result")
        SetTimer(() => ToolTip(), -2000)
    }
}
