# 3D Viewer Developer Guide

## File Location
`Extension/AutoNestCut/ui/html/main.html` (lines ~600-1100)

## Core Architecture

### Global Variables
```javascript
let canvas3DScene, canvas3DCamera, canvas3DRenderer, canvas3DCurrentMesh;
let viewer3DActive = false;           // Power on/off state
let allComponentsData = [];           // Array of all components
let currentComponentIndex = -1;       // Currently displayed component
let dimensionsVisible = false;        // Dimension lines visibility
let dimensionGroup = null;            // THREE.Group for dimension lines
let rotationEnabled = true;           // Auto-rotation toggle
let gridHelper = null;                // Grid helper object
let orbitControls = null;             // OrbitControls instance
```

## Key Functions

### Power Control
**`toggle3DViewer()`**
- Toggles `viewer3DActive` flag
- Shows/hides canvas and placeholder screens
- Initializes renderer if first time
- Calls `init3DCanvas()` and `animate3DCanvas()`

### Initialization
**`init3DCanvas()`**
- Creates THREE.Scene with background color `0xfafbfc`
- Sets up PerspectiveCamera (FOV: 45°)
- Creates WebGLRenderer with antialias and **`preserveDrawingBuffer: true`** (required for snapshots)
- Adds lights: AmbientLight (0.6) + DirectionalLight (0.8)
- Creates GridHelper (2000 units, 20 divisions)
- Initializes OrbitControls with middle-mouse rotate, right-mouse pan

### Component Display
**`selectPart(row, name, width, height, thickness)`**
- Called when user clicks table row
- Updates `currentComponentIndex`
- Removes old mesh, creates new BoxGeometry
- Resets camera: `position.set(maxDim * 1.5, maxDim * 1.2, maxDim * 1.5)`
- Resets orbit target: `orbitControls.target.set(0, 0, 0)`
- Adds wireframe edges with LineBasicMaterial

**`switchToNextComponent()`**
- Called by NEXT button
- Cycles through `allComponentsData` array
- Syncs table row selection with `selected` class
- Scrolls table row into view smoothly
- Resets camera and orbit controls

### Snapshot Feature
**`capture3DSnapshot()`**
- Captures current 3D view as PNG image
- Renders final frame before capture to ensure clean image
- Uses `canvas.toDataURL('image/png', 1.0)` for maximum quality
- Extracts material name from table row
- Formats filename: `Name--WxHxTH--Material--Q1--Asqm.png`
- Sends to Ruby backend via `callRuby('save_3d_snapshot', ...)`
- Automatically saves to Documents folder

**`showSnapshotSuccess(filepath)`**
- Called by Ruby after successful save
- Changes SNAP button to checkmark (✓) for 1 second with green background
- Shows toast message above viewer: "Snap Saved Successfully To (path)"
- Toast fades in/out smoothly over 2.3 seconds
- No user interaction required

### Dimension System
**`toggleDimensions()`**
- Toggles `dimensionsVisible` flag
- Creates/removes `dimensionGroup` (THREE.Group)
- Calls `createDimension()` for width, height, thickness

**`createDimension(start, end, offsetVec, text)`**
- Returns THREE.Group containing:
  - Dimension line (LineBasicMaterial, linewidth: 2)
  - Witness lines (opacity: 0.7)
  - Arrow cones at endpoints
  - Text sprite from `createTextSprite()`

**`createTextSprite(message, color)`**
- Creates canvas with text rendering
- **Font size**: `90px` (adjust here for text size)
- **Sprite scale**: `20` (adjust here for overall scale)
- Returns THREE.Sprite with CanvasTexture

### Animation Loop
**`animate3DCanvas()`**
- Runs via `requestAnimationFrame()`
- Updates `orbitControls`
- Auto-rotates mesh if `rotationEnabled` is true
- Renders scene with `canvas3DRenderer.render()`

## Customization Points

### Dimension Text Size
**Location**: `createTextSprite()` function
```javascript
const fontSize = 90;  // Change this value
sprite.scale.set((canvas.width / fontSize) * 20, 20, 1);  // Change scale multiplier
```

### Dimension Offset Distance
**Location**: `toggleDimensions()` function
```javascript
const offset = Math.max(w, h, t) * 0.1;  // Change multiplier (0.1 = 10%)
```

### Arrow Size
**Location**: `createDimension()` function
```javascript
const arrowSize = Math.max(5, offsetVec.length() * 0.12);  // Change multiplier
```

