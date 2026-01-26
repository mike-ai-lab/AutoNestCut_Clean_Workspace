// ===== VERSION INDICATOR =====
console.log('✅ assembly_viewer.js LOADED - v2.0-UPDATED');
console.log('Timestamp:', new Date().toISOString());

// 3D Assembly Viewer - Interactive visualization of complete assembled model
let scene, camera, renderer, controls, assemblyGroup;
let components = [];
let componentMeshes = {};
let selectedComponent = null;
let wireframeMode = false;
let displayMode = 'solid';
let lightingEnabled = true;
let originalComponents = [];

// Material color mapping
const materialColors = {};

function getMaterialColor(material) {
    if (!materialColors[material]) {
        let hash = 0;
        for (let i = 0; i < material.length; i++) {
            hash = material.charCodeAt(i) + ((hash << 5) - hash);
        }
        const hue = Math.abs(hash) % 360;
        const saturation = 45;
        const lightness = 65;
        materialColors[material] = `hsl(${hue}, ${saturation}%, ${lightness}%)`;
    }
    return materialColors[material];
}

function hslToRgb(hslString) {
    const match = hslString.match(/hsl\((\d+),\s*(\d+)%,\s*(\d+)%\)/);
    if (!match) return 0x888888;
    
    let h = parseInt(match[1]) / 360;
    let s = parseInt(match[2]) / 100;
    let l = parseInt(match[3]) / 100;
    
    let r, g, b;
    
    if (s === 0) {
        r = g = b = l;
    } else {
        const hue2rgb = (p, q, t) => {
            if (t < 0) t += 1;
            if (t > 1) t -= 1;
            if (t < 1/6) return p + (q - p) * 6 * t;
            if (t < 1/2) return q;
            if (t < 2/3) return p + (q - p) * (2/3 - t) * 6;
            return p;
        };
        
        const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
        const p = 2 * l - q;
        r = hue2rgb(p, q, h + 1/3);
        g = hue2rgb(p, q, h);
        b = hue2rgb(p, q, h - 1/3);
    }
    
    return (Math.round(r * 255) << 16) + (Math.round(g * 255) << 8) + Math.round(b * 255);
}

function receiveAssemblyData(data) {
    console.log('Received assembly data:', data);
    originalComponents = data.original_components || [];
    
    // Update statistics
    const totalComponentsEl = document.getElementById('totalComponents');
    const totalPartsEl = document.getElementById('totalParts');
    const totalMaterialsEl = document.getElementById('totalMaterials');
    const boundWidthEl = document.getElementById('boundWidth');
    const boundHeightEl = document.getElementById('boundHeight');
    const boundDepthEl = document.getElementById('boundDepth');
    
    if (totalComponentsEl) totalComponentsEl.textContent = originalComponents.length;
    if (totalPartsEl) totalPartsEl.textContent = data.total_parts || originalComponents.length;
    
    if (originalComponents.length > 0) {
        const uniqueMaterials = new Set(originalComponents.map(c => c.material));
        if (totalMaterialsEl) totalMaterialsEl.textContent = uniqueMaterials.size;
        
        // Calculate bounds
        const bounds = calculateAssemblyBounds(originalComponents);
        if (boundWidthEl) boundWidthEl.textContent = bounds.width.toFixed(0) + ' mm';
        if (boundHeightEl) boundHeightEl.textContent = bounds.height.toFixed(0) + ' mm';
        if (boundDepthEl) boundDepthEl.textContent = bounds.depth.toFixed(0) + ' mm';
    }
    
    // Initialize Three.js scene
    try {
        initThreeJS();
        
        // Create assembly from components
        createAssembly(originalComponents);
        
        // Populate component list
        populateComponentList(originalComponents);
        
        // Fit camera to view entire assembly
        fitCameraToAssembly();
        
        // Start animation loop
        animate();
    } catch (error) {
        console.error('Error initializing 3D viewer:', error);
        showErrorMessage('Failed to initialize 3D viewer: ' + error.message);
    }
}

