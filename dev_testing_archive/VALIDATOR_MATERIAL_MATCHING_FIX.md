# Component Validator - Material Matching Fix

## Problem

The validator was failing to find materials that were just saved to the database. When users:
1. Run the extension with components using material "Blue_Glass_Shelf" (8mm)
2. Choose to save it as a standard sheet → Creates "Blue_Glass_Shelf_8mm" in database
3. Run the extension again with the SAME components
4. **BUG**: Validator doesn't find "Blue_Glass_Shelf_8mm" and asks the user AGAIN

## Root Cause

The `exact_material_exists?` function was using exact equality (`==`) for floating-point thickness comparison:

```ruby
return [true, thickness_suffix] if db_thickness == thickness
```

This can fail due to floating-point precision issues where `8.0 == 8.0` might return false if one value is `8.0000001` and the other is `7.9999999`.

## Solution

### 1. Floating-Point Tolerance Comparison

Changed all thickness comparisons to use tolerance-based comparison:

```ruby
# OLD: Exact equality (fails with floating point precision)
return [true, thickness_suffix] if db_thickness == thickness

# NEW: Tolerance-based (0.01mm tolerance)
return [true, thickness_suffix] if (db_thickness - thickness).abs < 0.01
```

This allows for tiny floating-point differences while still being precise enough for real-world materials (0.01mm = 10 microns).

### 2. Enhanced Debug Logging

Added detailed logging to show exactly what the validator is searching for:

```
🔍 CHECKING: Glass Shelf
  Dimensions: 232.0mm × 348.0mm × 8.0mm
  Material: 'Blue_Glass_Shelf'
  Searching for:
    1. Exact name: 'Blue_Glass_Shelf'
    2. With suffix (int): 'Blue_Glass_Shelf_8mm'
    3. With suffix (decimal): 'Blue_Glass_Shelf_8.0mm'
  ✓ EXACT MATCH FOUND
    → Found as: 'Blue_Glass_Shelf_8mm'
    → Action: REMAP component to database material
```

This makes it immediately clear:
- What material the validator is looking for
- What variations it's checking
- Whether it found a match
- What action it's taking

## Files Modified

1. **Extension/AutoNestCut/processors/component_validator.rb**
   - Fixed `exact_material_exists?` to use tolerance-based comparison
   - Enhanced `log_component_check` to show search patterns

## Testing

To verify the fix works:

1. Open SketchUp with components using a new material (e.g., "TestMaterial" 18mm)
2. Run AutoNestCut → Validator will ask about missing material
3. Choose "Standard Sheet" and save to database
4. Close the config dialog
5. Run AutoNestCut AGAIN with the SAME components
6. **Expected**: Validator should find "TestMaterial_18mm" and NOT ask again
7. Check the log for: `✓ EXACT MATCH FOUND → Found as: 'TestMaterial_18mm'`

## Impact

- **User Experience**: Users won't be asked repeatedly about the same materials
- **Performance**: No impact (tolerance comparison is just as fast)
- **Accuracy**: 0.01mm tolerance is negligible for sheet materials (10 microns)
- **Reliability**: Eliminates floating-point comparison bugs

## Date

January 26, 2026
