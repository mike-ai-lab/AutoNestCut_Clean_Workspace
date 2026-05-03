# Plan and precise code changes (applied now)

Rewrite the validator logic so it **never** uses material *name* to decide feasibility. The validator will only perform **feasibility / containment checks** against sheet records. Auto-creation will be strictly exceptional and only triggered when **no sheet candidate** can contain the part (or other true edge cases). Below are the exact, copy-paste-ready method replacements you should apply to `component_validator.rb`.

**What this changes (concrete):**

1. Removes the validator's dependency on `find_compatible_material` for normal validation.
2. Adds `find_sheet_candidates` — returns sheet candidates that physically contain the part (rotation allowed) and pass thickness tolerance.
3. Replaces logic inside `validate_material_and_components` to:

   * Accept the original SketchUp material label as a label only (do not rename).
   * If at least one sheet candidate exists → do nothing (no auto-create).
   * If zero candidates exist → auto-create (only for genuine edge cases).
4. Keep existing hard-limit checks, flagged material handling, and old-auto cleanup.
5. Add detailed debug logging so next runs show exactly why an auto-material was created.

Apply the replacements below. They are minimal, deterministic, and production-ready.

---

## Replace / Add these methods

Replace the existing `validate_material_and_components`, `find_compatible_material` usage and add `find_sheet_candidates`. If you prefer to keep `find_compatible_material` for later reference, do not call it; the new flow uses `find_sheet_candidates`.

```ruby
# --- ADD / REPLACE IN component_validator.rb ---

# New helper: return array of candidate materials (name,data) that can physically contain the part.
# Rotation is allowed (width<->height). Thickness tolerance is configurable (default 1.0 mm).
def find_sheet_candidates(width, height, thickness, existing_materials, thickness_tolerance = 1.0)
  candidates = []

  existing_materials.each do |db_name, db_data|
    # Skip auto-generated or flagged placeholders
    next if db_name.start_with?('Auto_user_') || db_name.start_with?('no_material_')

    db_width = db_data['width'].to_f
    db_height = db_data['height'].to_f
    db_thickness = db_data['thickness'].to_f

    # defensive: require valid positive sheet dimensions
    next if db_width <= 0 || db_height <= 0

    # thickness match within tolerance
    thickness_ok = (thickness - db_thickness).abs <= thickness_tolerance

    # containment check with rotation allowed
    fits = (width <= db_width && height <= db_height) || (height <= db_width && width <= db_height)

    if thickness_ok && fits
      candidates << { name: db_name, data: db_data }
    end
  end

  candidates
end

# Replace the old validate_material_and_components with this corrected version.
# Key changes:
# - Validator no longer resolves materials by name.
# - It only checks if ANY sheet can contain the part (find_sheet_candidates).
# - Auto-create only when no candidate exists (true edge case).
def validate_material_and_components(material_name, part_entries, existing_materials, default_currency)
  part_entries.each do |part_entry|
    # Extract Part object
    part_obj = if part_entry.is_a?(Hash) && part_entry.key?(:part_type)
                 part_entry[:part_type]
               else
                 part_entry
               end

    next unless part_obj.respond_to?(:width) && part_obj.respond_to?(:height) && part_obj.respond_to?(:thickness)

    width = part_obj.width.to_f
    height = part_obj.height.to_f
    thickness = part_obj.thickness.to_f

    # HARD constraints
    if width > HARD_LIMIT_WIDTH || height > HARD_LIMIT_HEIGHT
      @validation_errors << "Component '#{part_obj.name}': #{width.round(0)}x#{height.round(0)}mm exceeds maximum limits (#{HARD_LIMIT_WIDTH}x#{HARD_LIMIT_HEIGHT}mm). This component is too large to fit on any standard sheet material."
      next
    end

    if width < MIN_DIMENSION || height < MIN_DIMENSION
      @validation_errors << "Component '#{part_obj.name}': #{width.round(1)}x#{height.round(1)}mm is too small (minimum #{MIN_DIMENSION}mm)"
      next
    end

    if thickness > MAX_THICKNESS
      @validation_errors << "Component '#{part_obj.name}': #{thickness.round(0)}mm thick - not a sheet material (maximum #{MAX_THICKNESS}mm)"
      next
    end

    if thickness < MIN_THICKNESS
      @validation_errors << "Component '#{part_obj.name}': #{thickness.round(2)}mm thick - too thin (minimum #{MIN_THICKNESS}mm)"
      next
    end

    # WARN if it exceeds the common standard sheet (but do not auto-create on this alone)
    can_fit_on_standard_sheet = false
    if (width <= 2440 && height <= 1220) || (height <= 2440 && width <= 1220)
      can_fit_on_standard_sheet = true
    end

    unless can_fit_on_standard_sheet
      @validation_warnings << "Component '#{part_obj.name}': #{width.round(1)}x#{height.round(1)}mm exceeds standard sheet size (2440x1220mm). This may require custom material sizing."
    end

    # If no material name assigned -> flagged temporary material (unchanged)
    if material_name.nil? || material_name.to_s.strip.empty?
      auto_create_flagged_material(part_obj.name, width, height, thickness, default_currency, existing_materials)
      next
    end

    # If material is already an auto-created placeholder, do not re-run matching/creation (prevents nested wrapping)
    if material_name.to_s.start_with?('Auto_user_') || material_name.to_s.start_with?('no_material_')
      puts "VALIDATOR: Skipping already auto-created material '#{material_name}' for component '#{part_obj.name}'"
      next
    end

    # --------- NEW CORRECT BEHAVIOR ----------
    # Instead of resolving by name, check whether any sheet in the database (same thickness category) can contain the part.
    sheet_candidates = find_sheet_candidates(width, height, thickness, existing_materials)

    # Debug log: show why decision happens
    if sheet_candidates.any?
      # Accept the original label. DO NOT auto-create. Nesting will group parts onto sheets later.
      puts "VALIDATOR: Component '#{part_obj.name}' (#{width.round(1)}x#{height.round(1)}x#{thickness.round(1)}) can fit on #{sheet_candidates.length} sheet candidate(s). No auto-create."
      # Optionally record candidate names for debugging
      candidate_names = sheet_candidates.map { |c| c[:name] }.join(', ')
      puts "  Candidates: #{candidate_names}"
    else
      # No candidate sheet. This is a true edge case -> auto-create
      puts "VALIDATOR: Component '#{part_obj.name}' (#{width.round(1)}x#{height.round(1)}x#{thickness.round(1)}) - NO sheet candidate found. Triggering auto-create."
      auto_create_oversized_material(material_name, width, height, thickness, default_currency, existing_materials)
    end
    # --------- END NEW BEHAVIOR ----------
  end
end

# (Optional) If we want to retain a thin compatibility wrapper but not used in validation:
# def find_compatible_material(...)  # leave uncalled or remove entirely
#   # deprecated: don't use for validation decisions. Keep only for legacy compatibility if required.
# end

# --- END ADD / REPLACE ---

```

