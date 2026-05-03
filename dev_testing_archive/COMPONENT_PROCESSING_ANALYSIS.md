# AutoNestCut Component Processing Analysis

## Executive Summary

This document explains why some components are not processed in AutoNestCut and how Edge Banding and Grain Direction are detected.

---

## 1. WHY COMPONENTS ARE NOT PROCESSED (Silent Filtering)

### Root Cause: Sheet Goods Detection Filter

Components are silently filtered out during the analysis phase if they **do not meet the "sheet goods" criteria**. There is **NO user feedback** about which components were excluded.

### The Filtering Logic

**Location:** `Extension/AutoNestCut/util.rb` - `Util.is_sheet_good?()` method

```ruby
def self.is_sheet_good?(bounds, min_thickness = 3, max_thickness = 100, min_area = 1000)
  dimensions = get_dimensions(bounds).sort  # [thickness, width, height]
  thickness = dimensions[0]
  width = dimensions[1]
  height = dimensions[2]
  
  # FILTER 1: Thickness must be between 3mm and 100mm
  return false if thickness < min_thickness || thickness > max_thickness
  
  # FILTER 2: Area must be at least 1000 mm²
  return false if (width * height) < min_area
  
  true
end
```

### Filtering Criteria

| Criterion | Default Value | Configurable | Impact |
|-----------|---------------|--------------|--------|
| **Min Thickness** | 3 mm | Yes (Config) | Rejects very thin components |
| **Max Thickness** | 100 mm | Yes (Config) | Rejects very thick components |
| **Min Area** | 1000 mm² | Yes (Config) | Rejects very small components |

### Where Filtering Occurs

**Location:** `Extension/AutoNestCut/processors/model_analyzer.rb` - `deep_recursive_search()` method

```ruby
def deep_recursive_search(entity, definition_counts, transformation = Geom::Transformation.new)
  if entity.is_a?(Sketchup::ComponentInstance)
    definition = entity.definition
    definition_counts[definition] ||= 0
    definition_counts[definition] += 1
    
    # CRITICAL: Only collect components that pass sheet goods test
    if Util.is_sheet_good?(definition.bounds)  # <-- SILENT FILTER HERE
      combined_transform = transformation * entity.transformation
      @original_components << {
        entity: entity,
        transform: combined_transform
      }
    end
    
    # Continue searching inside component definition
    component_transform = transformation * entity.transformation
    definition.entities.each { |child| deep_recursive_search(child, definition_counts, component_transform) }
  end
end
```

### Later Filtering in Nesting

**Location:** `Extension/AutoNestCut/processors/model_analyzer.rb` - `analyze_selection()` method

```ruby
# Process only sheet goods and batch create parts
definition_counts.each do |definition, total_count_for_type|
  next unless Util.is_sheet_good?(definition.bounds)  # <-- SECOND FILTER
  
  part_type = AutoNestCut::Part.new(definition)
  material_name = part_type.material
  part_types_by_material[material_name] ||= []
  part_types_by_material[material_name] << { part_type: part_type, total_quantity: total_count_for_type }
end
```

### Why No User Feedback?

The filtering happens **silently** in the background:

1. **No error messages** - The code uses `next` to skip non-sheet-goods without logging
2. **No warning dialog** - Users are not informed which components were excluded
3. **No count comparison** - The UI doesn't show "Selected: 10 components, Processing: 7 components"
4. **Silent success** - If all components are filtered out, the system shows "No valid sheet good parts found"

---

## 2. EDGE BANDING DETECTION

### Identifier: Attribute Dictionary Keys

Edge Banding is detected from **component attributes** stored in SketchUp's attribute dictionaries.

**Location:** `Extension/AutoNestCut/models/part.rb` - `initialize()` method

```ruby
# Get edge banding from attribute dictionaries (check instance first, then definition)
edge_banding_raw = 'None' # Default

if component_definition_or_instance.is_a?(Sketchup::ComponentInstance)
  # Check instance attributes first
  edge_banding_raw = component_definition_or_instance.get_attribute('AutoNestCut', 'edge_banding') ||
                    component_definition_or_instance.get_attribute('DynamicAttributes', 'edge_banding') ||
                    edge_banding_raw
end

# Check definition attributes if not found on instance
if edge_banding_raw == 'None'
  edge_banding_raw = definition.get_attribute('AutoNestCut', 'edge_banding') ||
                    definition.get_attribute('DynamicAttributes', 'edge_banding') ||
                    'None'
end

# Parse edge banding specification
@edge_banding = parse_edge_banding(edge_banding_raw)
```

