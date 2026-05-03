function callRuby(method, args) {
    if (typeof sketchup === 'object' && sketchup[method]) {
        sketchup[method](args);
    } else {
        // Debug logging removed for production
    }
}

// receiveData: Removed verbose logging
function receiveData(data) {
    g_boardsData = data.diagrams;
    g_reportData = data.report;
    
    renderDiagrams();
    renderReport();
}

let g_boardsData = [];
let g_reportData = null;

// alternative receiveData (backup) - verbose logging removed
function receiveData(data) {
    g_boardsData = data.diagrams;
    g_reportData = data.report;
    window.originalComponents = data.original_components || [];
    
    renderDiagrams();
    renderReport();
}

function renderDiagrams() {
    const container = document.getElementById('diagramsContainer');
    container.innerHTML = '';

    if (!g_boardsData || g_boardsData.length === 0) {
        container.innerHTML = '<p>No cutting diagrams to display.</p>';
        return;
    }

    g_boardsData.forEach((board, boardIndex) => {
        const card = document.createElement('div');
        card.className = 'diagram-card';

        const title = document.createElement('h3');
        title.textContent = `${board.material} Board ${boardIndex + 1}`;
        title.id = `diagram-${board.material}-${boardIndex}`;
        card.appendChild(title);

        const info = document.createElement('p');
        info.innerHTML = `Size: ${board.stock_width.toFixed(1)}x${board.stock_height.toFixed(1)}mm<br>
                          Waste: ${board.waste_percentage.toFixed(1)}% (Efficiency: ${board.efficiency_percentage.toFixed(1)}%)`;
        card.appendChild(info);

        const canvas = document.createElement('canvas');
        canvas.className = 'diagram-canvas';
        card.appendChild(canvas);

        container.appendChild(card);

        // Canvas Drawing
        const ctx = canvas.getContext('2d');
        const padding = 40;
        const maxCanvasDim = 600;
        const scale = Math.min(
            (maxCanvasDim - 2 * padding) / board.stock_width,
            (maxCanvasDim - 2 * padding) / board.stock_height
        );

        canvas.width = board.stock_width * scale + 2 * padding;
        canvas.height = board.stock_height * scale + 2 * padding;

        // Draw Board Outline (grayscale)
        ctx.fillStyle = '#f5f5f5';
        ctx.fillRect(padding, padding, board.stock_width * scale, board.stock_height * scale);
        ctx.strokeStyle = '#666';
        ctx.lineWidth = 2;
        ctx.strokeRect(padding, padding, board.stock_width * scale, board.stock_height * scale);
        
        // Add board dimensions as text on the board
        ctx.fillStyle = '#333';
        ctx.font = `${Math.max(12, 14 * scale)}px Arial`;
        ctx.textAlign = 'center';
        ctx.fillText(`${board.stock_width.toFixed(0)}mm`, padding + (board.stock_width * scale) / 2, padding - 5);
        
        ctx.save();
        ctx.translate(padding - 15, padding + (board.stock_height * scale) / 2);
        ctx.rotate(-Math.PI / 2);
        ctx.fillText(`${board.stock_height.toFixed(0)}mm`, 0, 0);
        ctx.restore();

        // Draw Parts
        const parts = board.parts || [];
        parts.forEach((part, partIndex) => {
            const partX = padding + part.x * scale;
            const partY = padding + part.y * scale;
            const partWidth = part.width * scale;
            const partHeight = part.height * scale;

            // Material-based color fill
            ctx.fillStyle = getMaterialColor(part.material);
            ctx.fillRect(partX, partY, partWidth, partHeight);
            ctx.strokeStyle = '#333';
            ctx.lineWidth = 1;
            ctx.strokeRect(partX, partY, partWidth, partHeight);

            // Store part data for click detection
            canvas.partData = canvas.partData || [];
            canvas.partData.push({
                x: partX, y: partY, width: partWidth, height: partHeight,
                part: part, boardIndex: boardIndex
            });

            // Add part ID in center - properly aligned
            if (partWidth > 30 && partHeight > 20) {
                ctx.fillStyle = '#000';
                ctx.font = `${Math.max(8, 10 * scale)}px Arial`;
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                const labelContent = part.instance_id || `P${partIndex + 1}`;
                ctx.fillText(labelContent, partX + partWidth / 2, partY + partHeight / 2);
            }
            
            // Add width dimension (horizontal) - inside piece
            if (partWidth > 50) {
                ctx.fillStyle = '#000';
                ctx.font = `${Math.max(8, 10 * scale)}px Arial`;
                ctx.textAlign = 'center';
                ctx.textBaseline = 'top';
                ctx.fillText(`${part.width.toFixed(0)}mm`, partX + partWidth / 2, partY + 5);
            }
            
            // Add height dimension (vertical) - inside piece
            if (partHeight > 50) {
                ctx.save();
                ctx.translate(partX + 5, partY + partHeight / 2);
                ctx.rotate(-Math.PI / 2);
                ctx.fillStyle = '#000';
                ctx.font = `${Math.max(8, 10 * scale)}px Arial`;
                ctx.textAlign = 'center';
                ctx.textBaseline = 'top';
                ctx.fillText(`${part.height.toFixed(0)}mm`, 0, 0);
                ctx.restore();
            }
        });

        // Add click event listener
        canvas.addEventListener('click', (e) => handleCanvasClick(e, canvas));
        canvas.addEventListener('mousemove', (e) => handleCanvasHover(e, canvas));
        canvas.style.cursor = 'pointer';
    });
}

