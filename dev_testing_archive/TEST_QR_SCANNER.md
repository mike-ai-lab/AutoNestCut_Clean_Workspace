# Testing QR Code Scanner with AutoNestCut

## Quick Test Instructions

### 1. Install QR Code Reader

**Easiest Method (Winget):**
```cmd
winget install OttoZumkeller.QR-CodeReader
```

**Alternative (Run Script Directly):**
- Requires AutoHotkey v2.0: https://www.autohotkey.com/
- Navigate to `QR-Code-Reader/Source/`
- Double-click `reader.ahk`

### 2. Generate Test QR Code in AutoNestCut

In SketchUp Ruby Console, run:
```ruby
# Quick test to generate a sample QR code
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

# Save to file for testing
File.write('test_qr_code.svg', qr_svg)
puts "QR code saved to test_qr_code.svg"
```

### 3. Test the Scanner

1. Open `test_qr_code.svg` in a web browser
2. Press `Win + Alt + Q`
3. Select the QR code with the snipping tool
4. Check the Windows notification for decoded data

### 4. Expected Result

You should see a notification with the JSON data:
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

## Full Workflow Test

### Step 1: Create Test Components in SketchUp
```ruby
# Create a simple test cabinet
model = Sketchup.active_model
entities = model.active_entities

# Create a component
definition = model.definitions.add("Test Panel")
definition.entities.add_face([0,0,0], [600,0,0], [600,800,0], [0,800,0])

# Add material attribute
definition.set_attribute('AutoNestCut', 'material', '18mm Plywood')

# Place instance
entities.add_instance(definition, Geom::Transformation.new)
```

### Step 2: Run AutoNestCut Analysis
1. Select the component
2. Open AutoNestCut dialog
3. Enable "QR Labels" in settings
4. Run nesting analysis
5. Export diagram (HTML or SVG)

### Step 3: Scan QR Codes from Diagram
1. Open exported diagram in browser
2. Use QR Code Reader (Win+Alt+Q)
3. Scan each QR code on the parts
4. Verify part information matches

## Troubleshooting

### QR Code Shows "NO USABLE DATA FOUND"
✅ **FIXED!** The recent updates to `qr_code_generator.rb` and `label_generator.rb` now generate valid QR codes with real data encoding.

If you still see this error:
1. Make sure you reloaded the AutoNestCut extension after the fix
2. Clear the QR code cache: `AutoNestCut::QRCodeGenerator.clear_cache`
3. Regenerate the diagram

### Scanner Says "No QR-Code detected!"
- Select a larger area around the QR code
- Ensure the QR code is at least 100x100 pixels on screen
- Check that the QR code is not distorted or blurry

### QR Code Too Small to Scan
Increase QR size in AutoNestCut settings:
```ruby
# In label_generator.rb options
qr_size: 30  # Increase from 20 to 30mm or more
```

## Keyboard Shortcuts

- `Win + Alt + Q` - Start QR scan
- Click system tray icon - Open menu
- Right-click notification - Dismiss

## Integration Benefits

Using this QR scanner with AutoNestCut provides:

1. **Quick Part Identification**: Scan labels during assembly
2. **Error Prevention**: Verify you're using the correct part
3. **Material Tracking**: Confirm material specifications
4. **Board Tracking**: Know which sheet the part came from
5. **Digital Integration**: Link physical parts to digital records

## Next Steps

Once testing is successful:
1. Print label sheets with QR codes
2. Attach labels to cut parts
3. Use scanner during assembly
4. Track parts through production workflow