function calculateAssemblyBounds(components) {
    if (components.length === 0) {
        return { width: 1000, height: 1000, depth: 1000 };
    }
    
    let minX = Infinity, maxX = -Infinity;
    let minY = Infinity, maxY = -Infinity;
    let minZ = Infinity, maxZ = -Infinity;
    
    components.forEach(comp => {
        const pos = comp.position || { x: 0, y: 0, z: 0 };
        const w = (comp.width || 100) / 2;
        const h = (comp.height || 100) / 2;
        const d = (comp.depth || 100) / 2;
        
        minX = Math.min(minX, pos.x - w);
        maxX = Math.max(maxX, pos.x + w);
        minY = Math.min(minY, pos.y - h);
        maxY = Math.max(maxY, pos.y + h);
        minZ = Math.min(minZ, pos.z - d);
        maxZ = Math.max(maxZ, pos.z + d);
    });
    
    return {
        width: Math.max(maxX - minX, 100),
        height: Math.max(maxY - minY, 100),
        depth: Math.max(maxZ - minZ, 100)
    };
}

function initThreeJS() {
    const canvas = document.getElementById('canvas');
    if (!canvas) {
        throw new Error('Canvas element not found');
    }
    
    // Scene setup
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0x1a1a1a);
    scene.fog = new THREE.Fog(0x1a1a1a, 5000, 10000);
    
    // Camera setup
    const width = canvas.clientWidth;
    const height = canvas.clientHeight;
    
    camera = new THREE.PerspectiveCamera(75, width / height, 0.1, 10000);
    camera.position.set(500, 500, 500);
    
    // Renderer setup - with error handling
    try {
        renderer = new THREE.WebGLRenderer({ 
            canvas: canvas, 
            antialias: true, 
            alpha: true,
            preserveDrawingBuffer: true
        });
    } catch (e) {
        console.error('WebGL not supported, trying fallback:', e);
        renderer = new THREE.WebGLRenderer({ 
            canvas: canvas, 
            antialias: false, 
            alpha: true
        });
    }
    
    renderer.setSize(width, height);
    renderer.setPixelRatio(window.devicePixelRatio || 1);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFShadowShadowMap;
    
    // Lighting
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
    scene.add(ambientLight);
    
    const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
    directionalLight.position.set(500, 800, 500);
    directionalLight.castShadow = true;
    directionalLight.shadow.mapSize.width = 2048;
    directionalLight.shadow.mapSize.height = 2048;
    directionalLight.shadow.camera.far = 2000;
    directionalLight.shadow.camera.left = -1000;
    directionalLight.shadow.camera.right = 1000;
    directionalLight.shadow.camera.top = 1000;
    directionalLight.shadow.camera.bottom = -1000;
    scene.add(directionalLight);
    
    // Add a point light for better visibility
    const pointLight = new THREE.PointLight(0xffffff, 0.4);
    pointLight.position.set(-500, 300, -500);
    scene.add(pointLight);
    
    // Assembly group
    assemblyGroup = new THREE.Group();
    scene.add(assemblyGroup);
    
    // Add grid helper for reference
    const gridHelper = new THREE.GridHelper(2000, 20, 0x444444, 0x222222);
    scene.add(gridHelper);
    
    // Orbit controls
    controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.05;
    controls.enableZoom = true;
    controls.enablePan = true;
    controls.enableRotate = true;
    controls.autoRotate = false;
    controls.minDistance = 10;
    controls.maxDistance = 5000;
    
    // Handle window resize
    window.addEventListener('resize', onWindowResize);
    
    // Handle component selection
    renderer.domElement.addEventListener('click', onCanvasClick);
}

function createAssembly(components) {
    components.forEach((comp, index) => {
        const mesh = createComponentMesh(comp, index);
        if (mesh) {
            assemblyGroup.add(mesh);
            componentMeshes[index] = mesh;
            components[index].meshIndex = index;
        }
    });
}