function getPartColor(partIndex) {
    const colors = [
        'rgba(255,0,0,0.6)', 'rgba(0,0,255,0.6)', 'rgba(0,255,0,0.6)', 'rgba(255,255,0,0.6)',
        'rgba(255,165,0,0.6)', 'rgba(128,0,128,0.6)', 'rgba(0,255,255,0.6)', 'rgba(255,0,255,0.6)'
    ];
    return colors[partIndex % colors.length];
}

function renderReport() {
    if (!g_reportData) return;

    // Summary Table
    const summaryTable = document.getElementById('summaryTable');
    summaryTable.innerHTML = `
        <tr><th>Metric</th><th>Value</th></tr>
        <tr><td>Total Parts Instances</td><td>${g_reportData.summary.total_parts_instances || 0}</td></tr>
        <tr><td>Total Unique Part Types</td><td>${g_reportData.summary.total_unique_part_types || 0}</td></tr>
        <tr><td>Total Boards</td><td>${g_reportData.summary.total_boards || 0}</td></tr>
        <tr><td>Overall Efficiency</td><td>${(g_reportData.summary.overall_efficiency || 0).toFixed(2)}%</td></tr>
        <tr><td><strong>Total Project Cost</strong></td><td class="total-highlight"><strong>$${(g_reportData.summary.total_project_cost || 0).toFixed(2)}</strong></td></tr>
    `;

    // Materials Used Section - moved to top
    const materialsContainer = document.getElementById('materialsContainer');
    if (materialsContainer && g_reportData.unique_board_types) {
        materialsContainer.innerHTML = g_reportData.unique_board_types.map((board_type, index) => `
            <div class="material-item" onclick="scrollToDiagram('${board_type.material}')" style="cursor: pointer;">
                <div class="material-swatch" style="background: ${getMaterialColor(board_type.material)}"></div>
                <span class="material-name">${board_type.material}</span>
                <span class="material-price">Price: $${(board_type.price_per_sheet || 0).toFixed(2)}</span>
            </div>
        `).join('');
    }

    // Unique Part Types Table
    const uniquePartTypesTable = document.getElementById('uniquePartTypesTable');
    if (uniquePartTypesTable) {
        uniquePartTypesTable.innerHTML = `
            <tr><th>Name</th><th>W (mm)</th><th>H (mm)</th><th>Thick (mm)</th><th>Material</th><th>Grain</th><th>Total Qty</th><th>Total Area (m²)</th></tr>
        `;
        if (g_reportData.unique_part_types) {
            g_reportData.unique_part_types.forEach(part_type => {
                uniquePartTypesTable.innerHTML += `
                    <tr>
                        <td>${part_type.name}</td>
                        <td>${part_type.width.toFixed(2)}</td>
                        <td>${part_type.height.toFixed(2)}</td>
                        <td>${part_type.thickness.toFixed(2)}</td>
                        <td>${part_type.material}</td>
                        <td>${part_type.grain_direction}</td>
                        <td class="total-highlight">${part_type.total_quantity}</td>
                        <td>${(part_type.total_area / 1000000).toFixed(3)}</td>
                    </tr>
                `;
            });
        }
    }

    // Sheet Inventory Summary Table
    const sheetInventoryTable = document.getElementById('sheetInventoryTable');
    if (sheetInventoryTable && g_reportData.unique_board_types) {
        sheetInventoryTable.innerHTML = `
            <tr><th>Material</th><th>Dimensions</th><th>Count</th><th>Total Area (m²)</th><th>Price/Sheet</th><th>Total Cost</th></tr>
        `;
        g_reportData.unique_board_types.forEach(board_type => {
            sheetInventoryTable.innerHTML += `
                <tr>
                    <td>${board_type.material}</td>
                    <td>${board_type.dimensions}</td>
                    <td class="total-highlight">${board_type.count}</td>
                    <td>${(board_type.total_area / 1000000).toFixed(3)}</td>
                    <td>$${(board_type.price_per_sheet || 0).toFixed(2)}</td>
                    <td class="total-highlight">$${(board_type.total_cost || 0).toFixed(2)}</td>
                </tr>
            `;
        });
    }

    // Parts Placed Table
    const partsTable = document.getElementById('partsTable');
    partsTable.innerHTML = `
        <tr><th>Unique ID</th><th>Name</th><th>Dimensions</th><th>Material</th><th>Board#</th></tr>
    `;
    const parts_list = g_reportData.parts_placed || g_reportData.parts || [];
    parts_list.forEach(part => {
        partsTable.innerHTML += `
            <tr>
                <td>${part.part_unique_id || part.part_number}</td>
                <td>${part.name}</td>
                <td>${part.width.toFixed(0)} × ${part.height.toFixed(0)}mm</td>
                <td>${part.material}</td>
                <td>${part.board_number}</td>
            </tr>
        `;
    });
}

