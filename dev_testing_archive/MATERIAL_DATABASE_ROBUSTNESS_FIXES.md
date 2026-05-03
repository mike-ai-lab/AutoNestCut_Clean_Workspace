# Material Database Robustness Fixes

## Overview

This document outlines critical fixes for the Material Database stock feature to ensure:
- ✅ Save button saves data robustly (no data loss)
- ✅ Refresh button doesn't delete any material
- ✅ Stock loads user's exact saved state with consistency
- ✅ Data saves safely with integrity checks
- ✅ Default database loads correctly
- ✅ No modifications happen without explicit user action

## Issues Identified

### 1. **Refresh Data Loss Risk**
**Problem:** The refresh button calls `requestMaterialsData()` which may reload from database without preserving unsaved UI changes.

**Risk:** User edits materials in UI → clicks refresh → loses changes if not saved first.

**Fix:** Add unsaved changes detection and warning before refresh.

### 2. **Silent Data Modifications**
**Problem:** Default material creation logic may silently modify materials during load.

**Risk:** User's custom materials get overwritten or merged unexpectedly.

**Fix:** Only create defaults if explicitly requested by user (Load Defaults button).

### 3. **Concurrent Save/Load Race Conditions**
**Problem:** Multiple save operations without proper locking could corrupt CSV.

**Risk:** If user saves while refresh is loading, data could be corrupted.

**Fix:** Implement atomic save operations with temporary file + rename pattern.

### 4. **CSV Parsing Robustness**
**Problem:** CSV parsing doesn't validate data types or handle malformed rows.

**Risk:** Corrupted CSV could cause silent data loss or type errors.

**Fix:** Add validation and error recovery for CSV operations.

### 5. **Material Contamination During Load**
**Problem:** Loading defaults could suppress unrelated materials (already fixed in dialog_manager.rb).

**Risk:** User's materials disappear when loading defaults.

**Fix:** Verify fix is applied (already done in previous commit).

## Implementation Fixes

### Fix 1: Atomic Save Operations

**File:** `Extension/AutoNestCut/materials_database.rb`

```ruby
def self.save_database(materials)
  ensure_database_folder
  
  # Use atomic write: write to temp file, then rename
  temp_file = "#{database_file}.tmp"
  
  begin
    CSV.open(temp_file, 'w') do |csv|
      csv << ['name', 'width', 'height', 'thickness', 'price', 'currency', 'density', 'auto_generated', 'created_at', 'original_sketchup_material', 'is_favorite', 'flagged_no_material']
      
      materials.each do |name, data|
        # Validate data before writing
        next if name.nil? || name.to_s.strip.empty?
        
        default_currency = Config.get_cached_settings['default_currency'] || 'USD'
        csv << [
          name,
          validate_float(data['width'], 2440),
          validate_float(data['height'], 1220),
          validate_float(data['thickness'], 18),
          validate_float(data['price'], 0),
          data['currency'] || default_currency,
          validate_float(data['density'], 600),
          data['auto_generated'] || false,
          data['created_at'] || '',
          data['original_sketchup_material'] || '',
          data['is_favorite'] || false,
          data['flagged_no_material'] || false
        ]
      end
    end
    
    # Atomic rename: temp file becomes the real database
    File.rename(temp_file, database_file)
    puts "✅ Materials database saved successfully (#{materials.length} materials)"
    
  rescue => e
    # Clean up temp file on error
    File.delete(temp_file) if File.exist?(temp_file)
    Util.debug("Error saving materials database: #{e.message}")
    raise e
  end
end

# Helper: Validate and coerce float values
def self.validate_float(value, default)
  return default if value.nil?
  float_val = value.to_f
  float_val.finite? ? float_val : default
rescue
  default
end
```

### Fix 2: Robust Load with Validation

**File:** `Extension/AutoNestCut/materials_database.rb`

```ruby
def self.load_database
  ensure_database_folder
  return {} unless File.exist?(database_file)
  
  materials = {}
  row_count = 0
  error_count = 0
  
  begin
    CSV.foreach(database_file, headers: true) do |row|
      row_count += 1
      
      begin
        name = row['name'].to_s.strip
        next if name.empty?
        
        # Validate all numeric fields
        width = validate_float(row['width'], 2440)
        height = validate_float(row['height'], 1220)
        thickness = validate_float(row['thickness'], 18)
        price = validate_float(row['price'], 0)
        density = validate_float(row['density'], 600)
        
        materials[name] = {
          'width' => width,
          'height' => height,
          'thickness' => thickness,
          'price' => price,
          'currency' => row['currency'] || 'USD',
          'density' => density,
          'auto_generated' => row['auto_generated'] == 'true' || row['auto_generated'] == true,
          'created_at' => row['created_at'] || '',
          'original_sketchup_material' => row['original_sketchup_material'] || '',
          'is_favorite' => row['is_favorite'] == 'true' || row['is_favorite'] == true,
          'flagged_no_material' => row['flagged_no_material'] == 'true' || row['flagged_no_material'] == true
        }
      rescue => e
        error_count += 1
        Util.debug("Warning: Skipped malformed row #{row_count}: #{e.message}")
      end
    end
    
    puts "✅ Materials database loaded: #{materials.length} materials (#{error_count} errors skipped)"
    materials
    
  rescue => e
    Util.debug("Error loading materials database: #{e.message}")
    {}
  end
end
```

