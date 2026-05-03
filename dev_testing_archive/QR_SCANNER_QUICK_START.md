# QR Scanner Quick Start Guide

## ✅ Ready to Use - No Installation Required!

I've created a browser-based QR scanner that works immediately without any installation.

## How to Use

### Option 1: Open the HTML File (Easiest)

1. **Open the scanner**:
   ```
   Double-click: qr_scanner_test.html
   ```
   It will open in your default browser.

2. **Scan QR codes**:
   - Click "📷 Start Camera" to use your webcam
   - OR click "📁 Upload Image" to scan from a file/screenshot

3. **View results**:
   - AutoNestCut QR codes will show formatted part information
   - Data is automatically copied to clipboard
   - Click "📋 Copy to Clipboard" to copy again

### Option 2: Scan from Screenshots

1. Take a screenshot of your AutoNestCut diagram (Win + Shift + S)
2. Open `qr_scanner_test.html`
3. Click "📁 Upload Image"
4. Select your screenshot
5. View the decoded part data!

## Testing Your QR Codes

### Quick Test with Sample QR Code

1. **Generate a test QR code** in SketchUp Ruby Console:
   ```ruby
   require_relative 'Extension/AutoNestCut/exporters/qr_code_generator'
   
   generator = AutoNestCut::QRCodeGenerator.new
   
   test_part = {
     part_id: 'TEST-001',
     name: 'Cabinet Side Panel',
     material: '18mm Plywood',
     width: 600,
     height: 800,
     thickness: 18,
     board_number: 1
   }
   
   qr_svg = generator.generate_qr_code(test_part, size: 50)
   File.write('test_qr_code.svg', qr_svg)
   puts "✅ QR code saved to test_qr_code.svg"
   ```

2. **Open the SVG file** in your browser

3. **Scan it** with the QR scanner tool

4. **Expected result**:
   ```json
   {
     "v": "1.0",
     "id": "TEST-001",
     "n": "Cabinet Side Panel",
     "m": "18mm Plywood",
     "d": {"w": 600.0, "h": 800.0, "t": 18.0},
     "b": 1,
     "ts": [timestamp]
   }
   ```

## What the Scanner Shows

### For AutoNestCut QR Codes:
- ✅ **Part ID**: Unique identifier
- ✅ **Part Name**: Component name
- ✅ **Material**: Material specification
- ✅ **Dimensions**: Width × Height × Thickness (mm)
- ✅ **Board Number**: Which sheet it's nested on
- ✅ **Version**: QR code format version

### For Other QR Codes:
- Shows the raw decoded text
- Works with URLs, WiFi codes, plain text, etc.

## Troubleshooting

### Camera Not Working
- Grant camera permissions when prompted
- Try a different browser (Chrome/Edge recommended)
- Use "Upload Image" option instead

### "No QR code found in image"
- Make sure the QR code is clearly visible
- Try a higher resolution screenshot
- Ensure good contrast (black QR on white background)

### QR Code Shows "NO USABLE DATA FOUND"
✅ **This is now fixed!** The recent updates to AutoNestCut ensure QR codes contain real data.

If you still see this:
1. Reload the AutoNestCut extension in SketchUp
2. Clear the QR cache: `AutoNestCut::QRCodeGenerator.clear_cache`
3. Regenerate your diagram

## Browser Compatibility

✅ **Works in**:
- Chrome/Edge (Recommended)
- Firefox
- Safari
- Opera

## Privacy Note

- All scanning happens locally in your browser
- No data is sent to any server
- Camera access is only used for scanning
- You can use offline after the page loads

## Alternative: Windows QR Code Reader

If you want the Windows desktop app with keyboard shortcuts:

1. **Download AutoHotkey v2.0**: https://www.autohotkey.com/
2. **Run the script**: Double-click `QR-Code-Reader/Source/reader.ahk`
3. **Use shortcut**: Press `Win + Alt + Q` to scan from screen

## Next Steps

Once you've verified your QR codes work:

1. ✅ Generate nesting diagrams with QR labels in AutoNestCut
2. ✅ Print the diagrams or label sheets
3. ✅ Use this scanner during assembly to identify parts
4. ✅ Scan labels to verify you're using the correct piece

## Tips for Best Results

- **QR Size**: Use at least 20mm × 20mm for printed labels
- **Print Quality**: Use high quality settings (300+ DPI)
- **Contrast**: Ensure good black/white contrast
- **Lighting**: Scan in good lighting conditions
- **Distance**: Hold camera 10-20cm from QR code

## Support

If you encounter issues:
1. Check that the QR code generator fix was applied
2. Verify the QR code contains data (not just a visual pattern)
3. Try scanning with a phone QR app to compare results