function getMaterialColor(material) {
    // Generate consistent colors based on material name
    let hash = 0;
    for (let i = 0; i < material.length; i++) {
        hash = material.charCodeAt(i) + ((hash << 5) - hash);
    }
    const hue = Math.abs(hash) % 360;
    return `hsl(${hue}, 45%, 65%)`;
}

function getMaterialTexture(material) {
    // Create a simple pattern based on material name
    if (material.toLowerCase().includes('wood') || material.toLowerCase().includes('chestnut')) {
        return 'repeating-linear-gradient(45deg, #8B4513, #8B4513 2px, #A0522D 2px, #A0522D 4px)';
    } else if (material.includes('240,240,240')) {
        return 'repeating-linear-gradient(90deg, #f0f0f0, #f0f0f0 3px, #e0e0e0 3px, #e0e0e0 6px)';
    }
    return getMaterialColor(material);
}

function handleCanvasClick(e, canvas) {
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    if (canvas.partData) {
        for (let partData of canvas.partData) {
            if (x >= partData.x && x <= partData.x + partData.width &&
                y >= partData.y && y <= partData.y + partData.height) {
                showPartModal(partData.part);
                break;
            }
        }
    }
}

function handleCanvasHover(e, canvas) {
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    let hovering = false;
    if (canvas.partData) {
        for (let partData of canvas.partData) {
            if (x >= partData.x && x <= partData.x + partData.width &&
                y >= partData.y && y <= partData.y + partData.height) {
                hovering = true;
                break;
            }
        }
    }
    canvas.style.cursor = hovering ? 'pointer' : 'default';
}

let scene, camera, renderer, controls, cube;
let showTexture = false, isOrthographic = false, currentPart = null;

function showPartModal(part) {
    const modal = document.getElementById('partModal');
    const modalCanvas = document.getElementById('modalCanvas');
    const modalInfo = document.getElementById('modalInfo');
    
    initThreeJS(part, modalCanvas);
    

    setupOrbitControls();
    
    // Set modal info
    modalInfo.innerHTML = `
        <h3>${part.name}</h3>
        <p><strong>Dimensions:</strong> ${part.width.toFixed(1)} × ${part.height.toFixed(1)} × ${part.thickness.toFixed(1)}mm</p>
        <p><strong>Area:</strong> ${(part.width * part.height / 1000000).toFixed(3)} m²</p>
        <p><strong>Material:</strong> ${part.material}</p>
        <p><strong>Grain Direction:</strong> ${part.grain_direction || 'Any'}</p>
        <p><strong>Rotated:</strong> ${part.rotated ? 'Yes' : 'No'}</p>
        <p style="color: #666; font-size: 12px;">Left drag: orbit | Middle/Shift+Left drag: pan | Scroll: zoom</p>
    `;
    
    // Setup button controls

    
    document.getElementById('projectionToggle').onclick = () => {
        isOrthographic = !isOrthographic;
        document.getElementById('projectionToggle').textContent = isOrthographic ? 'Perspective' : 'Orthographic';
        
        if (isOrthographic) {
            const distance = camera.position.distanceTo(controls.target);
            camera = new THREE.OrthographicCamera(-distance, distance, distance, -distance, 0.1, 1000);
        } else {
            camera = new THREE.PerspectiveCamera(75, renderer.domElement.width / renderer.domElement.height, 0.1, 1000);
        }
        camera.position.set(5, 5, 5);
        controls.object = camera;
    };
    
    currentPart = part;
    modal.style.display = 'block';
    animate();
}



