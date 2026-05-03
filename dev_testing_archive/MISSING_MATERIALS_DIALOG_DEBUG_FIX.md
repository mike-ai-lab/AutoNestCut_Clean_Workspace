# Missing Materials Dialog - Critical Bug Fix

## Problem Identified

The missing materials dialog was opening and collecting user choices correctly, but the config window was **ignoring those choices** and proceeding as if materials already existed.

## Root Cause

The issue was in the **validation flow**:

### Incorrect Flow (Before Fix)
1. ✅ Validate components → collect missing materials
2. ✅ Show missing materials dialog
3. ✅ User makes choices (existing/standard/custom)
4. ✅ `process_material_choices()` processes choices and modifies `parts_by_material`
5. ✅ Show config dialog
6. ❌ **Config dialog calls `send_initial_data()`**
7. ❌ **`send_initial_data()` runs validation AGAIN**
8. ❌ **Second validation doesn't know about user choices**
9. ❌ **Materials get auto-created or ignored**

### The Critical Bug
The `send_initial_data()` method in `dialog_manager.rb` was **re-running validation** every time the config dialog opened. This meant:
- User choices from the missing materials dialog were **completely ignored**
- The validator ran again with the original `parts_by_material` data
- Materials were either auto-created or treated as if they existed
- The remapping done in `process_material_choices()` was **overwritten**

## Solution Implemented

### 1. Added `skip_validation` Parameter
Modified `show_config_dialog()` to accept an optional `skip_validation` parameter:

```ruby
def show_config_dialog(parts_by_material, original_components = [], hierarchy_tree = [], assembly_entity = nil, skip_validation = false)
  @skip_validation = skip_validation
  # ...
end
```

### 2. Conditional Validation in `send_initial_data()`
Modified `send_initial_data()` to skip validation when materials have already been resolved:

```ruby
def send_initial_data
  if @skip_validation
    puts "\n=== STAGE 1: SKIPPING VALIDATION (materials already resolved) ==="
  else
    puts "\n=== STAGE 1: COMPONENT VALIDATION & AUTO-MATERIAL CREATION ==="
    validator = ComponentValidator.new
    validation_result = validator.validate_and_prepare_materials(@parts_by_material)
    # ... validation logic ...
  end
  # ... rest of method ...
end
```

### 3. Pass `skip_validation=true` After Material Resolution
Updated `main.rb` to pass `skip_validation=true` when showing config dialog after processing user choices:

```ruby
MissingMaterialsUI.show_dialog(validation_result[:missing_materials], existing_materials) do |user_choices|
  if user_choices
    process_material_choices(user_choices, parts_by_material, existing_materials)
    
    # Skip validation since we already handled it
    dialog_manager = UIDialogManager.new
    dialog_manager.show_config_dialog(parts_by_material, original_components, hierarchy_tree, assembly_entity, true)
  end
end
```

### Correct Flow (After Fix)
1. ✅ Validate components → collect missing materials
2. ✅ Show missing materials dialog
3. ✅ User makes choices (existing/standard/custom)
4. ✅ `process_material_choices()` processes choices and modifies `parts_by_material`
5. ✅ Show config dialog **with `skip_validation=true`**
6. ✅ `send_initial_data()` **skips validation** (materials already resolved)
7. ✅ Config dialog uses the **modified `parts_by_material`** with user choices applied
8. ✅ Materials are correctly mapped/created as per user decisions

## Enhanced Debug Logging

Added comprehensive debug logging to trace the entire flow:

### 1. Dialog Callback (`missing_materials_ui.rb`)
```ruby
dialog.add_action_callback('material_choices') do |action_context, json_string|
  puts "=" * 80
  puts "🦟 DIALOG CALLBACK: material_choices"
  puts "Raw JSON received: #{json_string[0..200]}..."
  choices = JSON.parse(json_string)
  puts "Parsed #{choices.length} choices successfully"
  # ...
end
```