### Edge Banding Identifiers

| Attribute Dictionary | Key | Value Format | Example |
|---------------------|-----|--------------|---------|
| **AutoNestCut** | `edge_banding` | String | `"PVC_White:top,bottom"` |
| **DynamicAttributes** | `edge_banding` | String | `"PVC_White:top,bottom"` |

### Edge Banding Format Specification

```ruby
def parse_edge_banding(raw_value)
  return { type: 'None', edges: [] } if raw_value.nil? || raw_value == 'None'
  
  parts = raw_value.split(':')
  type = parts[0] || 'PVC_White'  # Material type (e.g., "PVC_White", "Veneer_Oak")
  
  if parts.length > 1
    edges = parts[1].split(',').map(&:strip)  # Specific edges: "top", "bottom", "left", "right"
  else
    edges = ['top', 'bottom', 'left', 'right']  # Default: all edges
  end
  
  { type: type, edges: edges }
end
```

### Edge Banding Value Examples

| Raw Value | Parsed Result | Meaning |
|-----------|---------------|---------|
| `"None"` | `{type: 'None', edges: []}` | No edge banding |
| `"PVC_White"` | `{type: 'PVC_White', edges: ['top', 'bottom', 'left', 'right']}` | PVC White on all edges |
| `"PVC_White:top,bottom"` | `{type: 'PVC_White', edges: ['top', 'bottom']}` | PVC White on top and bottom only |
| `"Veneer_Oak:left,right"` | `{type: 'Veneer_Oak', edges: ['left', 'right']}` | Oak veneer on left and right edges |

### How to Set Edge Banding

In SketchUp Ruby:
```ruby
component_instance.set_attribute('AutoNestCut', 'edge_banding', 'PVC_White:top,bottom')
# OR
component_definition.set_attribute('AutoNestCut', 'edge_banding', 'PVC_White:top,bottom')
```

---

## 3. GRAIN DIRECTION DETECTION

### Identifier: Attribute Dictionary Keys

Grain Direction is detected from **component attributes** stored in SketchUp's attribute dictionaries.

**Location:** `Extension/AutoNestCut/models/part.rb` - `initialize()` method

```ruby
# Get grain direction from attribute dictionaries (check instance first, then definition)
@grain_direction = 'Any' # Default

if component_definition_or_instance.is_a?(Sketchup::ComponentInstance)
  # Check instance attributes first
  @grain_direction = component_definition_or_instance.get_attribute('AutoNestCut', 'grain_direction') ||
                    component_definition_or_instance.get_attribute('DynamicAttributes', 'grain_direction') ||
                    @grain_direction
end

# Check definition attributes if not found on instance
if @grain_direction == 'Any'
  @grain_direction = definition.get_attribute('AutoNestCut', 'grain_direction') ||
                    definition.get_attribute('DynamicAttributes', 'grain_direction') ||
                    'Any'
end
```

### Grain Direction Identifiers

| Attribute Dictionary | Key | Value Format | Example |
|---------------------|-----|--------------|---------|
| **AutoNestCut** | `grain_direction` | String | `"vertical"` |
| **DynamicAttributes** | `grain_direction` | String | `"horizontal"` |

### Grain Direction Values

| Value | Meaning | Rotation Allowed |
|-------|---------|------------------|
| `"Any"` | No grain constraint | ✅ Yes |
| `"fixed"` | Cannot rotate | ❌ No |
| `"vertical"` | Grain runs vertically | ❌ No |
| `"horizontal"` | Grain runs horizontally | ❌ No |

### Grain Direction Impact on Rotation

**Location:** `Extension/AutoNestCut/models/part.rb` - `can_rotate?()` method

```ruby
def can_rotate?
  return false if @grain_direction && ['fixed', 'vertical', 'horizontal'].include?(@grain_direction.downcase)
  true
end

def rotate!
  # Check if rotation is allowed based on grain_direction
  return false if @grain_direction && ['fixed', 'vertical', 'horizontal'].include?(@grain_direction.downcase)
  @width, @height = @height, @width
  @rotated = !@rotated
  true
end
```

### How to Set Grain Direction

In SketchUp Ruby:
```ruby
component_instance.set_attribute('AutoNestCut', 'grain_direction', 'vertical')
# OR
component_definition.set_attribute('AutoNestCut', 'grain_direction', 'horizontal')
```

---

## 4. MATERIAL DETECTION

### Material Detection Priority