function exportInteractiveHTML() {
    if (!g_boardsData || g_boardsData.length === 0 || !g_reportData) {
        alert('No data to export. Please generate a report first.');
        return;
    }

    const htmlContent = `<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>AutoNestCut Interactive Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        .container { display: flex; gap: 20px; }
        .diagrams-container { flex: 1; }
        .report-container { flex: 1; }
        .resizer { width: 5px; background: #ddd; cursor: col-resize; flex-shrink: 0; }
        .diagram-card { border: 1px solid #ddd; margin: 10px 0; padding: 10px; }
        .diagram-canvas { border: 1px solid #ccc; cursor: pointer; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .modal { display: none; position: fixed; z-index: 1000; left: 0; top: 0; width: 100%; height: 100%; background-color: rgba(0,0,0,0.4); }
        .modal-content { background-color: #fefefe; margin: 2% auto; padding: 20px; border: 1px solid #888; width: 80%; max-width: 900px; max-height: 90vh; overflow-y: auto; }
        .modal-controls { margin-bottom: 10px; }
        .modal-controls button { margin-right: 10px; padding: 5px 10px; }
        .close { color: #aaa; float: right; font-size: 28px; font-weight: bold; cursor: pointer; }
        .close:hover { color: black; }
        #modalCanvas { border: 1px solid #ddd; }
        #modalInfo { margin-top: 15px; }
        .material-item { display: flex; align-items: center; margin: 5px 0; }
        .material-swatch { width: 20px; height: 20px; margin-right: 10px; border: 1px solid #ccc; }
        .total-highlight { font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>AutoNestCut Interactive Report</h1>
        <button onclick="window.print()">Print / Save as PDF</button>
    </div>
    <div class="container">
        <div id="diagramsContainer" class="diagrams-container"></div>
        <div class="resizer" id="resizer"></div>
        <div id="reportContainer" class="report-container">
            <h2>Overall Summary</h2>
            <table id="summaryTable"></table>
            <h2>Materials Used</h2>
            <div id="materialsContainer"></div>
            <h2>Unique Part Types</h2>
            <table id="uniquePartTypesTable"></table>
            <h2>Sheet Inventory Summary</h2>
            <table id="sheetInventoryTable"></table>
            <h2>Parts Placed (Detailed)</h2>
            <table id="partsTable"></table>
        </div>
    </div>
    <div id="partModal" class="modal">
        <div class="modal-content">
            <span class="close">&times;</span>
            <div class="modal-controls">
                <button id="projectionToggle">Orthographic</button>
            </div>
            <canvas id="modalCanvas" width="500" height="400"></canvas>
            <div id="modalInfo"></div>
        </div>
    </div>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
    <script>
        let g_boardsData = ${JSON.stringify(g_boardsData)};
        let g_reportData = ${JSON.stringify(g_reportData)};
        let scene, camera, renderer, controls, cube;
        let showTexture = false, isOrthographic = false, currentPart = null;
        let resizerInitialized = false;
        
        ${getCompleteJSContent()}
        
        document.addEventListener('DOMContentLoaded', () => {
            renderDiagrams();
            renderReport();
            
            const modal = document.getElementById('partModal');
            const closeBtn = document.querySelector('.close');
            if (closeBtn) {
                closeBtn.addEventListener('click', () => modal.style.display = 'none');
            }
            window.addEventListener('click', (e) => {
                if (e.target === modal) modal.style.display = 'none';
            });
            initResizer();
        });
    </script>
</body>
</html>`;

    downloadHTML(htmlContent, 'AutoNestCut_Interactive_Report.html');
}



