# QR Code Scanning Fix Applied

## Problem
QR codes were generating visual patterns but not encoding actual data, resulting in "NO USABLE DATA FOUND" errors when scanned.

## Solution Applied

### 1. Updated `qr_code_generator.rb`
- ✅ Removed duplicate constant definitions
- ✅ Added proper RQRCode library integration with `setup_vendor_paths()`
- ✅ Implemented real QR code generation using `RQRCode::QRCode.new()`
- ✅ Added helper methods: `extract_viewbox()`, `extract_content()`, `generate_error_svg()`
- ✅ Proper error handling with fallback to error SVG
- ✅ Encodes part data as JSON with version, ID, name, material, dimensions, board number, and timestamp

### 2. Updated `label_generator.rb`
- ✅ Simplified QR code embedding using `<g transform>` wrapper
- ✅ Removed complex SVG extraction logic
- ✅ Direct embedding of generated QR SVG
- ✅ Cleaner fallback for failed generation

## How It Works Now

1. **Data Encoding**: Part data is encoded as compact JSON:
   ```json
   {
     "v": "1.0",
     "id": "part_id",
     "n": "part_name",
     "m": "material",
     "d": {"w": 100.0, "h": 50.0, "t": 18.0},
     "b": 1,
     "ts": 1234567890
   }
   ```

2. **QR Generation**: Uses the bundled `rqrcode` library to create valid QR codes with error correction level M (15%)

3. **SVG Output**: Generates clean SVG with proper viewBox and dimensions for embedding in labels

## Testing
To test the fix:
1. Reload the extension in SketchUp
2. Generate a nesting diagram with QR labels enabled
3. Scan the QR codes with any QR scanner app
4. You should now see the encoded part data instead of "NO USABLE DATA FOUND"

## Files Modified
- `Extension/AutoNestCut/exporters/qr_code_generator.rb`
- `Extension/AutoNestCut/exporters/label_generator.rb`