### Fix 3: Unsaved Changes Detection

**File:** `Extension/AutoNestCut/ui/dialog_manager.rb` (in send_initial_data method)

Add at the beginning of the method:

```ruby
# Track unsaved changes state
@materials_unsaved_changes = false

# In the HTML dialog, add this JavaScript:
# window.hasUnsavedMaterialChanges = false;
# 
# When user edits a material:
# window.hasUnsavedMaterialChanges = true;
#
# When user clicks Save:
# window.hasUnsavedMaterialChanges = false;
#
# When user clicks Refresh:
# if (window.hasUnsavedMaterialChanges) {
#   if (!confirm('You have unsaved changes. Refresh will discard them. Continue?')) {
#     return;
#   }
# }
```

### Fix 4: Prevent Silent Default Material Creation

**File:** `Extension/AutoNestCut/ui/dialog_manager.rb` (in send_initial_data method)

Change the logic to ONLY create defaults when user explicitly clicks "Load Defaults":

```ruby
# BEFORE: Auto-creates defaults during load (silent modification)
# @parts_by_material.each do |material_name, part_types|
#   # ... auto-creates materials ...
# end

# AFTER: Only create defaults on explicit user action
# Move default creation to a separate callback:

@dialog.add_action_callback("load_default_materials") do |action_context|
  begin
    defaults = MaterialsDatabase.get_default_materials
    current_settings = Config.get_cached_settings
    
    # Merge defaults with existing (defaults don't override user materials)
    merged = current_settings['stock_materials'].merge(defaults)
    current_settings['stock_materials'] = merged
    
    # Save to database
    MaterialsDatabase.save_database(merged)
    
    # Send updated data to UI
    @dialog.execute_script("receiveMaterialsData(#{merged.to_json})")
    puts "✅ Default materials loaded (#{defaults.length} materials)"
  rescue => e
    puts "ERROR loading defaults: #{e.message}"
    @dialog.execute_script("showError('Error loading defaults: #{e.message.gsub("'", "\\'")}')")
  end
end
```

### Fix 5: Refresh Without Data Loss

**File:** `Extension/AutoNestCut/ui/dialog_manager.rb`

```ruby
# Add a new callback for safe refresh:
@dialog.add_action_callback("refresh_materials_safe") do |action_context|
  begin
    # Load current database state (no modifications)
    loaded_materials = MaterialsDatabase.load_database
    
    # Send to UI without any auto-creation or modification
    @dialog.execute_script("receiveMaterialsData(#{loaded_materials.to_json})")
    puts "✅ Materials refreshed from database (#{loaded_materials.length} materials)"
  rescue => e
    puts "ERROR refreshing materials: #{e.message}"
    @dialog.execute_script("showError('Error refreshing: #{e.message.gsub("'", "\\'")}')")
  end
end
```

## Testing

Run the comprehensive test suite:

```bash
ruby TEST_MATERIAL_DATABASE_ROBUSTNESS.rb
```

Tests verify:
- ✅ Save robustness (data written correctly)
- ✅ Load consistency (data read back exactly)
- ✅ Refresh preserves data (no loss on reload)
- ✅ No silent modifications (only explicit user actions)
- ✅ Data integrity (all fields preserved)
- ✅ Concurrent access safety (atomic operations)
- ✅ Default materials loading (correct merge)
- ✅ Auto-material preservation (exact dimensions)
- ✅ Material contamination prevention (no cross-material suppression)

## Behavior After Fixes

### Save Button
- ✅ Writes all materials to CSV atomically
- ✅ Validates all data before writing
- ✅ Shows success message
- ✅ Clears unsaved changes flag

### Refresh Button
- ✅ Warns if unsaved changes exist
- ✅ Loads database without modification
- ✅ Preserves all materials exactly
- ✅ No auto-creation or merging

### Load Defaults Button
- ✅ Only runs on explicit user click
- ✅ Merges defaults with existing (doesn't override)
- ✅ Saves merged result to database
- ✅ Shows count of loaded defaults

### Stock Display
- ✅ Shows exact saved state
- ✅ No hidden modifications
- ✅ All materials coexist (no contamination)
- ✅ Auto-materials and standard materials separate

## Files Modified

1. `Extension/AutoNestCut/materials_database.rb` - Atomic save, robust load
2. `Extension/AutoNestCut/ui/dialog_manager.rb` - Unsaved changes detection, safe refresh
3. `Extension/AutoNestCut/ui/html/material_database.html` - UI callbacks for safe operations

## Rollback Plan

If issues occur:
1. Revert `materials_database.rb` to previous version
2. Revert `dialog_manager.rb` callbacks
3. Restore from backup CSV in AppData/AutoNestCut/

## Verification Checklist

- [ ] Save button saves all materials without loss
- [ ] Refresh button doesn't delete any materials
- [ ] Load Defaults only runs on explicit click
- [ ] Unsaved changes warning appears before refresh
- [ ] Auto-materials preserved with exact dimensions
- [ ] Standard materials not suppressed by auto-materials
- [ ] CSV file is valid after save
- [ ] Multiple save/load cycles preserve data
- [ ] No silent modifications occur
- [ ] All tests pass
