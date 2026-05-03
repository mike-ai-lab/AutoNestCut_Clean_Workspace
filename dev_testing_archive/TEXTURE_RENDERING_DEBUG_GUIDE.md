# 3D Assembly Viewer - Texture Rendering Debug Guide

## Issues Fixed

### 1. Ruby Backend - UV Coordinate Generation
**Problem**: The `collect_component_faces` method in `report_generator.rb` wasn't generating UV coordinates for faces.

**Fix Applied**:
- Added UV coordinate extraction from SketchUp materials with textures
- Implemented fallback planar UV mapping for materials without textures
- Added safety checks to handle nil position/normal values
- Fixed position handling to work with both `Geom::Point3d` and Hash types

**Files Modified**:
- `Extension/AutoNestCut/exporters/report_generator.rb`

### 2. Ruby Backend - Material Information
**Problem**: Material names weren't being captured per-part in the assembly geometry.

**Fix Applied**:
- Modified `extract_component_geometry` to capture material name for each part
- Material name is now included in the part data sent to frontend

### 3. JavaScript Frontend - UV Attribute
**Problem**: The `renderAssembly` function wasn't always adding UV attributes to geometries.

**Fix Applied**:
- Always add UV attribute to BufferGeometry (even with fallback UVs)
- Generate fallback UVs (0,0), (0.5,0), (0.5,0.5) if face UVs are missing
- Ensure all meshes are texture-ready

### 4. JavaScript Frontend - Texture Application
**Problem**: The `applyTextureToMesh` function had incomplete assembly mode handling.

**Fix Applied**:
- Apply textures to ALL assembly meshes (not just selected ones)
- Set material properties correctly for texture display
- Added comprehensive console logging for debugging

### 5. JavaScript Frontend - Material Properties
**Problem**: Materials created with `transparent: true, opacity: 0.85` prevent proper texture display.

**Fix Applied**:
- When texture mode is ON: set `transparent: false, opacity: 1.0, color: 0xFFFFFF`
- When texture mode is OFF: revert to `transparent: true, opacity: 0.85, color: 0xcccccc`

## Testing Instructions

### 1. Check Console Logs
Open the browser console (F12) and look for these debug messages:

```
=== TOGGLE TEXTURE ===
Current textureMode: false
isAssemblyMode: true
New textureMode: true
Assembly Mode - Processing X meshes
Unique materials found: ["Material1", "Material2", ...]
Requesting texture for: Material1
Requesting texture for: Material2
```

### 2. Check Ruby Console
In SketchUp Ruby Console, look for:

```
DEBUG: Texture requested for material: MaterialName
DEBUG: Material found: MaterialName
DEBUG: Material has texture: YES
DEBUG: Texture width: 512
DEBUG: Texture height: 512
DEBUG: Texture write success: true
DEBUG: Texture data URI length: XXXXX
```

### 3. Check Texture Application
After clicking TEX button, console should show:

```
=== APPLY TEXTURE TO MESH ===
textureData received: YES (length: XXXXX)
isAssemblyMode: true
Loading texture with THREE.TextureLoader...
✓ Texture loaded successfully!
Texture size: 512 x 512
Applying texture in assembly mode to X meshes
Mesh 0 (PartName): hasUVs: true material: MaterialName
✓ Applied texture to mesh 0
Texture applied to X meshes
```

## Common Issues & Solutions

### Issue 1: "No texture data provided!"
**Cause**: Ruby backend didn't send texture data
**Solution**: Check if material has a texture in SketchUp. Materials with only colors won't have textures.

### Issue 2: "Mesh X has no UV coordinates!"
**Cause**: UV generation failed in Ruby backend
**Solution**: Check Ruby console for errors in `generate_planar_uv` method

### Issue 3: Textures appear white/blank
**Cause**: UV coordinates are incorrect or texture isn't loading
**Solution**: 
- Check texture size in console (should be > 0)
- Verify UV coordinates are being generated (check Ruby logs)
- Try a different material with a known texture

### Issue 4: "Material not found: MaterialName"
**Cause**: Material name mismatch between assembly data and SketchUp model
**Solution**: Check that material names in assembly data match actual SketchUp materials

### Issue 5: Textures work in single mode but not assembly mode
**Cause**: Assembly meshes don't have UV attributes
**Solution**: Check console for "hasUVs: false" messages

## Architecture Overview

### Data Flow:
1. **Ruby Backend** (`report_generator.rb`):
   - `extract_component_geometry` → captures part names and materials
   - `collect_component_faces` → extracts vertices, UVs, colors, materials
   - `generate_planar_uv` → generates fallback UV coordinates

2. **Data Transfer** (`dialog_manager.rb`):
   - Assembly data sent to frontend via `send_initial_data`
   - Includes geometry with faces containing vertices + UVs

3. **JavaScript Frontend** (`main.html`):
   - `renderAssembly` → creates THREE.js meshes with UV attributes
   - `toggleTexture` → requests textures from Ruby backend
   - `applyTextureToMesh` → applies loaded textures to meshes

4. **Texture Loading** (`dialog_manager.rb`):
   - `get_material_texture` callback → extracts texture from SketchUp material
   - Converts to base64 data URI
   - Sends to frontend via `applyTextureToMesh` call

## Next Steps

If textures still don't render after these fixes:

1. **Verify Material Has Texture**:
   - In SketchUp, right-click material → Edit
   - Check if "Use texture image" is enabled
   - Verify texture file exists

2. **Check UV Coordinates**:
   - Add this to console: `console.log(mesh.geometry.attributes.uv)`
   - Should show Float32BufferAttribute with data

3. **Check Material Properties**:
   - Add this to console: `console.log(mesh.material)`
   - Verify `map` property is set to a Texture object
   - Verify `color` is white (0xFFFFFF)
   - Verify `transparent` is false

4. **Test with Simple Geometry**:
   - Create a simple box with a textured material
   - Test if texture renders in assembly mode

## Debug Commands

Add these to browser console for debugging:

```javascript
// Check assembly meshes
console.log('Assembly meshes:', assemblyMeshes.length);
assemblyMeshes.forEach((g, i) => {
    console.log(`Mesh ${i}:`, g.userData.partName, g.userData.materialName);
});

// Check UV attributes
assemblyMeshes.forEach((g, i) => {
    const mesh = g.children[0];
    const hasUVs = mesh.geometry.attributes.uv !== undefined;
    console.log(`Mesh ${i} UVs:`, hasUVs);
});

// Check textures
assemblyMeshes.forEach((g, i) => {
    const mesh = g.children[0];
    console.log(`Mesh ${i} texture:`, mesh.material.map);
});

// Force texture mode on
textureMode = true;
toggleTexture();
```
