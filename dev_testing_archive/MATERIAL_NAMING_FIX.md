# Material Naming Fix - Remove Thickness Suffix

## Problem

When users saved missing materials as "Standard Sheet", the system was adding a thickness suffix to the material name:
- User material: `Blue_Glass_Shelf` (8mm)
- Saved as: `Blue_Glass_Shelf_8mm` ❌

This caused confusion because:
1. Users expected the material to be saved with its original name
2. The thickness is already stored in the material data
3. It cluttered the materials database with redundant information
4. It made material names harder to read and manage

## Solution

### 1. Removed Thickness Suffix from Standard Sheets

**Before:**
```ruby
unique_material_name = "#{material_name}_#{thickness.round(0)}mm"
materials_to_save[unique_material_name] = material_data
# Saved as: "Blue_Glass_Shelf_8mm"
```

**After:**
```ruby
materials_to_save[material_name] = material_data
# Saved as: "Blue_Glass_Shelf"
```

The thickness is already in the material data:
```ruby
material_data = {
  'width' => 2440,
  'height' => 1220,
  'thickness' => 8.0,  # ← Thickness is here
  ...
}
```

### 2. Simplified Custom Materials

**Before:**
```ruby
unique_material_name = "#{material_name}_#{thickness.round(0)}mm_custom"
# Example: "Metal_18mm_custom"
```

**After:**
```ruby
unique_material_name = "#{material_name}_custom"
# Example: "Metal_custom"
```

### 3. Simplified Validator Logic

Removed the complex suffix-checking logic since we're not using suffixes anymore:

**Before:**
- Check exact name
- Check with integer suffix (`Material_18mm`)
- Check with decimal suffix (`Material_18.0mm`)

**After:**
- Check exact name only
- Compare thickness with 0.01mm tolerance

### 4. Cleaner Debug Logging

**Before:**
```
Searching for:
  1. Exact name: 'Blue_Glass_Shelf'
  2. With suffix (int): 'Blue_Glass_Shelf_8mm'
  3. With suffix (decimal): 'Blue_Glass_Shelf_8.0mm'
```

**After:**
```
Material: 'Blue_Glass_Shelf' (thickness: 8.0mm)
✓ EXACT MATCH FOUND
```

## Benefits

1. **Cleaner Material Names**: `Blue_Glass_Shelf` instead of `Blue_Glass_Shelf_8mm`
2. **Less Confusion**: Thickness is in the data, not the name
3. **Simpler Logic**: No complex suffix checking needed
4. **Better UX**: Users see the material names they expect
5. **Easier Management**: Fewer materials in the database

## Handling Multiple Thicknesses

If a user has the same material with different thicknesses (e.g., "Plywood" in 12mm and 18mm), they should create separate materials:
- `Plywood_12mm` (manually named by user)
- `Plywood_18mm` (manually named by user)

Or use descriptive names:
- `Plywood_Thin` (12mm)
- `Plywood_Standard` (18mm)

The system no longer automatically adds thickness suffixes.

## Files Modified

1. **Extension/AutoNestCut/main.rb**
   - Removed thickness suffix from standard sheet naming
   - Simplified custom material naming
   
2. **Extension/AutoNestCut/processors/component_validator.rb**
   - Simplified `exact_material_exists?` to check name + thickness only
   - Removed suffix pattern checking
   - Cleaned up debug logging

## Migration Note

Existing materials with thickness suffixes (e.g., `Blue_Glass_Shelf_8mm`) will continue to work. The validator will find them by exact name match. Users can rename them in the Material Database Manager if desired.

## Date

January 26, 2026