function getCompleteJSContent() {
    return `
        function renderDiagrams() {
            const container = document.getElementById('diagramsContainer');
            container.innerHTML = '';
        
            if (!g_boardsData || g_boardsData.length === 0) {
                container.innerHTML = '<p>No cutting diagrams to display.</p>';
                return;
            }
        
            g_boardsData.forEach((board, boardIndex) => {
                const card = document.createElement('div');
                card.className = 'diagram-card';
        
                const title = document.createElement('h3');
                title.textContent = \`\${board.material} Board \${boardIndex + 1}\`;
                title.id = \`diagram-\${board.material}-\${boardIndex}\`;
                card.appendChild(title);
        
                const info = document.createElement('p');
                info.innerHTML = \`Size: \${board.stock_width.toFixed(1)}x\${board.stock_height.toFixed(1)}mm<br>
                                  Waste: \${board.waste_percentage.toFixed(1)}% (Efficiency: \${board.efficiency_percentage.toFixed(1)}%)\`;
                card.appendChild(info);
        
                const canvas = document.createElement('canvas');
                canvas.className = 'diagram-canvas';
                card.appendChild(canvas);
        
                container.appendChild(card);
        
                const ctx = canvas.getContext('2d');
                const padding = 40;
                const maxCanvasDim = 600;
                const scale = Math.min(
                    (maxCanvasDim - 2 * padding) / board.stock_width,
                    (maxCanvasDim - 2 * padding) / board.stock_height
                );
        
                canvas.width = board.stock_width * scale + 2 * padding;
                canvas.height = board.stock_height * scale + 2 * padding;
        
                ctx.fillStyle = '#f5f5f5';
                ctx.fillRect(padding, padding, board.stock_width * scale, board.stock_height * scale);
                ctx.strokeStyle = '#666';
                ctx.lineWidth = 2;
                ctx.strokeRect(padding, padding, board.stock_width * scale, board.stock_height * scale);
                
                ctx.fillStyle = '#333';
                ctx.font = \`\${Math.max(12, 14 * scale)}px Arial\`;
                ctx.textAlign = 'center';
                ctx.fillText(\`\${board.stock_width.toFixed(0)}mm\`, padding + (board.stock_width * scale) / 2, padding - 5);
                
                ctx.save();
                ctx.translate(padding - 15, padding + (board.stock_height * scale) / 2);
                ctx.rotate(-Math.PI / 2);
                ctx.fillText(\`\${board.stock_height.toFixed(0)}mm\`, 0, 0);
                ctx.restore();
        
                const parts = board.parts || [];
                parts.forEach((part, partIndex) => {
                    const partX = padding + part.x * scale;
                    const partY = padding + part.y * scale;
                    const partWidth = part.width * scale;
                    const partHeight = part.height * scale;
        
                    ctx.fillStyle = getMaterialColor(part.material);
                    ctx.fillRect(partX, partY, partWidth, partHeight);
                    ctx.strokeStyle = '#333';
                    ctx.lineWidth = 1;
                    ctx.strokeRect(partX, partY, partWidth, partHeight);
        
                    canvas.partData = canvas.partData || [];
                    canvas.partData.push({
                        x: partX, y: partY, width: partWidth, height: partHeight,
                        part: part, boardIndex: boardIndex
                    });
        
                    if (partWidth > 30 && partHeight > 20) {
                        ctx.fillStyle = '#000';
                        ctx.font = \`\${Math.max(8, 10 * scale)}px Arial\`;
                        ctx.textAlign = 'center';
                        ctx.textBaseline = 'middle';
                        const labelContent = part.instance_id || \`P\${partIndex + 1}\`;
                        ctx.fillText(labelContent, partX + partWidth / 2, partY + partHeight / 2);
                    }
                    
                    if (partWidth > 50) {
                        ctx.fillStyle = '#000';
                        ctx.font = \`\${Math.max(8, 10 * scale)}px Arial\`;
                        ctx.textAlign = 'center';
                        ctx.textBaseline = 'top';
                        ctx.fillText(\`\${part.width.toFixed(0)}mm\`, partX + partWidth / 2, partY + 5);
                    }
                    
                    if (partHeight > 50) {
                        ctx.save();
                        ctx.translate(partX + 5, partY + partHeight / 2);
                        ctx.rotate(-Math.PI / 2);
                        ctx.fillStyle = '#000';
                        ctx.font = \`\${Math.max(8, 10 * scale)}px Arial\`;
                        ctx.textAlign = 'center';
                        ctx.textBaseline = 'top';
                        ctx.fillText(\`\${part.height.toFixed(0)}mm\`, 0, 0);
                        ctx.restore();
                    }
                });
        
                canvas.addEventListener('click', (e) => handleCanvasClick(e, canvas));
                canvas.addEventListener('mousemove', (e) => handleCanvasHover(e, canvas));
                canvas.style.cursor = 'pointer';
            });
        }
        
        function renderReport() {
            if (!g_reportData) return;
        
            const summaryTable = document.getElementById('summaryTable');
            summaryTable.innerHTML = \`
                <tr><th>Metric</th><th>Value</th></tr>
                <tr><td>Total Parts Instances</td><td>\${g_reportData.summary.total_parts_instances || 0}</td></tr>
                <tr><td>Total Unique Part Types</td><td>\${g_reportData.summary.total_unique_part_types || 0}</td></tr>
                <tr><td>Total Boards</td><td>\${g_reportData.summary.total_boards || 0}</td></tr>
                <tr><td>Overall Efficiency</td><td>\${(g_reportData.summary.overall_efficiency || 0).toFixed(2)}%</td></tr>
                <tr><td><strong>Total Project Cost</strong></td><td class="total-highlight"><strong>$\${(g_reportData.summary.total_project_cost || 0).toFixed(2)}</strong></td></tr>
            \`;
        
            const materialsContainer = document.getElementById('materialsContainer');
            if (materialsContainer && g_reportData.unique_board_types) {
                materialsContainer.innerHTML = g_reportData.unique_board_types.map(board_type => \`
                    <div class="material-item" onclick="scrollToDiagram('\${board_type.material}')" style="cursor: pointer;">
                        <div class="material-swatch" style="background: \${getMaterialColor(board_type.material)}"></div>
                        <span class="material-name">\${board_type.material}</span>
                        <span class="material-price">Price: $\${(board_type.price_per_sheet || 0).toFixed(2)}</span>
                    </div>
                \`).join('');
            }
        
            const uniquePartTypesTable = document.getElementById('uniquePartTypesTable');
            if (uniquePartTypesTable) {
                uniquePartTypesTable.innerHTML = \`
                    <tr><th>Name</th><th>W (mm)</th><th>H (mm)</th><th>Thick (mm)</th><th>Material</th><th>Grain</th><th>Total Qty</th><th>Total Area (m²)</th></tr>
                \`;
                if (g_reportData.unique_part_types) {
                    g_reportData.unique_part_types.forEach(part_type => {
                        uniquePartTypesTable.innerHTML += \`
                            <tr>
                                <td>\${part_type.name}</td>
                                <td>\${part_type.width.toFixed(2)}</td>
                                <td>\${part_type.height.toFixed(2)}</td>
                                <td>\${part_type.thickness.toFixed(2)}</td>
                                <td>\${part_type.material}</td>
                                <td>\${part_type.grain_direction}</td>
                                <td class="total-highlight">\${part_type.total_quantity}</td>
                                <td>\${(part_type.total_area / 1000000).toFixed(3)}</td>
                            </tr>
                        \`;
                    });
                }
            }
        

        

        
            const partsTable = document.getElementById('partsTable');
            partsTable.innerHTML = \`
                <tr><th>Unique ID</th><th>Name</th><th>Dimensions</th><th>Material</th><th>Board#</th></tr>
            \`;
            const parts_list = g_reportData.parts_placed || g_reportData.parts || [];
            parts_list.forEach(part => {
                partsTable.innerHTML += \`
                    <tr>
                        <td>\${part.part_unique_id || part.part_number}</td>
                        <td>\${part.name}</td>
                        <td>\${part.width.toFixed(0)} × \${part.height.toFixed(0)}mm</td>
                        <td>\${part.material}</td>
                        <td>\${part.board_number}</td>
                    </tr>
                \`;
            });
        }
        
        function showPartModal(part) {
            const modal = document.getElementById('partModal');
            const modalCanvas = document.getElementById('modalCanvas');
            const modalInfo = document.getElementById('modalInfo');
            
            initThreeJS(part, modalCanvas);
            setupOrbitControls();
            
            modalInfo.innerHTML = \`
                <h3>\${part.name}</h3>
                <p><strong>Dimensions:</strong> \${part.width.toFixed(1)} × \${part.height.toFixed(1)} × \${part.thickness.toFixed(1)}mm</p>
                <p><strong>Area:</strong> \${(part.width * part.height / 1000000).toFixed(3)} m²</p>
                <p><strong>Material:</strong> \${part.material}</p>
                <p><strong>Grain Direction:</strong> \${part.grain_direction || 'Any'}</p>
                <p><strong>Rotated:</strong> \${part.rotated ? 'Yes' : 'No'}</p>
                <p style="color: #666; font-size: 12px;">Left drag: orbit | Middle/Shift+Left drag: pan | Scroll: zoom</p>
            \`;
            
            document.getElementById('projectionToggle').onclick = () => {
                isOrthographic = !isOrthographic;
                document.getElementById('projectionToggle').textContent = isOrthographic ? 'Perspective' : 'Orthographic';
                
                if (isOrthographic) {
                    const distance = camera.position.distanceTo(controls.target);
                    camera = new THREE.OrthographicCamera(-distance, distance, distance, -distance, 0.1, 1000);
                } else {
                    camera = new THREE.PerspectiveCamera(75, renderer.domElement.width / renderer.domElement.height, 0.1, 1000);
                }
                camera.position.set(5, 5, 5);
                controls.object = camera;
            };
            
            currentPart = part;
            modal.style.display = 'block';
            animate();
        }
        
        function initThreeJS(part, canvas) {
            scene = new THREE.Scene();
            scene.background = new THREE.Color(0xf0f0f0);
            
            camera = new THREE.PerspectiveCamera(75, canvas.width / canvas.height, 0.1, 1000);
            camera.position.set(5, 5, 5);
            
            renderer = new THREE.WebGLRenderer({ canvas: canvas });
            renderer.setSize(canvas.width, canvas.height);
            
            const w = part.width / 100;
            const h = part.height / 100; 
            const d = part.thickness / 100;
            
            const geometry = new THREE.BoxGeometry(w, h, d);
            const material = new THREE.MeshBasicMaterial({ color: 0x74b9ff });
            cube = new THREE.Mesh(geometry, material);
            
            const edges = new THREE.EdgesGeometry(geometry);
            const edgeMaterial = new THREE.LineBasicMaterial({ color: 0x333333, linewidth: 1 });
            const wireframe = new THREE.LineSegments(edges, edgeMaterial);
            
            scene.add(cube);
            scene.add(wireframe);
        }
        
        function setupOrbitControls() {
            controls = new THREE.OrbitControls(camera, renderer.domElement);
            controls.enableDamping = true;
            controls.dampingFactor = 0.25;
            controls.enableZoom = true;
            controls.enablePan = true;
            controls.enableRotate = true;
            controls.minDistance = 1;
            controls.maxDistance = 50;
        }
        
        function animate() {
            if (!renderer || !scene || !camera) return;
            
            controls.update();
            renderer.render(scene, camera);
            
            if (document.getElementById('partModal').style.display === 'block') {
                requestAnimationFrame(animate);
            }
        }
        
        function handleCanvasClick(e, canvas) {
            const rect = canvas.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            
            if (canvas.partData) {
                for (let partData of canvas.partData) {
                    if (x >= partData.x && x <= partData.x + partData.width &&
                        y >= partData.y && y <= partData.y + partData.height) {
                        showPartModal(partData.part);
                        break;
                    }
                }
            }
        }
        
        function handleCanvasHover(e, canvas) {
            const rect = canvas.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            
            let hovering = false;
            if (canvas.partData) {
                for (let partData of canvas.partData) {
                    if (x >= partData.x && x <= partData.x + partData.width &&
                        y >= partData.y && y <= partData.y + partData.height) {
                        hovering = true;
                        break;
                    }
                }
            }
            canvas.style.cursor = hovering ? 'pointer' : 'default';
        }
        
        function getMaterialColor(material) {
            let hash = 0;
            for (let i = 0; i < material.length; i++) {
                hash = material.charCodeAt(i) + ((hash << 5) - hash);
            }
            const hue = Math.abs(hash) % 360;
            return \`hsl(\${hue}, 45%, 65%)\`;
        }
        
        function getMaterialTexture(material) {
            if (material.toLowerCase().includes('wood') || material.toLowerCase().includes('chestnut')) {
                return 'repeating-linear-gradient(45deg, #8B4513, #8B4513 2px, #A0522D 2px, #A0522D 4px)';
            } else if (material.includes('240,240,240')) {
                return 'repeating-linear-gradient(90deg, #f0f0f0, #f0f0f0 3px, #e0e0e0 3px, #e0e0e0 6px)';
            }
            return getMaterialColor(material);
        }
        
        // Scroll to the first diagram for a material
        function scrollToDiagram(material) {
            const id = 'diagram-' + material + '-0';
            const firstDiagram = document.getElementById(id);
            if (firstDiagram) {
                firstDiagram.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        }
        
        function initResizer() {
            const resizer = document.getElementById('resizer');
            const leftSide = document.getElementById('diagramsContainer');
            const rightSide = document.getElementById('reportContainer');
            
            if (!resizer || !leftSide || !rightSide || resizerInitialized) return;
            
            let isResizing = false;
            resizerInitialized = true;
            
            resizer.style.cursor = 'col-resize';
            
            function handleMouseMove(e) {
                if (!isResizing) return;
                e.preventDefault();
                
                const container = document.querySelector('.container');
                const containerRect = container.getBoundingClientRect();
                const leftWidth = e.clientX - containerRect.left;
                const totalWidth = containerRect.width;
                const leftPercent = (leftWidth / totalWidth) * 100;
                const rightPercent = 100 - leftPercent;
                
                if (leftPercent > 15 && rightPercent > 25) {
                    leftSide.style.flex = \`0 0 \${leftPercent}%\`;
                    rightSide.style.flex = \`0 0 \${rightPercent}%\`;
                }
            }
            
            function handleMouseUp() {
                isResizing = false;
                document.body.style.cursor = '';
                document.body.style.userSelect = '';
                resizer.style.cursor = 'col-resize';
                document.removeEventListener('mousemove', handleMouseMove);
                document.removeEventListener('mouseup', handleMouseUp);
            }
            
            resizer.addEventListener('mousedown', (e) => {
                e.preventDefault();
                isResizing = true;
                document.body.style.cursor = 'col-resize';
                document.body.style.userSelect = 'none';
                
                document.addEventListener('mousemove', handleMouseMove);
                document.addEventListener('mouseup', handleMouseUp);
            });
            
            resizer.addEventListener('mouseenter', () => {
                if (!isResizing) {
                    resizer.style.cursor = 'col-resize';
                }
            });
        }
    `;
}

