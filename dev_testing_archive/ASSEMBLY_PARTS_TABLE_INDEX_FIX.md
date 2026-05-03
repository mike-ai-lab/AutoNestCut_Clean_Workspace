# Assembly Parts Table Index Mapping Fix

## Problem
When clicking on a 3D mesh in the assembly viewer, the wrong row is highlighted in the parts table (or no row is highlighted at all).

### Root Cause
- **3D Viewer**: Creates 46 meshes (one for each part instance in the assembly)
- **Parts Table**: Only shows 42 rows (parts are grouped/deduplicated)
- **Index Mismatch**: Clicking mesh index 44 tries to find row index 44, but table only has rows 0-41

## Analysis from Log
```
📊 Total assembly meshes: 46
📊 Total rows in table: 42
❌ NO MATCHING ROW FOUND! Searched for partIndex: 44
```

The assembly has 46 individual part instances, but the parts table was populated from `partsData` which groups parts by material and doesn't fully expand all instances to match the assembly structure.

## Solution Applied

### File Modified
`Extension/AutoNestCut/ui/html/app.js` - Function: `displayPartsPreview()`

### Fix Strategy
1. Check if `window.assemblyData.geometry.parts` exists
2. If yes, populate table directly from assembly parts array (one row per part instance)
3. If no, fall back to original `partsData` logic
4. This ensures table rows map 1:1 with 3D meshes by index

### Key Changes
- Added assembly data check at the beginning of `displayPartsPreview()`
- When assembly data exists, iterate through `assemblyData.geometry.parts` array
- Create one table row for each part with matching index
- Each row's `data-part-index` attribute matches its position in the assembly parts array
- This creates perfect 1:1 correspondence between table rows and 3D meshes

### Result
- Table will now have exactly 46 rows (matching 46 meshes)
- Clicking mesh index 44 will correctly highlight row index 44
- All part highlighting will work correctly in assembly mode

## Testing
1. Load a model with assembly data
2. Open the 3D viewer
3. Click on any part in the 3D viewer
4. Verify the correct row is highlighted in the parts table
5. Check that all 46 parts are listed in the table

## Notes
- The fix maintains backward compatibility with non-assembly mode
- If no assembly data exists, the original logic is used
- The fix is minimal and focused on the root cause
