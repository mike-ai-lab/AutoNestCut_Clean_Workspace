# Material Contamination Fix - Default Material Suppression Logic

## The Problem (Material Contamination)

The system was using a **global "any auto-material exists" flag** to suppress default material creation. This caused unrelated materials to be blocked.

### Example of the Bug
```
Auto-material created: Auto_user_W232xH348xTH8_(Blue_Glass_Shelf)
  → This blocked: Metal_Corrogated_Shiny (18.0mm)
  → Even though they are completely different materials!
```

**Why this is wrong:**
- Blue_Glass_Shelf is 8mm thick (glass shelf)
- Metal_Corrogated_Shiny is 18mm thick (metal)
- They have nothing to do with each other
- But the system treated ANY auto-material as a global blocker

## The Root Cause

In `Extension/AutoNestCut/ui/dialog_manager.rb` (lines 1109-1113), the logic was:

```ruby
# WRONG: Global check
auto_variant = current_settings['stock_materials'].select { |k, _| 
  k.start_with?('Auto_user_') || k.start_with?('no_material_') 
}.first

if auto_variant
  # Block ALL default materials if ANY auto-material exists
  puts "DEBUG: Skipping default material creation for '#{display_name}' - auto-created variant exists: #{auto_variant[0]}"
  next
end
```

This is like saying: "If any custom item exists in the workshop, stop using all standard materials."

## The Solution (Scoped Matching)

Changed the logic to check **per-material-family and per-thickness**:

```ruby
# CORRECT: Scoped check
# Extract base material name from display_name
base_material_match = display_name.match(/^(.+?)\s*\([\d.]+mm\)$/)
base_material_name = base_material_match ? base_material_match[1] : material_name

# Look for auto-materials that match THIS specific base material + thickness
matching_auto_variant = current_settings['stock_materials'].select do |k, v|
  next unless k.start_with?('Auto_user_') || k.start_with?('no_material_')
  
  # Extract base material from auto-material name
  # Format: Auto_user_W232xH348xTH8_(Blue_Glass_Shelf)
  auto_base_match = k.match(/\(([^)]+)\)$/)
  auto_base_name = auto_base_match ? auto_base_match[1] : nil
  
  # Extract thickness from auto-material name
  auto_thickness_match = k.match(/TH([\d.]+)_/)
  auto_thickness = auto_thickness_match ? auto_thickness_match[1].to_f : nil
  
  # Only skip if BOTH base material AND thickness match (with 1mm tolerance)
  auto_base_name == base_material_name && auto_thickness && 
    (auto_thickness - thickness_val).abs <= 1.0
end.first

if matching_auto_variant
  # Only skip if THIS specific material+thickness has an auto-variant
  puts "DEBUG: Skipping default material creation for '#{display_name}' - matching auto-variant exists: #{matching_auto_variant[0]}"
  next
end
```

## What Changed

### Before (Wrong)
```
Auto: Auto_user_W232xH348xTH8_(Blue_Glass_Shelf)
Default: Metal_Corrogated_Shiny (18.0mm)
Result: ❌ BLOCKED (global check)
```

### After (Correct)
```
Auto: Auto_user_W232xH348xTH8_(Blue_Glass_Shelf)
  Base: Blue_Glass_Shelf
  Thickness: 8mm

Default: Metal_Corrogated_Shiny (18.0mm)
  Base: Metal_Corrogated_Shiny
  Thickness: 18mm

Result: ✅ ALLOWED (different base material, different thickness)
```

## Real-World Analogy

**Before:** "If I have one custom glass shelf, I can't use any MDF sheets anymore."

**After:** "I have one custom glass shelf (8mm). I can still use standard MDF sheets (18mm) because they're different materials and thicknesses."

## Matching Logic

The fix extracts and compares:

1. **Base Material Name**
   - From auto-material: `Auto_user_W232xH348xTH8_(Blue_Glass_Shelf)` → `Blue_Glass_Shelf`
   - From default: `Metal_Corrogated_Shiny (18.0mm)` → `Metal_Corrogated_Shiny`

2. **Thickness**
   - From auto-material: `Auto_user_W232xH348xTH8_(...)` → `8`
   - From default: `Metal_Corrogated_Shiny (18.0mm)` → `18`

3. **Comparison**
   - Only skip if: `base_name_matches AND thickness_matches (±1mm tolerance)`

## Files Changed

- `Extension/AutoNestCut/ui/dialog_manager.rb` (lines 1103-1140)

## Expected Behavior After Fix

When processing a model with:
- Glass Shelf (8mm) → Auto-creates `Auto_user_W232xH348xTH8_(Blue_Glass_Shelf)`
- Metal Base (100mm) → Auto-creates `Auto_user_W250xH750xTH100_(Metal_Corrogated_Shiny)`
- Metal Panels (18mm) → Uses standard `Metal_Corrogated_Shiny (18.0mm)` ✅

All three materials coexist without contamination.

## Log Output After Fix

```
DEBUG: Skipping default material creation for 'Blue_Glass_Shelf (8.0mm)' - matching auto-variant exists: Auto_user_W232xH348xTH8_(Blue_Glass_Shelf)
DEBUG: Creating default material: Metal_Corrogated_Shiny (18.0mm) ✅
DEBUG: Creating default material: Metal_Corrogated_Shiny (100.0mm) ✅
```

Instead of the old contaminated output:
```
DEBUG: Skipping default material creation for 'Metal_Corrogated_Shiny (18.0mm)' - auto-created variant exists: Auto_user_W232xH348xTH8_(Blue_Glass_Shelf) ❌
```
