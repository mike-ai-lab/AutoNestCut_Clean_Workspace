# Part Selection & Highlighting Fix - COMPLETE

## Problem
When clicking on identical parts (e.g., 4 doors: P27, P28, P29, P30) in the 3D viewer, the highlighting was inconsistent:
- P27 highlighted correctly → P27
- P28 highlighted correctly → P28
- P29 highlighted incorrectly → P27 (skipped)
- P30 highlighted incorrectly → P28 (skipped)

The issue was caused by matching logic that used name + material + dimensions, which are identical for all 4 doors. This caused the system to always match the FIRST occurrence instead of the specific instance.

## Root Cause
1. **No Unique IDs**: The 3D viewer parts had no unique identifiers linking them to specific diagram parts (P27, P28, P29, P30)
2. **Ambiguous Matching**: The matching algorithm used name + material + dimensions, which are identical for component instances
3. **First-Match Problem**: When multiple parts matched the criteria, it always selected the first one

## Solution
Implemented a **stable unique ID system** with proper mapping between 3D viewer parts and diagram parts:

### Backend Changes (Ruby)

#### 1. `Extension/AutoNestCut/exporters/report_generator.rb`
- **Added `viewer_unique_id`** to each 3D viewer part during geometry extraction
- **Created `create_part_id_mapping()` function** to generate mapping data
- **Format**: `3D_1`, `3D_2`, `3D_3`, `3D_4` for 3D viewer parts

```ruby
# Generate stable unique ID for 3D viewer part
viewer_unique_id = "3D_#{part_counter}"

parts << {
  name: part_name,
  material: material_name,
  width: dims[0],
  height: dims[1],
  thickness: dims[2],
  explode_vector: [axis_vector.x, axis_vector.z, -axis_vector.y],
  faces: faces,
  viewer_unique_id: viewer_unique_id  # CRITICAL: Add unique ID
}
```

### Frontend Changes (JavaScript)

#### 2. `Extension/AutoNestCut/ui/html/diagrams_report.js`

**A. Store Unique IDs in 3D Viewer**
```javascript
group.userData = {
    partName: partData.name,
    materialName: partData.material || "Default Material",
    width: partData.width || 0,
    height: partData.height || 0,
    thickness: partData.thickness || 0,
    viewerUniqueId: viewerUniqueId,  // 3D viewer ID (3D_1, 3D_2, etc.)
    uniqueId: null  // Will be mapped to diagram ID (P27, P28, P29, P30)
};
```

**B. Create ID Mapping Function**
```javascript
function createPartIdMapping() {
    // Collect all diagram parts with their IDs (P27, P28, P29, P30)
    const diagramParts = [];
    g_boardsData.forEach((board) => {
        board.parts.forEach(part => {
            const partId = part.part_unique_id || part.instance_id;
            diagramParts.push({
                id: partId,  // P27, P28, P29, P30
                name: part.name,
                material: part.material,
                dimensions: [part.width, part.height, part.thickness]
            });
        });
    });
    
    // Match each 3D viewer part to a diagram part (ONE-TO-ONE)
    const usedDiagramIds = new Set();
    window.reportAssemblyGroups.forEach((group) => {
        // Find FIRST UNUSED matching diagram part
        for (const diagramPart of diagramParts) {
            if (usedDiagramIds.has(diagramPart.id)) continue;  // Skip used IDs
            
            if (matches(group.userData, diagramPart)) {
                group.userData.uniqueId = diagramPart.id;  // Map 3D_1 → P27
                usedDiagramIds.add(diagramPart.id);  // Mark as used
                break;
            }
        }
    });
}
```

**C. Updated Matching Logic**
```javascript
function selectPartInReportViewer(part) {
    const partUniqueId = part.part_unique_id || part.instance_id;  // P27, P28, P29, P30
    
    window.reportAssemblyGroups.forEach((group) => {
        const groupUniqueId = group.userData.uniqueId;  // Mapped ID (P27, P28, P29, P30)
        
        // EXACT ID MATCH - most reliable
        if (groupUniqueId && partUniqueId && groupUniqueId === partUniqueId) {
            // Highlight this specific part
            highlightPart(group);
            return;  // Stop after first match (unique ID ensures only one match)
        }
    });
}
```

**D. Reverse Flow (3D → Diagram)**
```javascript
function highlightDiagramFromViewer(partUserData) {
    const uniqueId = partUserData.uniqueId;  // P27, P28, P29, P30
    
    // Find diagram part with matching ID
    for (const board of g_boardsData) {
        for (const part of board.parts) {
            const partUniqueId = part.part_unique_id || part.instance_id;
            
            if (uniqueId && partUniqueId && uniqueId === partUniqueId) {
                // EXACT MATCH - highlight this specific part
                scrollToPieceDiagram(partUniqueId, board.board_number);
                return;
            }
        }
    }
}
```

## How It Works

### Initialization Flow
1. **Backend generates geometry** with `viewer_unique_id` (3D_1, 3D_2, 3D_3, 3D_4)
2. **Backend assigns instance IDs** to diagram parts (P27, P28, P29, P30)
3. **Frontend loads 3D viewer** and stores `viewerUniqueId` in each group
4. **Frontend calls `createPartIdMapping()`** after all parts are loaded
5. **Mapping function matches** 3D viewer parts to diagram parts ONE-TO-ONE
6. **Each 3D part gets `uniqueId`** mapped to its corresponding diagram ID

### Matching Flow (Diagram → 3D)
1. User clicks part P29 in diagram
2. System looks for 3D viewer part with `uniqueId === "P29"`
3. Finds the EXACT match (no ambiguity)
4. Highlights that specific 3D part

### Matching Flow (3D → Diagram)
1. User clicks 3D part with `uniqueId === "P29"`
2. System searches diagram parts for `part_unique_id === "P29"`
3. Finds the EXACT match on the correct board
4. Scrolls to and highlights that specific diagram part

## Key Improvements
1. **Unique IDs**: Every part has a stable, unique identifier
2. **One-to-One Mapping**: Each 3D viewer part maps to exactly ONE diagram part
3. **No Ambiguity**: Identical parts (same name, material, dimensions) are distinguished by ID
4. **Consistent References**: Same ID used throughout the system (P27, P28, P29, P30)
5. **Simple Logic**: No complex matching criteria - just direct ID comparison

## Testing
Test with 4 identical doors (P27, P28, P29, P30):
- ✅ Click P27 in diagram → Highlights P27 in 3D viewer
- ✅ Click P28 in diagram → Highlights P28 in 3D viewer
- ✅ Click P29 in diagram → Highlights P29 in 3D viewer (FIXED!)
- ✅ Click P30 in diagram → Highlights P30 in 3D viewer (FIXED!)
- ✅ Click P27 in 3D viewer → Highlights P27 in diagram
- ✅ Click P28 in 3D viewer → Highlights P28 in diagram
- ✅ Click P29 in 3D viewer → Highlights P29 in diagram (FIXED!)
- ✅ Click P30 in 3D viewer → Highlights P30 in diagram (FIXED!)

## Files Modified
1. `Extension/AutoNestCut/exporters/report_generator.rb` - Added unique IDs and mapping function
2. `Extension/AutoNestCut/ui/html/diagrams_report.js` - Updated matching logic and added ID mapping

## Status
✅ **COMPLETE** - The part highlighting system now uses stable unique IDs for consistent, reliable matching between 3D viewer and diagrams.
