# 🔍 PRICING SYSTEM DEBUG INSTRUCTIONS

## 🔴 Issue: Prices Showing as $0.00 in Report

You've added prices to materials in the Stock Materials table, but the report still shows $0.00 for all costs.

---

## ✅ DEBUG LOGGING ADDED

I've added comprehensive debug logging to help identify the issue. The logging will show:

1. **What material name is being looked up**
2. **What materials are available in the database**
3. **Whether the material was found**
4. **What price was extracted (or why it failed)**

---

## 📋 DEBUGGING STEPS

### Step 1: Reload the Extension

```ruby
load 'Extension/autonestcut.rb'
```

### Step 2: Open the Ruby Console

In SketchUp:
- **Windows:** Extensions → Developer → Ruby Console
- **Mac:** Window → Ruby Console

### Step 3: Generate a Report

1. Select your components
2. Open AutoNestCut dialog
3. Click "Generate Cut List"

### Step 4: Check the Ruby Console Output

Look for sections like this:

```
🔍 PRICING DEBUG for Plywood:
  - Looking for material: 'Plywood'
  - Available materials: ["Plywood", "MDF", "Chipboard"]
  - Material found: YES
  - Price found: 50.0 USD
```

OR if there's a problem:

```
🔍 PRICING DEBUG for Plywood 18mm:
  - Looking for material: 'Plywood 18mm'
  - Available materials: ["Plywood", "MDF", "Chipboard"]
  - Material found: NO
  - ⚠️ NO PRICE DATA FOUND - Using 0
```

---

## 🔍 COMMON ISSUES & SOLUTIONS

### Issue 1: Material Name Mismatch

**Symptom:**
```
- Looking for material: 'Plywood 18mm'
- Available materials: ["Plywood"]
- Material found: NO
```

**Cause:** The material name in SketchUp doesn't match the name in the Stock Materials table.

**Solution:**
1. Check what material name is assigned to your components in SketchUp
2. Make sure the EXACT same name exists in Stock Materials table
3. Names are case-sensitive: "Plywood" ≠ "plywood"

**How to Fix:**
- Option A: Rename the material in SketchUp to match the Stock Materials table
- Option B: Add a new material in Stock Materials with the exact name from SketchUp

---

### Issue 2: Price Not Saved

**Symptom:**
```
- Material found: YES
- Price found: 0 USD
```

**Cause:** The price field is empty or wasn't saved.

**Solution:**
1. Open Stock Materials table
2. Find the material
3. Enter a price (e.g., 50.00)
4. Click the **Save** button (or press Enter)
5. Verify the price is saved by refreshing the page

---

### Issue 3: Material Data is Array

**Symptom:**
```
- Material is Array, using first element
- Price found: 0 USD
```

**Cause:** The material has multiple thickness variations, and the price is in the wrong element.

**Solution:**
1. Check if your material has multiple thicknesses in the database
2. Make sure each thickness variation has a price set
3. The system will use the first matching thickness

---

### Issue 4: Stock Materials Not Loaded

**Symptom:**
```
- Available materials: []
- Material found: NO
```

**Cause:** The materials database isn't being loaded.

**Solution:**
1. Check if the materials database file exists
2. Try adding a new material and saving
3. Reload the extension
4. Check Ruby console for any error messages about loading the database

---

## 🔧 MANUAL VERIFICATION

### Check the Materials Database File

**Windows:**
```
%APPDATA%\SketchUp\SketchUp 2020\SketchUp\Plugins\AutoNestCut\materials_database.json
```

**Mac:**
```
~/Library/Application Support/SketchUp 2020/SketchUp/Plugins/AutoNestCut/materials_database.json
```

Open this file in a text editor and verify:
1. The file exists
2. It contains your materials
3. Each material has a "price" field
4. The material names match exactly

**Example:**
```json
{
  "Plywood": {
    "width": 2440,
    "height": 1220,
    "thickness": 18,
    "price": 50.00,
    "currency": "USD",
    "density": 600
  }
}
```

---

## 📊 EXPECTED CONSOLE OUTPUT (Working)

When pricing is working correctly, you should see:

```
=== BOARD MATERIAL DEBUG ===
Board #1
board.material: "Plywood"
============================

DEBUG: stock_materials class: Hash
DEBUG: stock_materials keys: ["Plywood", "MDF", "Chipboard"]
DEBUG: board_material: "Plywood"
DEBUG: material_data class: Hash
DEBUG: material_data: {"width"=>2440, "height"=>1220, "thickness"=>18, "price"=>50.0, "currency"=>"USD", "density"=>600}

🔍 PRICING DEBUG for Plywood:
  - Looking for material: 'Plywood'
  - Available materials: ["Plywood", "MDF", "Chipboard"]
  - Material found: YES
  - Price found: 50.0 USD
```

---

## 🎯 QUICK FIX CHECKLIST

- [ ] Material names in SketchUp match Stock Materials table EXACTLY
- [ ] Prices are entered in Stock Materials table
- [ ] Prices are saved (click Save button)
- [ ] Extension reloaded after adding/changing prices
- [ ] Ruby console checked for error messages
- [ ] Materials database file exists and is valid JSON

---

## 💡 TIPS

### Tip 1: Use Simple Material Names
Instead of "Plywood 18mm", use just "Plywood" and let the system handle thickness matching.

### Tip 2: Check Material Assignment
In SketchUp, select a component and check:
- Entity Info window
- What material is assigned?
- Does it match your Stock Materials table?

### Tip 3: Test with One Material First
1. Create a simple test with just one material
2. Make sure pricing works for that one
3. Then add more materials

### Tip 4: Clear Cache
If prices still don't work:
1. Close SketchUp
2. Delete the cache file (if it exists)
3. Reopen SketchUp
4. Reload extension
5. Try again

---

## 📞 WHAT TO REPORT

If pricing still doesn't work after following these steps, please provide:

1. **Ruby Console Output** - Copy the entire output from the console
2. **Material Names** - What materials are assigned to your components?
3. **Stock Materials Table** - Screenshot or list of materials with prices
4. **Materials Database File** - Content of the materials_database.json file

---

**Generated:** 2026-01-31
**Issue:** Prices showing as $0.00 in report
**Status:** 🔍 DEBUG LOGGING ADDED
**Next Step:** Check Ruby console output and follow debugging steps
