# 3D Assembly Texture Rendering Fix

## Problem Summary

Textures were not rendering in the 3D assembly viewer due to multiple critical issues:

1. **No UV coordinates in assembly data** - Ruby backend didn't generate UV coordinates
2. **No material information per part** - Parts didn't have material names attached
3. **Incomplete texture application** - JavaScript had bugs in texture application logic
4. **Material properties blocking textures** - Transparency settings prevented texture display

## Root Causes Identified

### 1. Missing UV Coordinates (Ruby Backend)
**File**: `Extension/AutoNestCut/exporters/report_generator.rb`

The `collect_component_faces` method only extracted vertex positions and colors, but not UV coordinates needed for texture mapping.

**Original Code**:
```ruby
def collect_component_faces(entity, transformation, faces)
  # Only extracted vertices and color
  # No UV coordinate generation
end
```

### 2. Missing Material Information (Ruby Backend)
**File**: `Extension/AutoNestCut/exporters/report_generator.rb`

The `extract_component_geometry` method didn't capture material names for each part.

**Original Code**:
```ruby
parts << {
  name: part_name,
  explode_vector: [...],
  faces: faces
  # Missing: material information
}
```

### 3. Incomplete Texture Application (JavaScript Frontend)
**File**: `Extension/AutoNestCut/ui/html/main.html`

The `applyTextureToMesh` function had incomplete logic for assembly mode and didn't properly handle material matching.

### 4. Material Transparency Blocking Textures (JavaScript Frontend)
**File**: `Extension/AutoNestCut/ui/html/main.html`

The `renderAssembly` function created materials with `transparent: true, opacity: 0.85` which prevented proper texture display.

## Fixes Applied

### Fix 1: Generate UV Coordinates in Ruby Backend

**File**: `Extension/AutoNestCut/exporters/report_generator.rb`

Added UV coordinate generation to `collect_component_faces`:

```ruby
def collect_component_faces(entity, transformation, faces, material_ref = nil)
  entities.each do |e|
    if e.is_a?(Sketchup::Face)
      vertices = []
      uvs = []  # NEW: Array for UV coordinates
      
      # Get material for this face
      face_material = e.material || e.back_material
      
      e.outer_loop.vertices.each_with_index do |v, idx|
        # Extract vertex position
        pt = 