**Location:** `Extension/AutoNestCut/models/part.rb` - `initialize()` method

Materials are detected in this priority order:

```
1. Specific material passed to constructor (if provided)
   ↓
2. Material assigned to component instance
   ↓
3. Material assigned to component definition
   ↓
4. Dominant material from definition's faces (recursive search)
   ↓
5. Default: 'No Material'
```

### Material Detection Code

```ruby
detected_material = nil

# Priority 1: Specific material passed as parameter
if specific_material.is_a?(Sketchup::Material)
  detected_material = specific_material.display_name || specific_material.name
elsif specific_material.is_a?(String)
  detected_material = specific_material
end

# Priority 2: Instance material
unless detected_material
  detected_material = instance_material&.display_name || instance_material&.name
end

# Priority 3: Definition material
unless detected_material
  detected_material = definition.material&.display_name || definition.material&.name
end

# Priority 4: Dominant face material
unless detected_material
  detected_material = AutoNestCut::Util.get_dominant_material(definition)
end

# Priority 5: Default
@material = detected_material || 'No Material'
```

---

## 5. COMPONENT PROCESSING FLOW

### Complete Processing Pipeline

```
User Selection
    ↓
ModelAnalyzer.analyze_selection()
    ↓
deep_recursive_search() - Traverse all nested components
    ↓
    ├─→ For each component:
    │   ├─→ Check: is_sheet_good?(bounds) ← FILTER 1
    │   │   ├─→ Thickness: 3-100mm?
    │   │   ├─→ Area: > 1000mm²?
    │   │   └─→ If NO → SKIP (no feedback)
    │   │
    │   └─→ If YES → Collect component data
    │       ├─→ Extract dimensions
    │       ├─→ Detect material
    │       ├─→ Detect grain_direction
    │       └─→ Detect edge_banding
    │
    ├─→ Count unique definitions
    │
    └─→ Process definitions
        ├─→ Check: is_sheet_good?(bounds) ← FILTER 2
        ├─→ Create Part objects
        ├─→ Group by material
        └─→ Return parts_by_material
            ↓
        UIDialogManager.show_config_dialog()
            ↓
        User configures settings
            ↓
        Nester.optimize_boards()
            ↓
        Generate reports
```

---

## 6. RECOMMENDED IMPROVEMENTS

### For User Feedback

Add a validation report before processing:

```ruby
# Suggested: In dialog_manager.rb
def validate_and_report_filtering(selected_entities, analyzed_parts)
  filtered_out = []
  
  selected_entities.each do |entity|
    unless analyzed_parts.any? { |p| p.entity_id == entity.entityID }
      filtered_out << {
        name: entity.definition.name,
        reason: determine_filter_reason(entity)
      }
    end
  end
  
  if filtered_out.any?
    show_filtering_report(filtered_out)
  end
end
```

### For Configuration

Make sheet goods criteria configurable in UI:

```ruby
# In config.rb
def self.get_sheet_goods_criteria
  {
    min_thickness: get_setting('min_sheet_thickness', 3),
    max_thickness: get_setting('max_sheet_thickness', 100),
    min_area: get_setting('min_sheet_area', 1000)
  }
end
```

---

## 7. SUMMARY TABLE

| Aspect | Identifier | Location | Default | Configurable |
|--------|-----------|----------|---------|--------------|
| **Sheet Goods Filter** | Bounds dimensions | `util.rb` | 3-100mm thickness, >1000mm² area | Yes (Config) |
| **Edge Banding** | `AutoNestCut:edge_banding` or `DynamicAttributes:edge_banding` | `part.rb` | `"None"` | Via attributes |
| **Grain Direction** | `AutoNestCut:grain_direction` or `DynamicAttributes:grain_direction` | `part.rb` | `"Any"` | Via attributes |
| **Material** | Component material property | `part.rb` | Detected from faces | Via SketchUp material |

---

## 8. KEY FILES REFERENCE

| File | Purpose | Key Methods |
|------|---------|-------------|
| `util.rb` | Utility functions | `is_sheet_good?()`, `get_dominant_material()` |
| `model_analyzer.rb` | Component analysis | `analyze_selection()`, `deep_recursive_search()` |
| `part.rb` | Part data model | `initialize()`, `parse_edge_banding()`, `can_rotate?()` |
| `dialog_manager.rb` | UI management | `validate_component_dimensions()`, `show_config_dialog()` |
| `nester.rb` | Nesting algorithm | `optimize_boards()`, `try_place_part_on_board()` |

