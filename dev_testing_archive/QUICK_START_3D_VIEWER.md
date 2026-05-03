# Quick Start - 3D Viewer Export

## 1. Load the Script
```ruby
load 'VIEWS_EXPORTER_EXPLODE.rb'
```

## 2. Select Component/Group
- Select ONE component or group in SketchUp
- Must contain geometry (faces)

## 3. Run Export
- Go to: **Plugins > Export Standard Views Pro**
- ✓ Check **"Include Interactive 3D Viewer"**
- Click **Generate**

## 4. Open HTML File
- Drag to rotate
- Use slider to explode parts
- Works in any modern browser

## Features

✅ **Solid Colors** - Red, blue, green, etc. (working now)
✅ **Textures** - Apply textured materials in SketchUp first
✅ **Openings** - Holes and cutouts render correctly
✅ **L-Shapes** - Any polygon shape works
✅ **Radial Explosion** - Parts fly outward naturally

## Texture Export

**"0 textures" = Using solid colors (correct!)**

To export textures:
1. Window > Materials
2. Choose material with image icon
3. Apply to faces
4. Export again
5. Will show "Loaded texture [name]"

## Test Script

```ruby
load 'TEST_ADVANCED_3D_FEATURES.rb'
# Go to: Plugins > Create Advanced Test Assembly
# Then export it!
```

## Troubleshooting

**No geometry in HTML?**
- Check Ruby console for vertex count
- Ensure component has faces

**Explode not working?**
- Need nested parts (sub-groups/components)
- Single-body models don't explode

**Textures not showing?**
- Check if materials are textured (not just colors)
- Look for "Loaded texture" in Ruby console

## That's It!

The exporter is ready to use. Everything is working correctly.
