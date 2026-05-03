Here are the precise fixes for `main.html` to resolve the Explode, Selection, and Texture issues in the 3D Viewer.

### 1. Fix the Explode Function

In `updateExplosion`, the code tries to access `originalPos`, but the property set in `renderAssembly` is `originalPosition`.

**Find function:** `function updateExplosion(val)`
**Replace with:**

```javascript
        function updateExplosion(val) {
            if (!isAssemblyMode || assemblyMeshes.length === 0) return;

            const percentage = val / 100.0;
            const explodeScale = 500; // Scale factor for explosion distance

            assemblyMeshes.forEach(mesh => {
                // FIX: Changed mesh.userData.originalPos to mesh.userData.originalPosition
                if (mesh.userData && mesh.userData.explodeVector && mesh.userData.originalPosition) {
                    // New Pos = Original + (Vector * Percentage * Scale)
                    const vec = mesh.userData.explodeVector;
                    // FIX: Changed mesh.userData.originalPos to mesh.userData.originalPosition
                    mesh.position.copy(mesh.userData.originalPosition).addScaledVector(vec, percentage * explodeScale);
                }
            });

            renderOnce();
        }

```

### 2. Fix Component Selection Highlighting

In `selectPart`, the code tries to match `userData.name`, but `renderAssembly` saves it as `userData.partName`. Additionally, `assemblyMeshes` are Groups, so we must highlight the child Mesh (index 0).

**Find function:** `function selectPart(row, name, width, height, thickness)`
**Locate the `if (isAssemblyMode)` block and replace it with:**

```javascript
            if (isAssemblyMode) {
                // ASSEMBLY MODE: Highlight selected component in 3D view
                console.log('Selected part in assembly:', name);
                
                // Reset all components to normal opacity
                assemblyMeshes.forEach(group => {
                    const mesh = group.children[0]; // FIX: Access the mesh inside the group
                    if (mesh && mesh.material) {
                        mesh.material.opacity = 0.85;
                        mesh.material.transparent = true;
                        if (mesh.material.emissive) {
                            mesh.material.emissive.setHex(0x000000);
                        }
                    }
                });
                
                // Highlight the selected component
                // FIX: Changed m.userData.name to m.userData.partName
                const selectedGroup = assemblyMeshes.find(m => m.userData.partName === name);
                if (selectedGroup) {
                    const mesh = selectedGroup.children[0]; // FIX: Access the mesh inside the group
                    if (mesh && mesh.material) {
                        mesh.material.opacity = 1.0;
                        mesh.material.transparent = false;
                        if (mesh.material.emissive) {
                            mesh.material.emissive.setHex(0x444444); // Subtle glow
                        }
                    }
                }
                
                renderOnce();
            } else {

```

### 3. Fix Textures (Loading & Rendering)

This requires updates in three places: `renderAssembly` to parse UVs and store material names, `toggleTexture` to trigger loading, and `applyTextureToMesh` to apply it.

**Step A: Update `renderAssembly**`
Replace the existing `renderAssembly` function with this version that processes UVs and correctly targets the Group structure.

```javascript
        function renderAssembly(data) {
            if (!canvas3DScene) return;
            clearAssemblyScene();

            const geometryData = data.geometry || data;
            if (!geometryData || !geometryData.parts || geometryData.parts.length === 0) {
                console.warn('No geometry parts to render');
                return;
            }

            console.log('Rendering assembly:', geometryData.parts.length, 'components');

            let allBounds = null;
            
            // Render each component as separate mesh
            geometryData.parts.forEach((partData, partIndex) => {
                const faces = partData.faces || [];
                if (faces.length === 0) return;

                const positions = [];
                const uvs = []; // FIX: Array to store UVs

                faces.forEach(face => {
                    const vertices = face.vertices;
                    const faceUVs = face.uvs; // FIX: Get UVs from face data
                    if (!vertices || vertices.length < 3) return;
                    
                    // Triangulate and swap Y/Z
                    for (let i = 1; i < vertices.length - 1; i++) {
                        positions.push(vertices[0].x, vertices[0].z, -vertices[0].y);
                        positions.push(vertices[i].x, vertices[i].z, -vertices[i].y);
                        positions.push(vertices[i + 1].x, vertices[i + 1].z, -vertices[i + 1].y);
                        
                        // FIX: Push UVs if available
                        if (faceUVs && faceUVs.length === vertices.length) {
                            uvs.push(faceUVs[0].x, faceUVs[0].y);
                            uvs.push(faceUVs[i].x, faceUVs[i].y);
                            uvs.push(faceUVs[i + 1].x, faceUVs[i + 1].y);
                        }
                    }
                });

                if (positions.length === 0) return;

                const geometry = new THREE.BufferGeometry();
                geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
                // FIX: Add UV attribute
                if (uvs.length > 0) {
                    geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
                }
                geometry.computeVertexNormals();

                const material = new THREE.MeshStandardMaterial({ 
                    color: 0xcccccc,
                    metalness: 0.1,
                    roughness: 0.6,
                    side: THREE.DoubleSide,
                    transparent: true,
                    opacity: 0.85
                });
                
                const mesh = new THREE.Mesh(geometry, material);
                
                const edges = new THREE.EdgesGeometry(geometry, 15);
                const edgeMaterial = new THREE.LineBasicMaterial({ color: 0x666666 });
                const wireframe = new THREE.LineSegments(edges, edgeMaterial);
                
                const group = new THREE.Group();
                group.add(mesh);
                group.add(wireframe);
                
                group.userData = {
                    partName: partData.name,
                    materialName: partData.material, // FIX: Store material name
                    explodeVector: new THREE.Vector3(...(partData.explode_vector || [0, 0, 0])),
                    originalPosition: group.position.clone()
                };
                
                canvas3DScene.add(group);
                assemblyMeshes.push(group);
                
                // Track bounds
                const box = new THREE.Box3().setFromObject(group);
                if (!allBounds) {
                    allBounds = box;
                } else {
                    allBounds.union(box);
                }
            });
            
            // ... (Rest of the function remains the same: Camera positioning)
            if (assemblyMeshes.length === 0) return;

            const center = allBounds.getCenter(new THREE.Vector3());
            const size = allBounds.getSize(new THREE.Vector3());
            const maxDim = Math.max(size.x, size.y, size.z);
            
            assemblyMeshes.forEach(group => {
                group.position.sub(center);
                group.userData.originalPosition = group.position.clone();
            });
            
            const distance = maxDim * 2.5;
            canvas3DCamera.position.set(distance * 0.7, distance * 0.5, distance * 0.7);
            canvas3DCamera.lookAt(0, 0, 0);
            orbitControls.target.set(0, 0, 0);
            orbitControls.update();

            renderOnce();
        }

```

