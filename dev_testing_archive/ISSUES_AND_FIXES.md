# AutoNestCut Issues Analysis & Fixes

## Issue 1: Thickness Showing 0.0 in Components Table

### Problem
The "Components Found" table displays thickness as `0.0` while the "Parts Preview" section correctly shows the actual thickness (e.g., `18 mm`).

### Root Cause
The components table was using hardcoded `.toFixed(1)` formatting without:
1. Respecting the user's precision settings
2. Converting from SketchUp's internal units (inches) to the display units (mm)
3. Using the `formatNumber()` function that applies proper unit conversion

### Original Code (BROKEN)
```javascript
<td style="padding: 8px; text-align: right;">${(comp.thickness || 0).toFixed(1)}</td>
```

### Fixed Code
```javascript
const thickness = (comp.depth || comp.thickness || 0) / (window.unitFactors[window.currentUnits || 'mm'] || 1);
<td style="padding: 8px; text-align: right;">${formatNumber(thickness, reportPrecision)}</td>
```

### Key Changes
- **Unit Conversion**: Divides by `window.unitFactors` to convert from SketchUp units to display units
- **Precision Respect**: Uses `formatNumber()` with `window.currentPrecision` instead of hardcoded `.toFixed(1)`
- **Fallback Handling**: Checks both `comp.depth` and `comp.thickness` properties
- **Consistency**: Now matches the "Parts Preview" section formatting

---

## Issue 2: Precision Inconsistency (0.0 vs 0)

### Problem
- Components table shows `0.0` (one decimal place)
- Parts Preview respects user settings (shows `0` when precision is 0, `0.0` when precision is 1)

### Root Cause
The components table was hardcoded to use `.toFixed(1)` regardless of user settings.

### Solution
Now uses `window.currentPrecision` which is set from user's Settings:
- Precision 0 → displays as `364` (no decimals)
- Precision 1 → displays as `364.0` (one decimal)
- Precision 2 → displays as `364.00` (two decimals)

---

## Issue 3: No Materials Showing in Configuration Window

### Problem
The "Stock Materials & Pricing" section appears empty even though materials are assigned to components.

### Root Cause
This is a **display/filtering issue**, not a data issue. The materials ARE being detected and stored, but:

1. **Auto-Generated Materials**: When you assign "Maple Wood" to a component, the system auto-creates a material entry in the database
2. **"Used Only" Filter**: By default, the materials list is filtered to show only materials that are actually used in the current selection
3. **Initial Load**: The materials list may not populate immediately on first load

### How Materials Are Detected

#### Detection Priority (in order):
1. **Instance Material** - Material assigned directly to the component instance in SketchUp
2. **Definition Material** - Material assigned to the component definition
3. **Dominant Face Material** - Material detected from the faces inside the component
4. **Default** - "No Material" if nothing is found

#### Code Location
File: `Extension/AutoNestCut/models/part.rb` (lines 30-50)

```ruby
# Priority 1: Specific material passed as parameter
if specific_material.is_a?(Sketchup::Material)
  detected_material = specific_material.display_name || specific_material.name
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

### How to See Your Materials

1. **Click the filter icon** (funnel icon) in the materials section to toggle "Used Only" mode
2. **Materials will appear** if they're assigned to selected components
3. **Check the "Status" column** - it shows "Used" for materials in your selection

---

## Edge Banding Detection

### Identifier
**Attribute Dictionary Keys:**
- Dictionary Name: `AutoNestCut` or `DynamicAttributes`
- Key Name: `edge_banding`

### Format Specification
```
"MaterialType:edge1,edge2,edge3"
```

### Examples
- `"PVC_White"` → PVC White on all edges (top, bottom, left, right)
- `"PVC_White:top,bottom"` → PVC White only on top and bottom edges
- `"Veneer_Oak:left,right"` → Oak veneer only on left and right edges
- `"None"` → No edge banding

### Detection Code
File: `Extension/AutoNestCut/models/part.rb` (lines 60-75)

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

### How to Set Edge Banding in SketchUp
```ruby
# Via Ruby Console:
component_instance.set_attribute('AutoNestCut', 'edge_banding', 'PVC_White:top,bottom')
```

---

## Grain Direction Detection

### Identifier
**Attribute Dictionary Keys:**
- Dictionary Name: `AutoNestCut` or `DynamicAttributes`
- Key Name: `grain_direction`

### Valid Values
- `"Any"` → No grain constraint, part can rotate freely
- `"fixed"` → Cannot rotate at all
- `"vertical"` → Grain runs vertically, no rotation allowed
- `"horizontal"` → Grain runs horizontally, no rotation allowed

### Detection Code
File: `Extension/AutoNestCut/models/part.rb` (lines 45-58)

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

### Impact on Rotation
File: `Extension/AutoNestCut/models/part.rb` (lines 130-140)

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

### How to Set Grain Direction in SketchUp
```ruby
# Via Ruby Console:
component_instance.set_attribute('AutoNestCut', 'grain_direction', 'vertical')
```

---

## Component Processing Flow

### Why Some Components Don't Get Processed

Components are silently filtered out if they don't meet "sheet goods" criteria:

**Filtering Criteria** (File: `Extension/AutoNestCut/util.rb`)
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

### Why No User Feedback?

The filtering happens silently in two places:

1. **During Collection** (File: `Extension/AutoNestCut/processors/model_analyzer.rb`)
   ```ruby
   if Util.is_sheet_good?(definition.bounds)  # <-- SILENT FILTER
     @original_components << { entity: entity, transform: combined_transform }
   end
   ```

2. **During Processing** (File: `Extension/AutoNestCut/processors/model_analyzer.rb`)
   ```ruby
   definition_counts.each do |definition, total_count_for_type|
     next unless Util.is_sheet_good?(definition.bounds)  # <-- SILENT FILTER
     # Process only sheet goods
   end
   ```

### Recommended Improvement
Add a validation report showing:
- Total components selected
- Components processed
- Components filtered out (with reasons)
- User feedback about why components were excluded

---

## Summary Table

| Issue | Cause | Location | Fix |
|-------|-------|----------|-----|
| **Thickness 0.0** | No unit conversion, hardcoded precision | `main.html` updateComponentsList() | Use formatNumber() with unit conversion |
| **Precision Inconsistency** | Hardcoded .toFixed(1) | `main.html` updateComponentsList() | Use window.currentPrecision |
| **No Materials Showing** | "Used Only" filter active by default | `main.html` displayMaterials() | Toggle filter or materials are auto-created |
| **Edge Banding Detection** | Attribute dictionary lookup | `part.rb` lines 60-75 | Keys: `AutoNestCut:edge_banding` or `DynamicAttributes:edge_banding` |
| **Grain Direction Detection** | Attribute dictionary lookup | `part.rb` lines 45-58 | Keys: `AutoNestCut:grain_direction` or `DynamicAttributes:grain_direction` |
| **Silent Component Filtering** | No user feedback on filtered components | `model_analyzer.rb` & `util.rb` | Add validation report with filtering reasons |

