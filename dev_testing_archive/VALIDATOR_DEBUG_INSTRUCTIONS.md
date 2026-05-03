# Validator Debug Instructions

## Issue Summary

User reports that the validator is NOT creating auto-materials for components with incompatible dimensions:

- **Glass Shelf**: 232×348×**8mm** thick (Blue_Glass_Shelf1)
- **Base**: 250×750×**100mm** thick (Silver_Metal_Finish)
- **Other parts**: 18mm thick (should match existing 18mm sheets)

## Expected Behavior

### Glass Shelf (8mm thick)
- Database has: 6mm, 12mm, 15mm, 18mm, 22mm sheets
- 8mm vs 6mm = 2mm difference > 1mm tolerance ❌
- 8mm vs 12mm = 4mm difference > 1mm tolerance ❌
- **Expected**: Auto-create `Auto_user_W232xH348xTH8_(Blue_Glass_Shelf1)`

### Base (100mm thick)
- Database max thickness: ~25mm
- 100mm vs any sheet = way over tolerance ❌
- **Expected**: Auto-create `Auto_user_W250xH750xTH100_(Silver_Metal_Finish)`

### 18mm Parts
- Database has many 18mm sheets
- 18mm vs 18mm = 0mm difference ✓
- **Expected**: NO auto-create (will nest on existing 18mm sheets)

## Debug Steps

### Step 1: Check Console Logs

After running the extension, look for these validator logs:

```
🦟 Validation: X materials, Y parts
🦟 Database: Z materials loaded from CSV
🦟 Defaults: 111 default materials available
🦟 Merged: ZZZ total materials available for matching
```

**If you don't see these logs**, the validator is NOT being called!

### Step 2: Check Component-Level Logs

For EACH component, you should see:

```
🦟 VALIDATOR: Checking component 'Glass Shelf#1'
  Dimensions: W232.0 x H348.0 x TH8.0mm
  Material: 'Blue_Glass_Shelf1'
  Sheet candidates found: 0
  ✗ CANNOT FIT on any existing sheet (thickness tolerance: 1mm)
  → Decision: AUTO-CREATE material for this component
```

**If you see "Sheet candidates found: 0" but NO auto-create**, there's a bug in the logic!

### Step 3: Check Auto-Created Materials

At the end of validation, you should see:

```
🦟 Created: 2 auto-materials
```

And in the warnings:

```
• Auto-created material 'Auto_user_W232xH348xTH8_(Blue_Glass_Shelf1)' for component (232.0x348.0mm)
• Auto-created material 'Auto_user_W250xH750xTH100_(Silver_Metal_Finish)' for component (250.0x750.0mm)
```

## Test Script

Run this test script in SketchUp Ruby Console to verify validator behavior:

```ruby
# Load the test script
load 'TEST_GLASS_SHELF_VALIDATOR.rb'
```

This will create mock components and run the validator, showing detailed logs.

## Common Issues

### Issue 1: Validator Not Called
**Symptom**: No validator logs in console
**Cause**: Extension not reloaded, or components not being processed
**Fix**: Reload extension, ensure components are selected

### Issue 2: Old Auto-Materials Interfering
**Symptom**: Validator skips components with message "Skipping already auto-created material"
**Cause**: Components already have auto-material names from previous run
**Fix**: Delete auto-materials from database, reload extension

### Issue 3: Thickness Tolerance Too Strict
**Symptom**: 8mm glass not matching 6mm or 12mm sheets
**Cause**: 1mm tolerance is correct - 8mm SHOULD NOT match 6mm or 12mm
**Expected**: Auto-create material (this is correct behavior)

### Issue 4: Database Not Merged
**Symptom**: "Database: 30 materials loaded" instead of "Merged: 111+ materials"
**Cause**: Default materials not being merged
**Fix**: Check `MaterialsDatabase.get_default_materials()` is working

## Code Changes Applied

### Enhanced Logging (component_validator.rb)

Added detailed per-component logging to show:
- Component name and dimensions
- Material name
- Number of sheet candidates found
- Decision (auto-create or not)
- List of matching sheets (if any)

### Thickness Tolerance

Current tolerance: **1.0mm**

This means:
- 18mm part + 18mm sheet = 0mm diff ✓ MATCH
- 18mm part + 19mm sheet = 1mm diff ✓ MATCH
- 8mm part + 6mm sheet = 2mm diff ❌ NO MATCH
- 8mm part + 12mm sheet = 4mm diff ❌ NO MATCH

**This is correct behavior!** 8mm glass should NOT match standard sheets.

## Next Steps

1. **Run the extension** with the user's components
2. **Copy the console logs** (all validator output)
3. **Check if validator is being called** (look for 🦟 logs)
4. **Verify auto-materials are created** for 8mm and 100mm parts
5. **Verify 18mm parts are NOT auto-created** (they should match existing sheets)

If the validator is being called but NOT creating materials, there's a logic bug that needs fixing.

If the validator is NOT being called at all, the issue is in the dialog_manager or model_analyzer.