function createComponentMesh(component, index) {
    // Convert mm to Three.js units (divide by 100 for reasonable scale)
    const width = Math.max((component.width || 100) / 100, 0.1);
    const height = Math.max((component.height || 100) / 100, 0.1);
    const depth = Math.max((component.depth || 100) / 100, 0.1);
    
    // Create geometry
    const geometry = new THREE.BoxGeometry(width, height, depth);
    
    // Create material with component's material color
    const colorHsl = getMaterialColor(component.material || 'Default');
    const colorHex = hslToRgb(colorHsl);
    
    const material = new THREE.MeshPhongMaterial({
        color: colorHex,
        shininess: 100,
        side: THREE.DoubleSide
    });
    
    // Create mesh
    const mesh = new THREE.Mesh(geometry, material);
    
    // Position the mesh
    const pos = component.position || { x: 0, y: 0, z: 0 };
    const posX = pos.x / 100;
    const posY = pos.y / 100;
    const posZ = pos.z / 100;
    
    mesh.position.set(posX, posY, posZ);
    
    // Apply rotation if available
    if (component.rotation) {
        mesh.rotation.order = 'XYZ';
        mesh.rotation.x = component.rotation.x || 0;
        mesh.rotation.y = component.rotation.y || 0;
        mesh.rotation.z = component.rotation.z || 0;
    }
    
    // Enable shadows
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    
    // Store component data on mesh
    mesh.userData = {
        componentIndex: index,
        component: component,
        originalMaterial: material.clone()
    };
    
    return mesh;
}

function populateComponentList(components) {
    const listContainer = document.getElementById('componentList');
    if (!listContainer) return;
    
    listContainer.innerHTML = '';
    
    components.forEach((comp, index) => {
        const item = document.createElement('div');
        item.className = 'component-item';
        item.innerHTML = `
            <div class="component-name">${comp.name || `Part ${index + 1}`}</div>
            <div class="component-info">
                ${(comp.width || 0).toFixed(0)} × ${(comp.height || 0).toFixed(0)} × ${(comp.depth || 0).toFixed(0)} mm<br>
                Material: ${comp.material || 'Unknown'}
            </div>
        `;
        
        item.addEventListener('click', () => selectComponent(index));
        item.dataset.componentIndex = index;
        
        listContainer.appendChild(item);
    });
}

function selectComponent(index) {
    // Deselect previous component
    if (selectedComponent !== null) {
        const prevMesh = componentMeshes[selectedComponent];
        if (prevMesh && prevMesh.userData.originalMaterial) {
            prevMesh.material = prevMesh.userData.originalMaterial.clone();
            prevMesh.scale.set(1, 1, 1);
        }
        
        const prevItem = document.querySelector(`[data-component-index="${selectedComponent}"]`);
        if (prevItem) {
            prevItem.classList.remove('selected');
        }
    }
    
    // Select new component
    selectedComponent = index;
    const mesh = componentMeshes[index];
    
    if (mesh) {
        // Highlight material
        const highlightMaterial = new THREE.MeshPhongMaterial({
            color: 0x00FF00,
            shininess: 100,
            emissive: 0x00AA00,
            side: THREE.DoubleSide
        });
        mesh.material = highlightMaterial;
        mesh.scale.set(1.05, 1.05, 1.05);
        
        // Update UI
        const item = document.querySelector(`[data-component-index="${index}"]`);
        if (item) {
            item.classList.add('selected');
            item.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }
        
        // Zoom to component
        zoomToComponent(mesh);
    }
}

function zoomToComponent(mesh) {
    const box = new THREE.Box3().setFromObject(mesh);
    const size = box.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z);
    const fov = camera.fov * (Math.PI / 180);
    let cameraZ = Math.abs(maxDim / 2 / Math.tan(fov / 2));
    
    cameraZ *= 1.5;
    
    const center = box.getCenter(new THREE.Vector3());
    
    controls.target.copy(center);
    camera.position.copy(center);
    camera.position.z += cameraZ;
    
    controls.update();
}

