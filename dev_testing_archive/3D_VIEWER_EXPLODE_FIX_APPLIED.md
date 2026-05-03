# 3D Viewer Explode Function Fix - APPLIED

## Problem Identified

The explode function was moving the entire assembly as a whole instead of exploding individual nested components.

## Root Cause Analysis

After analyzing the code flow:

1. **Ruby Side** (`report_generator.rb`):
   - Correctly calculates explode vectors for each part: `(part_center - parent_center).normalize`
   - Finds the dominant axis (X, Y, or Z) and creates a unit vector in that direction
   - Transforms coordinates for WebGL: `[axis_vector.x, axis_vector.z, -axis_vector.y]`
   - Sends data as: `{ entity_name, views, geometry: { parts: [...] } }`

2. **JavaScript Side** (`main.html`):
   - Receives assembly data and renders each part as a THREE.Group
   - Centers all parts around origin for better camera framing
   - Stores centered position as `originalPosition`
   - On slider move: `newPosition = originalPosition + (explodeVector * percentage * scale)`

## Fixes Applied

### 1. Clarified Explosion Logic

The `updateExplosion` function now clearly documents the transformation:
```javascript
// Calculate the translation: Vector * Percentage * Scale
const vec = group.userData.explodeVector;
const translation = vec.clone().multiplyScalar(percentage * explodeScale);

// Apply: New Position = Original Position + Translation
group.position.copy(group.userData.originalPosition).add(translation);
```

### 2. Added Minimal Debug Logging

Added strategic console.log statements that only fire:
- When slider is at 0% or 100%
- On first explosion attempt
- Shows sample part data to verify vectors are correct

### 3. Ensured Proper Position Storage

The `renderAssembly` function:
1. Creates each part group at (0,0,0)
2. Adds all parts to the scene
3. Calculates the bounding box center
4. Centers all parts by subtracting the center
5. Stores the CENTERED position as `originalPosition`

This ensures the explode vectors work correctly relative to the centered assembly.

## Testing Instructions

1. **Reload the extension** in SketchUp
2. **Create or open a model** with an assembly containing nested components/groups
3. **Generate the cut list** to open the main dialog
4. **Switch to the Configuration tab**
5. **Turn on the 3D viewer** (power button)
6. **The viewer should automatically detect assembly mode** and show the explode slider
7. **Open browser console** (F12 in the dialog) to see debug output
8. **Move the explode slider** and observe:
   - Parts should move INDIVIDUALLY along their explode vectors
   - NOT all parts moving together as one unit
   - Console shows explode vectors and sample part data

## Expected Console Output

When you first move the explode slider, you should see:
```
First part explode vector: [0, 1, 0]  // or similar
Exploding 5 parts to 50%
Sample part: Shelf_1
  Explode vector: Vector3 {x: 0, y: 1, z: 0}
  Original pos: Vector3 {x: -100, y: 50, z: 0}
```

## Troubleshooting

### If all explode vectors are [0, 0, 0]:
The problem is in the Ruby code. Check:
- Are the parts actually nested inside the assembly?
- Are the part centers different from the parent center?
- Is the `extract_component_geometry` method finding the parts?

### If parts still move together:
Check the console output:
- Do all parts have the SAME `originalPosition`? → Problem in centering logic
- Do all parts have the SAME `explodeVector`? → Problem in Ruby vector calculation
- Are there actually multiple groups in `assemblyMeshes`? → Problem in rendering

### If parts move in wrong directions:
The coordinate transformation might need adjustment:
- Current: `[axis_vector.x, axis_vector.z, -axis_vector.y]`
- This swaps Y and Z for WebGL coordinate system
- May need to adjust based on your SketchUp model orientation

## Code Changes Summary

**File: `Extension/AutoNestCut/ui/html/main.html`**

1. **Line ~1800**: Added debug logging for first part's explode vector
2. **Line ~1854**: Simplified and documented the `updateExplosion` function
3. **Line ~1820**: Added comment clarifying that `originalPosition` will be updated after centering

## Next Steps

Once confirmed working:
1. Test with various assembly configurations (vertical, horizontal, complex nesting)
2. Adjust `explodeScale` value (currently 500) if explosion distance is too much/little
3. Consider adding UI control for explosion scale
4. Remove debug logging for production build

## Related Files

- `Extension/AutoNestCut/exporters/report_generator.rb` - Generates explode vectors
- `Extension/AutoNestCut/ui/html/main.html` - Renders and explodes assembly
- `EXPLODE_ASSEMBLY.rb` - Standalone working example for reference
