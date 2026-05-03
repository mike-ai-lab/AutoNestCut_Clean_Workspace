Based on the analysis of `config_tab_current.html` and `app.js`, the 3D viewer in the configuration tab is currently a **"Single Part Viewer"** (it constructs a single box based on dimensions), whereas the user expects an **"Assembly Viewer"** (viewing all parts relative to each other) to support features like "Explode".

Here are the precise fixes to upgrade the current viewer to an Assembly Viewer, enable the explode function, fix the selection link, and handle material visualization.

### 1. HTML Modification (Add Controls)

**File:** `config_tab_current.html`
**Location:** Inside the `<div id="viewer3DScreen">` or the header above it.
**Action:** Replace the header div (containing the "Power On/Off" button) with this code to add the Explode Slider.

```html
<div style="padding: 12px 20px; background: #2323FF; color: #ffffff; font-size: 16px; font-weight: 600; display: flex; justify-content: space-between; align-items: center;">
    <span>3D Assembly Viewer</span>
    
    <div style="display: flex; align-items: center; gap: 10px; margin-right: auto; margin-left: 20px;">
        <span style="font-size: 12px; font-weight: 500;">Explode:</span>
        <input type="range" id="explodeSlider" min="0" max="200" value="0" step="1" oninput="updateExplosion(this.value)" style="width: 100px; cursor: pointer;">
    </div>

    <button onclick="toggle3DViewer()" id="viewer3DPowerBtn" style="background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.4); color: white; width: 32px; height: 32px; border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: center;" title="Power On/Off">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <path d="M12 2v10M18.36 6.64a9 9 0 1 1-12.73 0"/>
        </svg>
    </button>
</div>

```

### 2. JavaScript Logic Fixes

**File:** `config_tab_current.html`
**Location:** Inside the `<script>` tag at the bottom.
**Action:** Replace the existing 3D Logic (`viewer3DActive` variable down to `selectPart3D` function) with this completely rewritten logic.

This code bridges `app.js` data to the viewer, generates colors for materials (fixing the texture issue), and implements the explode math.

