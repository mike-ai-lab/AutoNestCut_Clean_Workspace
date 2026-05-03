# Configuration Tab 3D Viewer - Individual Part Highlighting Fix + Bidirectional Selection

## Problem 1: Grouped Highlighting
When clicking on parts in the Configuration tab's Parts Preview table, the 3D viewer was highlighting ALL instances of identical parts (e.g., all 4 doors) instead of highlighting each instance individually.

**Example Issue:**
- User has 4 identical doors in the assembly
- Parts Preview table showed 1 row with "Quantity: 4"
- Clicking that row highlighted ALL 4 doors in the 3D viewer
- User wanted to click each instance separately to highlight them individually

## Problem 2: No Reverse Selection
- Clicking on a 3D component in the viewer did nothing
- No way to select parts from the 3D viewer
- Cursor showed hand icon (orbit control) instead of pointer
- No bidirectional interaction between table and 3D viewer

## Root Cause

### Problem 1:
The Parts Preview table was displaying **grouped/aggregated** parts (one row per unique part type with a quantity column), but the 3D viewer contains **individual instances** (4 separate meshes for 4 doors).

When clicking a grouped row, the `selectPart` function would:
1. Receive a `partIndex` that didn't match the 3D mesh array
2. Fall back to NAME-based matching
3. Highlight ALL meshes with the same name (all 4 doors)

### Problem 2:
- No click event handler on the 3D canvas
- No raycaster for detecting clicks on 3D objects
- Orbit controls were using LEFT mouse button (blocking selection)

## Solution

### Part 1: Individual Table Rows
Modified the `displayPartsPreview()` function in `Extension/AutoNestCut/ui/html/app.js` to create **individual rows for each instance** instead of grouped rows.

**Before:**
```javascript
parts.forEach(part => {
    const displayName = part.name || 'Unnamed';
    const tr = document.createElement('tr');
    tr.onclick = function() {
        selectPart(this, displayName, part.width, part.height, part.thickness, globalPartIndex);
    };
    // ... create ONE row with quantity column
    globalPartIndex++;  // Only increments once per unique part
});
```

**After:**
```javascript
parts.forEach(part => {
    const displayName = part.name || 'Unnamed';
    const quantity = part.total_quantity || part.quantity || 1;
    
    // Create individual rows for each instance
    for (let instanceNum = 0; instanceNum < quantity; instanceNum++) {
        const tr = document.createElement('tr');
        const currentIndex = globalPartIndex;
        tr.onclick = function() {
            selectPart(this, displayName, part.width, part.height, part.thickness, currentIndex);
        };
        
        // Show instance number if multiple instances
        const instanceLabel = quantity > 1 ? ` #${instanceNum + 1}` : '';
        
        // ... create row with instance label and quantity=1
        globalPartIndex++;  // Increments for EACH instance
    }
});
```

### Part 2: Bidirectional Selection
Added click detection and reverse selection in `Extension/AutoNestCut/ui/html/main.html`:

**A. Initialize Raycaster:**
```javascript
let raycaster = null;
let mouse = new THREE.Vector2();

