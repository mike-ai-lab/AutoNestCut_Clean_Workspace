# Texture Export Guide

## Why Textures Show "0 textures"

The exporter is working correctly! The "0 textures" message means:
- **Your model has no textured materials applied**
- Only solid colors are being used

## How to Test Texture Export

### Method 1: Use SketchUp's Built-in Materials

1. **Open SketchUp Materials Panel**:
   - Window > Materials (or press 'B')

2. **Select a Textured Material**:
   - Choose from "Wood", "Brick", "Metal", etc.
   - Look for materials with image icons (not just solid colors)

3. **Apply to Your Model**:
   - Select faces in your component
   - Click the material to apply

4. **Export and Check**:
   - Run the export again
   - You should see: "Loaded texture [filename]"
   - Console will show: "X textures" instead of "0 textures"

### Method 2: Create Custom Textured Material

```ruby
# In SketchUp Ruby Console:
model = Sketchup.active_model
mat = model.materials.add("My Texture")

# Set a texture from a file
mat.texture = "C:/path/to/your/image.jpg"

# Apply to selected faces
model.selection.grep(Sketchup::Face).each { |f| f.material = mat }
```

### Method 3: Import Textured Model

1. Download a textured 3D model (3D Warehouse)
2. Import into SketchUp
3. Export using the tool
4. Textures will be included

## Verifying Texture Export

### In Ruby Console (During Export)
Look for these messages:
```
ViewExporter: Loaded texture wood_oak.jpg
ViewExporter: Loaded texture metal_brushed.png
ViewExporter: Processed 12 faces, 120 vertices, 2 textures
```

### In Browser Console (After Opening HTML)
Press F12 and look for:
```
Loaded 5 parts with 432 vertices
```

No errors = textures loaded successfully!

## Texture Support Details

### ✅ Supported Formats
- JPG/JPEG
- PNG (with transparency)
- BMP
- Any format SketchUp can load

### ✅ What Works
- Image-based textures
- UV mapping from SketchUp
- Multiple textures per model
- Texture tiling/repeating
- Transparency (PNG alpha)

### ❌ Not Supported
- Procedural/generated textures
- Bump/normal maps
- Specular maps
- SketchUp's color-only materials (these export as solid colors)

## Common Scenarios

### Scenario 1: Cabinet with Wood Grain
```
1. Apply "Wood_Floor_Light" material to cabinet faces
2. Export → Will show "1 texture"
3. HTML will display wood grain texture
```

### Scenario 2: Mixed Materials
```
1. Wood texture on body
2. Metal texture on hardware
3. Solid color on interior
4. Export → Will show "2 textures" (wood + metal)
5. HTML will show all correctly
```

### Scenario 3: No Textures (Current Situation)
```
1. Only solid colors applied (red, blue, green, etc.)
2. Export → Will show "0 textures"
3. HTML will show solid colors (this is correct!)
```

## Testing Checklist

- [ ] Open Materials panel in SketchUp
- [ ] Find a material with an image icon (textured)
- [ ] Apply to faces in your component
- [ ] Run export
- [ ] Check Ruby console for "Loaded texture" messages
- [ ] Open HTML file
- [ ] Verify texture appears in 3D viewer

## Troubleshooting

### "0 textures" but I applied a material
**Check**: Is it a solid color material or textured?
- Solid color = No texture file = "0 textures" ✓ Correct
- Textured = Has image = Should show "1+ textures"

### "Texture file not found"
**Fix**: The texture file path is invalid
- SketchUp moved the texture
- File was deleted
- Try re-applying the material

### Texture appears black/wrong in HTML
**Check Browser Console** (F12):
- Look for texture loading errors
- Check if base64 data is present
- Verify MIME type is correct

### Texture is stretched/distorted
**Issue**: UV mapping problem
- Check texture positioning in SketchUp
- Use "Position Texture" tool to adjust
- Re-export after fixing

## Example: Adding Texture to Test Model

```ruby
# Load the test script
load 'TEST_ADVANCED_3D_FEATURES.rb'

# Create the test assembly
assembly = create_advanced_test_assembly

# Now manually add a texture:
model = Sketchup.active_model

# Find the "Textured Panel" part
part2 = assembly.definition.entities.grep(Sketchup::Group).find { |g| g.name == "Textured Panel" }

if part2
  # Apply a SketchUp default textured material
  mat = model.materials["Wood_Floor_Light"] || model.materials["Brick_Antique"]
  
  if mat
    part2.entities.grep(Sketchup::Face).each { |f| f.material = mat }
    puts "Applied texture: #{mat.name}"
  else
    puts "No default textured materials found"
    puts "Open Materials panel and apply a textured material manually"
  end
end

# Now export and you should see textures!
```

## Summary

**The exporter DOES support textures!** 

The "0 textures" message simply means your current model uses only solid colors, which is perfectly valid. To test texture export:

1. Apply a textured material from SketchUp's Materials panel
2. Look for materials with image icons (not just color swatches)
3. Export again and check for "Loaded texture" messages
4. Open HTML to see textures rendered in 3D viewer

The texture system is fully functional and ready to use whenever you have textured materials in your model.
