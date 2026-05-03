# Component Validator Bug Analysis

## The Problem

The validator is auto-creating materials for **normal, compatible components** when it should only do so for edge cases. Cabinet components with realistic dimensions (250-800mm) are being flagged as incompatible.

## Root Cause: Material Name Mismatch

The validator logic at line 145-162 in `component_validator.rb`:

```ruby
unless existing_materials.key?(material_name)
  # Material doesn't exist - auto-create one
  auto_create_oversized_material(material_name, ...)
else
  # Material exists - check if component fits
  if width > material_width || height > material_height || (thickness - material_thickness).abs > 0.5
    auto_create_oversized_material(material_name, ...)
  end
end
```

### Issue 1: Material Name Mismatch
- **SketchUp components** have material names like: `"Plywood"`, `"MDF"`, `"Oak"` (simple names)
- **Database keys** are: `"Plywood_Birch_18mm_2440x1220"`, `"MDF_Standard_18mm_2440x1220"` (descriptive names)
- **Result**: `existing_materials.key?(material_name)` returns `false` because `"Plywood"` ≠ `"Plywood_Birch_18mm_2440x1220"`
- **Consequence**: Every component triggers auto-creation, even if a compatible material exists

### Issue 2: Dimension Comparison Logic
The condition `width > material_width || height > material_height` is backwards:
- Component dimensions: 250mm x 750mm (a cabinet side panel)
- Material dimensions: 2440mm x 1220mm (standard sheet)
- Check: `250 > 2440` = FALSE ✓ (correct, component fits)
- But this only works if the material name matches!

### Issue 3: Thickness Tolerance
The tolerance `(thickness - material_thickness).abs > 0.5` is too strict:
- Component thickness: 18.0mm
- Material thickness: 18.0mm
- Difference: 0.0mm < 0.5mm ✓ (should pass)
- But again, only if material name matches!

## Why All Components Get Auto-Created

1. ModelAnalyzer extracts material name from SketchUp: `"Plywood"` (simple name)
2. Validator looks for `"Plywood"` in database
3. Database only has `"Plywood_Birch_18mm_2440x1220"`, `"Plywood_Poplar_18mm_2440x1220"`, etc.
4. Key not found → auto-create material
5. **Result**: Every component gets a new auto-material, even normal ones

## Solution

The validator needs to:
1. **Match material names intelligently** - find compatible materials by type, not exact key match
2. **Only auto-create for true edge cases** - when no compatible material exists
3. **Preserve original material names** - don't force users to use database keys

## Test Case

**Normal Cabinet Component:**
- Name: "Cabinet_Side"
- Dimensions: 250mm x 750mm x 18mm
- SketchUp Material: "Plywood"

**Expected Behavior:**
- Find compatible material: `"Plywood_Birch_18mm_2440x1220"` (2440x1220, 18mm thick)
- Component fits: 250 < 2440 ✓, 750 < 1220 ✓, 18 ≈ 18 ✓
- **Result**: Use existing material, NO auto-creation

**Current Behavior:**
- Look for exact key: `"Plywood"` in database
- Not found → auto-create `"Auto_user_W250xH750xTH18_(Plywood)"`
- **Result**: Unnecessary auto-material created