### Dimension Line Appearance
**Location**: `createDimension()` function
```javascript
const lineMat = new THREE.LineBasicMaterial({ 
    color: 0x2563eb,    // Line color
    linewidth: 2        // Line thickness
});
const witnessMat = new THREE.LineBasicMaterial({ 
    color: 0x2563eb, 
    opacity: 0.7,       // Witness line opacity
    transparent: true, 
    linewidth: 2 
});
```

### Camera Position
**Location**: `selectPart()` and `switchToNextComponent()`
```javascript
const maxDim = Math.max(width, height, thickness);
canvas3DCamera.position.set(
    maxDim * 1.5,  // X distance multiplier
    maxDim * 1.2,  // Y distance multiplier
    maxDim * 1.5   // Z distance multiplier
);
```

### Component Color
**Location**: `selectPart()` and `switchToNextComponent()`
```javascript
const material = new THREE.MeshPhongMaterial({ 
    color: 0x2323FF,      // Component color (blue)
    transparent: true, 
    opacity: 0.8          // Component opacity
});
```

### Grid Settings
**Location**: `init3DCanvas()` function
```javascript
gridHelper = new THREE.GridHelper(
    2000,  // Grid size
    20,    // Number of divisions
    0xcccccc,  // Center line color
    0xeeeeee   // Grid line color
);
```

### Snapshot Feedback
**Location**: `showSnapshotSuccess()` function
```javascript
// Button feedback duration
setTimeout(() => { /* restore button */ }, 1000);  // 1 second

// Toast display timing
setTimeout(() => { toast.style.opacity = '1'; }, 10);     // Fade in
setTimeout(() => { toast.style.opacity = '0'; }, 2000);   // Start fade out
setTimeout(() => { toast.remove(); }, 2300);              // Remove from DOM

// Toast styling
toast.style.cssText = 'background: rgba(76, 175, 80, 0.95); ...'  // Green success color
```

## UI Controls

### HTML Elements
- **Canvas**: `#parts3DCanvas`
- **Power Button**: `#viewer3DPowerBtn`
- **Placeholder**: `#canvasPlaceholder`
- **Off Screen**: `#viewer3DOffScreen`
- **Viewer Screen**: `#viewer3DScreen` (container for toast messages)
- **Info Display**: `#selectedPartName`, `#selectedPartDims`, `#selectedPartVolume`

### Control Buttons
- **DIMS**: Calls `toggleDimensions()`
- **SPIN**: Calls `toggleRotation()`
- **GRID**: Calls `toggleGrid()`
- **NEXT**: Calls `switchToNextComponent()`
- **SNAP**: Calls `capture3DSnapshot()` - saves PNG to Documents folder
- **Power**: Calls `toggle3DViewer()`

## Data Flow

1. **Component data** populated in `populateComponentsArray()` from `#partsTableBody`
2. **User clicks row** → `selectPart()` → Updates mesh and camera
3. **User clicks NEXT** → `switchToNextComponent()` → Cycles index, updates table selection
4. **User clicks SNAP** → `capture3DSnapshot()` → Sends to Ruby → `showSnapshotSuccess()` → Visual feedback
5. **Dimensions toggled** → `toggleDimensions()` → Creates/removes dimension group
6. **Animation loop** → `animate3DCanvas()` → Renders continuously when active

## Ruby Backend Integration

### Snapshot Callback
**Location**: `dialog_manager.rb`
```ruby
@dialog.add_action_callback("save_3d_snapshot") do |action_context, data_json|
  # Decodes base64 image data
  # Saves to Documents folder with formatted filename
  # Calls showSnapshotSuccess(filepath) on success
end
```

**Filename Format**: `Name--WxHxTH--Material--Q1--Asqm.png`
- Name: Component name (sanitized)
- W/H/TH: Width/Height/Thickness in mm
- Material: Material name from table (sanitized)
- Q: Quantity (always 1 for individual snapshots)
- A: Area in square meters (4 decimal places)

## Common Modifications

### Make text larger
Change `fontSize` and `scale` in `createTextSprite()`

### Move dimensions closer/farther
Change `offset` multiplier in `toggleDimensions()`

### Change arrow size
Change `arrowSize` multiplier in `createDimension()`

### Reset camera on selection
Ensure `orbitControls.target.set(0, 0, 0)` is called after camera position change

### Sync table selection
Add/remove `selected` class on table rows, use `scrollIntoView()` for visibility

### Fix snapshot corruption
Ensure `preserveDrawingBuffer: true` in WebGLRenderer options

### Customize snapshot feedback
Modify timings and colors in `showSnapshotSuccess()`

## Dependencies
- **Three.js**: r128 (CDN loaded)
- **OrbitControls**: Three.js examples addon
- **Canvas API**: For text sprite rendering and image capture
- **Base64 encoding**: For image data transfer to Ruby backend
