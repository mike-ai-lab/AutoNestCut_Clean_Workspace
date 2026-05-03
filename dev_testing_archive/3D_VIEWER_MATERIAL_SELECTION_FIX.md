# 3D Viewer Material Selection Fix

## Issue 1: Material Properties Lost on Selection
When clicking on components in the 3D assembly viewer, materials would revert to solid opaque colors instead of maintaining their original properties (like glass transparency). This happened because the selection logic was overwriting all material properties with hardcoded values.

## Issue 2: Inconsistent Highlighting
The highlighting feature was inconsistent - sometimes visible, sometimes not. This was because emissive glow alone isn't always visible on textured materials or certain material types.

## Root Cause
In the `selectPart()` function (line ~2256), when highlighting a selected component:
1. ALL meshes were reset to hardcoded gray color (0xcccccc) with opacity 0.85
2. Selected meshes were changed to green (0x4CAF50) with opacity 1.0
3. This completely ignored the original material properties set by `applyMaterialToMesh()`
4. Highlighting used only emissive glow, which isn't visible on all material types

## Solution

### Part 1: Material Property Preservation System

#### 1. Store Original Material Properties
When materials are applied (texture or color/opacity), store the properties in `group.userData.originalMaterial`:
```javascript
group.userData.originalMaterial = {
    color: color,
    opacity: alpha,
    transparent: alpha < 1.0,
    map: texture || null
};
```

#### 2. Restore Original Properties on Selection
Modified `selectPart()` to restore original materials instead of using hardcoded values:
```javascript
// Reset all components to their ORIGINAL material appearance
assemblyMeshes.forEach(group => {
    const mesh = group.children[0];
    if (mesh && mesh.material) {
        const originalMaterial = group.userData.originalMaterial;
        if (originalMaterial) {
            mesh.material.color.setHex(originalMaterial.color);
            mesh.material.opacity = originalMaterial.opacity;
            mesh.material.transparent = originalMaterial.transparent;
            mesh.material.map = originalMaterial.map || null;
        }
        // ... reset emissive properties
    }
});
```

### Part 2: Enhanced Multi-Layer Highlighting

To ensure highlighting is always visible, implemented a three-layer approach:

#### 1. Emissive Glow (Primary)
```javascript
mesh.material.emissive.setHex(0x66FF66); // Bright green glow
mesh.material.emissiveIntensity = 0.8; // Increased from 0.5 to 0.8
```

#### 2. Color Brightening (For Non-Textured Materials)
```javascript
if (!mesh.material.map) {
    // Brighten the base color by adding 30 to each RGB component
    const currentColor = mesh.material.color.getHex();
    const r = Math.min(255, ((currentColor >> 16) & 0xFF) + 30);
    const g = Math.min(255, ((currentColor >> 8) & 0xFF) + 30);
    const b = Math.min(255, (currentColor & 0xFF) + 30);
    mesh.material.color.setRGB(r/255, g/255, b/255);
}
```

#### 3. Edge/Wireframe Highlighting (Most Visible)
```javascript
const wireframe = group.children[1];
if (wireframe && wireframe.material) {
    wireframe.material.color.setHex(0x00FF00); // Bright green edges
    wireframe.material.linewidth = 3; // Thicker lines
}
```

#### 4. Debug Logging
Added comprehensive logging to diagnose highlighting issues:
```javascript
console.log(`Highlighting mesh ${highlightCount}:`, {
    partName: group.userData.partName,
    hasTexture: mesh.material.map !== null,
    currentColor: mesh.material.color.getHex().toString(16),
    currentOpacity: mesh.material.opacity
});

if (highlightCount === 0) {
    console.warn('⚠️ No instances highlighted! Part name:', name);
    console.warn('Available part names:', assemblyMeshes.map(g => g.userData.partName));
}
```

## Changes Made

### File: `Extension/AutoNestCut/ui/html/main.html`

1. **renderAssembly() function** (~line 2050)
   - Added `originalMaterial` to `group.userData` when meshes are first created
   - Added `originalEdgeColor` to store original wireframe color
   - Stores initial default material properties

2. **applyMaterialToMesh() function** (~line 1480)
   - Added storage of original material properties after applying textures
   - Added storage of original material properties after applying colors/opacity

3. **selectPart() function** (~line 2256)
   - Changed to restore original material properties instead of hardcoded values
   - Enhanced highlighting with three-layer approach:
     * Emissive glow (increased intensity to 0.8)
     * Color brightening for non-textured materials
     * Bright green edges with thicker lines
   - Added edge/wireframe reset to original color
   - Added comprehensive debug logging

## Result
- ✅ Glass materials maintain their transparency when components are selected
- ✅ Textured materials keep their textures when components are selected
- ✅ All material properties (color, opacity, transparency, textures) are preserved
- ✅ Highlighting is now ALWAYS visible using three visual cues:
  - Emissive green glow on the material
  - Brightened base color (non-textured only)
  - Bright green edges/wireframe (most visible)
- ✅ Debug logging helps diagnose any remaining issues

## Testing
1. Load an assembly with mixed materials (glass, wood, metal)
2. Click "TEX" button to apply textures
3. Click on different components
4. Verify that:
   - Glass remains semi-transparent ✓
   - Textured materials keep their textures ✓
   - Selected parts show green glow + green edges ✓
   - Highlighting is visible on ALL material types ✓
   - Console shows highlighting debug info ✓