**Step B: Update `toggleTexture**`
Fix it to access the mesh inside the group and trigger loading for the selected part.

```javascript
        function toggleTexture() {
            textureMode = !textureMode;
            
            if (isAssemblyMode) {
                // FIX: Handle Assembly Mode Textures
                assemblyMeshes.forEach(group => {
                    const mesh = group.children[0]; // Access mesh inside group
                    if (textureMode) {
                        mesh.material.color.setHex(0xFFFFFF); 
                    } else {
                        mesh.material.color.setHex(0xcccccc); // Revert to base gray
                        mesh.material.map = null;
                        mesh.material.needsUpdate = true;
                    }
                });
                
                // If turning on, try to load texture for the currently selected part
                if (textureMode) {
                    const selectedName = document.getElementById('selectedPartName').textContent;
                    const selectedGroup = assemblyMeshes.find(m => m.userData.partName === selectedName);
                    if (selectedGroup && selectedGroup.userData.materialName) {
                         // Request texture for this material
                         if (typeof callRuby === 'function') {
                             callRuby('get_material_texture', selectedGroup.userData.materialName);
                         }
                    }
                }
                renderOnce();
            } else {
                // ... (Keep existing Single Mode logic)
                if (!canvas3DCurrentMesh) return;
                // ...
                 if (textureMode) {
                    loadTextureForCurrentComponent();
                } else {
                    // ... existing disable logic
                }
            }
        }

```

**Step C: Update `applyTextureToMesh**`
Update to handle applying the texture to all parts in the assembly that match the material.

```javascript
        function applyTextureToMesh(textureData) {
            if (!textureData) return;

            if (currentTexture) {
                currentTexture.dispose();
                currentTexture = null;
            }

            const loader = new THREE.TextureLoader();
            currentTexture = loader.load(
                textureData,
                (texture) => {
                    texture.wrapS = THREE.RepeatWrapping;
                    texture.wrapT = THREE.RepeatWrapping;
                    
                    if (isAssemblyMode) {
                        // FIX: Assembly Mode Application
                        // Apply to all meshes that match the selected component's material
                        const selectedName = document.getElementById('selectedPartName').textContent;
                        const selectedGroup = assemblyMeshes.find(m => m.userData.partName === selectedName);
                        
                        if (selectedGroup) {
                            const targetMaterial = selectedGroup.userData.materialName;
                            
                            assemblyMeshes.forEach(group => {
                                if (group.userData.materialName === targetMaterial) {
                                    const mesh = group.children[0];
                                    if (mesh.isMesh) {
                                        // Scale texture roughly (assuming 1000mm repeat)
                                        // Since we don't have per-part dims easily accessible here without calculation, use fixed repeat
                                        texture.repeat.set(1, 1); 
                                        
                                        mesh.material.map = texture;
                                        mesh.material.color.setHex(0xFFFFFF);
                                        mesh.material.needsUpdate = true;
                                    }
                                }
                            });
                        }
                        renderOnce();
                    } else {
                        // ... (Keep existing Single Mode logic)
                        if (canvas3DCurrentMesh && canvas3DCurrentMesh.material) {
                            const comp = allComponentsData[currentComponentIndex];
                            texture.repeat.set(comp.width / 1000, comp.height / 1000);
                            
                            canvas3DCurrentMesh.material.map = texture;
                            canvas3DCurrentMesh.material.color.setHex(0xFFFFFF);
                            canvas3DCurrentMesh.material.needsUpdate = true;
                            renderOnce();
                        }
                    }
                }
            );
        }

```