function init3DCanvas() {
    // ... existing setup ...
    
    // Initialize raycaster for click detection
    raycaster = new THREE.Raycaster();
    
    // Disable LEFT mouse for orbit (use for selection instead)
    orbitControls.mouseButtons = {
        LEFT: null,  // Disabled for selection
        MIDDLE: THREE.MOUSE.ROTATE,
        RIGHT: THREE.MOUSE.PAN
    };
    
    // Add click event listener
    canvas.addEventListener('click', on3DViewerClick, false);
    
    // Add hover effect
    canvas.addEventListener('mousemove', on3DViewerMouseMove, false);
    
    // Set cursor to pointer
    canvas.style.cursor = 'pointer';
}
```

**B. Handle 3D Viewer Clicks:**
```javascript
function on3DViewerClick(event) {
    if (!isAssemblyMode || assemblyMeshes.length === 0) return;
    
    // Calculate mouse position in normalized device coordinates
    const rect = canvas.getBoundingClientRect();
    mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
    
    // Update raycaster
    raycaster.setFromCamera(mouse, canvas3DCamera);
    
    // Get all meshes from assembly groups
    const meshes = assemblyMeshes.map(group => group.children[0]).filter(m => m);
    const intersects = raycaster.intersectObjects(meshes, false);
    
    if (intersects.length > 0) {
        // Find which group this mesh belongs to
        const clickedMesh = intersects[0].object;
        let clickedIndex = -1;
        
        for (let i = 0; i < assemblyMeshes.length; i++) {
            if (assemblyMeshes[i].children[0] === clickedMesh) {
                clickedIndex = i;
                break;
            }
        }
        
        if (clickedIndex >= 0) {
            // Highlight in 3D viewer
            highlightPartIn3DViewer(clickedIndex);
            
            // Highlight in table
            highlightPartInTable(clickedIndex);
            
            // Update info panel
            updateInfoPanel(clickedIndex);
        }
    }
}
```

**C. Highlight Part in Table:**
```javascript
function highlightPartInTable(partIndex) {
    const tbody = document.getElementById('partsTableBody');
    const rows = tbody.querySelectorAll('tr');
    
    // Remove highlight from all rows
    rows.forEach(row => row.classList.remove('selected'));
    
    // Highlight the corresponding row
    if (partIndex >= 0 && partIndex < rows.length) {
        const targetRow = rows[partIndex];
        targetRow.classList.add('selected');
        
        // Scroll into view
        targetRow.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
}
```

**D. Mouse Hover Effect:**
```javascript
function on3DViewerMouseMove(event) {
    // ... calculate mouse position ...
    
    raycaster.setFromCamera(mouse, canvas3DCamera);
    const meshes = assemblyMeshes.map(group => group.children[0]).filter(m => m);
    const intersects = raycaster.intersectObjects(meshes, false);
    
    // Change cursor based on hover
    if (intersects.length > 0) {
        canvas.style.cursor = 'pointer';
    } else {
        canvas.style.cursor = 'default';
    }
}
```

## How It Works Now

### Table Display:
```
Component Name    | Width | Height | Thickness | Material | Qty | Area
Door #1          | 578   | 798    | 18        | Material | 1   | 0.46  ← Selected (blue highlight)
Door #2          | 578   | 798    | 18        | Material | 1   | 0.46
Door #3          | 578   | 798    | 18        | Material | 1   | 0.46
Door #4          | 578   | 798    | 18        | Material | 1   | 0.46
```

### Visual Highlighting:
When a row is selected (either by clicking the row or clicking the 3D component):
- **Background**: Light blue (#dbeafe)
- **Left Border**: 4px solid blue (#3b82f6)
- **Box Shadow**: Blue inset border for emphasis
- **Text**: Bold, dark blue color (#1e40af)
- **Animation**: Smooth pulse effect on selection (0.6s)
- **Transform**: Subtle scale animation for visual feedback

### Bidirectional Selection:

**Table → 3D Viewer:**
1. User clicks "Door #3" row (index 2)
2. `selectPart()` is called with `partIndex = 2`
3. INDEX-based matching finds `assemblyMeshes[2]`
4. Only the 3rd door is highlighted in the 3D viewer ✅

**3D Viewer → Table:**
1. User clicks on a door in the 3D viewer
2. Raycaster detects the clicked mesh
3. System finds the mesh index in `assemblyMeshes` array
4. `highlightPartInTable()` highlights the corresponding row
5. Row scrolls into view automatically ✅

### Cursor Behavior:
- **Default**: Pointer cursor (not hand)
- **Hovering over part**: Pointer cursor
- **Hovering over empty space**: Default cursor
- **Middle mouse**: Rotate camera (orbit)
- **Right mouse**: Pan camera
- **Left mouse**: Select parts (no longer used for orbit)

## Benefits

1. **Individual Selection**: Each instance can be selected separately
2. **Bidirectional**: Click in table OR 3D viewer
3. **Clear Identification**: Instance numbers (#1, #2, #3, #4)
4. **Consistent Mapping**: Table row index = 3D mesh index
5. **Visual Feedback**: Cursor changes on hover
6. **Auto-scroll**: Table scrolls to show selected row
7. **No Ambiguity**: No more "highlight all instances"

## Testing

Test with 4 identical doors:

**Table → 3D:**
- ✅ Click "Door #1" row → Highlights only 1st door in 3D
- ✅ Click "Door #2" row → Highlights only 2nd door in 3D
- ✅ Click "Door #3" row → Highlights only 3rd door in 3D
- ✅ Click "Door #4" row → Highlights only 4th door in 3D

**3D → Table:**
- ✅ Click 1st door in 3D → Highlights "Door #1" row, scrolls into view
- ✅ Click 2nd door in 3D → Highlights "Door #2" row, scrolls into view
- ✅ Click 3rd door in 3D → Highlights "Door #3" row, scrolls into view
- ✅ Click 4th door in 3D → Highlights "Door #4" row, scrolls into view

**Cursor:**
- ✅ Pointer cursor when hovering over parts
- ✅ Default cursor when hovering over empty space
- ✅ No hand cursor (orbit control disabled on left click)

## Files Modified

1. `Extension/AutoNestCut/ui/html/app.js` - Modified `displayPartsPreview()` function
2. `Extension/AutoNestCut/ui/html/main.html` - Added:
   - Raycaster initialization
   - Click event handler (`on3DViewerClick`)
   - Mouse move handler (`on3DViewerMouseMove`)
   - `highlightPartIn3DViewer()` function
   - `highlightPartInTable()` function
   - Cursor style changes
   - **CSS styling for `.selected` class with blue highlight and animation**

## Status

✅ **COMPLETE** - The Configuration tab now has full bidirectional selection between the Parts Preview table and the 3D viewer, with individual part highlighting and proper cursor behavior.