---

## Why this exact change fixes the problem

* **No name-based procurement:** The validator no longer asks “does this part match a material name?” It asks “can this part fit on any known sheet?”
* **Prevents per-part stock creation:** If a sheet exists that can contain the part, the validator will not create `Auto_user_...` materials. Nesting will later group multiple parts on a sheet.
* **Auto-create only for real edge-cases:** Only when *no* existing sheet can contain the part will the validator create an auto material. That matches real workshop behavior.
* **Preserves existing safety checks:** Hard limits, flagged materials, and existing auto-cleanup remain intact.
* **Explicit debug logs:** The code logs how many candidate sheets were found and their names; this will make it trivial to confirm fixes in the logs.

---

## Quick test checklist (i will run these after applying the code)

1. Load the default database (all 111 default materials).
2. Clean any existing auto materials (you already perform cleanup at start).
3. Run validator on the problematic parts (the 305×762, 305×914, etc.).
4. Observe logs:

   * Expect `Candidates: ...` lines for each part (showing matching sheet(s)).
   * No `Auto_user_` created for these normal parts.
5. Check report: parts should keep their original material labels and nesting should group multiple parts per sheet.

If a part truly exceeds all sheet candidates, you will see:

* `NO sheet candidate found. Triggering auto-create.` and only then an `Auto_user_` will be created.

---
provide a small unit test harness (Ruby) that creates four parts (304.8×762, 304.8×914, 304.8×1066.8, 304.8×609.6) and runs the validator against your default database so WE can see the logs and confirm there are no auto-created materials for those normal sizes.