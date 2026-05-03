function callRuby(method, args) {
    if (typeof sketchup === 'object' && sketchup[method]) {
        sketchup[method](args);
    } else {
        // Debug logging removed for production
    }
}

let g_boardsData = [];
let g_reportData = null;

function receiveData(data) {
    // Debug logging removed for production
    g_boardsData = data.diagrams;
    g_reportData = data.report;
    window.originalComponents = data.original_components || [];
    window.hierarchyTree = data.hierarchy_tree || [];
    
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
        title.id = `diagram-${board.material.replace(/[^a-zA-Z0-9]/g, '_')}-${boardIndex}`;
        card.appendChild(title);

        const info = document.createElement('p');
        info.innerHTML = `Size: ${board.stock_width.toFixed(1)}x${board.stock_height.toFixed(1)}mm<br>
                          Waste: ${board.waste_percentage.toFixed(1)}% (Efficiency: ${board.efficiency_percentage.toFixed(1)}%)`;
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
        ctx.font = `${Math.max(12, 14 * scale)}px Arial`;
        ctx.textAlign = 'center';
        ctx.fillText(`${board.stock_width.toFixed(0)}mm`, padding + (board.stock_width * scale) / 2, padding - 5);
        
        ctx.save();
        ctx.translate(padding - 15, padding + (board.stock_height * scale) / 2);
        ctx.rotate(-Math.PI / 2);
        ctx.fillText(`${board.stock_height.toFixed(0)}mm`, 0, 0);
        ctx.restore();

        const parts = board.parts || [];
        canvas.boardIndex = boardIndex;
        canvas.boardData = board;
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
                // Larger, centered white labels for readability
                ctx.fillStyle = '#ffffff';
                ctx.font = `bold ${Math.max(12, 14 * scale)}px sans-serif`;
                ctx.textAlign = 'center';
                ctx.textBaseline = 'middle';
                const labelContent = String(part.instance_id || `P${partIndex + 1}`);
                const maxChars = Math.max(6, Math.floor(partWidth / 8));
                const displayLabel = labelContent.length > maxChars ? labelContent.slice(0, maxChars - 1) + 'ÔÇª' : labelContent;
                ctx.fillText(displayLabel, partX + partWidth / 2, partY + partHeight / 2);
            }

            if (partWidth > 50) {
                ctx.fillStyle = '#ffffff';
                ctx.font = `${Math.max(10, 11 * scale)}px sans-serif`;
                ctx.textAlign = 'center';
                ctx.textBaseline = 'top';
                ctx.fillText(`${Math.round(part.width)}mm`, partX + partWidth / 2, partY + 5);
            }

            if (partHeight > 50) {
                ctx.save();
                ctx.translate(partX + 5, partY + partHeight / 2);
                ctx.rotate(-Math.PI / 2);
                ctx.fillStyle = '#ffffff';
                ctx.font = `${Math.max(10, 11 * scale)}px sans-serif`;
                ctx.textAlign = 'center';
                ctx.textBaseline = 'top';
                ctx.fillText(`${Math.round(part.height)}mm`, 0, 0);
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
    summaryTable.innerHTML = `
        <tr><th>Metric</th><th>Value</th></tr>
        <tr><td>Total Parts Instances</td><td>${g_reportData.summary.total_parts_instances || 0}</td></tr>
        <tr><td>Total Unique Part Types</td><td>${g_reportData.summary.total_unique_part_types || 0}</td></tr>
        <tr><td>Total Boards</td><td>${g_reportData.summary.total_boards || 0}</td></tr>
        <tr><td>Overall Efficiency</td><td>${(g_reportData.summary.overall_efficiency || 0).toFixed(2)}%</td></tr>
        <tr><td><strong>Total Project Cost</strong></td><td class="total-highlight"><strong>$${(g_reportData.summary.total_project_cost || 0).toFixed(2)}</strong></td></tr>
    `;

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

    const uniqueBoardTypesTable = document.getElementById('uniqueBoardTypesTable');
    if (uniqueBoardTypesTable) {
        uniqueBoardTypesTable.innerHTML = `
            <tr><th>Material</th><th>Dimensions</th><th>Count</th><th>Total Area (m²)</th><th>Price/Sheet</th><th>Total Cost</th></tr>
        `;
        if (g_reportData.unique_board_types) {
            g_reportData.unique_board_types.forEach(board_type => {
                uniqueBoardTypesTable.innerHTML += `
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
    }

    const boardsTable = document.getElementById('boardsTable');
    boardsTable.innerHTML = `
        <tr><th>Board#</th><th>Material</th><th>Size</th><th>Parts</th><th>Efficiency</th></tr>
    `;
    if (g_reportData.boards) {
        g_reportData.boards.forEach(board => {
            boardsTable.innerHTML += `
                <tr>
                    <td>${board.board_number}</td>
                    <td>${board.material}</td>
                    <td>${board.stock_size}</td>
                    <td class="total-highlight">${board.parts_count}</td>
                    <td>${board.efficiency.toFixed(2)}%</td>
                </tr>
            `;
        });
    }

    const partsTable = document.getElementById('partsTable');
    partsTable.innerHTML = `
        <tr><th>Unique ID</th><th>Name</th><th>Dimensions</th><th>Material</th><th>Board#</th></tr>
    `;
    const parts_list = g_reportData.parts_placed || g_reportData.parts || [];
    parts_list.forEach(part => {
        const partId = part.part_unique_id || part.part_number;
        const dimensionsStr = `${part.width.toFixed(0)} ├ù ${part.height.toFixed(0)}mm`;
        partsTable.innerHTML += `
            <tr data-part-id="${partId}" data-board-number="${part.board_number}">
                <td class="part-label-cell" onclick="scrollToPieceDiagram('${partId}', ${part.board_number})">${partId}</td>
                <td>${part.name}</td>
                <td class="part-dimensions-cell" onclick="scrollToPieceDiagram('${partId}', ${part.board_number})">${dimensionsStr}</td>
                <td>${part.material}</td>
                <td>${part.board_number}</td>
            </tr>
        `;
    });
    
    // Add click styling to make cells look clickable
    attachPartTableClickHandlers();
}

function getMaterialColor(material) {
    let hash = 0;
    for (let i = 0; i < material.length; i++) {
        hash = material.charCodeAt(i) + ((hash << 5) - hash);
    }
    const hue = Math.abs(hash) % 360;
    return `hsl(${hue}, 45%, 65%)`;
}

function getMaterialTexture(material) {
    if (material.toLowerCase().includes('wood') || material.toLowerCase().includes('chestnut')) {
        return 'repeating-linear-gradient(45deg, #8B4513, #8B4513 2px, #A0522D 2px, #A0522D 4px)';
    } else if (material.includes('240,240,240')) {
        return 'repeating-linear-gradient(90deg, #f0f0f0, #f0f0f0 3px, #e0e0e0 3px, #e0e0e0 6px)';
    }
    return getMaterialColor(material);
}

function scrollToDiagram(material) {
    // Sanitize material name for ID matching
    const sanitizedMaterial = material.replace(/[^a-zA-Z0-9]/g, '_');
    const diagrams = document.querySelectorAll(`[id^="diagram-${sanitizedMaterial}-"]`);
    if (diagrams.length > 0) {
        diagrams[0].scrollIntoView({ behavior: 'smooth', block: 'start' });
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

let scene, camera, renderer, controls, cube;
let showTexture = false, isOrthographic = false, currentPart = null;

function showPartModal(part) {
    const modal = document.getElementById('partModal');
    const modalCanvas = document.getElementById('modalCanvas');
    const modalInfo = document.getElementById('modalInfo');
    
    initThreeJS(part, modalCanvas);
    setupOrbitControls();
    
    modalInfo.innerHTML = `
        <h3>${part.name}</h3>
        <p><strong>Dimensions:</strong> ${part.width.toFixed(1)} ├ù ${part.height.toFixed(1)} ├ù ${part.thickness.toFixed(1)}mm</p>
        <p><strong>Area:</strong> ${(part.width * part.height / 1000000).toFixed(3)} m²</p>
        <p><strong>Material:</strong> ${part.material}</p>
        <p><strong>Grain Direction:</strong> ${part.grain_direction || 'Any'}</p>
        <p><strong>Rotated:</strong> ${part.rotated ? 'Yes' : 'No'}</p>
        <p style="color: #666; font-size: 12px;">Left drag: orbit | Middle/Shift+Left drag: pan | Scroll: zoom</p>
    `;
    
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

let resizerInitialized = false;

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
    
    resizer.addEventListener('mouseenter', () => {
        if (!isResizing) {
            resizer.style.cursor = 'col-resize';
        }
    });
}

function exportInteractiveHTML() {
    if (!g_boardsData || g_boardsData.length === 0 || !g_reportData) {
        alert('No data to export. Please generate a report first.');
        return;
    }

    // Complete CSS embedded in the HTML
    const completeCSS = `
        * { box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, Arial, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #ffffff;
            color: #222;
            display: flex;
            flex-direction: column;
            height: 100vh;
        }
        .header {
            background: linear-gradient(90deg, #005b9f 0%, #008ad6 100%);
            color: #fff;
            padding: 14px 18px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 1px solid rgba(0,0,0,0.06);
        }
        .header h1 {
            font-size: 1.8em;
            margin: 0;
            color: #ffffff !important;
        }
        button {
            background: linear-gradient(180deg,#00A5E3 0%, #008FCC 100%);
            color: #ffffff;
            border: none;
            padding: 10px 16px;
            border-radius: 10px;
            cursor: pointer;
            margin-left: 8px;
            box-shadow: 0 4px 10px rgba(0,0,0,0.08);
            font-weight: 600;
        }
        button:hover {
            filter: brightness(0.95);
        }
        .container {
            display: flex;
            flex-grow: 1;
            overflow: hidden;
        }
        .diagrams-container {
            flex: 1 1 auto;
            min-width: 300px;
            padding: 20px;
            background-color: #ffffff;
            border-right: 3px solid #ddd;
            overflow-y: auto;
            overflow-x: hidden;
            display: flex;
            flex-wrap: wrap;
            align-content: flex-start;
            gap: 20px;
        }
        .report-container {
            flex: 2 1 auto;
            min-width: 400px;
            padding: 18px;
            padding-right: 50px;
            background-color: #fff;
            overflow-y: auto;
            overflow-x: auto;
            border-left: 1px solid rgba(0,0,0,0.04);
        }
        .resizer {
            width: 8px;
            background: #ddd;
            cursor: col-resize;
            user-select: none;
            flex-shrink: 0;
            transition: background 0.2s;
        }
        .resizer:hover {
            background: #007bff;
        }
        .resizer:active {
            background: #0056b3;
        }
        .diagram-card {
            border: 1px solid #ccc;
            padding: 12px;
            background-color: #fbfdff;
            box-shadow: 0 6px 18px rgba(0,0,0,0.06);
            border-radius: 12px;
            flex: 0 0 auto;
            width: 100%;
        }
        .diagram-card h3 {
            font-size: 1.1em;
            margin-bottom: 6px;
            color: #006fb3;
        }
        .diagram-card p {
            font-size: 0.85em;
            color: #666;
            margin-bottom: 10px;
        }
        .diagram-canvas {
            border: 1px dashed #aaa;
            display: block;
            background-color: #fff;
            width: 100%;
            height: auto;
        }
        table {
            border-collapse: collapse;
            margin-bottom: 18px;
            font-size: 0.8em;
            width: auto;
            max-width: calc(100% - 30px);
            table-layout: auto;
            background: transparent;
        }
        th, td {
            border: 1px solid #ddd;
            padding: 6px;
            text-align: left;
            white-space: nowrap;
        }
        th {
            background-color: #f3f6f8;
            font-weight: 600;
            color: #034a6b;
        }
        h2 {
            margin-top: 20px;
            margin-bottom: 12px;
            color: #006fb3;
            font-size: 1.2em;
        }
        .material-item {
            display: inline-flex;
            align-items: center;
            margin: 4px 8px 4px 0;
            padding: 4px 8px;
            background: #ffffff;
            border-radius: 8px;
            border: 1px solid rgba(0,0,0,0.06);
            cursor: pointer;
        }
        .material-swatch {
            width: 20px;
            height: 20px;
            border: 1px solid rgba(0,0,0,0.08);
            margin-right: 8px;
            border-radius: 4px;
        }
        .material-name {
            font-size: 0.9em;
            font-weight: bold;
        }
        .material-price {
            font-size: 0.8em;
            color: #666;
            margin-left: 10px;
            font-weight: normal;
        }
        .total-highlight {
            background-color: #eaf7ff !important;
            font-weight: 700;
            color: #014f6e;
        }
        .modal {
            display: none;
            position: fixed;
            z-index: 1000;
            left: 0;
            top: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0,0,0,0.5);
        }
        .modal-content {
            background-color: #ffffff;
            margin: 5% auto;
            padding: 20px;
            border: 1px solid rgba(0,0,0,0.06);
            width: 520px;
            max-width: 92%;
            max-height: 80vh;
            border-radius: 12px;
            text-align: center;
            overflow-y: auto;
        }
        .close {
            color: #aaa;
            float: right;
            font-size: 28px;
            font-weight: bold;
            cursor: pointer;
            line-height: 1;
        }
        .close:hover, .close:focus {
            color: #000;
        }
        #modalCanvas {
            border: 1px solid #ddd;
            margin: 10px 0;
        }
        #modalInfo {
            text-align: left;
            margin-top: 15px;
        }
        #modalInfo h3 {
            margin-top: 0;
            color: #333;
        }
        #modalInfo p {
            margin: 5px 0;
            color: #666;
        }
        .modal-controls {
            text-align: center;
            margin-bottom: 10px;
        }
        .modal-controls button {
            margin: 0 5px;
            padding: 8px 16px;
            background: #007acc;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
        }
        .modal-controls button:hover {
            background: #005a9e;
        }
        .part-label-cell,
        .part-dimensions-cell {
            cursor: pointer;
            text-decoration: underline;
            color: #0066cc;
            transition: all 0.2s ease;
        }
        .part-label-cell:hover,
        .part-dimensions-cell:hover {
            background-color: #e3f2fd !important;
            font-weight: bold;
            color: #003d99;
        }
        .part-label-cell:active,
        .part-dimensions-cell:active {
            background-color: #bbdefb !important;
        }
        @media print {
            @page { margin: 0.75in; size: letter; }
            * { -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
            body { font-family: Arial, sans-serif; font-size: 11pt; line-height: 1.3; margin: 0; padding: 0; background: white; color: black; display: block; height: auto; }
            .header { text-align: center; background: none; color: black; border-bottom: 2pt solid #333; margin-bottom: 20pt; padding: 15pt 0; }
            .header h1 { font-size: 20pt; font-weight: bold; margin: 0; color: #333; }
            button, .resizer { display: none !important; }
            .container { display: block; width: 100%; }
            .diagrams-container { display: block; width: 100%; margin-bottom: 30pt; page-break-after: always; }
            .report-container { display: block; width: 100%; margin: 0; padding: 0; }
            .diagram-card { page-break-inside: avoid; margin-bottom: 20pt; border: 1pt solid #333; padding: 12pt; background: white; text-align: center; }
            .diagram-card h3 { font-size: 14pt; font-weight: bold; margin: 0 0 8pt 0; color: #333; }
            .diagram-card p { font-size: 10pt; margin: 0 0 12pt 0; color: #666; }
            .diagram-canvas { max-width: 100%; height: auto; border: 1pt solid #666; background: white; }
            h2 { font-size: 16pt; font-weight: bold; margin: 25pt 0 12pt 0; color: #333; border-bottom: 1pt solid #333; padding-bottom: 6pt; page-break-after: avoid; }
            table { width: 100%; border-collapse: collapse; margin-bottom: 20pt; font-size: 9pt; page-break-inside: auto; }
            th, td { border: 1pt solid #333; padding: 6pt 8pt; text-align: left; vertical-align: top; }
            th { background: #e8e8e8; font-weight: bold; font-size: 10pt; }
            tr { page-break-inside: avoid; }
        }
    `;

    const htmlContent = `<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AutoNestCut Interactive Report</title>
    <style>${completeCSS}</style>
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
            <h2>Unique Board Types</h2>
            <table id="uniqueBoardTypesTable"></table>
            <h2>Boards Summary</h2>
            <table id="boardsTable"></table>
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
    <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"><\/script>
    <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"><\/script>
    <script>
        // Embedded data - CRITICAL: Must be valid JSON
        let g_boardsData = ${JSON.stringify(g_boardsData)};
        let g_reportData = ${JSON.stringify(g_reportData)};
        
        // All functions embedded below
        ${getCompleteJSContent()}
        
        // Initialize on page load
        document.addEventListener('DOMContentLoaded', function() {
            try {
                renderDiagrams();
                renderReport();
                
                const modal = document.getElementById('partModal');
                const closeBtn = document.querySelector('.close');
                
                if (closeBtn) {
                    closeBtn.addEventListener('click', function() {
                        modal.style.display = 'none';
                    });
                }
                
                window.addEventListener('click', function(e) {
                    if (e.target === modal) {
                        modal.style.display = 'none';
                    }
                });
                
                initResizer();
            } catch (error) {
                console.error('Error initializing report:', error);
                console.error('g_boardsData:', g_boardsData);
                console.error('g_reportData:', g_reportData);
            }
        });
    </script>
</body>
</html>`;

    downloadHTML(htmlContent, 'AutoNestCut_Interactive_Report.html');
}

function getCompleteJSContent() {
    // All functions needed for the exported HTML
    return `
        let scene, camera, renderer, controls, cube;
        let showTexture = false, isOrthographic = false, currentPart = null;
        let currentHighlightedPiece = null;
        let currentHighlightedCanvas = null;
        
        // Calculate total project cost from unique board types
        function calculateTotalProjectCost() {
            if (!g_reportData || !g_reportData.unique_board_types) return 0;
            return g_reportData.unique_board_types.reduce((sum, board) => sum + (board.total_cost || 0), 0);
        }
        
        // Calculate overall efficiency from total areas
        function calculateOverallEfficiency() {
            if (!g_reportData || !g_reportData.unique_board_types || !g_reportData.unique_part_types) return 0;
            const totalPartsArea = g_reportData.unique_part_types.reduce((sum, part) => sum + (part.total_area || 0), 0);
            const totalBoardsArea = g_reportData.unique_board_types.reduce((sum, board) => sum + (board.total_area || 0), 0);
            if (totalBoardsArea === 0) return 0;
            return (totalPartsArea / totalBoardsArea) * 100;
        }
        
        ${getMaterialColor.toString()}
        
        ${getMaterialTexture.toString()}
        
        ${renderDiagrams.toString()}
        
        function renderReport() {
            if (!g_reportData) return;

            const summaryTable = document.getElementById('summaryTable');
            const totalCost = calculateTotalProjectCost();
            const efficiency = calculateOverallEfficiency();
            
            summaryTable.innerHTML = \`
                <tr><th>Metric</th><th>Value</th></tr>
                <tr><td>Total Parts Instances</td><td>\${g_reportData.summary.total_parts_instances || 0}</td></tr>
                <tr><td>Total Unique Part Types</td><td>\${g_reportData.summary.total_unique_part_types || 0}</td></tr>
                <tr><td>Total Boards</td><td>\${g_reportData.summary.total_boards || 0}</td></tr>
                <tr><td>Overall Efficiency</td><td>\${efficiency.toFixed(2)}%</td></tr>
                <tr><td><strong>Total Project Cost</strong></td><td class="total-highlight"><strong>$\${totalCost.toFixed(2)}</strong></td></tr>
            \`;

            const materialsContainer = document.getElementById('materialsContainer');
            if (materialsContainer && g_reportData.unique_board_types) {
                materialsContainer.innerHTML = g_reportData.unique_board_types.map((board_type, index) => \`
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

            const uniqueBoardTypesTable = document.getElementById('uniqueBoardTypesTable');
            if (uniqueBoardTypesTable) {
                uniqueBoardTypesTable.innerHTML = \`
                    <tr><th>Material</th><th>Dimensions</th><th>Count</th><th>Total Area (m²)</th><th>Price/Sheet</th><th>Total Cost</th></tr>
                \`;
                if (g_reportData.unique_board_types) {
                    g_reportData.unique_board_types.forEach(board_type => {
                        uniqueBoardTypesTable.innerHTML += \`
                            <tr>
                                <td>\${board_type.material}</td>
                                <td>\${board_type.dimensions}</td>
                                <td class="total-highlight">\${board_type.count}</td>
                                <td>\${(board_type.total_area / 1000000).toFixed(3)}</td>
                                <td>$\${(board_type.price_per_sheet || 0).toFixed(2)}</td>
                                <td class="total-highlight">$\${(board_type.total_cost || 0).toFixed(2)}</td>
                            </tr>
                        \`;
                    });
                }
            }

            const boardsTable = document.getElementById('boardsTable');
            boardsTable.innerHTML = \`
                <tr><th>Board#</th><th>Material</th><th>Size</th><th>Parts</th><th>Efficiency</th></tr>
            \`;
            if (g_reportData.boards) {
                g_reportData.boards.forEach(board => {
                    boardsTable.innerHTML += \`
                        <tr>
                            <td>\${board.board_number}</td>
                            <td>\${board.material}</td>
                            <td>\${board.stock_size}</td>
                            <td class="total-highlight">\${board.parts_count}</td>
                            <td>\${board.efficiency.toFixed(2)}%</td>
                        </tr>
                    \`;
                });
            }

            const partsTable = document.getElementById('partsTable');
            partsTable.innerHTML = \`
                <tr><th>Unique ID</th><th>Name</th><th>Dimensions</th><th>Material</th><th>Board#</th></tr>
            \`;
            const parts_list = g_reportData.parts_placed || g_reportData.parts || [];
            parts_list.forEach(part => {
                const partId = part.part_unique_id || part.part_number;
                const dimensionsStr = \`\${part.width.toFixed(0)} ├ù \${part.height.toFixed(0)}mm\`;
                partsTable.innerHTML += \`
                    <tr data-part-id="\${partId}" data-board-number="\${part.board_number}">
                        <td class="part-label-cell" onclick="scrollToPieceDiagram('\${partId}', \${part.board_number})">\${partId}</td>
                        <td>\${part.name}</td>
                        <td class="part-dimensions-cell" onclick="scrollToPieceDiagram('\${partId}', \${part.board_number})">\${dimensionsStr}</td>
                        <td>\${part.material}</td>
                        <td>\${part.board_number}</td>
                    </tr>
                \`;
            });
            
            attachPartTableClickHandlers();
        }
        
        ${scrollToDiagram.toString()}
        
        ${scrollToPieceDiagram.toString()}
        
        ${highlightPieceOnCanvas.toString()}
        
        ${clearPieceHighlight.toString()}
        
        ${redrawCanvasDiagram.toString()}
        
        ${attachPartTableClickHandlers.toString()}
        
        ${handleCanvasClick.toString()}
        
        ${handleCanvasHover.toString()}
        
        ${showPartModal.toString()}
        
        ${initThreeJS.toString()}
        
        ${setupOrbitControls.toString()}
        
        ${animate.toString()}
        
        function initResizer() {
            const resizer = document.getElementById('resizer');
            const leftSide = document.getElementById('diagramsContainer');
            const rightSide = document.getElementById('reportContainer');
            
            if (!resizer || !leftSide || !rightSide) return;
            
            let isResizing = false;
            
            resizer.addEventListener('mousedown', (e) => {
                isResizing = true;
                document.body.style.cursor = 'col-resize';
                document.body.style.userSelect = 'none';
            });
            
            document.addEventListener('mousemove', (e) => {
                if (!isResizing) return;
                
                const container = document.querySelector('.container');
                const containerRect = container.getBoundingClientRect();
                const newLeftWidth = e.clientX - containerRect.left;
                const totalWidth = containerRect.width;
                
                if (newLeftWidth > 200 && totalWidth - newLeftWidth > 300) {
                    leftSide.style.flex = \`0 0 \${newLeftWidth}px\`;
                    rightSide.style.flex = \`1 1 auto\`;
                }
            });
            
            document.addEventListener('mouseup', () => {
                if (isResizing) {
                    isResizing = false;
                    document.body.style.cursor = '';
                    document.body.style.userSelect = '';
                }
            });
        }
    `;
}

function downloadHTML(content, filename) {
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
    alert('Interactive HTML report exported successfully!');
}

let showTreeView = false;
let treeNodeId = 0;
let expandedNodes = new Set();
let searchTerm = '';
function toggleTreeView() {
    showTreeView = !showTreeView;
    const button = document.getElementById('treeToggle');
    const treeContainer = document.getElementById('treeStructure');
    const searchContainer = document.getElementById('treeSearchContainer');
    
    if (showTreeView) {
        button.textContent = 'Hide Tree Structure';
        treeContainer.style.display = 'block';
        searchContainer.style.display = 'flex';
        renderTreeStructure();
    } else {
        button.textContent = 'Show Tree Structure';
        treeContainer.style.display = 'none';
        searchContainer.style.display = 'none';
    }
}

function renderTreeStructure() {
    const container = document.getElementById('treeStructure');
    if (!window.hierarchyTree || window.hierarchyTree.length === 0) {
        container.innerHTML = '<p>No hierarchy data available.</p>';
        return;
    }

    treeNodeId = 0;
    let html = '<div class="tree-header">Model Structure:</div>';
    html += '<div class="tree">';

    window.hierarchyTree.forEach(node => {
        html += renderTreeNode(node, 1);
    });

    html += '</div>';
    container.innerHTML = html;

    // Attach click handlers to buttons for toggling nodes
    container.querySelectorAll('button.node-button').forEach(btn => {
        const id = btn.dataset.nodeId;
        if (!id) return;
        // Only add listener for nodes that have a children container
        const children = document.getElementById(`children-${id}`);
        if (children) {
            btn.addEventListener('click', () => toggleNode(id));
        }
    });

    if (searchTerm) {
        filterTreeNodes();
    }
}

function renderTreeNode(node, level) {
    const hasChildren = node.children && node.children.length > 0;
    const nodeId = `tree-node-${treeNodeId++}`;

    let html = `<div class="tree-node" data-node-id="${nodeId}" data-level="${level}">`;
    html += `<div class="tree-item level-${Math.min(level,7)}">`;

    const btnClass = hasChildren ? '' : 'no-children';
    // Use a button for accessibility and consistent focus behavior
    html += `<button class="node-button ${btnClass}" data-node-id="${nodeId}">${escapeHtml(node.name || '')}</button>`;
    html += `</div>`;

    if (hasChildren) {
        html += `<div class="children" id="children-${nodeId}">`;
        node.children.forEach(child => {
            html += renderTreeNode(child, level + 1);
        });
        html += `</div>`;
    }

    html += `</div>`;
    return html;
}

// Simple HTML escape to avoid injection from model names
function escapeHtml(str) {
    return str.replace(/[&<>\"']/g, function (c) {
        return {'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":"&#39;"}[c];
    });
}

function toggleNode(nodeId) {
    const childrenContainer = document.getElementById(`children-${nodeId}`);
    const button = document.querySelector(`button[data-node-id="${nodeId}"]`);

    if (!childrenContainer || !button) return;

    const isExpanded = childrenContainer.classList.contains('expanded');
    if (isExpanded) {
        childrenContainer.classList.remove('expanded');
        button.classList.remove('expanded');
        expandedNodes.delete(nodeId);
    } else {
        childrenContainer.classList.add('expanded');
        button.classList.add('expanded');
        expandedNodes.add(nodeId);
    }
}

function expandAll() {
    document.querySelectorAll('.children').forEach(child => child.classList.add('expanded'));
    document.querySelectorAll('button.node-button').forEach(btn => btn.classList.add('expanded'));
    document.querySelectorAll('.tree-node').forEach(node => {
        const id = node.dataset.nodeId;
        if (id) expandedNodes.add(id);
    });
}

function collapseAll() {
    document.querySelectorAll('.children').forEach(child => child.classList.remove('expanded'));
    document.querySelectorAll('button.node-button').forEach(btn => btn.classList.remove('expanded'));
    expandedNodes.clear();
}

function filterTree() {
    searchTerm = document.getElementById('treeSearch').value.toLowerCase();
    filterTreeNodes();
}

function filterTreeNodes() {
    const nodes = document.querySelectorAll('.tree-node');

    if (!searchTerm) {
        nodes.forEach(node => {
            node.style.display = 'block';
            node.classList.remove('search-highlight');
        });
        return;
    }

    nodes.forEach(node => {
        const button = node.querySelector('.node-button');
        const text = (button ? button.textContent : '').toLowerCase();
        const matches = text.includes(searchTerm);

        if (matches) {
            node.style.display = 'block';
            node.classList.add('search-highlight');
            expandParentNodes(node);
        } else {
            node.style.display = 'none';
            node.classList.remove('search-highlight');
        }
    });
}

function expandParentNodes(node) {
    let parent = node.parentElement;
    while (parent) {
        if (parent.classList && parent.classList.contains('children')) {
            parent.classList.add('expanded');
            const parentNode = parent.previousElementSibling;
            if (parentNode) {
                const btn = parentNode.querySelector('button.node-button');
                if (btn) btn.classList.add('expanded');
            }
            const nodeId = parent.id && parent.id.replace('children-', '');
            if (nodeId) expandedNodes.add(nodeId);
        }
        parent = parent.parentElement;
    }
}

function clearTreeSearch() {
    const input = document.getElementById('treeSearch');
    if (input) input.value = '';
    searchTerm = '';
    filterTreeNodes();
}

// Track currently highlighted piece for piece diagram navigation
let currentHighlightedPiece = null;
let currentHighlightedCanvas = null;

function scrollToPieceDiagram(partId, boardNumber) {
    // Find the board diagram that contains this piece
    const boardIndex = boardNumber - 1; // Convert to 0-based index
    
    if (boardIndex < 0 || boardIndex >= g_boardsData.length) {
        console.warn(`Board ${boardNumber} not found`);
        return;
    }
    
    const board = g_boardsData[boardIndex];
    const diagramContainer = document.getElementById('diagramsContainer');
    
    if (!diagramContainer) {
        console.warn('Diagrams container not found');
        return;
    }
    
    // Find the canvas for this board
    const diagrams = diagramContainer.querySelectorAll('.diagram-card');
    let targetCanvas = null;
    let targetCard = null;
    
    if (boardIndex < diagrams.length) {
        targetCard = diagrams[boardIndex];
        targetCanvas = targetCard.querySelector('canvas');
    }
    
    if (!targetCanvas) {
        console.warn(`Canvas for board ${boardNumber} not found`);
        return;
    }
    
    // Clear previous highlight
    clearPieceHighlight();
    
    // Find the piece in the canvas data
    if (targetCanvas.partData) {
        for (let partData of targetCanvas.partData) {
            const partLabel = String(partData.part.instance_id || `P${partData.part.index || 0}`);
            if (partLabel === partId) {
                // Highlight this piece on the canvas
                highlightPieceOnCanvas(targetCanvas, partData);
                currentHighlightedPiece = partId;
                currentHighlightedCanvas = targetCanvas;
                break;
            }
        }
    }
    
    // Scroll the diagram card into view
    if (targetCard) {
        targetCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
}

function highlightPieceOnCanvas(canvas, partData) {
    // Redraw the canvas with the piece highlighted
    const ctx = canvas.getContext('2d');

    // Store original drawing function if not already stored
    if (!canvas.originalDraw) {
        canvas.originalDraw = canvas.toDataURL();
    }

    // Add a visual highlight by drawing a border around the piece
    ctx.strokeStyle = '#007bff';
    ctx.lineWidth = 3;

    // Draw highlight border
    ctx.strokeRect(
        partData.x - 2,
        partData.y - 2,
        partData.width + 4,
        partData.height + 4
    );
}

function clearPieceHighlight() {
    if (currentHighlightedCanvas) {
        // Redraw the canvas to remove highlight
        const board = g_boardsData[currentHighlightedCanvas.boardIndex];
        if (board) {
            // Redraw the entire diagram
            redrawCanvasDiagram(currentHighlightedCanvas, board);
        }
        currentHighlightedCanvas = null;
        currentHighlightedPiece = null;
    }
}

function redrawCanvasDiagram(canvas, board) {
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
    ctx.font = `${Math.max(12, 14 * scale)}px Arial`;
    ctx.textAlign = 'center';
    ctx.fillText(`${board.stock_width.toFixed(0)}mm`, padding + (board.stock_width * scale) / 2, padding - 5);
    
    ctx.save();
    ctx.translate(padding - 15, padding + (board.stock_height * scale) / 2);
    ctx.rotate(-Math.PI / 2);
    ctx.fillText(`${board.stock_height.toFixed(0)}mm`, 0, 0);
    ctx.restore();

    const parts = board.parts || [];
    canvas.partData = [];
    
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

        canvas.partData.push({
            x: partX, y: partY, width: partWidth, height: partHeight,
            part: part, boardIndex: board.index || 0
        });

        if (partWidth > 30 && partHeight > 20) {
            ctx.fillStyle = '#ffffff';
            ctx.font = `bold ${Math.max(12, 14 * scale)}px sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'middle';
            const labelContent = String(part.instance_id || `P${partIndex + 1}`);
            const maxChars = Math.max(6, Math.floor(partWidth / 8));
            const displayLabel = labelContent.length > maxChars ? labelContent.slice(0, maxChars - 1) + 'ÔÇª' : labelContent;
            ctx.fillText(displayLabel, partX + partWidth / 2, partY + partHeight / 2);
        }

        if (partWidth > 50) {
            ctx.fillStyle = '#ffffff';
            ctx.font = `${Math.max(10, 11 * scale)}px sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'top';
            ctx.fillText(`${Math.round(part.width)}mm`, partX + partWidth / 2, partY + 5);
        }

        if (partHeight > 50) {
            ctx.save();
            ctx.translate(partX + 5, partY + partHeight / 2);
            ctx.rotate(-Math.PI / 2);
            ctx.fillStyle = '#ffffff';
            ctx.font = `${Math.max(10, 11 * scale)}px sans-serif`;
            ctx.textAlign = 'center';
            ctx.textBaseline = 'top';
            ctx.fillText(`${Math.round(part.height)}mm`, 0, 0);
            ctx.restore();
        }
    });
}

function attachPartTableClickHandlers() {
    // Add hover styling to make cells look clickable
    const partLabelCells = document.querySelectorAll('.part-label-cell, .part-dimensions-cell');
    partLabelCells.forEach(cell => {
        cell.style.cursor = 'pointer';
        cell.style.textDecoration = 'underline';
        cell.style.color = '#0066cc';
        
        cell.addEventListener('mouseenter', function() {
            this.style.backgroundColor = '#e3f2fd';
            this.style.fontWeight = 'bold';
        });
        
        cell.addEventListener('mouseleave', function() {
            this.style.backgroundColor = '';
            this.style.fontWeight = '';
        });
    });
}

// Preview and Export Management
let pendingExportType = null;

function showExportPreview(exportType) {
    pendingExportType = exportType;
    const previewModal = document.getElementById('previewModal');
    const previewContent = document.getElementById('previewContent');
    
    let previewHTML = '';
    
    if (exportType === 'pdf' || exportType === 'print') {
        previewHTML = generatePDFPreview();
    } else if (exportType === 'csv') {
        previewHTML = generateCSVPreview();
    } else if (exportType === 'html') {
        previewHTML = '<p>Interactive HTML report will be exported with all diagrams and data embedded.</p>';
    }
    
    previewContent.innerHTML = previewHTML;
    previewModal.style.display = 'block';
}

function generatePDFPreview() {
    let html = '<h3>PDF Report Preview</h3>';
    html += '<p><strong>Report Title:</strong> AutoNestCut Report</p>';
    html += '<p><strong>Format:</strong> Professional PDF with diagrams and tables</p>';
    html += '<h3>Report Sections:</h3>';
    html += '<ul style="text-align: left;">';
    html += '<li>Overall Summary (Efficiency, Cost, Parts Count)</li>';
    html += '<li>Cutting Diagrams (All boards with piece layouts)</li>';
    html += '<li>Materials Used</li>';
    html += '<li>Unique Part Types</li>';
    html += '<li>Unique Board Types</li>';
    html += '<li>Boards Summary</li>';
    html += '<li>Parts Placed (Detailed List)</li>';
    html += '</ul>';
    return html;
}

function generateCSVPreview() {
    let html = '<h3>CSV Report Preview</h3>';
    html += '<p><strong>Format:</strong> Comma-separated values for spreadsheet applications</p>';
    html += '<h3>Included Data:</h3>';
    html += '<ul style="text-align: left;">';
    html += '<li>Summary metrics</li>';
    html += '<li>Board information</li>';
    html += '<li>Part details</li>';
    html += '<li>Material specifications</li>';
    html += '</ul>';
    html += '<p><strong>Compatible with:</strong> Excel, Google Sheets, LibreOffice Calc</p>';
    return html;
}

function confirmExport() {
    if (pendingExportType === 'pdf' || pendingExportType === 'print') {
        window.print();
    } else if (pendingExportType === 'csv') {
        sketchup.export_csv();
    } else if (pendingExportType === 'html') {
        exportInteractiveHTML();
    }
    
    document.getElementById('previewModal').style.display = 'none';
    pendingExportType = null;
}

document.addEventListener('DOMContentLoaded', () => {
    const partModal = document.getElementById('partModal');
    const previewModal = document.getElementById('previewModal');
    const closeButtons = document.querySelectorAll('.close');

    closeButtons.forEach(btn => {
        btn.addEventListener('click', (e) => {
            if (e.target.closest('#partModal')) {
                if (partModal) partModal.style.display = 'none';
            } else if (e.target.closest('#previewModal')) {
                if (previewModal) previewModal.style.display = 'none';
            }
        });
    });

    window.addEventListener('click', (e) => {
        if (partModal && e.target === partModal) {
            partModal.style.display = 'none';
        }
        if (previewModal && e.target === previewModal) {
            previewModal.style.display = 'none';
        }
    });

    // Setup export button handlers
    const printBtn = document.getElementById('printButton');
    if (printBtn) {
        printBtn.addEventListener('click', () => {
            showExportPreview('pdf');
        });
    }

    const exportCsvBtn = document.getElementById('exportCsvButton');
    if (exportCsvBtn) {
        exportCsvBtn.addEventListener('click', () => {
            showExportPreview('csv');
        });
    }

    const exportHtmlBtn = document.getElementById('exportHtmlButton');
    if (exportHtmlBtn) {
        exportHtmlBtn.addEventListener('click', () => {
            showExportPreview('html');
        });
    }

    // Setup preview modal buttons
    const confirmExportBtn = document.getElementById('confirmExportBtn');
    if (confirmExportBtn) {
        confirmExportBtn.addEventListener('click', confirmExport);
    }

    const cancelExportBtn = document.getElementById('cancelExportBtn');
    if (cancelExportBtn && previewModal) {
        cancelExportBtn.addEventListener('click', () => {
            previewModal.style.display = 'none';
            pendingExportType = null;
        });
    }

    initResizer();
    setTimeout(() => {
        callRuby('ready');
    }, 100);
});