function fitCameraToAssembly() {
    if (!assemblyGroup || assemblyGroup.children.length === 0) {
        // Default view if no objects
        camera.position.set(500, 500, 500);
        controls.target.set(0, 0, 0);
        controls.update();
        return;
    }
    
    const box = new THREE.Box3().setFromObject(assemblyGroup);
    
    // Check if box is valid
    if (!box.isEmpty()) {
        const size = box.getSize(new THREE.Vector3());
        const maxDim = Math.max(size.x, size.y, size.z);
        const fov = camera.fov * (Math.PI / 180);
        let cameraZ = Math.abs(maxDim / 2 / Math.tan(fov / 2));
        
        cameraZ *= 1.8;
        
        const center = box.getCenter(new THREE.Vector3());
        
        controls.target.copy(center);
        camera.position.copy(center);
        camera.position.z += cameraZ;
    } else {
        // Fallback if box is empty
        camera.position.set(500, 500, 500);
        controls.target.set(0, 0, 0);
    }
    
    controls.update();
}

function onCanvasClick(event) {
    const canvas = renderer.domElement;
    const rect = canvas.getBoundingClientRect();
    const x = (event.clientX - rect.left) / rect.width * 2 - 1;
    const y = -(event.clientY - rect.top) / rect.height * 2 + 1;
    
    const raycaster = new THREE.Raycaster();
    raycaster.setFromCamera(new THREE.Vector2(x, y), camera);
    
    const meshes = Object.values(componentMeshes);
    const intersects = raycaster.intersectObjects(meshes);
    
    if (intersects.length > 0) {
        const mesh = intersects[0].object;
        const index = mesh.userData.componentIndex;
        selectComponent(index);
    }
}

function resetView() {
    selectedComponent = null;
    
    // Reset all meshes
    Object.values(componentMeshes).forEach(mesh => {
        if (mesh.userData.originalMaterial) {
            mesh.material = mesh.userData.originalMaterial.clone();
        }
        mesh.scale.set(1, 1, 1);
    });
    
    // Clear selection UI
    document.querySelectorAll('.component-item').forEach(item => {
        item.classList.remove('selected');
    });
    
    // Reset camera
    fitCameraToAssembly();
}

function toggleWireframe() {
    wireframeMode = !wireframeMode;
    
    Object.values(componentMeshes).forEach(mesh => {
        mesh.material.wireframe = wireframeMode;
    });
}

function setDisplayMode(mode) {
    displayMode = mode;
    
    Object.values(componentMeshes).forEach(mesh => {
        if (mode === 'solid') {
            mesh.material.transparent = false;
            mesh.material.opacity = 1;
        } else if (mode === 'transparent') {
            mesh.material.transparent = true;
            mesh.material.opacity = 0.7;
        }
    });
}

function toggleLighting() {
    lightingEnabled = !lightingEnabled;
    
    scene.children.forEach(child => {
        if (child instanceof THREE.Light) {
            child.visible = lightingEnabled;
        }
    });
}

function onWindowResize() {
    const canvas = renderer.domElement;
    const width = canvas.clientWidth;
    const height = canvas.clientHeight;
    
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    renderer.setSize(width, height);
}

function showErrorMessage(message) {
    const canvas = document.getElementById('canvas');
    if (canvas) {
        const errorDiv = document.createElement('div');
        errorDiv.style.cssText = `
            position: absolute;
            top: 50%;
            left: 50%;
            transform: translate(-50%, -50%);
            background: rgba(0, 0, 0, 0.8);
            color: #ff6b6b;
            padding: 20px;
            border-radius: 8px;
            font-family: monospace;
            max-width: 400px;
            text-align: center;
            z-index: 1000;
        `;
        errorDiv.textContent = message;
        canvas.parentElement.appendChild(errorDiv);
    }
}

function animate() {
    requestAnimationFrame(animate);
    
    if (controls) {
        controls.update();
    }
    
    if (renderer && scene && camera) {
        renderer.render(scene, camera);
    }
}

// Initialize when page loads
window.addEventListener('load', function() {
    console.log('Assembly viewer page loaded');
    
    // Check if data is being passed from SketchUp
    if (typeof sketchup === 'object' && sketchup.ready) {
        sketchup.ready();
    }
});

// Fallback: if no data is received from SketchUp, show loading message
setTimeout(() => {
    if (originalComponents.length === 0) {
        console.warn('No assembly data received after 3 seconds');
    }
}, 3000);