function downloadHTML(content, filename) {
    try {
        const blob = new Blob([content], { type: 'text/html' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.style.display = 'none';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        
        setTimeout(() => {
            alert('Interactive HTML report exported successfully! Click on any part in the cutting diagrams to view it in 3D.');
        }, 100);
    } catch (error) {
        alert('Error exporting HTML: ' + error.message);
    }
}



function initThreeJS(part, canvas) {
    scene = new THREE.Scene();
    scene.background = new THREE.Color(0xf0f0f0);
    
    camera = new THREE.PerspectiveCamera(75, canvas.width / canvas.height, 0.1, 1000);
    camera.position.set(5, 5, 5);
    
    renderer = new THREE.WebGLRenderer({ canvas: canvas });
    renderer.setSize(canvas.width, canvas.height);
    
    // Create box with part dimensions
    const w = part.width / 100;
    const h = part.height / 100; 
    const d = part.thickness / 100;
    
    const geometry = new THREE.BoxGeometry(w, h, d);
    const material = new THREE.MeshBasicMaterial({ color: 0x74b9ff });
    cube = new THREE.Mesh(geometry, material);
    
    // Add subtle edges
    const edges = new THREE.EdgesGeometry(geometry);
    const edgeMaterial = new THREE.LineBasicMaterial({ color: 0x333333, linewidth: 1 });
    const wireframe = new THREE.LineSegments(edges, edgeMaterial);
    
    scene.add(cube);
    scene.add(wireframe);
}

function createShader(type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    return shader;
}

function createProgram(vertexShader, fragmentShader) {
    const program = gl.createProgram();
    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);
    return program;
}

function setupOrbitControls() {
    controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.25;
    controls.enableZoom = true;
    controls.enablePan = true;
    controls.enableRotate = true;
    controls.minDistance = 1;
    controls.maxDistance = 50;
}

function animate() {
    if (!renderer || !scene || !camera) return;
    
    controls.update();
    renderer.render(scene, camera);
    
    if (document.getElementById('partModal').style.display === 'block') {
        requestAnimationFrame(animate);
    }
}





function initResizer() {
    const resizer = document.getElementById('resizer');
    const leftSide = document.getElementById('diagramsContainer');
    const rightSide = document.getElementById('reportContainer');
    
    if (!resizer || !leftSide || !rightSide || resizerInitialized) return;
    
    let isResizing = false;
    resizerInitialized = true;
    
    // Set initial cursor style
    resizer.style.cursor = 'col-resize';
    
    function handleMouseMove(e) {
        if (!isResizing) return;
        e.preventDefault();
        
        const container = document.querySelector('.container');
        const containerRect = container.getBoundingClientRect();
        const leftWidth = e.clientX - containerRect.left;
        const totalWidth = containerRect.width;
        const leftPercent = (leftWidth / totalWidth) * 100;
        const rightPercent = 100 - leftPercent;
        
        if (leftPercent > 15 && rightPercent > 25) {
            leftSide.style.flex = `0 0 ${leftPercent}%`;
            rightSide.style.flex = `0 0 ${rightPercent}%`;
        }
    }
    
    function handleMouseUp() {
        isResizing = false;
        document.body.style.cursor = '';
        document.body.style.userSelect = '';
        resizer.style.cursor = 'col-resize';
        document.removeEventListener('mousemove', handleMouseMove);
        document.removeEventListener('mouseup', handleMouseUp);
    }
    
    resizer.addEventListener('mousedown', (e) => {
        e.preventDefault();
        isResizing = true;
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
        
        document.addEventListener('mousemove', handleMouseMove);
        document.addEventListener('mouseup', handleMouseUp);
    });
    
    // Ensure resizer cursor is always visible
    resizer.addEventListener('mouseenter', () => {
        if (!isResizing) {
            resizer.style.cursor = 'col-resize';
        }
    });
}

document.addEventListener('DOMContentLoaded', () => {
    // Only handle back button here since export buttons are handled in main.html
    const backBtn = document.getElementById('backButton');
    
    if (backBtn) {
        backBtn.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            callRuby('back_to_config');
        });
    }

    // Modal close functionality
    const modal = document.getElementById('partModal');
    const closeBtn = document.querySelector('.close');
    
    closeBtn.addEventListener('click', () => {
        modal.style.display = 'none';
    });
    
    window.addEventListener('click', (e) => {
        if (e.target === modal) {
            modal.style.display = 'none';
        }
    });

    initResizer();
    // Initialize the page
    setTimeout(() => {
        callRuby('ready');
    }, 100);
});