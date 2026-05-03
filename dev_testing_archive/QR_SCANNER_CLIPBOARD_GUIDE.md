# QR Scanner - Clipboard Only Version

## ✅ Simple Setup - Just Run the Script!

I've created a simplified version that copies QR codes directly to your clipboard without any notifications.

## How to Use

### Step 1: Run the Script

Double-click: **`qr_to_clipboard.ahk`**

You'll see a brief tray notification saying "QR Scanner Ready"

### Step 2: Scan QR Codes

1. Press **`Win + Alt + Q`** (or click the tray icon)
2. Windows Snipping Tool opens
3. Select the QR code area
4. **Done!** The decoded text is now in your clipboard

### Step 3: Paste the Result

Press **`Ctrl + V`** anywhere to paste the decoded QR data

## What's Different?

✅ **No notifications** (except brief "copied" message)  
✅ **Direct to clipboard** - just paste after scanning  
✅ **Auto-cleanup** - removes screenshot files automatically  
✅ **Simple tray icon** - minimal interface  

## Testing

### Quick Test:

1. Open `qr_scanner_test.html` in your browser
2. Generate a test QR code (or use any QR code)
3. Press `Win + Alt + Q`
4. Select the QR code on screen
5. Open Notepad and press `Ctrl + V`
6. You should see the decoded data!

### Test with AutoNestCut:

1. Generate a nesting diagram with QR labels in SketchUp
2. Export as HTML or open the diagram
3. Press `Win + Alt + Q`
4. Select a QR code from the diagram
5. Paste into Notepad to see the part data

Expected format:
```json
{"v":"1.0","id":"TEST-001","n":"Cabinet Side Panel","m":"18mm Plywood","d":{"w":600.0,"h":800.0,"t":18.0},"b":1,"ts":1234567890}
```

## Troubleshooting

### "No QR code detected"
- Make sure you're selecting the complete QR code
- Try selecting a larger area around the QR code
- Ensure the QR code is clearly visible (not blurry)

### "ZXing library not found"
The script looks for: `QR-Code-Reader\Source\zxing.dll`

Make sure the folder structure is:
```
Your Workspace/
├── qr_to_clipboard.ahk          ← Run this
└── QR-Code-Reader/
    └── Source/
        └── zxing.dll            ← Must be here
```

### Nothing happens when I press Win+Alt+Q
- Make sure the script is running (check system tray)
- Try right-clicking the tray icon and selecting "Scan QR Code"
- Restart the script

### Clipboard doesn't update
- Check if you see any error messages in the tray notification
- Try scanning a simple QR code first (like a URL)
- Make sure you're waiting for the snipping tool to close

## Tips for Best Results

1. **QR Code Size**: Larger QR codes scan more reliably
2. **Screen Resolution**: Higher resolution = better scanning
3. **Contrast**: Black QR on white background works best
4. **Selection**: Select the entire QR code plus a small margin
5. **Lighting**: If using printed QR codes, ensure good lighting

## Keyboard Shortcuts

- **`Win + Alt + Q`** - Start QR scan
- **`Ctrl + V`** - Paste decoded result

## System Tray

The script runs in the background with a system tray icon:
- **Left-click** or **Double-click** - Start scan
- **Right-click** - Show menu
  - 📷 Scan QR Code
  - ❌ Exit

## Workflow for AutoNestCut

1. **Design** → Create furniture in SketchUp
2. **Nest** → Run AutoNestCut to optimize layout
3. **Export** → Generate diagram with QR labels
4. **Print** → Print the diagram or label sheet
5. **Scan** → Use this tool to identify parts during assembly
6. **Paste** → Paste part data into your tracking system

## Alternative: Browser-Based Scanner

If the AutoHotkey version doesn't work, you can use the browser version:

1. Open `qr_scanner_test.html`
2. Click "📁 Upload Image"
3. Take a screenshot (Win+Shift+S) and save it
4. Upload the screenshot
5. Copy the result from the browser

## Files

- **`qr_to_clipboard.ahk`** - Main script (recommended)
- **`qr_scanner_simple.ahk`** - Alternative version
- **`qr_scanner_test.html`** - Browser-based scanner (no installation)
- **`QR-Code-Reader/Source/zxing.dll`** - Required library

## Uninstalling

To remove:
1. Right-click the tray icon and select "Exit"
2. Delete the `.ahk` files
3. Optionally delete the `QR-Code-Reader` folder

## Support

If you encounter issues:
1. Make sure AutoHotkey v2.0 is installed (from Microsoft Store)
2. Check that `zxing.dll` exists in the correct location
3. Try the browser-based scanner as an alternative
4. Test with a simple QR code (like a URL) first
