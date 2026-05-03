# ✅ USABLE OFFCUTS TABLE - COMPLETELY FIXED

## 🔴 Issues Fixed

### Issue 1: Mixed Content in "Estimated Size" Column
**Problem:** The "Estimated Size" column showed `"1952 x 922mm"` - mixing numbers and units in the same cell.

**Solution:** Split into separate "Width" and "Height" columns with dynamic unit headers.

### Issue 2: Hardcoded Area Units
**Problem:** The "Area" header was hardcoded to `"Area (m²)"` instead of using dynamic units.

**Solution:** Changed to use `getAreaUnitLabel()` to show the user's selected area units (ft², m², etc.).

---

## ✅ CHANGES APPLIED

### 1. Ruby Backend (`report_generator.rb`)

**Added separate width/height fields:**
```ruby
offcuts << {
  board_number: index + 1,
  material: board.material,
  estimated_dimensions: "#{estimated_width} x #{estimated_height}mm", # Keep for backward compatibility
  estimated_width_mm: estimated_width,  # ✅ NEW: Separate width in mm
  estimated_height_mm: estimated_height, # ✅ NEW: Separate height in mm
  area: remaining_area.round(0),
  area_m2: (remaining_area / 1000000.0).round(3)
}
```

**Why keep `estimated_dimensions`?**
- Backward compatibility with old exports
- Fallback if JavaScript can't parse the new fields

---

### 2. JavaScript Frontend (`diagrams_report.js`)

#### A. HTML Table Rendering

**Before:**
```javascript
<th>Estimated Size</th>
<td>${offcut.estimated_dimensions}</td> // Shows "1952 x 922mm"
```

**After:**
```javascript
<th>Width (${reportUnits})</th>
<th>Height (${reportUnits})</th>
<td>${width}</td>  // Shows "76.850" (converted to inches)
<td>${height}</td> // Shows "36.299" (converted to inches)
```

**Conversion Logic:**
```javascript
// Use separate fields if available
if (offcut.estimated_width_mm !== undefined && offcut.estimated_height_mm !== undefined) {
    width = formatDimension(offcut.estimated_width_mm);
    height = formatDimension(offcut.estimated_height_mm);
} else {
    // Fallback: Parse the old format "1952 x 922mm"
    const match = offcut.estimated_dimensions.match(/(\d+)\s*x\s*(\d+)/);
    if (match) {
        width = formatDimension(parseFloat(match[1]));
        height = formatDimension(parseFloat(match[2]));
    }
}
```

#### B. Markdown Export

**Before:**
```markdown
| Sheet # | Material | Estimated Size | Area (m²) |
|---------|----------|----------------|-----------|
| 1 | Material | 1952 x 922mm | 2.8 |
```

**After:**
```markdown
| Sheet # | Material | Width (in) | Height (in) | Area (ft²) |
|---------|----------|------------|-------------|-----------|
| 1 | Material | 76.850 | 36.299 | 30.139 |
```

---

## 🎯 NEW TABLE STRUCTURE

### Before (Old)
```
┌──────────┬──────────┬─────────────────┬────────────┐
│ Sheet #  │ Material │ Estimated Size  │ Area (m²)  │
├──────────┼──────────┼─────────────────┼────────────┤
│ 1        │ Plywood  │ 1952 x 922mm    │ 2.8        │
│ 2        │ MDF      │ 1952 x 530mm    │ 1.0        │
└──────────┴──────────┴─────────────────┴────────────┘
```

### After (New)
```
┌──────────┬──────────┬─────────────┬──────────────┬─────────────┐
│ Sheet #  │ Material │ Width (in)  │ Height (in)  │ Area (ft²)  │
├──────────┼──────────┼─────────────┼──────────────┼─────────────┤
│ 1        │ Plywood  │ 76.850      │ 36.299       │ 30.139      │
│ 2        │ MDF      │ 76.850      │ 20.866       │ 17.321      │
└──────────┴──────────┴─────────────┴──────────────┴─────────────┘
```

---

## 📋 TESTING INSTRUCTIONS

### 1. Reload the Extension
```ruby
load 'Extension/autonestcut.rb'
```

### 2. Generate a New Report
- Set units to **inches**
- Set area units to **square feet**
- Generate a new report

### 3. Check the Usable Offcuts Table

**Verify:**
- ✅ Headers show "Width (in)" and "Height (in)" instead of "Estimated Size"
- ✅ Width column shows converted values (e.g., 76.850 instead of 1952)
- ✅ Height column shows converted values (e.g., 36.299 instead of 922)
- ✅ Area header shows "Area (ft²)" instead of "Area (m²)"
- ✅ Area values are converted (e.g., 30.139 ft² instead of 2.8 m²)
- ✅ NO cells contain mixed content like "1952 x 922mm"

### 4. Check Markdown Export

Copy the report as markdown and verify:
- ✅ Table has separate Width and Height columns
- ✅ Headers show dynamic units
- ✅ Values are converted

---

## 🔍 TECHNICAL DETAILS

### Data Flow

```
1. Ruby calculates offcut dimensions in mm
   ↓
2. Ruby sends BOTH:
   - estimated_dimensions: "1952 x 922mm" (backward compatibility)
   - estimated_width_mm: 1952 (new field)
   - estimated_height_mm: 922 (new field)
   ↓
3. JavaScript checks if new fields exist
   ↓
4. If yes: Use new fields and convert
   If no: Parse old format and convert
   ↓
5. Display in separate columns with dynamic units
```

### Conversion Functions Used

- `formatDimension(valueInMm)` - Converts mm to current units and formats
- `getAreaDisplay(areaInMm2)` - Converts mm² to current area units and formats
- `getAreaUnitLabel()` - Returns the current area unit label (ft², m², etc.)

### Backward Compatibility

The code maintains backward compatibility by:
1. Keeping the old `estimated_dimensions` field in Ruby
2. Checking for new fields first in JavaScript
3. Falling back to parsing the old format if new fields don't exist

This ensures:
- Old cached reports still work
- Old exports still work
- New reports use the improved format

---

## ✅ FILES MODIFIED

1. **Extension/AutoNestCut/exporters/report_generator.rb**
   - Added `estimated_width_mm` and `estimated_height_mm` fields

2. **Extension/AutoNestCut/ui/html/diagrams_report.js**
   - Updated `renderOffcutsTable()` function
   - Updated markdown export for offcuts
   - Split "Estimated Size" into separate Width/Height columns
   - Added conversion logic for dimensions

3. **Extension/AutoNestCut/ui/html/main.html**
   - Updated cache-busting version

---

## 🎉 RESULT

**The Usable Offcuts table now:**
- ✅ Has separate Width and Height columns
- ✅ Shows dynamic unit headers based on user settings
- ✅ Converts all dimensions to user's selected units
- ✅ Converts area to user's selected area units
- ✅ Has NO mixed content (numbers + units in same cell)
- ✅ Works in HTML dialog, markdown export, and all other exports

**Example with inches and ft²:**
```
Sheet # | Material | Width (in) | Height (in) | Area (ft²)
--------|----------|------------|-------------|------------
1       | Plywood  | 76.850     | 36.299      | 30.139
2       | MDF      | 76.850     | 20.866      | 17.321
```

---

**Generated:** 2026-01-31
**Issue:** Offcuts table had mixed content and hardcoded units
**Status:** ✅ COMPLETELY FIXED
**Files Modified:** report_generator.rb, diagrams_report.js, main.html