### 2. Material Choice Processing (`main.rb`)
```ruby
def self.process_material_choices(user_choices, parts_by_material, existing_materials)
  puts "=" * 80
  puts "🦟 PROCESSING MATERIAL CHOICES"
  puts "Received #{user_choices.length} choices"
  
  # Detailed logging for each choice type
  # Shows before/after state of parts_by_material
  # Shows material creation/remapping operations
  
  puts "🦟 FINAL STATE AFTER PROCESSING:"
  puts "  Materials in parts_by_material: #{parts_by_material.keys.inspect}"
  puts "=" * 80
end
```

### 3. Config Dialog Initialization (`dialog_manager.rb`)
```ruby
def show_config_dialog(parts_by_material, ...)
  puts "=" * 80
  puts "🦟 CONFIG DIALOG: show_config_dialog called"
  puts "Materials received: #{parts_by_material.keys.inspect}"
  puts "Skip validation: #{skip_validation}"
  # ...
end
```

## Testing Instructions

1. **Reload the extension** in SketchUp Ruby Console:
   ```ruby
   load 'Extension/AutoNestCut/main.rb'
   ```

2. **Select components** with missing materials

3. **Run the extension** and watch the Ruby Console for debug output

4. **Expected Console Output**:
   ```
   ================================================================================
   🦟 DIALOG CALLBACK: material_choices
   ================================================================================
   Parsed 2 choices successfully
     Choice 0: standard for polywood
     Choice 1: existing for glass
   Dialog closed, calling Ruby callback...
   
   ================================================================================
   🦟 PROCESSING MATERIAL CHOICES
   ================================================================================
   Received 2 choices
   Processing choice 0:
     Material: polywood
     Type: standard
     → Creating standard sheet 'polywood' (2440x1220x8mm)
     ✓ Will save to database
   
   Processing choice 1:
     Material: glass
     Type: existing
     → REMAPPING 'glass' to 'Glass-6mm'
     Parts before remap: ["polywood", "glass"]
     ✓ Remapped successfully
     Parts after remap: ["polywood", "Glass-6mm"]
   
   🦟 FINAL STATE AFTER PROCESSING:
     Materials in parts_by_material: ["polywood", "Glass-6mm"]
   ================================================================================
   
   ================================================================================
   🦟 CONFIG DIALOG: show_config_dialog called
   ================================================================================
   Materials received: ["polywood", "Glass-6mm"]
   Skip validation: true
     polywood: 5 parts
     Glass-6mm: 3 parts
   ================================================================================
   
   === STAGE 1: SKIPPING VALIDATION (materials already resolved) ===
   ```

5. **Verify in Config Dialog**:
   - Materials should match user choices
   - "polywood" should be a new 2440x1220mm sheet
   - "glass" components should be under "Glass-6mm"
   - No auto-created materials should appear

## Files Modified

1. **`Extension/AutoNestCut/main.rb`**
   - Enhanced `process_material_choices()` with detailed debug logging
   - Added final state logging
   - Pass `skip_validation=true` to config dialog after material resolution

2. **`Extension/AutoNestCut/ui/missing_materials_ui.rb`**
   - Added debug logging to material_choices callback
   - Shows raw JSON and parsed choices

3. **`Extension/AutoNestCut/ui/dialog_manager.rb`**
   - Added `skip_validation` parameter to `show_config_dialog()`
   - Modified `send_initial_data()` to conditionally skip validation
   - Added debug logging to show received materials

## Impact

This fix ensures that:
- ✅ User choices from the missing materials dialog are **respected**
- ✅ Materials are created/remapped **exactly as the user specified**
- ✅ No duplicate validation or auto-creation happens
- ✅ The config dialog shows the **correct materials** based on user decisions
- ✅ The entire flow is **traceable** via debug logs

## Next Steps

If the issue persists after this fix, check the debug logs to identify:
1. Are choices being sent correctly from the dialog?
2. Is `process_material_choices()` modifying `parts_by_material` correctly?
3. Is the config dialog receiving the modified data?
4. Is validation being skipped as expected?

The debug logs will pinpoint exactly where the flow breaks.