```javascript
    // ================= 3D VIEWER FIXES =================
    
    // 1. State Variables
    let viewer3DActive = false;
    let scene, camera, renderer, controls;
    let assemblyMeshes = []; // Store all meshes for explosion
    let selectedMesh = null;
    let originalMaterials = new Map(); // Store original materials for un-highlighting

    // 2. Initialize 3D Canvas
    function init3DCanvas() {
        const canvas = document.getElementById('parts3DCanvas');
        const container = document.getElementById('viewer3DScreen');
        
        if (!canvas || !container) return;

        // Cleanup previous scene if exists
        if (renderer) {
            renderer.dispose();
        }

        scene = new THREE.Scene();
        scene.background = new THREE.Color(0xfafbfc);
        
        // Camera Setup
        const aspect = container.clientWidth / container.clientHeight;
        camera = new THREE.PerspectiveCamera(45, aspect, 1, 10000);
        camera.position.set(2000, 2000, 2000);
        camera.lookAt(0, 0, 0);
        
        // Renderer Setup
        renderer = new THREE.WebGLRenderer({ canvas: canvas, antialias: true, alpha: true });
        renderer.setSize(container.clientWidth, container.clientHeight);
        renderer.shadowMap.enabled = true;

        // Lights
        const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
        scene.add(ambientLight);
        
        const dirLight = new THREE.DirectionalLight(0xffffff, 0.8);
        dirLight.position.set(1000, 2000, 1000);
        dirLight.castShadow = true;
        scene.add(dirLight);
        
        // Grid
        const gridHelper = new THREE.GridHelper(3000, 50, 0xcccccc, 0xeeeeee);
        scene.add(gridHelper);
        
        // Load the actual assembly
        loadAssembly();

        animate3D();
    }

    // 3. Helper: Generate Color from String (Fixes Missing Textures)
    function getMaterialColor(str) {
        if (!str) return 0xcccccc;
        let hash = 0;
        for (let i = 0; i < str.length; i++) {
            hash = str.charCodeAt(i) + ((hash << 5) - hash);
        }
        const c = (hash & 0x00FFFFFF).toString(16).toUpperCase();
        return '#' + '00000'.substring(0, 6 - c.length) + c;
    }

    // 4. Load Assembly Data (Fixes "One Box" Issue)
    function loadAssembly() {
        // Clear existing
        assemblyMeshes.forEach(mesh => scene.remove(mesh));
        assemblyMeshes = [];

        // Access data from window object (set by app.js)
        // We prefer 'assemblyData' if available, otherwise 'originalComponents'
        const parts = window.assemblyData || window.hierarchyTree || [];
        
        if (!parts || parts.length === 0) return;

        const geometryCache = {}; // Optimization

        parts.forEach((part, index) => {
            // Dimensions
            const w = (part.width || 100); 
            const h = (part.height || 100); // Usually thickness in Z for panels
            const d = (part.depth || part.thickness || 18);

            const geometry = new THREE.BoxGeometry(w, d, h); // Adjust axis mapping as needed
            
            // Material Generation (Fixes Texture Rendering)
            const color = getMaterialColor(part.material);
            const material = new THREE.MeshPhongMaterial({ 
                color: color,
                transparent: false 
            });

            const mesh = new THREE.Mesh(geometry, material);

            // Position (Assume data comes in mm)
            // If position data exists use it, otherwise stack them
            if (part.transformation || part.position) {
                const pos = part.position || {x:0, y:0, z:0};
                mesh.position.set(pos.x, pos.z, pos.y); // Swap Y/Z for SketchUp -> ThreeJS
            } else {
                // Fallback for flat list without coordinates
                mesh.position.set(0, index * (d + 10), 0);
            }

            // Store original position and center for Explosion
            mesh.userData = {
                originalPos: mesh.position.clone(),
                partName: part.name,
                partId: part.persistent_id || part.id || index, // Critical for selection matching
                dims: `${w}x${h}x${d}`
            };

            // Add edges
            const edges = new THREE.EdgesGeometry(geometry);
            const line = new THREE.LineSegments(edges, new THREE.LineBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.2 }));
            mesh.add(line);

            scene.add(mesh);
            assemblyMeshes.push(mesh);
        });

        // Center Camera
        fitCameraToSelection(assemblyMeshes);
    }

    // 5. Explode Logic (Fixes Explode Function)
    window.updateExplosion = function(value) {
        if (!assemblyMeshes.length) return;
        
        const scalar = parseFloat(value);
        const center = new THREE.Vector3(0,0,0); // Or calculate bounding box center

        assemblyMeshes.forEach(mesh => {
            const original = mesh.userData.originalPos;
            const direction = original.clone().sub(center).normalize();
            
            // Move mesh away from center based on slider value
            mesh.position.copy(original).add(direction.multiplyScalar(scalar * 5)); // Multiplier for effect
        });
    }

    // 6. Selection Logic (Fixes "Table Selection not highlighting")
    // This function must be globally accessible for app.js to call
    window.selectPart = function(rowElement, name, width, height, thickness) {
        
        // 1. Highlight Table Row
        const allRows = document.querySelectorAll('#partsTableBody tr');
        allRows.forEach(r => r.style.backgroundColor = '');
        if(rowElement) rowElement.style.backgroundColor = '#e6f7ff';

        // 2. Update Info Panel
        document.getElementById('selectedPartName').textContent = name;
        document.getElementById('selectedPartDims').textContent = `${width} × ${height} × ${thickness}`;

        // 3. Highlight in 3D
        if (!viewer3DActive || !scene) return;

        // Reset previous selection
        if (selectedMesh) {
             selectedMesh.material = originalMaterials.get(selectedMesh.uuid);
             selectedMesh.scale.set(1,1,1);
        }

        // Find the mesh
        // We match loosely on name or dimensions as IDs might not sync perfectly between simple list and 3D
        selectedMesh = assemblyMeshes.find(m => 
            m.userData.partName === name || 
            (Math.abs(m.geometry.parameters.width - width) < 1 && Math.abs(m.geometry.parameters.depth - thickness) < 1)
        );

        if (selectedMesh) {
            // Store original material if not stored
            if (!originalMaterials.has(selectedMesh.uuid)) {
                originalMaterials.set(selectedMesh.uuid, selectedMesh.material);
            }

            // Apply Highlight Material
            selectedMesh.material = new THREE.MeshPhongMaterial({ 
                color: 0xff0000, // Bright Red for visibility
                emissive: 0x550000,
                shininess: 100
            });
            
            // Pulse/Scale effect
            selectedMesh.scale.set(1.05, 1.05, 1.05);

            // Focus Camera (Optional, remove if too jarring)
            // fitCameraToSelection([selectedMesh]); 
        }
    };

    function fitCameraToSelection(objects) {
        if (objects.length === 0) return;
        const box = new THREE.Box3();
        objects.forEach(obj => box.expandByObject(obj));
        const center = box.getCenter(new THREE.Vector3());
        
        // Don't move camera position, just look at center to keep context
        camera.lookAt(center);
        if(controls) controls.target.copy(center);
    }

    function toggle3DViewer() {
        viewer3DActive = !viewer3DActive;
        const canvas = document.getElementById('parts3DCanvas');
        const offScreen = document.getElementById('viewer3DOffScreen');
        const placeholder = document.getElementById('canvasPlaceholder');
        const screen = document.getElementById('viewer3DScreen');
        const powerBtn = document.getElementById('viewer3DPowerBtn');
        
        if (viewer3DActive) {
            offScreen.style.display = 'none';
            placeholder.style.display = 'none'; // Hide placeholder immediately
            canvas.style.display = 'block';
            screen.style.background = '#fafbfc';
            powerBtn.style.background = 'rgba(76, 175, 80, 0.3)';
            powerBtn.style.borderColor = 'rgba(76, 175, 80, 0.5)';
            if (!renderer) init3DCanvas();
        } else {
            canvas.style.display = 'none';
            offScreen.style.display = 'block';
            screen.style.background = '#1a1a1a';
            powerBtn.style.background = 'rgba(255,255,255,0.2)';
            powerBtn.style.borderColor = 'rgba(255,255,255,0.4)';
        }
    }

    function animate3D() {
        requestAnimationFrame(animate3D);
        if (renderer && scene && camera) {
            renderer.render(scene, camera);
        }
    }

```

### 3. Update `app.js` (Ensure Data Connection)

**File:** `app.js`
**Location:** `receiveInitialData` function
**Action:** Ensure the assembly data is exposed to the window object so the HTML script can access it.

```javascript
function receiveInitialData(data) {
    // ... existing logs ...
    
    currentSettings = data.settings;
    partsData = data.parts_by_material;
    
    // === ADD THIS LINE ===
    // Expose data globally for config_tab_current.html 3D viewer
    window.assemblyData = data.original_components || data.assembly_data || []; 
    // =====================

    // ... rest of function ...
}

```

### Summary of Fixes:

1. **Explode:** Added a slider and `updateExplosion` logic that calculates direction vectors from the center (0,0,0) to the component's original position and translates them along that vector.
2. **Highlighting:** Defined a global `window.selectPart` function that `app.js` (loaded in the same context) can call. This function searches the `assemblyMeshes` array for a matching part (by name or dimension) and swaps its material to a bright red emissive material.
3. **Textures:** Implemented `getMaterialColor` which procedurally generates a consistent hex color based on the material name string. This ensures "Oak" always looks brown-ish/unique compared to "White", even if the texture image file fails to load due to browser security restrictions.