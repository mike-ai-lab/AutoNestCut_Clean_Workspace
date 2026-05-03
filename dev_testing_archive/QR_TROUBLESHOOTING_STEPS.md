# QR Code Troubleshooting - Step by Step

## Current Issue
QR codes show "NO USABLE DATA FOUND" when scanned.

---

## Diagnostic Tests (Run in Order)

### TEST 1: Verify RQRCode Gem Works
**File:** `DEBUG_QR_GENERATION.txt`

**Purpose:** Check if RQRCode gem is generating valid QR data

**Run this first!** Copy/paste into SketchUp Ruby Console.

**Expected output:**
- Modules size: 21x21 (or similar)
- Black/white module counts
- Visual matrix display

**If this fails:** RQRCode gem is not working properly

---

### TEST 2: Generate PNG/SVG QR Codes
**File:** `TEST_QR_PNG_METHOD.txt`

**Purpose:** Use RQRCode's built-in export methods

**What it does:**
- Generates PNG file with QR code
- Generates SVG file with QR code
- Shows ASCII art QR in console

**Test:** Open the PNG/SVG files and scan them with your phone

**If PNG/SVG scan successfully:** QR generation works, PDF rendering is the problem
**If PNG/SVG don't scan:** RQRCode gem has issues

---

### TEST 3: Ultra Simple PDF Test
**File:** `ULTRA_SIMPLE_QR_TEST.txt`

**Purpose:** Test PDF generation with simplest possible data

**What it does:**
- Generates QR for "HELLO"
- Generates QR for "12345"
- Large QR codes (200pt)

**If these don't scan:** PDF rendering method is broken

---

### TEST 4: Fixed Coordinates Test
**File:** `FIX_QR_COORDINATES.txt`

**Purpose:** Test with corrected Prawn coordinate system

**What it does:**
- Draws white background first
- Correctly calculates Y coordinates
- Adds border for visual reference

**This might be the fix!**

---

## Possible Root Causes

### 1. **Coordinate System Issue** (Most Likely)
- Prawn Y coordinates go DOWN from top
- QR might be drawn upside down or mirrored
- **Fix:** Use corrected coordinate calculation

### 2. **Module Size Too Small**
- QR modules might be sub-pixel size
- Scanner can't detect individual modules
- **Fix:** Ensure module_size >= 2pt

### 3. **Data Too Long**
- Even with compact format, data might be too long
- **Fix:** Use even shorter data or larger QR

### 4. **RQRCode Gem Issue**
- Gem might not be generating valid QR codes
- **Test:** Use PNG/SVG export methods

### 5. **PDF Rendering Issue**
- Prawn might not be rendering rectangles correctly
- **Test:** Check if border rectangle appears

---

## Quick Fixes to Try

### Fix 1: Use RQRCode's Built-in SVG
If RQRCode has `as_svg` method, use it directly instead of manual rectangles.

### Fix 2: Increase Module Size
Ensure each QR module is at least 2-3 points:
```ruby
module_size = [qr_size / qr.modules.size, 2.0].max
```

### Fix 3: Add Quiet Zone
QR codes need white border (quiet zone):
```ruby
# Add 4-module quiet zone
quiet_zone = module_size * 4
# Draw white rectangle larger than QR
```

### Fix 4: Use Different Error Correction
Try different levels:
- `:l` - Low (7% correction, most data)
- `:m` - Medium (15% correction)
- `:q` - Quartile (25% correction)
- `:h` - High (30% correction, least data)

---

## What to Report Back

After running the tests, please tell me:

1. **DEBUG_QR_GENERATION.txt result:**
   - Did it show valid module data?
   - Any errors?

2. **TEST_QR_PNG_METHOD.txt result:**
   - Did PNG file generate?
   - Does PNG scan successfully?
   - Does SVG scan successfully?

3. **ULTRA_SIMPLE_QR_TEST.txt result:**
   - Does "HELLO" QR scan?
   - Does "12345" QR scan?

4. **FIX_QR_COORDINATES.txt result:**
   - Does this version scan?

5. **Your QR scanner app:**
   - Which app are you using?
   - Does it scan other QR codes successfully?

---

## Next Steps Based on Results

### If PNG/SVG scan but PDF doesn't:
→ Problem is PDF rendering
→ Need to fix coordinate system or use different rendering method

### If nothing scans (PNG, SVG, PDF):
→ Problem is RQRCode gem or data format
→ Need to check gem installation or use different gem

### If simple data scans but complex doesn't:
→ Problem is data length
→ Need even more compact format

---

## Alternative Solution

If all else fails, we can:
1. Use RQRCode's built-in PNG export
2. Embed PNG images in PDF instead of drawing rectangles
3. This is guaranteed to work if RQRCode gem is functional

---

**Please run the tests in order and report results!**
