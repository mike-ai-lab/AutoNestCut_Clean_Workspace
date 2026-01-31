// ============================================================================
// DIAGRAMS_REPORT.JS LOADED - VERSION 20250201_RUBY_FIX
// ============================================================================
console.log('🚀🚀🚀 diagrams_report.js LOADED - VERSION 20250201_RUBY_FIX 🚀🚀🚀');
console.log('🚀 File timestamp:', new Date().toISOString());

// Global formatting utility - put this at the top of the script or in a global utility file.
// This ensures consistency across all numeric displays affected by precision settings.

// Ensure window.currencySymbols and other globals are defined if app.js hasn't done so
// This prevents "Cannot read properties of undefined" errors if app.js loads later or fails.
window.currencySymbols = window.currencySymbols || {
    'USD': '$',
    'EUR': 'Ôé¼',
    'GBP': '┬ú',
    'JPY': '┬Ñ',
    'CAD': '$',
    'AUD': '$',
    'CHF': 'CHF',
    'CNY': '┬Ñ',
    'SEK': 'kr',
    'NZD': '$',
    'SAR': 'SAR', // Added SAR
    // Add other common currencies as needed
};

// Also ensure other critical globals expected from app.js are initialized
window.currentUnits = window.currentUnits || 'mm';
window.currentPrecision = window.currentPrecision ?? 1; // Use nullish coalescing for precision
window.currentAreaUnits = window.currentAreaUnits || 'm2'; // Ensure this is also global

// ============================================================================
// UNIT SYSTEM DEBUG LOGGER
// ============================================================================
function debugUnitSystem(section, data = {}) {
    const debugInfo = {
        section: section,
        timestamp: new Date().toISOString(),
        currentUnits: window.currentUnits,
        currentPrecision: window.currentPrecision,
        currentAreaUnits: window.currentAreaUnits,
        defaultCurrency: window.defaultCurrency,
        ...data
    };
    
    console.log(`🔍 [UNIT DEBUG] ${section}:`, debugInfo);
    
    // Check for hardcoded units
    if (data.detectedUnit && data.detectedUnit !== window.currentUnits) {
        console.warn(`⚠️ [UNIT MISMATCH] ${section}: Using "${data.detectedUnit}" but settings say "${window.currentUnits}"`);
    }
}

window.areaFactors = window.areaFactors || {
    'mm2': 1,
    'cm2': 100,
    'm2': 1000000,
    'in2': 645.16, // Factor for converting from mm² to in² (1 in² = 645.16 mm²)
    'ft2': 92903.04, // Factor for converting from mm² to ft² (1 ft² = 92903.04 mm²)
};
window.unitFactors = window.unitFactors || { // Unit factors for linear dimensions (mm as base)
    'mm': 1,
    'cm': 10,
    'm': 1000,
    'in': 25.4,
    'ft': 304.8
};
window.defaultCurrency = window.defaultCurrency || 'USD';


function getAreaDisplay(areaMM2) {
    // Using currentAreaUnits and areaFactors from app.js globals
    const units = window.currentAreaUnits || 'm2';
    // The factor needs to divide areaMM2 to convert to target area unit.
    // e.g., if areaMM2 is 1,000,000 and units is 'm2', factor is 1,000,000. 1,000,000 / 1,000,000 = 1 m2
    const factor = window.areaFactors[units] || window.areaFactors['m2']; // Fallback to m2 factor
    const convertedArea = areaMM2 / factor;
    // Return formatted number only, unit is in the header
    return formatNumber(convertedArea, window.currentPrecision); 
}

function formatAreaForPDF(areaMM2) {
    const units = window.currentAreaUnits || 'm2';
    const areaLabels = { mm2: 'mm²', cm2: 'cm²', m2: 'm²', in2: 'in²', ft2: 'ft²' };
    const factor = window.areaFactors[units] || window.areaFactors['m2']; 
    const convertedArea = areaMM2 / factor;
    return `${formatNumber(convertedArea, window.currentPrecision)} ${areaLabels[units]}`;
}

function getAreaUnitLabel() {
    // This function can be more complex if you have specific labels for units.
    // For now, it will just return 'm2', 'mm2', etc.
    // It should ideally return a displayable string like 'm²'
    const unitMap = {
        'mm2': 'mm²',
        'cm2': 'cm²',
        'm2': 'm²',
        'in2': 'in²',
        'ft2': 'ft²'
    };
    return unitMap[window.currentAreaUnits] || window.currentAreaUnits || 'm²';
}


function formatNumber(value, precision) {
    if (typeof value !== 'number' || isNaN(value) || value === null) { // Handle null, undefined, NaN
        return '-'; // Return placeholder for invalid numbers
    }
    
    // Explicitly check for 0 or string '0' to use Math.round for no decimal places.
    // This correctly renders 800 instead of 800.0 when precision is 0.
    const actualPrecision = (precision === 0 || precision === '0' || precision === 0.0) ? 0 : (typeof precision === 'number' ? precision : parseFloat(precision));
    
    if (isNaN(actualPrecision) || actualPrecision < 0) {
        console.warn('Invalid precision provided to formatNumber, defaulting to 1 decimal:', precision);
        return value.toFixed(1); // Default to 1 decimal place if precision is invalid
    }
    
    return value.toFixed(actualPrecision);
}

// HTML escaping function to prevent XSS vulnerabilities
function escapeHtml(text) {
    if (typeof text !== 'string') {
        return String(text || '');
    }
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function callRuby(method, args) {
    if (typeof sketchup === 'object' && sketchup[method]) {
        sketchup[method](args);
    }
}

let g_boardsData = [];
let g_reportData = null;
let currentHighlightedPiece = null;
let currentHighlightedCanvas = null;

// 3D Viewer globals (removed - now using unified Assembly 3D Viewer)
// Old modal-based viewer variables removed: modalScene, modalCamera, modalRenderer, modalControls, currentPart

function receiveData(data) {
    console.log('╔════════════════════════════════════════════════════════════════╗');
    console.log('║ RECEIVE DATA - FRONTEND ENTRY POINT                            ║');
    console.log('╚═════════════════════════════════════════════════════���══════════╝');
    console.log('📥 Data received from Ruby backend');
    console.log('📊 Data type:', typeof data);
    console.log('📋 Data keys:', data ? Object.keys(data) : 'NULL/UNDEFINED');
    console.log('📈 Full data object:', data);
    
    if (!data) {
        console.error('❌ CRITICAL: Data is NULL or UNDEFINED!');
        return;
    }
    
    console.log('✓ Data exists');
    console.log('  - diagrams:', data.diagrams ? `${data.diagrams.length} boards` : 'MISSING');
    console.log('  - report:', data.report ? 'EXISTS' : 'MISSING');
    console.log('  - assembly_data:', data.assembly_data ? 'EXISTS' : 'MISSING');
    console.log('  - original_components:', data.original_components ? `${data.original_components.length} items` : 'MISSING');
    console.log('  - hierarchy_tree:', data.hierarchy_tree ? `${data.hierarchy_tree.length} items` : 'MISSING');
    
    g_boardsData = data.diagrams || [];
    g_reportData = data.report;
    window.originalComponents = data.original_components || [];
    window.hierarchyTree = data.hierarchy_tree || [];
    window.assemblyData = data.assembly_data || null;
    
    console.log('✓ Global variables assigned:');
    console.log('  - g_boardsData:', g_boardsData.length, 'boards');
    console.log('  - g_reportData:', g_reportData ? 'SET' : 'NULL');
    console.log('  - window.assemblyData:', window.assemblyData ? 'SET' : 'NULL');
    console.log('  - window.hierarchyTree:', window.hierarchyTree.length, 'items');
    
    if (g_reportData && g_reportData.summary) {
        window.currentUnits = g_reportData.summary.units || 'mm';
        window.currentPrecision = g_reportData.summary.precision ?? 1;
        window.defaultCurrency = g_reportData.summary.currency || 'USD';
        window.currentAreaUnits = g_reportData.summary.area_units || 'm2';
        console.log('═══════════════════════════════════════════════════════════');
        console.log('🔧 FRONTEND SETTINGS DEBUG');
        console.log('═══════════════════════════════════════════════════════════');
        console.log('✓ Report summary settings loaded:');
        console.log('  - Units:', window.currentUnits);
        console.log('  - Precision:', window.currentPrecision);
        console.log('  - Currency:', window.defaultCurrency);
        console.log('  - Area Units:', window.currentAreaUnits);
        console.log('  - Unit Factors:', window.unitFactors);
        console.log('');
        console.log('🧪 CONVERSION TEST:');
        console.log('  - 300mm in current units:', (300 / window.unitFactors[window.currentUnits]).toFixed(window.currentPrecision), window.currentUnits);
        console.log('  - 2440mm in current units:', (2440 / window.unitFactors[window.currentUnits]).toFixed(window.currentPrecision), window.currentUnits);
        console.log('═══════════════════════════════════════════════════════════');
        
        // Update the unit debug display
        if (typeof updateUnitDebugDisplay === 'function') {
            updateUnitDebugDisplay();
        }
    } else {
        console.error('⚠️  No report summary found or g_reportData is null!');
        console.error('g_reportData:', g_reportData);
    }

    console.log('🎨 Calling renderDiagrams()...');
    try {
        renderDiagrams();
        console.log('✓ renderDiagrams() completed');
    } catch (e) {
        console.error('❌ renderDiagrams() failed:', e);
    }
    
    console.log('📊 Calling renderReport()...');
    try {
        renderReport();
        console.log('✓ renderReport() completed');
    } catch (e) {
        console.error('❌ renderReport() failed:', e);
    }
    
    if (window.assemblyData && window.assemblyData.views) {
        console.log('🏗️  Calling renderAssemblyViews()...');
        try {
            renderAssemblyViews(window.assemblyData);
            console.log('✓ renderAssemblyViews() completed');
        } catch (e) {
            console.error('❌ renderAssemblyViews() failed:', e);
        }
    } else {
        console.log('⚠️  No assembly data to render');
    }
    
    setTimeout(() => {
        if (typeof validateExports === 'function') {
            console.log('🔍 Calling validateExports()...');
            try {
                validateExports();
                console.log('✓ validateExports() completed');
            } catch (e) {
                console.error('❌ validateExports() failed:', e);
            }
        }
    }, 500);
    
    console.log('╔════════════════════════════════════════════════════════════════╗');
    console.log('║ RECEIVE DATA - COMPLETE                                        ║');
    console.log('╚════════════════════════════════════════════════════════════════╝');
}

function convertDimension(value, fromUnit, toUnit) {
    if (fromUnit === toUnit) return value;
    const valueInMM = value * window.unitFactors[fromUnit];
    return valueInMM / window.unitFactors[toUnit];
}

function renderDiagrams() {
    const container = document.getElementById('diagramsContainer');
    if (!container) {
        return;
    }
    
    container.innerHTML = '';

    if (!g_boardsData || g_boardsData.length === 0) {
        container.innerHTML = '<p>No cutting diagrams to display. Please generate a cut list first.</p>';
        return;
    }
    
    console.log('\n=== DIAGRAMS RENDER DEBUG ===');
    console.log('Number of boards:', g_boardsData.length);
    g_boardsData.forEach((board, idx) => {
        console.log(`Board ${idx + 1} material: "${board.material}"`);
    });
    console.log('=============================\n');

    // Use report-specific units and precision
    const reportUnits = window.currentUnits || 'mm';
    const reportPrecision = window.currentPrecision ?? 1; 

    g_boardsData.forEach((board, boardIndex) => {
        const card = document.createElement('div');
        card.className = 'diagram-card';

        const boardMaterial = board.material || 'Unknown Material';
        console.log(`\nDiagram ${boardIndex + 1} - Material: "${boardMaterial}"`);

        // Create header with title
        const header = document.createElement('div');
        header.className = 'diagram-header';
        
        const title = document.createElement('h3');
        title.textContent = `Board ${boardIndex + 1}`;
        title.id = `diagram-${String(boardMaterial).replace(/[^a-zA-Z0-9]/g, '_')}-${boardIndex}`;
        header.appendChild(title);
        
        // Create tags container with Lucide icons
        const tagsContainer = document.createElement('div');
        tagsContainer.className = 'diagram-tags';
        
        // Material tag with Package icon
        const materialTag = document.createElement('div');
        materialTag.className = 'diagram-tag material-tag';
        materialTag.innerHTML = `
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="m7.5 4.27 9 5.15"></path>
                <path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"></path>
                <path d="m3.3 7 8.7 5 8.7-5"></path>
                <path d="M12 22V12"></path>
            </svg>
            <span>${boardMaterial}</span>
        `;
        tagsContainer.appendChild(materialTag);
        
        // Dimensions tag with Maximize icon
        const width = board.stock_width / window.unitFactors[reportUnits];
        const height = board.stock_height / window.unitFactors[reportUnits];
        const dimensionsTag = document.createElement('div');
        dimensionsTag.className = 'diagram-tag dimensions-tag';
        dimensionsTag.innerHTML = `
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M8 3H5a2 2 0 0 0-2 2v3"></path>
                <path d="M21 8V5a2 2 0 0 0-2-2h-3"></path>
                <path d="M3 16v3a2 2 0 0 0 2 2h3"></path>
                <path d="M16 21h3a2 2 0 0 0 2-2v-3"></path>
            </svg>
            <span>${formatNumber(width, reportPrecision)} × ${formatNumber(height, reportPrecision)} ${reportUnits}</span>
        `;
        tagsContainer.appendChild(dimensionsTag);
        
        // Thickness tag with Layers icon
        const thickness = board.thickness || (board.parts_on_board && board.parts_on_board.length > 0 ? board.parts_on_board[0].thickness : 18);
        const thicknessTag = document.createElement('div');
        thicknessTag.className = 'diagram-tag thickness-tag';
        thicknessTag.innerHTML = `
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="m12.83 2.18a2 2 0 0 0-1.66 0L2.6 6.08a1 1 0 0 0 0 1.83l8.58 3.91a2 2 0 0 0 1.66 0l8.58-3.9a1 1 0 0 0 0-1.83Z"></path>
                <path d="m22 17.65-9.17 4.16a2 2 0 0 1-1.66 0L2 17.65"></path>
                <path d="m22 12.65-9.17 4.16a2 2 0 0 1-1.66 0L2 12.65"></path>
            </svg>
            <span>${formatNumber(thickness / window.unitFactors[reportUnits], reportPrecision)} ${reportUnits}</span>
        `;
        tagsContainer.appendChild(thicknessTag);
        
        // Efficiency tag with TrendingUp icon
        const efficiencyTag = document.createElement('div');
        efficiencyTag.className = 'diagram-tag efficiency-tag';
        const efficiencyValue = board.efficiency_percentage || 0;
        const efficiencyClass = efficiencyValue >= 80 ? 'high' : efficiencyValue >= 60 ? 'medium' : 'low';
        efficiencyTag.classList.add(`efficiency-${efficiencyClass}`);
        efficiencyTag.innerHTML = `
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="22 7 13.5 15.5 8.5 10.5 2 17"></polyline>
                <polyline points="16 7 22 7 22 13"></polyline>
            </svg>
            <span>${formatNumber(efficiencyValue, 1)}% Efficiency</span>
        `;
        tagsContainer.appendChild(efficiencyTag);
        
        header.appendChild(tagsContainer);
        card.appendChild(header);

        const canvas = document.createElement('canvas');
        canvas.className = 'diagram-canvas';
        card.appendChild(canvas);

        container.appendChild(card);

        canvas.drawCanvas = function() {
            const containerWidth = card.offsetWidth - 24;
            const ctx = canvas.getContext('2d');
            const padding = 40;
            const maxCanvasDim = Math.min(containerWidth, 600);
            
            const boardWidth = parseFloat(board.stock_width) || 1000;
            const boardHeight = parseFloat(board.stock_height) || 1000;
            
            const scale = Math.min(
                (maxCanvasDim - 2 * padding) / boardWidth,
                (maxCanvasDim - 2 * padding) / boardHeight
            );

            // Use normal DPR for live display (performance), but allow override for PDF capture
            // When capturing for PDF, we'll temporarily set a higher DPR for quality
            const dpr = window.capturingForPDF ? 3 : (window.devicePixelRatio || 1);
            canvas.width = (boardWidth * scale + 2 * padding) * dpr;
            canvas.height = (boardHeight * scale + 2 * padding) * dpr;
            canvas.style.width = (boardWidth * scale + 2 * padding) + 'px';
            canvas.style.height = (boardHeight * scale + 2 * padding) + 'px';
            ctx.scale(dpr, dpr);

            // Draw board background with light color
            ctx.fillStyle = '#fafafa';
            ctx.fillRect(padding, padding, boardWidth * scale, boardHeight * scale);
            
            ctx.strokeStyle = '#333';
            ctx.lineWidth = 2.5;
            ctx.strokeRect(padding, padding, boardWidth * scale, boardHeight * scale);
            
            ctx.fillStyle = '#1a1a1a';
            ctx.font = `600 ${Math.max(13, 15 * scale)}px 'Inter', -apple-system, sans-serif`;
            ctx.textAlign = 'center';
            const displayWidth = boardWidth / window.unitFactors[reportUnits];
            ctx.fillText(`${formatNumber(displayWidth, reportPrecision)}${reportUnits}`, padding + (boardWidth * scale) / 2, padding - 8);
            
            ctx.save();
            ctx.translate(padding - 18, padding + (boardHeight * scale) / 2);
            ctx.rotate(-Math.PI / 2);
            const displayHeight = boardHeight / window.unitFactors[reportUnits];
            ctx.fillText(`${formatNumber(displayHeight, reportPrecision)}${reportUnits}`, 0, 0);
            ctx.restore();

            const parts = board.parts || [];
            const offcuts = board.offcuts || [];
            canvas.boardIndex = boardIndex;
            canvas.boardData = board;
            canvas.partData = [];
            
            // Draw offcuts FIRST (so they appear behind parts)
            if (offcuts && offcuts.length > 0) {
                offcuts.forEach((offcut) => {
                    const offcutX = padding + (offcut.x || 0) * scale;
                    const offcutY = padding + (offcut.y || 0) * scale;
                    const offcutWidth = (offcut.width || offcut.w || 0) * scale;
                    const offcutHeight = (offcut.height || offcut.h || 0) * scale;
                    
                    if (offcutWidth > 0 && offcutHeight > 0) {
                        drawCrossedOffcut(ctx, offcutX, offcutY, offcutWidth, offcutHeight);
                    }
                });
            }
            
            parts.forEach((part, partIndex) => {
                // Ensure part dimensions and positions are valid numbers
                const partPosX = parseFloat(part.x) || 0;
                const partPosY = parseFloat(part.y) || 0;
                const partW = parseFloat(part.width) || 10;
                const partH = parseFloat(part.height) || 10;
                
                const partX = padding + partPosX * scale;
                const partY = padding + partPosY * scale;
                const partWidth = partW * scale;
                const partHeight = partH * scale;

                drawPartWithGrain(ctx, partX, partY, partWidth, partHeight, part);
                
                ctx.strokeStyle = '#1a1a1a';
                ctx.lineWidth = 1.5;
                ctx.strokeRect(partX, partY, partWidth, partHeight);
                
                drawGrainArrow(ctx, partX, partY, partWidth, partHeight, part.grain_direction);

                canvas.partData.push({
                    x: partX, y: partY, width: partWidth, height: partHeight,
                    part: part, boardIndex: boardIndex
                });

                if (partWidth > 50) {
                    ctx.fillStyle = '#1a1a1a';
                    ctx.font = `500 ${Math.max(11, 13 * scale)}px 'Inter', -apple-system, sans-serif`;
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'top';
                    const partDisplayW = partW / window.unitFactors[reportUnits];
                    ctx.fillText(`${formatNumber(partDisplayW, reportPrecision)}`, partX + partWidth / 2, partY + 6);
                }

                if (partHeight > 50) {
                    ctx.save();
                    ctx.translate(partX + 6, partY + partHeight / 2);
                    ctx.rotate(-Math.PI / 2);
                    ctx.fillStyle = '#1a1a1a';
                    ctx.font = `500 ${Math.max(11, 13 * scale)}px 'Inter', -apple-system, sans-serif`;
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'top';
                    const partDisplayH = partH / window.unitFactors[reportUnits];
                    ctx.fillText(`${formatNumber(partDisplayH, reportPrecision)}`, 0, 0);
                    ctx.restore();
                }

                if (partWidth > 30 && partHeight > 20) {
                    ctx.fillStyle = '#1a1a1a';
                    ctx.font = `700 ${Math.max(15, 18 * scale)}px 'Inter', -apple-system, sans-serif`;
                    ctx.textAlign = 'center';
                    ctx.textBaseline = 'middle';
                    const labelContent = String(part.part_unique_id || part.part_number || part.instance_id || `P${partIndex + 1}`);
                    const maxChars = Math.max(6, Math.floor(partWidth / 8));
                    const displayLabel = labelContent.length > maxChars ? labelContent.slice(0, maxChars - 1) + 'ÔÇª' : labelContent;
                    
                    let labelX = partX + partWidth / 2;
                    let labelY = partY + partHeight / 2;
                    
                    if (partWidth < 50 && partHeight > partWidth * 2) {
                        labelY = partY + partHeight * 0.7;
                    }
                    
                    if (partHeight < 35 && partWidth > partHeight * 2) {
                        labelX = partX + partWidth * 0.7;
                    }
                    
                    ctx.fillText(displayLabel, labelX, labelY);
                }
            });

            canvas.addEventListener('click', (e) => handleCanvasClick(e, canvas));
            canvas.addEventListener('mousemove', (e) => handleCanvasHover(e, canvas));
            canvas.style.cursor = 'pointer';
        };
        
        canvas.drawCanvas(); // Initial draw
        
        const resizeObserver = new ResizeObserver(() => {
            canvas.drawCanvas(); // Redraw on resize
        });
        resizeObserver.observe(card);
    });
}

function renderReport() {
    if (!g_reportData) {
        return;
    }
    
    // Validate report data structure
    if (!g_reportData.summary) {
        const container = document.getElementById('reportContainer');
        if (container) {
            container.innerHTML = '<div style="color: red; padding: 20px; text-align: center;"><h3>Invalid Report Data</h3><p>The report data is incomplete. Please try generating the cut list again.</p></div>';
        }
        return;
    }
    
    // Populate Summary Cards
    const currency = g_reportData.summary.currency || window.defaultCurrency || 'USD';
    const currencySymbol = window.currencySymbols[currency] || currency;
    const reportPrecision = window.currentPrecision ?? 1;
    
    // Total Cost Card
    const totalCostElement = document.getElementById('summaryTotalCost');
    if (totalCostElement) {
        const totalCost = g_reportData.summary.total_project_cost || 0;
        totalCostElement.textContent = `${currencySymbol}${formatNumber(totalCost, 2)}`;
    }
    
    // Number of Materials Card
    const materialCountElement = document.getElementById('summaryMaterialCount');
    if (materialCountElement) {
        const materialCount = g_reportData.unique_board_types ? g_reportData.unique_board_types.length : 0;
        materialCountElement.textContent = materialCount;
    }
    
    // Total Boards Card
    const totalBoardsElement = document.getElementById('summaryTotalBoards');
    if (totalBoardsElement) {
        const totalBoards = g_reportData.summary.total_boards || 0;
        totalBoardsElement.textContent = totalBoards;
    }
    
    // Overall Efficiency Card
    const overallEfficiencyElement = document.getElementById('summaryOverallEfficiency');
    if (overallEfficiencyElement) {
        const efficiency = g_reportData.summary.overall_efficiency || 0;
        overallEfficiencyElement.textContent = `${formatNumber(efficiency, reportPrecision)}%`;
    }
    
    // Total Parts Card
    const totalPartsElement = document.getElementById('summaryTotalParts');
    if (totalPartsElement) {
        const totalParts = g_reportData.summary.total_parts_instances || 0;
        totalPartsElement.textContent = totalParts;
    }
    
    // Use globals from app.js
    const reportUnits = window.currentUnits || 'mm';
    const currentAreaUnitLabel = getAreaUnitLabel(); // Get label like 'm²'


    const summaryTable = document.getElementById('summaryTable');
    if (summaryTable) {
        // Check if summary data exists
        if (!g_reportData.summary || Object.keys(g_reportData.summary).length === 0) {
            // Hide the entire Overall Summary section if no data
            const summarySection = summaryTable.closest('.report-table-container');
            const summaryTitle = document.querySelector('h2[data-translate="overall_summary"]');
            if (summarySection) summarySection.style.display = 'none';
            if (summaryTitle) summaryTitle.style.display = 'none';
        } else {
            let summaryHTML = `
                <thead><tr><th>Metric</th><th>Value</th></tr></thead>
                <tbody>`;
            
            // Add project details if available (with HTML escaping)
            if (g_reportData.summary.project_name && g_reportData.summary.project_name !== 'Untitled Project') {
                summaryHTML += `<tr><td>Project Name</td><td><strong>${escapeHtml(g_reportData.summary.project_name)}</strong></td></tr>`;
            }
            if (g_reportData.summary.client_name) {
                summaryHTML += `<tr><td>Client</td><td><strong>${escapeHtml(g_reportData.summary.client_name)}</strong></td></tr>`;
            }
            if (g_reportData.summary.prepared_by) {
                summaryHTML += `<tr><td>Prepared by</td><td><strong>${escapeHtml(g_reportData.summary.prepared_by)}</strong></td></tr>`;
            }
            
            summaryHTML += `
                <tr><td>Total Parts Instances</td><td>${g_reportData.summary.total_parts_instances || 0}</td></tr>
                <tr><td>Total Unique Part Types</td><td>${g_reportData.summary.total_unique_part_types || 0}</td></tr>
                <tr><td>Total Boards</td><td>${g_reportData.summary.total_boards || 0}</td></tr>
                <tr><td>Overall Efficiency</td><td>${formatNumber(g_reportData.summary.overall_efficiency || 0, reportPrecision)}%</td></tr>
                <tr><td><strong>Total Project Weight</strong></td><td class="total-highlight"><strong>${formatNumber(g_reportData.summary.total_project_weight_kg || 0, 2)} kg</strong></td></tr>
                <tr><td><strong>Total Project Cost</strong></td><td class="total-highlight"><strong>${currencySymbol}${formatNumber(g_reportData.summary.total_project_cost || 0, 2)}</strong></td></tr>
                </tbody>`;
            
            summaryTable.innerHTML = summaryHTML;
        }
    }

    const materialsUsedTable = document.getElementById('materialsUsedTable');
    if (materialsUsedTable && g_reportData.unique_board_types) {
        let html = `<thead><tr><th>Material</th><th>Price per Sheet</th></tr></thead><tbody>`;
        g_reportData.unique_board_types.forEach(board_type => {
            const boardCurrency = board_type.currency || currency;
            const boardSymbol = window.currencySymbols[boardCurrency] || boardCurrency;
            html += `<tr><td>${board_type.material}</td><td>${boardSymbol}${formatNumber(board_type.price_per_sheet || 0, 2)}</td></tr>`;
        });
        html += `</tbody>`;
        materialsUsedTable.innerHTML = html;
    } else if (materialsUsedTable) {
        materialsUsedTable.innerHTML = `<thead><tr><th>Material</th><th>Price per Sheet</th></tr></thead><tbody><tr><td colspan="2">No materials data available.</td></tr></tbody>`;
    }


    const uniquePartTypesTable = document.getElementById('uniquePartTypesTable');
    if (uniquePartTypesTable) {
        let html = `<thead><tr><th>Name</th><th>W (${reportUnits})</th><th>H (${reportUnits})</th><th>Thick (${reportUnits})</th><th>Material</th><th>Grain</th><th>Edge Banding</th><th>Total Qty</th><th style="text-align:right;">Total Area (${currentAreaUnitLabel})</th><th style="text-align:right;">Weight (kg)</th></tr></thead><tbody>`;
        if (g_reportData.unique_part_types && g_reportData.unique_part_types.length > 0) {
            g_reportData.unique_part_types.forEach(part_type => {
                const width = part_type.width / window.unitFactors[reportUnits];
                const height = part_type.height / window.unitFactors[reportUnits];
                const thickness = part_type.thickness / window.unitFactors[reportUnits];
                
                const edgeBandingDisplay = typeof part_type.edge_banding === 'object' && part_type.edge_banding.type ? part_type.edge_banding.type : (part_type.edge_banding || 'None');
                html += `
                    <tr>
                        <td title="${escapeHtml(part_type.name)}">${escapeHtml(part_type.name)}</td>
                        <td>${formatNumber(width, reportPrecision)}</td>
                        <td>${formatNumber(height, reportPrecision)}</td>
                        <td>${formatNumber(thickness, reportPrecision)}</td>
                        <td title="${escapeHtml(part_type.material)}">${escapeHtml(part_type.material)}</td>
                        <td>${escapeHtml(part_type.grain_direction || 'Any')}</td>
                        <td>${escapeHtml(edgeBandingDisplay)}</td>
                        <td class="total-highlight">${part_type.total_quantity}</td>
                        <td style="text-align:right;">${getAreaDisplay(part_type.total_area)}</td>
                        <td style="text-align:right;">${formatNumber(part_type.total_weight_kg || 0, 2)}</td>
                    </tr>
                `;
            });
        }
        html += `</tbody>`;
        uniquePartTypesTable.innerHTML = html;
    }

    // Sheet Inventory Summary Table
    const sheetInventoryTable = document.getElementById('sheetInventoryTable');
    if (sheetInventoryTable && g_reportData.unique_board_types) {
        // Updated Dimensions header to explicitly include units
        let html = `<thead><tr><th>Material</th><th>Dimensions (${reportUnits})</th><th>Count</th><th style="text-align:right;">Total Area (${currentAreaUnitLabel})</th><th>Price/Sheet</th><th>Total Cost</th></tr></thead><tbody>`;
        g_reportData.unique_board_types.forEach(board_type => {
            const boardCurrency = board_type.currency || currency;
            const boardSymbol = window.currencySymbols[boardCurrency] || boardCurrency;
            const width_mm = parseFloat(board_type.stock_width);
            const height_mm = parseFloat(board_type.stock_height);

            const width = width_mm / window.unitFactors[reportUnits];
            const height = height_mm / window.unitFactors[reportUnits];
            // Removed unit from dimensionsStr
            const dimensionsStr = `${formatNumber(width, reportPrecision)} × ${formatNumber(height, reportPrecision)}`;
            
            html += `
                <tr>
                    <td title="${escapeHtml(board_type.material)}">${escapeHtml(board_type.material)}</td>
                    <td>${dimensionsStr}</td>
                    <td class="total-highlight">${board_type.count}</td>
                    <td style="text-align:right;">${getAreaDisplay(board_type.total_area)}</td>
                    <td>${boardSymbol}${formatNumber(board_type.price_per_sheet || 0, 2)}</td>
                    <td class="total-highlight">${boardSymbol}${formatNumber(board_type.total_cost || 0, 2)}</td>
                </tr>
            `;
        });
        html += `</tbody>`;
        sheetInventoryTable.innerHTML = html;
    }

    const partsTable = document.getElementById('partsTable');
    if (partsTable) {
        
        // Calculate piece costs and statistics (logic from original)
        const parts_list = g_reportData.parts_placed || g_reportData.parts || [];
        const boardTypeMap = {};
        g_reportData.unique_board_types.forEach(bt => {
            boardTypeMap[bt.material] = {
                price: bt.price_per_sheet || 0,
                currency: bt.currency || currency,
                area: (bt.stock_width || 2440) * (bt.stock_height || 1220) // Use actual stock_width/height from board_type
            };
        });
        
        const partsWithCosts = parts_list.map(part => {
            const boardType = boardTypeMap[part.material] || { price: 0, currency: currency, area: 2976800 }; // Fallback to default area
            const partArea = (part.width || 0) * (part.height || 0); // in mm²
            const costPerMm2 = boardType.area > 0 ? boardType.price / boardType.area : 0;
            const partCost = partArea * costPerMm2;
            return { ...part, cost: partCost, currency: boardType.currency };
        });
        
        const costs = partsWithCosts.map(p => p.cost).filter(c => c > 0);
        const totalPartsCost = costs.reduce((a, b) => a + b, 0);
        const avgCost = costs.length > 0 ? totalPartsCost / costs.length : 0;
        
        let partsHtml = `<thead><tr><th>ID</th><th>Name</th><th>Dimensions (${reportUnits})</th><th>Material</th><th>Grain</th><th>Edge Banding</th><th>Board#</th><th>Cost</th><th>Level</th></tr></thead><tbody>`;
        
        partsWithCosts.forEach(part => {
            const partId = part.part_unique_id || part.part_number;
            const width = (part.width || 0) / window.unitFactors[reportUnits];
            const height = (part.height || 0) / window.unitFactors[reportUnits];
            // Removed unit from dimensionsStr
            const dimensionsStr = `${formatNumber(width, reportPrecision)} × ${formatNumber(height, reportPrecision)}`;
            const partSymbol = window.currencySymbols[part.currency] || part.currency;
            
            let costLevel = 'avg', costColor = '#ffa500', costText = 'Average';
            if (part.cost > avgCost * 1.2) { costLevel = 'high'; costColor = '#ff4444'; costText = 'High'; }
            else if (part.cost < avgCost * 0.8 && part.cost > 0) { costLevel = 'low'; costColor = '#44aa44'; costText = 'Low'; }
            
            const edgeBandingDisplay = typeof part.edge_banding === 'object' && part.edge_banding.type ? part.edge_banding.type : (part.edge_banding || 'None');
            partsHtml += `
                <tr data-part-id="${escapeHtml(partId)}" data-board-number="${part.board_number}" data-cost-level="${costLevel}">
                    <td><button class="part-id-btn" onclick="scrollToPieceDiagram('${escapeHtml(partId)}', ${part.board_number})">${escapeHtml(partId)}</button></td>
                    <td title="${escapeHtml(part.name)}">${escapeHtml(part.name)}</td>
                    <td>${dimensionsStr}</td>
                    <td title="${escapeHtml(part.material)}">${escapeHtml(part.material)}</td>
                    <td>${escapeHtml(part.grain_direction || 'Any')}</td>
                    <td>${escapeHtml(edgeBandingDisplay)}</td>
                    <td>${part.board_number}</td>
                    <td>${partSymbol}${formatNumber(part.cost, 2)}</td>
                    <td><span class="cost-indicator" style="background: ${costColor}; color: white; padding: 2px 6px; border-radius: 3px; font-size: 11px;">${costText}</span></td>
                </tr>
            `;
        });
        
        partsHtml += `
                <tr style="border-top: 2px solid #22863a; background: #f6ffed;">
                    <td colspan="7" style="text-align: right; font-weight: bold;">Total Parts Cost:</td>
                    <td style="font-weight: bold; color: #22863a;">${currencySymbol}${formatNumber(totalPartsCost, 2)}</td>
                    <td></td>
                </tr>
            </tbody>`;
        
        partsTable.innerHTML = partsHtml;
        // attachPartTableClickHandlers(); // This function is empty, no need to call
    } else {
        console.error('partsTable element not found');
    }
    
    // Render new sections
    if (g_reportData.cut_sequences) {
        renderCutSequences(g_reportData);
    }

    if (g_reportData.usable_offcuts) {
        renderOffcutsTable(g_reportData);
    }
    
    // Initialize card visualizations after report is rendered
    if (typeof initializeCardVisualizations === 'function') {
        initializeCardVisualizations();
    }
    
    console.log('Finished rendering report');
}

function renderCutSequences(reportData) {
    console.log('🔧 renderCutSequences called with data:', reportData);
    console.log('🔧 Cut sequences count:', reportData.cut_sequences?.length || 0);
    
    // COMPLETELY NEW IMPLEMENTATION - NO OLD CODE
    const container = document.getElementById('cutSequenceContainer');
    if (!container) {
        console.error('❌ Cut sequence container not found');
        return;
    }
    
    console.log('✅ Container found:', container);
    
    if (!reportData.cut_sequences || reportData.cut_sequences.length === 0) {
        console.log('⚠️ No cut sequences data available');
        container.innerHTML = '<div class="report-table-container"><div class="report-table-header">No Cut Sequences</div><div style="padding: 20px; text-align: center; color: #64748b;">No cut sequences available</div></div>';
        return;
    }
    
    console.log('🎨 Building HTML with NEW DESIGN for', reportData.cut_sequences.length, 'boards');
    
    // Build HTML from scratch with new design
    let htmlOutput = '';
    
    reportData.cut_sequences.forEach(board => {
        const tableId = `cutSequenceTable_${board.board_number}`;
        
        // Create table with report design classes
        htmlOutput += `
            <div class="report-table-container" style="margin-bottom: 24px;">
                <div class="report-table-header" style="display: flex; justify-content: space-between; align-items: center;">
                    <span>Sheet ${board.board_number}: ${escapeHtml(board.material)} - ${board.stock_dimensions}</span>
                </div>
                <table id="${tableId}" style="width: 100%; border-collapse: collapse; font-size: 13px;">
                    <colgroup>
                        <col style="width: 10%;">
                        <col style="width: 20%;">
                        <col style="width: auto;">
                        <col style="width: 20%;">
                    </colgroup>
                    <thead>
                        <tr>
                            <th style="text-align: left; padding: 12px 20px; font-weight: 600; color: #64748b; border-bottom: 1px solid #e2e8f0; background: #ffffff;">#</th>
                            <th style="text-align: left; padding: 12px 20px; font-weight: 600; color: #64748b; border-bottom: 1px solid #e2e8f0; background: #ffffff;">Operation</th>
                            <th style="text-align: left; padding: 12px 20px; font-weight: 600; color: #64748b; border-bottom: 1px solid #e2e8f0; background: #ffffff;">Description</th>
                            <th style="text-align: right; padding: 12px 20px; font-weight: 600; color: #64748b; border-bottom: 1px solid #e2e8f0; background: #ffffff;">Measurement</th>
                        </tr>
                    </thead>
                    <tbody>`;
        
        // Add rows
        board.cut_sequence.forEach((step, index) => {
            const isLast = index === board.cut_sequence.length - 1;
            const borderStyle = isLast ? 'border-bottom: none;' : 'border-bottom: 1px solid #e2e8f0;';
            
            htmlOutput += `
                        <tr style="transition: background 0.15s;">
                            <td style="padding: 12px 20px; color: #0f172a; ${borderStyle}">
                                <span style="background: #f1f5f9; color: #475569; padding: 2px 8px; border-radius: 9999px; font-size: 11px; font-weight: 500; display: inline-block;">${step.step}</span>
                            </td>
                            <td style="padding: 12px 20px; color: #0f172a; font-weight: 500; ${borderStyle}">${escapeHtml(step.type)}</td>
                            <td style="padding: 12px 20px; color: #0f172a; ${borderStyle}">${escapeHtml(step.description)}</td>
                            <td style="padding: 12px 20px; color: #0f172a; text-align: right; ${borderStyle}">${escapeHtml(step.measurement)}</td>
                        </tr>`;
        });
        
        htmlOutput += `
                    </tbody>
                </table>
            </div>`;
    });
    
    // Set the HTML
    container.innerHTML = htmlOutput;
    
    console.log('✅ Cut sequences rendered successfully with NEW DESIGN');
    console.log('📊 Total boards rendered:', reportData.cut_sequences.length);
}

function renderOffcutsTable(reportData) {
    const table = document.getElementById('offcutsTable');
    if (!table || !reportData.usable_offcuts) {
        return;
    }
    
    const currentAreaUnitLabel = getAreaUnitLabel();
    const reportUnits = window.reportUnits || window.currentUnits || 'mm';
    
    if (reportData.usable_offcuts.length === 0) {
        table.innerHTML = `<thead><tr><th>Sheet #</th><th>Material</th><th>Width (${reportUnits})</th><th>Height (${reportUnits})</th><th>Area (${currentAreaUnitLabel})</th></tr></thead><tbody><tr><td colspan="5">No significant offcuts</td></tr></tbody>`;
        return;
    }
    
    let html = `<thead><tr><th>Sheet #</th><th>Material</th><th>Width (${reportUnits})</th><th>Height (${reportUnits})</th><th>Area (${currentAreaUnitLabel})</th></tr></thead><tbody>`;
    
    reportData.usable_offcuts.forEach(offcut => {
        // Convert area from m² to current area units
        const areaMM2 = offcut.area_m2 * 1000000; // Convert m² to mm²
        const convertedArea = getAreaDisplay(areaMM2);
        
        // ✅ NEW: Convert dimensions from mm to current units
        let width, height;
        if (offcut.estimated_width_mm !== undefined && offcut.estimated_height_mm !== undefined) {
            // Use separate fields if available
            width = formatDimension(offcut.estimated_width_mm);
            height = formatDimension(offcut.estimated_height_mm);
        } else {
            // Fallback: Parse the old format "1952 x 922mm"
            const match = offcut.estimated_dimensions.match(/(\d+)\s*x\s*(\d+)/);
            if (match) {
                width = formatDimension(parseFloat(match[1]));
                height = formatDimension(parseFloat(match[2]));
            } else {
                width = offcut.estimated_dimensions;
                height = '';
            }
        }
        
        html += `<tr>
            <td>${offcut.board_number}</td>
            <td>${escapeHtml(offcut.material)}</td>
            <td>${width}</td>
            <td>${height}</td>
            <td>${convertedArea}</td>
        </tr>`;
    });
    
    html += '</tbody>';
    table.innerHTML = html;
}

// Draw crossed X pattern for offcuts area
function drawCrossedOffcut(ctx, x, y, width, height) {
    // Draw light green background
    ctx.fillStyle = 'rgba(220, 252, 231, 0.2)';
    ctx.fillRect(x, y, width, height);
    
    // Draw dashed border
    ctx.strokeStyle = 'rgba(34, 197, 94, 0.4)';
    ctx.lineWidth = 1;
    ctx.setLineDash([4, 4]);
    ctx.strokeRect(x, y, width, height);
    ctx.setLineDash([]);
    
    // Draw X pattern (two diagonal lines)
    ctx.strokeStyle = 'rgba(34, 197, 94, 0.3)';
    ctx.lineWidth = 1.5;
    
    // First diagonal (top-left to bottom-right)
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + width, y + height);
    ctx.stroke();
    
    // Second diagonal (top-right to bottom-left)
    ctx.beginPath();
    ctx.moveTo(x + width, y);
    ctx.lineTo(x, y + height);
    ctx.stroke();
}

// Professional monochrome color palette for materials
// Maps material names to subtle, professional colors
const MATERIAL_COLOR_PALETTE = {
    // Greys (neutral/default)
    'grey': '#D3D3D3',
    'gray': '#D3D3D3',
    'default': '#D3D3D3',
    
    // Light greys (plywood, standard materials)
    'plywood': '#E8E8E8',
    'mdf': '#E8E8E8',
    'particle board': '#E8E8E8',
    'chipboard': '#E8E8E8',
    
    // Medium greys (hardwoods, oak, maple)
    'oak': '#C0C0C0',
    'maple': '#C0C0C0',
    'birch': '#C0C0C0',
    'ash': '#C0C0C0',
    'hardwood': '#C0C0C0',
    
    // Darker greys (walnut, dark woods)
    'walnut': '#A9A9A9',
    'cherry': '#A9A9A9',
    'mahogany': '#A9A9A9',
    'dark wood': '#A9A9A9',
    'ebony': '#808080',
    
    // Light neutral (melamine, laminates)
    'melamine': '#F0F0F0',
    'laminate': '#F0F0F0',
    'veneer': '#E0E0E0',
    
    // Slightly darker (composite, engineered)
    'composite': '#D9D9D9',
    'engineered': '#D9D9D9',
    'mdf': '#D9D9D9',
    
    // Very light (white, light finishes)
    'white': '#F5F5F5',
    'light': '#F5F5F5',
    'cream': '#F5F5F5',
    'ivory': '#F5F5F5',
    
    // Very dark (black, dark finishes)
    'black': '#4D4D4D',
    'dark': '#4D4D4D',
    'charcoal': '#4D4D4D',
};

function getMaterialColor(material) {
    if (!material) return '#D3D3D3';
    
    const materialStr = String(material).toLowerCase().trim();
    
    // Direct match
    if (MATERIAL_COLOR_PALETTE[materialStr]) {
        return MATERIAL_COLOR_PALETTE[materialStr];
    }
    
    // Partial match (check if material name contains any key)
    for (const [key, color] of Object.entries(MATERIAL_COLOR_PALETTE)) {
        if (materialStr.includes(key) || key.includes(materialStr)) {
            return color;
        }
    }
    
    // Handle RGB color strings (e.g., "171,171,171")
    if (/^\d+,\d+,\d+$/.test(materialStr)) {
        const parts = materialStr.split(',').map(p => parseInt(p.trim()));
        if (parts.length === 3) {
            const [r, g, b] = parts;
            // Convert RGB to hex
            const hex = '#' + [r, g, b].map(x => {
                const hex = x.toString(16);
                return hex.length === 1 ? '0' + hex : hex;
            }).join('').toUpperCase();
            
            // Map to monochrome equivalent based on brightness
            const brightness = (r + g + b) / 3;
            if (brightness > 200) return '#F0F0F0';      // Very light
            if (brightness > 170) return '#E0E0E0';      // Light
            if (brightness > 140) return '#D3D3D3';      // Medium-light
            if (brightness > 110) return '#C0C0C0';      // Medium
            if (brightness > 80) return '#A9A9A9';       // Medium-dark
            if (brightness > 50) return '#808080';       // Dark
            return '#4D4D4D';                             // Very dark
        }
    }
    
    // Default fallback
    return '#D3D3D3';
}

function hslToRgb(hslString) {
    // Handle hex color strings (like #D3D3D3)
    if (hslString.startsWith('#')) {
        return parseInt(hslString.substring(1), 16);
    }
    
    const match = hslString.match(/hsl\((\d+),\s*(\d+)%,\s*(\d+)%\)/);
    if (!match) return 0xD3D3D3; // Return grey as default
    
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

function drawPartWithGrain(ctx, x, y, width, height, part) {
    const baseColor = getMaterialColor(part.material);
    ctx.fillStyle = baseColor;
    ctx.fillRect(x, y, width, height);
    
    if (part.grain_direction && part.grain_direction !== 'Any') {
        ctx.save();
        ctx.globalAlpha = 0.25;
        ctx.strokeStyle = '#6b4423';
        ctx.lineWidth = 0.8;
        
        const spacing = 8;
        if (part.grain_direction === 'L' || part.grain_direction === 'length') {
            // Vertical grain lines
            for (let i = x; i < x + width; i += spacing) {
                ctx.beginPath();
                ctx.moveTo(i, y);
                ctx.lineTo(i, y + height);
                ctx.stroke();
            }
        } else if (part.grain_direction === 'W' || part.grain_direction === 'width') {
            // Horizontal grain lines
            for (let i = y; i < y + height; i += spacing) {
                ctx.beginPath();
                ctx.moveTo(x, i);
                ctx.lineTo(x + width, i);
                ctx.lineTo(x + width, i); // Ensure proper line path
                ctx.stroke();
            }
        }
        ctx.restore();
    }
}

function drawGrainArrow(ctx, x, y, width, height, grainDirection) {
    if (!grainDirection || grainDirection === 'Any') return;
    
    ctx.save();
    ctx.strokeStyle = '#1a1a1a';
    ctx.fillStyle = '#1a1a1a';
    ctx.lineWidth = 2.5;
    
    const centerX = x + width / 2;
    const arrowSize = Math.min(width, height) * 0.15;
    
    if (grainDirection === 'L' || grainDirection === 'length') {
        // Vertical arrow at top
        const arrowY = y + 20;
        const arrowEndY = arrowY + Math.max(arrowSize, 20);
        
        // Arrow line
        ctx.beginPath();
        ctx.moveTo(centerX, arrowY);
        ctx.lineTo(centerX, arrowEndY);
        ctx.stroke();
        
        // Arrow head (triangle)
        ctx.beginPath();
        ctx.moveTo(centerX, arrowY);
        ctx.lineTo(centerX - 4, arrowY + 8);
        ctx.lineTo(centerX + 4, arrowY + 8);
        ctx.closePath();
        ctx.fill();
    } else if (grainDirection === 'W' || grainDirection === 'width') {
        // Horizontal arrow at bottom
        const arrowY = y + height - 20;
        const arrowStartX = centerX - Math.max(arrowSize/2, 15);
        const arrowEndX = centerX + Math.max(arrowSize/2, 15);
        
        // Arrow line
        ctx.beginPath();
        ctx.moveTo(arrowStartX, arrowY);
        ctx.lineTo(arrowEndX, arrowY);
        ctx.stroke();
        
        // Arrow head (triangle)
        ctx.beginPath();
        ctx.moveTo(arrowEndX, arrowY);
        ctx.lineTo(arrowEndX - 8, arrowY - 4);
        ctx.lineTo(arrowEndX - 8, arrowY + 4);
        ctx.closePath();
        ctx.fill();
    }
    
    ctx.restore();
}

// Function to redraw a specific canvas diagram
function redrawCanvasDiagram(canvas, board) {
    if (canvas.drawCanvas) {
        canvas.drawCanvas(); // Call the drawing function bound to the canvas
    }
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
    if (!material) {
        console.warn('scrollToDiagram called with null/undefined material');
        return;
    }
    const sanitizedMaterial = String(material).replace(/[^a-zA-Z0-9]/g, '_');
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
                console.log(`🖱️ Clicked: ${partData.part.name}`);
                highlightPartInAssemblyViewer(partData.part);
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

// Highlight part in the Report Assembly 3D Viewer
function highlightPartInAssemblyViewer(part) {
    // Ensure the Assembly 3D Viewer is visible and initialized
    const canvas = document.getElementById('reportAssembly3DCanvas');
    const offScreen = document.getElementById('reportViewer3DOffScreen');
    const controls = document.getElementById('reportViewControls');
    const explodeControls = document.getElementById('reportExplodeControls');
    const powerBtn = document.getElementById('reportViewer3DPowerBtn');
    
    if (!canvas) {
        console.error('❌ Assembly 3D Viewer canvas not found');
        return;
    }
    
    // Turn on the viewer if it's off
    if (canvas.style.display === 'none') {
        canvas.style.display = 'block';
        if (offScreen) offScreen.style.display = 'none';
        if (controls) controls.style.display = 'flex';
        if (explodeControls) explodeControls.style.display = 'flex';
        if (powerBtn) powerBtn.style.background = 'rgba(76, 175, 80, 0.3)';
        
        // Initialize viewer if not already initialized
        if (!window.reportAssemblyScene && window.reportAssemblyData) {
            initReportAssemblyViewer();
        }
    }
    
    // Wait a moment for viewer to initialize if needed
    setTimeout(() => {
        selectPartInReportViewer(part);
    }, 100);
}

// Select and highlight a part in the Report Assembly 3D Viewer
function selectPartInReportViewer(part) {
    if (!window.reportAssemblyGroups || window.reportAssemblyGroups.length === 0) {
        console.warn('⚠️ No assembly groups available for highlighting');
        return;
    }
    
    // Get the unique ID for this part (P27, P28, P29, P30, etc.)
    const partUniqueId = part.part_unique_id || part.instance_id || part.part_number;
    console.log(`🔍 Searching for EXACT match: ${partUniqueId} | ${part.name} | ${part.material}`);
    
    // Reset all parts to default appearance
    window.reportAssemblyGroups.forEach(group => {
        group.traverse((child) => {
            if (child.isMesh && child.material) {
                // Reset to original material properties
                const originalMat = group.userData.originalMaterial || {};
                child.material.emissive.setHex(0x000000);
                child.material.emissiveIntensity = 0;
                child.material.color.setHex(originalMat.color || 0xcccccc);
                child.material.opacity = originalMat.opacity || 0.85;
                child.material.needsUpdate = true;
            }
            if (child.isLineSegments) {
                // Reset edge color
                child.material.color.setHex(group.userData.originalEdgeColor || 0x666666);
                child.material.needsUpdate = true;
            }
        });
    });
    
    // Find and highlight ONLY the exact matching part by unique ID
    let foundCount = 0;
    const matchedGroups = [];
    
    window.reportAssemblyGroups.forEach((group, index) => {
        // CRITICAL FIX: Use unique ID as PRIMARY matching criterion
        const groupUniqueId = group.userData.uniqueId || group.userData.partUniqueId;
        
        // EXACT ID MATCH - this is the most reliable way
        if (groupUniqueId && partUniqueId && groupUniqueId === partUniqueId) {
            console.log(`✅ Group ${index}: EXACT ID MATCH - ${groupUniqueId}`);
            foundCount++;
            matchedGroups.push({ group, index, reason: 'exact_id_match' });
            
            // Apply highlighting
            group.traverse((child) => {
                if (child.isMesh && child.material) {
                    // Store original color if not already stored
                    if (!group.userData.originalMaterial.color) {
                        group.userData.originalMaterial.color = child.material.color.getHex();
                        group.userData.originalMaterial.opacity = child.material.opacity;
                    }
                    
                    // Apply emissive glow (green highlight)
                    child.material.emissive.setHex(0x00ff00);
                    child.material.emissiveIntensity = 0.5;
                    
                    // Brighten the color
                    const currentColor = child.material.color.getHex();
                    const r = Math.min(255, ((currentColor >> 16) & 0xff) + 50);
                    const g = Math.min(255, ((currentColor >> 8) & 0xff) + 50);
                    const b = Math.min(255, (currentColor & 0xff) + 50);
                    child.material.color.setRGB(r / 255, g / 255, b / 255);
                    
                    // Increase opacity slightly
                    child.material.opacity = Math.min(1.0, child.material.opacity + 0.15);
                    child.material.needsUpdate = true;
                }
                if (child.isLineSegments) {
                    // Highlight edges in green
                    child.material.color.setHex(0x00ff00);
                    child.material.needsUpdate = true;
                }
            });
            return; // Stop after first match (unique ID ensures only one match)
        }
    });
    
    if (foundCount > 0) {
        console.log(`✅ Found exact match using unique ID`);
        
        // Focus camera on the matched part
        if (window.reportCamera && window.reportControls && matchedGroups.length > 0) {
            const firstMatch = matchedGroups[0].group;
            const box = new THREE.Box3().setFromObject(firstMatch);
            const center = box.getCenter(new THREE.Vector3());
            const size = box.getSize(new THREE.Vector3());
            const maxDim = Math.max(size.x, size.y, size.z);
            
            // Smoothly move camera to focus on this part
            const distance = maxDim * 3;
            const targetPos = new THREE.Vector3(
                center.x + distance * 0.7,
                center.y + distance * 0.5,
                center.z + distance * 0.7
            );
            
            console.log('📷 Focusing camera on matched part');
            animateCameraToTarget(targetPos, center);
        }
    } else {
        console.warn(`❌ No matching part found for unique ID: ${partUniqueId}`);
    }
}

// Animate camera movement to target position
function animateCameraToTarget(targetPosition, targetLookAt) {
    if (!window.reportCamera || !window.reportControls) return;
    
    const startPos = window.reportCamera.position.clone();
    const startTarget = window.reportControls.target.clone();
    const duration = 1000; // 1 second
    const startTime = Date.now();
    
    function animate() {
        const elapsed = Date.now() - startTime;
        const t = Math.min(elapsed / duration, 1);
        
        // Ease-in-out function
        const eased = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
        
        // Interpolate position
        window.reportCamera.position.lerpVectors(startPos, targetPosition, eased);
        window.reportControls.target.lerpVectors(startTarget, targetLookAt, eased);
        window.reportControls.update();
        
        if (t < 1) {
            requestAnimationFrame(animate);
        }
    }
    
    animate();
}

// Handle clicks on 3D viewer to highlight corresponding diagram parts
function handle3DViewerClick(event, canvas) {
    if (!window.reportCamera || !window.reportAssemblyGroups) return;
    
    // Calculate mouse position in normalized device coordinates (-1 to +1)
    const rect = canvas.getBoundingClientRect();
    const mouse = new THREE.Vector2();
    mouse.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    mouse.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
    
    // Create raycaster
    const raycaster = new THREE.Raycaster();
    raycaster.setFromCamera(mouse, window.reportCamera);
    
    // Find intersected objects
    const intersects = raycaster.intersectObjects(window.reportAssemblyScene.children, true);
    
    if (intersects.length > 0) {
        // Find the first mesh intersection
        for (let intersect of intersects) {
            if (intersect.object.isMesh) {
                // Find the parent group that contains userData
                let group = intersect.object;
                while (group && !group.userData.partName) {
                    group = group.parent;
                }
                
                if (group && group.userData.partName) {
                    console.log('🖱️ 3D Viewer clicked:', group.userData.partName);
                    
                    // Apply visual highlight to clicked component
                    highlight3DViewerComponent(group);
                    
                    // Then highlight the diagram
                    highlightDiagramFromViewer(group.userData);
                    break;
                }
            }
        }
    }
}

// Apply visual highlight to clicked 3D component
function highlight3DViewerComponent(clickedGroup) {
    // Reset all parts to default appearance first
    window.reportAssemblyGroups.forEach(group => {
        group.traverse((child) => {
            if (child.isMesh && child.material) {
                const originalMat = group.userData.originalMaterial || {};
                child.material.emissive.setHex(0x000000);
                child.material.emissiveIntensity = 0;
                child.material.color.setHex(originalMat.color || 0xcccccc);
                child.material.opacity = originalMat.opacity || 0.85;
                child.material.needsUpdate = true;
            }
            if (child.isLineSegments) {
                child.material.color.setHex(group.userData.originalEdgeColor || 0x666666);
                child.material.needsUpdate = true;
            }
        });
    });
    
    // Apply highlight to clicked component
    clickedGroup.traverse((child) => {
        if (child.isMesh && child.material) {
            // Store original color if not already stored
            if (!clickedGroup.userData.originalMaterial.color) {
                clickedGroup.userData.originalMaterial.color = child.material.color.getHex();
                clickedGroup.userData.originalMaterial.opacity = child.material.opacity;
            }
            
            // Apply bright cyan/blue emissive glow for click feedback
            child.material.emissive.setHex(0x00ffff);
            child.material.emissiveIntensity = 0.6;
            
            // Brighten the color
            const currentColor = child.material.color.getHex();
            const r = Math.min(255, ((currentColor >> 16) & 0xff) + 60);
            const g = Math.min(255, ((currentColor >> 8) & 0xff) + 60);
            const b = Math.min(255, (currentColor & 0xff) + 60);
            child.material.color.setRGB(r / 255, g / 255, b / 255);
            
            // Increase opacity
            child.material.opacity = Math.min(1.0, child.material.opacity + 0.2);
            child.material.needsUpdate = true;
        }
        if (child.isLineSegments) {
            // Store original edge color
            if (!clickedGroup.userData.originalEdgeColor) {
                clickedGroup.userData.originalEdgeColor = child.material.color.getHex();
            }
            // Highlight edges in bright cyan
            child.material.color.setHex(0x00ffff);
            child.material.needsUpdate = true;
        }
    });
    
    console.log('✨ Applied visual highlight to:', clickedGroup.userData.partName);
}

// Highlight diagram part when 3D viewer part is clicked (reverse flow)
function highlightDiagramFromViewer(partUserData) {
    // CRITICAL FIX: Use unique ID as PRIMARY matching criterion
    const uniqueId = partUserData.uniqueId || partUserData.partUniqueId;
    const partName = partUserData.partName;
    const materialName = partUserData.materialName;
    
    console.log(`🔍 Searching diagrams for unique ID: ${uniqueId} | ${partName} | ${materialName}`);
    
    // Search through all boards to find the EXACT matching part by unique ID
    let foundPart = null;
    let foundBoardIndex = -1;
    
    for (let boardIndex = 0; boardIndex < g_boardsData.length; boardIndex++) {
        const board = g_boardsData[boardIndex];
        const parts = board.parts || [];
        
        for (let part of parts) {
            // EXACT ID MATCH - most reliable
            const partUniqueId = part.part_unique_id || part.instance_id || part.part_number;
            
            if (uniqueId && partUniqueId && uniqueId === partUniqueId) {
                foundPart = part;
                foundBoardIndex = boardIndex;
                console.log(`✅ EXACT ID MATCH: ${partUniqueId} on Board ${boardIndex + 1}`);
                break;
            }
        }
        
        if (foundPart) break;
    }
    
    if (!foundPart) {
        console.warn(`❌ No matching diagram part found for unique ID: ${uniqueId}`);
        return;
    }
    
    // Get the part ID for highlighting
    const partId = foundPart.part_unique_id || foundPart.part_number || foundPart.instance_id || foundPart.name;
    const boardNumber = foundBoardIndex + 1;
    
    console.log(`🎯 Highlighting: ${partId} on Board ${boardNumber}`);
    
    // Scroll to and highlight the diagram
    scrollToPieceDiagram(partId, boardNumber);
}

// REMOVED: Old modal-based 3D viewer code (initPartViewer, displayPartViewerFallback, etc.)
// Now using unified Assembly 3D Viewer with highlighting instead

function renderAssemblyViews(assemblyData) {
    console.log('DEBUG: renderAssemblyViews called with:', assemblyData);
    const container = document.getElementById('assemblyViewsContainer');
    console.log('DEBUG: assemblyViewsContainer found:', !!container);
    if (!container || !assemblyData || !assemblyData.views) {
        console.log('DEBUG: missing container or data');
        return;
    }
    
    const views = assemblyData.views;
    const entityName = assemblyData.entity_name || 'Assembly';
    
    console.log('DEBUG: Views keys:', Object.keys(views));
    
    // Build HTML for assembly views
    let html = `
    <div class="assembly-section" style="margin-top: 40px; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
        <h2 style="color: #00A5E3; border-bottom: 3px solid #00A5E3; padding-bottom: 10px;">Assembly: ${escapeHtml(entityName)}</h2>
        
        <h3 style="color: #555; margin-top: 20px;">Standard Views</h3>
        <div class="assembly-views-grid" style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; margin-bottom: 30px;">
    `;
    
    // Add each view - views are stored directly with view name as key and data URI as value
    const viewNames = ['Front', 'Back', 'Left', 'Right', 'Top', 'Bottom'];
    viewNames.forEach(viewName => {
        const imageData = views[viewName];
        console.log(`DEBUG: Looking for ${viewName}, found: ${!!imageData}`);
        if (imageData && imageData.startsWith('data:image')) {
            html += `
            <div class="assembly-view-item" style="background: #f9f9f9; padding: 12px; border-radius: 6px; border: 1px solid #ddd; cursor: pointer; transition: transform 0.2s;" onclick="openImageModal(this.querySelector('img'))">
                <h4 style="margin: 0 0 8px 0; color: #555; text-align: center; font-size: 13px;">${escapeHtml(viewName)}</h4>
                <img src="${imageData}" style="width: 100%; height: auto; border: 1px solid #ddd; border-radius: 4px;" onerror="console.log('Image failed to load for ${viewName}'); this.style.display='none';" />
            </div>
            `;
        }
    });
    
    html += `
        </div>
        
        <h3 style="color: #555; margin-top: 30px;">3D Interactive Model</h3>
        <div style="background: #ffffff; border: 1px solid #d0d7de; border-radius: 6px; overflow: hidden;">
            <div style="padding: 16px 20px; background: #2323FF; color: #ffffff; font-size: 16px; font-weight: 600; display: flex; justify-content: space-between; align-items: center;">
                <span>3D Assembly Viewer</span>
                <div style="display: flex; gap: 8px;">
                    <button onclick="toggleReportGrid()" style="background: #1a8cff; color: white; border: none; padding: 8px 16px; border-radius: 5px; cursor: pointer; font-weight: bold;">GRID</button>
                    <button onclick="toggleReportTexture()" style="background: #1a8cff; color: white; border: none; padding: 8px 16px; border-radius: 5px; cursor: pointer; font-weight: bold;">TEX</button>
                    <button onclick="setReportView('iso')" style="background: #1a8cff; color: white; border: none; padding: 8px 16px; border-radius: 5px; cursor: pointer; font-weight: bold;">ISO</button>
                    <button onclick="toggleReport3DViewer()" id="reportViewer3DPowerBtn" style="background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.4); color: white; width: 36px; height: 36px; border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: center;">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                            <path d="M12 2v10M18.36 6.64a9 9 0 1 1-12.73 0"/>
                        </svg>
                    </button>
                </div>
            </div>
            <div style="background: #1a1a1a; position: relative; height: 500px;">
                <canvas id="reportAssembly3DCanvas" style="display: none; width: 100%; height: 100%;"></canvas>
                <div id="reportExplodeControls" style="display: none; position: absolute; right: 60px; top: 50%; transform: translateY(-50%); height: 60%; flex-direction: column; align-items: center; gap: 10px; z-index: 100; background: rgba(255, 255, 255, 0.9); padding: 15px 8px; border-radius: 30px;">
                    <span style="writing-mode: vertical-rl; font-size: 11px; font-weight: 700; color: #4a4a4a;">EXPLODE</span>
                    <input type="range" min="0" max="100" value="0" id="reportExplodeSlider" oninput="updateReportExplosion(this.value)" style="writing-mode: vertical-lr; direction: rtl; width: 6px; height: 100%; cursor: ns-resize;">
                </div>
                <div id="reportViewControls" style="display: none; position: absolute; right: 10px; top: 10px; flex-direction: column; gap: 4px; z-index: 100;">
                    <button onclick="toggleReportProjection()" style="background: rgba(255,255,255,0.9); border: 1px solid #ddd; border-radius: 4px; cursor: pointer; padding: 6px; opacity: 0.9; transition: all 0.2s;" onmouseover="this.style.opacity='1'; this.style.background='rgba(255,255,255,1)'" onmouseout="this.style.opacity='0.9'; this.style.background='rgba(255,255,255,0.9)'" title="Toggle Perspective">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="2"><path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"/></svg>
                    </button>
                    <button onclick="setReportView('top')" style="background: rgba(255,255,255,0.9); border: 1px solid #ddd; border-radius: 4px; cursor: pointer; padding: 6px; opacity: 0.9; transition: all 0.2s;" onmouseover="this.style.opacity='1'; this.style.background='rgba(255,255,255,1)'" onmouseout="this.style.opacity='0.9'; this.style.background='rgba(255,255,255,0.9)'" title="Top View">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/></svg>
                    </button>
                    <button onclick="setReportView('front')" style="background: rgba(255,255,255,0.9); border: 1px solid #ddd; border-radius: 4px; cursor: pointer; padding: 6px; opacity: 0.9; transition: all 0.2s;" onmouseover="this.style.opacity='1'; this.style.background='rgba(255,255,255,1)'" onmouseout="this.style.opacity='0.9'; this.style.background='rgba(255,255,255,0.9)'" title="Front View">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="2"><rect x="3" y="8" width="18" height="8" rx="1"/></svg>
                    </button>
                    <button onclick="setReportView('right')" style="background: rgba(255,255,255,0.9); border: 1px solid #ddd; border-radius: 4px; cursor: pointer; padding: 6px; opacity: 0.9; transition: all 0.2s;" onmouseover="this.style.opacity='1'; this.style.background='rgba(255,255,255,1)'" onmouseout="this.style.opacity='0.9'; this.style.background='rgba(255,255,255,0.9)'" title="Right View">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="2"><rect x="8" y="3" width="8" height="18" rx="1"/></svg>
                    </button>
                    <button onclick="setReportView('iso')" style="background: rgba(255,255,255,0.9); border: 1px solid #ddd; border-radius: 4px; cursor: pointer; padding: 6px; opacity: 0.9; transition: all 0.2s;" onmouseover="this.style.opacity='1'; this.style.background='rgba(255,255,255,1)'" onmouseout="this.style.opacity='0.9'; this.style.background='rgba(255,255,255,0.9)'" title="Isometric View">
                        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="2"><path d="M12 2l9 5v10l-9 5-9-5V7l9-5z"/><path d="M12 22V12M12 12L3 7M12 12l9-5"/></svg>
                    </button>
                </div>
                <div id="reportViewer3DOffScreen" style="display: flex; flex-direction: column; align-items: center; justify-content: center; color: #4a4a4a; padding: 40px; height: 100%;">
                    <svg width="80" height="80" viewBox="0 0 24 24" fill="none" stroke="#4a4a4a" stroke-width="1.5" style="margin-bottom: 16px;">
                        <rect x="2" y="3" width="20" height="14" rx="2"/>
                        <path d="M8 21h8M12 17v4"/>
                    </svg>
                    <p style="font-size: 14px; margin: 0;">3D Viewer is OFF</p>
                    <p style="font-size: 12px; margin: 8px 0 0 0; opacity: 0.7;">Click power button to turn on</p>
                </div>
            </div>
        </div>
    </div>
    
    <style>
        .assembly-view-item:hover { transform: scale(1.02); box-shadow: 0 4px 12px rgba(0,0,0,0.15); }
    </style>
    `;
    
    container.innerHTML = html;
    
    // Initialize 3D viewer with assembly geometry data
    if (assemblyData.geometry && assemblyData.geometry.parts) {
        console.log('DEBUG: Initializing report 3D viewer with geometry data');
        window.reportAssemblyData = assemblyData.geometry;
    }
}

function openImageModal(imgElement) {
    // Create modal overlay
    const modal = document.createElement('div');
    modal.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.85);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 10000;
        cursor: pointer;
    `;
    
    // Create enlarged image container
    const imageContainer = document.createElement('div');
    imageContainer.style.cssText = `
        position: relative;
        max-width: 90vw;
        max-height: 90vh;
        display: flex;
        align-items: center;
        justify-content: center;
    `;
    
    // Create enlarged image
    const enlargedImg = document.createElement('img');
    enlargedImg.src = imgElement.src;
    enlargedImg.style.cssText = `
        max-width: 90vw;
        max-height: 90vh;
        object-fit: contain;
        border-radius: 8px;
        box-shadow: 0 10px 40px rgba(0, 0, 0, 0.3);
    `;
    
    // Create close button
    const closeBtn = document.createElement('button');
    closeBtn.innerHTML = '×';
    closeBtn.style.cssText = `
        position: absolute;
        top: -40px;
        right: 0;
        background: none;
        border: none;
        color: white;
        font-size: 40px;
        cursor: pointer;
        padding: 0;
        width: 40px;
        height: 40px;
        display: flex;
        align-items: center;
        justify-content: center;
        transition: transform 0.2s;
    `;
    closeBtn.onmouseover = () => closeBtn.style.transform = 'scale(1.2)';
    closeBtn.onmouseout = () => closeBtn.style.transform = 'scale(1)';
    closeBtn.onclick = (e) => {
        e.stopPropagation();
        modal.remove();
    };
    
    imageContainer.appendChild(enlargedImg);
    imageContainer.appendChild(closeBtn);
    modal.appendChild(imageContainer);
    
    // Close modal when clicking outside the image
    modal.onclick = () => modal.remove();
    
    // Close modal on Escape key
    const handleEscape = (e) => {
        if (e.key === 'Escape') {
            modal.remove();
            document.removeEventListener('keydown', handleEscape);
        }
    };
    document.addEventListener('keydown', handleEscape);
    
    document.body.appendChild(modal);
}

// Report 3D Viewer Control Functions
function toggleReport3DViewer() {
    const canvas = document.getElementById('reportAssembly3DCanvas');
    const offScreen = document.getElementById('reportViewer3DOffScreen');
    const controls = document.getElementById('reportViewControls');
    const explodeControls = document.getElementById('reportExplodeControls');
    const powerBtn = document.getElementById('reportViewer3DPowerBtn');
    
    if (!canvas || !offScreen) return;
    
    const isOff = canvas.style.display === 'none';
    
    if (isOff) {
        canvas.style.display = 'block';
        offScreen.style.display = 'none';
        if (controls) controls.style.display = 'flex';
        if (explodeControls) explodeControls.style.display = 'flex';
        if (powerBtn) powerBtn.style.background = 'rgba(76, 175, 80, 0.3)';
        
        if (!window.reportAssemblyScene && window.reportAssemblyData) {
            initReportAssemblyViewer();
        }
    } else {
        canvas.style.display = 'none';
        offScreen.style.display = 'flex';
        if (controls) controls.style.display = 'none';
        if (explodeControls) explodeControls.style.display = 'none';
        if (powerBtn) powerBtn.style.background = 'rgba(255,255,255,0.2)';
    }
}

function toggleReportDimensions() {
    if (window.reportShowDimensions !== undefined) {
        window.reportShowDimensions = !window.reportShowDimensions;
    }
}

function toggleReportRotation() {
    if (window.reportAutoRotate !== undefined) {
        window.reportAutoRotate = !window.reportAutoRotate;
        if (window.reportControls) window.reportControls.autoRotate = window.reportAutoRotate;
    }
}

function toggleReportGrid() {
    if (window.reportShowGrid !== undefined) {
        window.reportShowGrid = !window.reportShowGrid;
        if (window.reportGridHelper) window.reportGridHelper.visible = window.reportShowGrid;
    }
}

function toggleReportTexture() {
    console.log('🎨 TEX button clicked');
    console.log('🎨 Current reportShowTextures:', window.reportShowTextures);
    console.log('🎨 reportAssemblyGroups count:', window.reportAssemblyGroups ? window.reportAssemblyGroups.length : 'undefined');
    
    if (window.reportShowTextures !== undefined) {
        window.reportShowTextures = !window.reportShowTextures;
        console.log('🎨 Toggled reportShowTextures to:', window.reportShowTextures);
        
        // Apply texture toggle to all meshes
        if (window.reportAssemblyGroups) {
            window.reportAssemblyGroups.forEach((group, idx) => {
                group.traverse((child) => {
                    if (child.isMesh && child.material) {
                        const hasStoredTexture = child.userData.originalMaterial && child.userData.originalMaterial.map;
                        console.log(`🎨 Group ${idx} mesh - has map:`, !!child.material.map, 'has stored texture:', hasStoredTexture);
                        
                        if (window.reportShowTextures) {
                            // Show texture if available
                            if (hasStoredTexture) {
                                child.material.map = child.userData.originalMaterial.map;
                                child.material.color.setHex(0xFFFFFF);
                                child.material.needsUpdate = true;
                                console.log(`✅ Enabled texture for group ${idx}`);
                            } else {
                                console.log(`⚠️ No texture available for group ${idx}`);
                            }
                        } else {
                            // Hide texture, show color only
                            child.material.map = null;
                            child.material.color.setHex(0xcccccc);
                            child.material.needsUpdate = true;
                            console.log(`❌ Disabled texture for group ${idx}`);
                        }
                    }
                });
            });
        } else {
            console.log('❌ reportAssemblyGroups not found!');
        }
    } else {
        console.log('❌ reportShowTextures is undefined!');
    }
}

function toggleReportProjection() {
    if (!window.reportCamera || !window.reportControls) return;
    const canvas = document.getElementById('reportAssembly3DCanvas');
    if (!canvas) return;
    
    // Store current position and target
    const currentPos = window.reportCamera.position.clone();
    const currentTarget = window.reportControls.target.clone();
    
    const aspect = canvas.clientWidth / canvas.clientHeight;
    if (window.reportCamera.isPerspectiveCamera) {
        const frustumSize = 1000;
        window.reportCamera = new THREE.OrthographicCamera(frustumSize * aspect / -2, frustumSize * aspect / 2, frustumSize / 2, frustumSize / -2, 1, 50000);
    } else {
        window.reportCamera = new THREE.PerspectiveCamera(75, aspect, 1, 50000);
    }
    
    // Restore position and target
    window.reportCamera.position.copy(currentPos);
    window.reportControls.object = window.reportCamera;
    window.reportControls.target.copy(currentTarget);
    window.reportControls.update();
}

function setReportView(view) {
    if (!window.reportCamera || !window.reportControls || !window.reportAssemblyBounds) return;
    
    const distance = window.reportAssemblyBounds.size * 1.8; // Reduced from 2.5 to bring camera closer
    const center = window.reportAssemblyBounds.center;
    
    switch(view) {
        case 'top':
            window.reportCamera.position.set(center.x, distance, center.z);
            break;
        case 'front':
            window.reportCamera.position.set(center.x, center.y, distance);
            break;
        case 'right':
            window.reportCamera.position.set(distance, center.y, center.z);
            break;
        case 'iso':
            // Reduced multipliers to bring ISO view much closer
            window.reportCamera.position.set(distance * 0.5, distance * 0.4, distance * 0.5);
            break;
    }
    
    window.reportControls.target.copy(center);
    window.reportControls.update();
}

function updateReportExplosion(value) {
    if (!window.reportAssemblyGroups || window.reportAssemblyGroups.length === 0) return;
    const t = value / 100;
    const explosionDistance = 300;
    
    window.reportAssemblyGroups.forEach(group => {
        if (group.userData.explodeVector && group.userData.originalPosition) {
            const vec = group.userData.explodeVector;
            const orig = group.userData.originalPosition;
            
            // Apply explosion: original position + (explode vector * t * distance)
            group.position.set(
                orig.x + vec.x * t * explosionDistance,
                orig.y + vec.y * t * explosionDistance,
                orig.z + vec.z * t * explosionDistance
            );
        }
    });
}

function initReportAssemblyViewer() {
    const canvas = document.getElementById('reportAssembly3DCanvas');
    if (!canvas || !window.reportAssemblyData) return;
    console.log('Initializing report assembly viewer...');
    
    // Initialize THREE.js scene with LIGHT background
    window.reportAssemblyScene = new THREE.Scene();
    window.reportAssemblyScene.background = new THREE.Color(0xf0f0f0); // Light gray background
    
    window.reportCamera = new THREE.PerspectiveCamera(75, canvas.clientWidth / canvas.clientHeight, 1, 50000);
    window.reportCamera.position.set(500, 500, 500);
    
    window.reportRenderer = new THREE.WebGLRenderer({ canvas: canvas, antialias: true, alpha: false });
    window.reportRenderer.setSize(canvas.clientWidth, canvas.clientHeight);
    window.reportRenderer.setPixelRatio(window.devicePixelRatio);
    
    window.reportControls = new THREE.OrbitControls(window.reportCamera, canvas);
    window.reportControls.enableDamping = true;
    window.reportControls.dampingFactor = 0.1;
    
    const ambientLight = new THREE.AmbientLight(0xffffff, 0.6);
    window.reportAssemblyScene.add(ambientLight);
    
    const directionalLight = new THREE.DirectionalLight(0xffffff, 0.8);
    directionalLight.position.set(100, 100, 100);
    window.reportAssemblyScene.add(directionalLight);
    
    window.reportGridHelper = new THREE.GridHelper(2000, 20, 0xcccccc, 0xe0e0e0); // Light grid colors
    window.reportAssemblyScene.add(window.reportGridHelper);
    
    window.reportShowGrid = true;
    window.reportShowTextures = true;
    window.reportShowDimensions = false;
    window.reportAutoRotate = false;
    
    window.reportAssemblyGroups = [];
    
    // Render assembly using EXACT same logic as config tab
    const geometryData = window.reportAssemblyData;
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
        const uvs = [];
        const colors = [];
        let hasTexture = false;
        let texturePath = null;
        
        // Check if any face has a texture
        faces.forEach(face => {
            if (face.texture) {
                hasTexture = true;
                texturePath = face.texture;
            }
        });
        
        faces.forEach(face => {
            const vertices = face.vertices;
            const faceUVs = face.uvs;
            if (!vertices || vertices.length < 3) return;
            
            // Triangulate and swap Y/Z
            for (let i = 1; i < vertices.length - 1; i++) {
                positions.push(vertices[0].x, vertices[0].z, -vertices[0].y);
                positions.push(vertices[i].x, vertices[i].z, -vertices[i].y);
                positions.push(vertices[i + 1].x, vertices[i + 1].z, -vertices[i + 1].y);
                
                // Push UVs if available
                if (faceUVs && faceUVs.length === vertices.length) {
                    uvs.push(faceUVs[0].x, faceUVs[0].y);
                    uvs.push(faceUVs[i].x, faceUVs[i].y);
                    uvs.push(faceUVs[i + 1].x, faceUVs[i + 1].y);
                } else {
                    uvs.push(0, 0);
                    uvs.push(0.5, 0);
                    uvs.push(0.5, 0.5);
                }
            }
        });
        
        if (positions.length === 0) return;
        
        const geometry = new THREE.BufferGeometry();
        geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
        
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
            opacity: 0.85,
            emissive: 0x000000,
            emissiveIntensity: 1.0
        });
        
        const mesh = new THREE.Mesh(geometry, material);
        
        const edges = new THREE.EdgesGeometry(geometry, 15);
        const edgeMaterial = new THREE.LineBasicMaterial({ color: 0x666666 });
        const wireframe = new THREE.LineSegments(edges, edgeMaterial);
        
        const group = new THREE.Group();
        group.add(mesh);
        group.add(wireframe);
        
        // CRITICAL FIX: Store the viewer_unique_id for reliable matching
        const viewerUniqueId = partData.viewer_unique_id || `3D_${partIndex + 1}`;
        
        group.userData = {
            partName: partData.name,
            materialName: partData.material || "Default Material",
            width: partData.width || 0,
            height: partData.height || 0,
            thickness: partData.thickness || 0,
            explodeVector: new THREE.Vector3(...(partData.explode_vector || [0, 0, 0])),
            originalPosition: null, // Will be set after centering
            originalMaterial: {
                color: 0xcccccc,
                opacity: 0.85,
                transparent: true,
                map: null
            },
            originalEdgeColor: 0x666666,
            texturePath: texturePath,
            viewerUniqueId: viewerUniqueId,  // CRITICAL: Add unique ID for matching
            uniqueId: null  // Will be set by ID mapping
        };
        
        // Load texture if available
        if (hasTexture && texturePath) {
            console.log(`Loading texture for ${partData.name}: ${texturePath}`);
            const loader = new THREE.TextureLoader();
            loader.load(
                texturePath,
                (texture) => {
                    console.log(`✓ Texture loaded for ${partData.name}`);
                    texture.wrapS = THREE.RepeatWrapping;
                    texture.wrapT = THREE.RepeatWrapping;
                    mesh.material.map = texture;
                    mesh.material.color.setHex(0xFFFFFF);
                    mesh.material.needsUpdate = true;
                    
                    // Store texture in BOTH group userData AND mesh userData for toggle
                    group.userData.originalMaterial.map = texture;
                    mesh.userData.originalMaterial = mesh.userData.originalMaterial || {};
                    mesh.userData.originalMaterial.map = texture;
                    
                    console.log(`✓ Stored texture in userData for ${partData.name}`);
                },
                undefined,
                (error) => {
                    console.error(`✗ Failed to load texture for ${partData.name}:`, error);
                }
            );
        }
        
        if (partIndex === 0) {
            console.log(`First part explode vector:`, partData.explode_vector);
            console.log(`First part material:`, partData.material);
            console.log(`First part has texture:`, hasTexture);
        }
        
        window.reportAssemblyScene.add(group);
        window.reportAssemblyGroups.push(group);
        
        const box = new THREE.Box3().setFromObject(group);
        if (!allBounds) {
            allBounds = box;
        } else {
            allBounds.union(box);
        }
    });
    
    if (window.reportAssemblyGroups.length === 0) {
        console.warn('No valid parts rendered');
        return;
    }
    
    // Center camera on all parts
    const center = allBounds.getCenter(new THREE.Vector3());
    const size = allBounds.getSize(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z);
    
    // Center all parts and store their centered position as the original
    window.reportAssemblyGroups.forEach(group => {
        group.position.sub(center);
        group.userData.originalPosition = group.position.clone();
    });
    
    const distance = maxDim * 2.5;
    window.reportCamera.position.set(distance * 0.7, distance * 0.5, distance * 0.7);
    window.reportCamera.lookAt(0, 0, 0);
    window.reportControls.target.set(0, 0, 0);
    window.reportControls.update();
    
    // Store bounds for view functions
    window.reportAssemblyBounds = {
        min: allBounds.min,
        max: allBounds.max,
        center: new THREE.Vector3(0, 0, 0),
        size: maxDim
    };
    
    console.log('Assembly rendered:', window.reportAssemblyGroups.length, 'components');
    
    // Add click handler for 3D viewer to highlight diagram parts
    canvas.addEventListener('click', (event) => {
        handle3DViewerClick(event, canvas);
    });
    
    function animate() {
        requestAnimationFrame(animate);
        window.reportControls.update();
        window.reportRenderer.render(window.reportAssemblyScene, window.reportCamera);
    }
    animate();
    
    // CRITICAL FIX: Create ID mapping between 3D viewer parts and diagram parts
    // This must be done AFTER all parts are loaded
    createPartIdMapping();
    
    console.log('Report assembly viewer initialized');
}

// CRITICAL FIX: Create mapping between 3D viewer parts and diagram parts
// This function matches 3D viewer parts to their corresponding diagram part IDs (P27, P28, P29, P30)
function createPartIdMapping() {
    if (!window.reportAssemblyGroups || !g_boardsData) {
        console.warn('⚠️ Cannot create ID mapping - missing data');
        return;
    }
    
    console.log('🔗 Creating ID mapping between 3D viewer and diagrams...');
    
    // Collect all diagram parts with their IDs
    const diagramParts = [];
    g_boardsData.forEach((board, boardIndex) => {
        const parts = board.parts || [];
        parts.forEach(part => {
            const partId = part.part_unique_id || part.instance_id || part.part_number;
            if (partId) {
                diagramParts.push({
                    id: partId,
                    name: part.name,
                    material: part.material,
                    width: part.width,
                    height: part.height,
                    thickness: part.thickness || 0,
                    boardNumber: boardIndex + 1
                });
            }
        });
    });
    
    console.log(`📊 Found ${diagramParts.length} diagram parts with IDs`);
    console.log(`🎨 Found ${window.reportAssemblyGroups.length} 3D viewer parts`);
    
    // Match each 3D viewer part to a diagram part
    let matchCount = 0;
    const usedDiagramIds = new Set();
    
    window.reportAssemblyGroups.forEach((group, index) => {
        const viewerPart = group.userData;
        const viewerName = viewerPart.partName;
        const viewerMaterial = viewerPart.materialName;
        const viewerDims = [viewerPart.width, viewerPart.height, viewerPart.thickness].sort((a, b) => b - a);
        
        console.log(`\n🔍 Matching 3D part ${index + 1}: ${viewerName} | ${viewerMaterial} | ${viewerDims.join('×')}mm`);
        
        // Find matching diagram part (that hasn't been used yet)
        for (const diagramPart of diagramParts) {
            // Skip if already matched
            if (usedDiagramIds.has(diagramPart.id)) continue;
            
            // Match by name + material + dimensions
            const nameMatch = diagramPart.name === viewerName;
            const materialMatch = diagramPart.material === viewerMaterial;
            
            const diagramDims = [diagramPart.width, diagramPart.height, diagramPart.thickness].sort((a, b) => b - a);
            const tolerance = 1.0;
            const dimsMatch = Math.abs(viewerDims[0] - diagramDims[0]) < tolerance &&
                            Math.abs(viewerDims[1] - diagramDims[1]) < tolerance &&
                            Math.abs(viewerDims[2] - diagramDims[2]) < tolerance;
            
            if (nameMatch && materialMatch && dimsMatch) {
                // MATCH FOUND!
                group.userData.uniqueId = diagramPart.id;
                group.userData.partUniqueId = diagramPart.id;
                usedDiagramIds.add(diagramPart.id);
                matchCount++;
                console.log(`✅ MATCHED to diagram part: ${diagramPart.id} (Board ${diagramPart.boardNumber})`);
                break;
            }
        }
        
        if (!group.userData.uniqueId) {
            console.warn(`❌ No match found for 3D part ${index + 1}: ${viewerName}`);
        }
    });
    
    console.log(`\n🎯 ID Mapping complete: ${matchCount}/${window.reportAssemblyGroups.length} parts matched`);
}

function initAssemblyViewer(geometryData) {
    const container = document.getElementById('assemblyViewer');
    if (!container) {
        console.warn('Assembly viewer container not found');
        return;
    }
    
    // Check if THREE.js is available
    if (typeof THREE === 'undefined') {
        console.warn('THREE.js not available - 3D viewer disabled in exported HTML');
        container.innerHTML = '<p style="color: #999; text-align: center; padding: 40px; background: #f5f5f5; border-radius: 8px;">3D viewer not available in exported report. View assembly images above.</p>';
        return;
    }
    
    try {
        const scene = new THREE.Scene();
        scene.background = new THREE.Color(0xf0f0f0);
        
        const camera = new THREE.PerspectiveCamera(75, container.clientWidth / container.clientHeight, 0.1, 10000);
        
        const renderer = new THREE.WebGLRenderer({ antialias: true });
        renderer.setSize(container.clientWidth, container.clientHeight);
        renderer.shadowMap.enabled = true;
        container.appendChild(renderer.domElement);
        
        const controls = new THREE.OrbitControls(camera, renderer.domElement);
        controls.enableDamping = true;
        controls.dampingFactor = 0.1;
        
        const ambientLight = new THREE.AmbientLight(0xffffff, 1.2);
        scene.add(ambientLight);
        
        const keyLight = new THREE.DirectionalLight(0xffffff, 1.0);
        keyLight.position.set(5, 10, 7);
        scene.add(keyLight);
        
        const group = new THREE.Group();
        const mergedGeometry = new THREE.BufferGeometry();
        const positions = [];
        
        if (geometryData.faces && geometryData.faces.length > 0) {
            geometryData.faces.forEach(face => {
                const vertices = face.vertices;
                if (vertices.length < 3) return;
                
                for (let i = 1; i < vertices.length - 1; i++) {
                    positions.push(vertices[0].x, vertices[0].z, -vertices[0].y);
                    positions.push(vertices[i].x, vertices[i].z, -vertices[i].y);
                    positions.push(vertices[i + 1].x, vertices[i + 1].z, -vertices[i + 1].y);
                }
            });
        }
        
        if (positions.length > 0) {
            mergedGeometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
            mergedGeometry.computeVertexNormals();
            
            const material = new THREE.MeshStandardMaterial({ 
                color: 0xcccccc,
                metalness: 0.1,
                roughness: 0.6,
                side: THREE.DoubleSide
            });
            const mesh = new THREE.Mesh(mergedGeometry, material);
            
            const edges = new THREE.EdgesGeometry(mergedGeometry, 15);
            const edgeMaterial = new THREE.LineBasicMaterial({ color: 0x666666 });
            const wireframe = new THREE.LineSegments(edges, edgeMaterial);
            
            group.add(mesh);
            group.add(wireframe);
        }
        
        scene.add(group);
        
        const box = new THREE.Box3().setFromObject(group);
        const center = box.getCenter(new THREE.Vector3());
        const size = box.getSize(new THREE.Vector3());
        const maxDim = Math.max(size.x, size.y, size.z);
        
        group.position.sub(center);
        
        const distance = maxDim * 2.5;
        camera.position.set(distance * 0.7, distance * 0.5, distance * 0.7);
        camera.lookAt(0, 0, 0);
        controls.target.set(0, 0, 0);
        controls.update();
        
        function animate() {
            requestAnimationFrame(animate);
            controls.update();
            renderer.render(scene, camera);
        }
        animate();
        
        // Handle window resize
        window.addEventListener('resize', () => {
            const width = container.clientWidth;
            const height = container.clientHeight;
            camera.aspect = width / height;
            camera.updateProjectionMatrix();
            renderer.setSize(width, height);
        });
        
    } catch (error) {
        console.error('Error initializing assembly viewer:', error);
        container.innerHTML = '<p style="color: #666; text-align: center; padding: 20px;">3D viewer initialization failed</p>';
    }
}

function captureDiagramImages() {
    const diagrams = [];
    const canvases = document.querySelectorAll('.diagram-canvas');
    
    // Set flag to enable high-resolution rendering for PDF capture
    window.capturingForPDF = true;
    
    // Redraw all canvases at high resolution
    canvases.forEach(canvas => {
        if (canvas.drawCanvas) {
            canvas.drawCanvas();
        }
    });
    
    // Capture the high-resolution images
    canvases.forEach((canvas, index) => {
        try {
            // Use maximum quality (1.0) for PDF export instead of 0.8
            // PNG format with quality 1.0 ensures crisp, clear images
            const dataURL = canvas.toDataURL('image/png', 1.0);
            diagrams.push({
                index: index,
                image: dataURL,
                board: canvas.boardData
            });
        } catch (e) {
            console.error('Failed to capture diagram:', e);
        }
    });
    
    // Reset flag and redraw at normal resolution for display
    window.capturingForPDF = false;
    canvases.forEach(canvas => {
        if (canvas.drawCanvas) {
            canvas.drawCanvas();
        }
    });
    
    return diagrams;
}

function exportInteractiveHTML() {
    console.log('=== exportInteractiveHTML START ===');
    console.log('g_reportData:', !!g_reportData);
    console.log('g_boardsData:', !!g_boardsData);
    console.log('window.assemblyData:', window.assemblyData);
    console.log('window.assemblyData type:', typeof window.assemblyData);
    console.log('window.assemblyData keys:', window.assemblyData ? Object.keys(window.assemblyData) : 'null');
    
    if (!g_reportData || !g_boardsData) {
        alert('No report data available for HTML export.');
        return;
    }
    
    showProgressOverlay('Preparing interactive HTML export...', 10);
    
    const diagramImages = captureDiagramImages();
    
    const reportDataJSON = JSON.stringify({
        diagrams: g_boardsData,
        diagram_images: diagramImages,
        report: g_reportData,
        original_components: window.originalComponents || [],
        hierarchy_tree: window.hierarchyTree || [],
        assembly_data: window.assemblyData || null
    });
    
    const parsedData = JSON.parse(reportDataJSON);
    console.log('reportDataJSON assembly_data:', parsedData.assembly_data);
    console.log('reportDataJSON assembly_data type:', typeof parsedData.assembly_data);
    if (parsedData.assembly_data) {
        console.log('reportDataJSON assembly_data keys:', Object.keys(parsedData.assembly_data));
        console.log('reportDataJSON assembly_data.views count:', parsedData.assembly_data.views ? Object.keys(parsedData.assembly_data.views).length : 'no views');
    }
    console.log('=== exportInteractiveHTML END - calling Ruby ===');
    
    if (typeof callRuby === 'function') {
        callRuby('export_interactive_html', reportDataJSON);
        setTimeout(() => {
            hideProgressOverlay();
        }, 1000);
    } else {
        hideProgressOverlay();
        alert('Export function not available');
    }
}

function attachPartTableClickHandlers() {
    // No additional styling needed - buttons are styled via CSS
}

function scrollToPieceDiagram(partId, boardNumber) {
    console.log('scrollToPieceDiagram called:', partId, boardNumber);
    console.log('g_boardsData:', g_boardsData);
    
    // Find the board diagram that contains this piece
    const boardIndex = boardNumber - 1; // Convert to 0-based index
    
    if (!g_boardsData || g_boardsData.length === 0) {
        console.warn('g_boardsData is empty or not loaded');
        return;
    }
    
    if (boardIndex < 0 || boardIndex >= g_boardsData.length) {
        console.warn(`Board ${boardNumber} not found. Available boards: ${g_boardsData.length}`);
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
    
    // Check if this is the EXACT same piece (same partId AND same canvas) - only then toggle off
    if (currentHighlightedPiece === partId && currentHighlightedCanvas === targetCanvas) {
        console.log('Same piece clicked again - toggling off');
        clearPieceHighlight();
        return;
    }
    
    // Different piece or different board - clear previous and highlight new
    clearPieceHighlight();
    
    // Find the piece in the canvas data
    if (targetCanvas.partData) {
        for (let partData of targetCanvas.partData) {
            const partLabel = String(partData.part.part_unique_id || partData.part.part_number || partData.part.instance_id || `P${partData.part.index || 0}`);
            if (partLabel === partId) {
                // Highlight this piece on the canvas
                highlightPieceOnCanvas(targetCanvas, partData);
                currentHighlightedPiece = partId;
                currentHighlightedCanvas = targetCanvas;
                console.log('✅ Highlighted piece:', partId, 'on board', boardNumber);
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
    // Redraw the canvas to get a fresh state
    if (canvas.drawCanvas) {
        canvas.drawCanvas();
    }
    
    // Add a visual highlight by drawing a border around the piece
    const ctx = canvas.getContext('2d');
    ctx.strokeStyle = '#007bff';
    ctx.lineWidth = 4;
    ctx.shadowColor = 'rgba(0, 123, 255, 0.5)';
    ctx.shadowBlur = 8;
    ctx.shadowOffsetX = 0;
    ctx.shadowOffsetY = 0;

    // Draw highlight border with glow effect
    ctx.strokeRect(
        partData.x - 3,
        partData.y - 3,
        partData.width + 6,
        partData.height + 6
    );
    
    // Reset shadow
    ctx.shadowColor = 'transparent';
}

function copyTableAsMarkdown(tableId) {
    const tableContainer = document.getElementById(tableId);
    if (!tableContainer) {
        console.error(`Table or container with ID '${tableId}' not found.`);
        return;
    }
    
    const table = tableContainer.tagName === 'TABLE' ? tableContainer : tableContainer.querySelector('table');
    if (!table) {
        console.error(`No table found within container '${tableId}'.`);
        return;
    }
    
    let markdown = '';
    const rows = table.querySelectorAll('tr');
    
    if (rows.length === 0) {
        alert('No table data to copy.');
        return;
    }
    
    rows.forEach((row, index) => {
        const cells = row.querySelectorAll('th, td');
        const rowData = Array.from(cells).map(cell => {
            let text = cell.textContent.trim();
            text = text.replace(/\|/g, '\\|');
            return text;
        }).join(' | ');
        markdown += '| ' + rowData + ' |\n';
        
        if (index === 0 && row.querySelector('th')) {
            const separator = Array.from(cells).map(() => '---').join(' | ');
            markdown += '| ' + separator + ' |\n';
        }
    });
    
    if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(markdown).then(() => {
            showCopyFeedback();
        }).catch(() => fallbackCopyToClipboard(markdown));
    } else {
        fallbackCopyToClipboard(markdown);
    }
}

function showCopyFeedback() {
    const button = event?.target?.closest('.icon-btn');
    if (button) {
        const originalHTML = button.innerHTML;
        button.innerHTML = 'Ô£à';
        button.style.background = '#28a745';
        button.style.color = 'white';
        setTimeout(() => {
            button.innerHTML = originalHTML;
            button.style.background = '';
            button.style.color = '';
        }, 1500);
    } else {
        alert('Table copied as Markdown!');
    }
}

function fallbackCopyToClipboard(text) {
    const textArea = document.createElement('textarea');
    textArea.value = text;
    textArea.style.position = 'fixed';
    textArea.style.left = '-999999px';
    document.body.appendChild(textArea);
    textArea.select();
    
    try {
        document.execCommand('copy');
        alert('Table copied as Markdown!');
    } catch (err) {
        alert('Copy not supported.');
    } finally {
        document.body.removeChild(textArea);
    }
}

function copyCutSequenceAsMarkdown() {
    const container = document.getElementById('cutSequenceContainer');
    if (!container) return;
    
    let markdown = '# Cut Sequences\n\n';
    const boards = container.querySelectorAll('.cut-sequence-board');
    
    boards.forEach(board => {
        const title = board.querySelector('h4');
        const table = board.querySelector('table');
        
        if (title) markdown += `## ${title.textContent}\n\n`;
        if (table) {
            const rows = table.querySelectorAll('tr');
            rows.forEach((row, index) => {
                const cells = row.querySelectorAll('th, td');
                const rowData = Array.from(cells).map(cell => cell.textContent.trim()).join(' | ');
                markdown += '| ' + rowData + ' |\n';
                
                if (index === 0) {
                    const separator = Array.from(cells).map(() => '---').join(' | ');
                    markdown += '| ' + separator + ' |\n';
                }
            });
            markdown += '\n';
        }
    });
    
    navigator.clipboard.writeText(markdown).then(() => {
        alert('Cut sequences copied as Markdown!');
    }).catch(() => fallbackCopyToClipboard(markdown));
}

function clearPieceHighlight() {
    if (currentHighlightedCanvas && currentHighlightedCanvas.boardData) {
        // Redraw the canvas to remove highlight
        redrawCanvasDiagram(currentHighlightedCanvas, currentHighlightedCanvas.boardData);
        currentHighlightedCanvas = null;
        currentHighlightedPiece = null;
    }
}

function copyFullReportAsMarkdown() {
    if (!g_reportData || !g_boardsData) {
        alert('No report data available to copy.');
        return;
    }
    
    // Use globals from app.js
    const reportUnits = window.currentUnits || 'mm';
    const reportPrecision = window.currentPrecision ?? 1;
    const currency = g_reportData.summary.currency || window.defaultCurrency || 'USD';
    const currencySymbol = window.currencySymbols[currency] || currency;
    const currentAreaUnitLabel = getAreaUnitLabel();
    
    let markdown = `# AutoNestCut Report\n\n`;
    markdown += `**Generated:** ${new Date().toLocaleString()}\n\n`;
    
    // Project Information
    if (g_reportData.summary.project_name && g_reportData.summary.project_name !== 'Untitled Project') {
        markdown += `**Project:** ${g_reportData.summary.project_name}\n`;
    }
    if (g_reportData.summary.client_name) {
        markdown += `**Client:** ${g_reportData.summary.client_name}\n`;
    }
    if (g_reportData.summary.prepared_by) {
        markdown += `**Prepared by:** ${g_reportData.summary.prepared_by}\n`;
    }
    markdown += `\n---\n\n`;
    
    // Overall Summary
    markdown += `## Overall Summary\n\n`;
    markdown += `| Metric | Value |\n`;
    markdown += `|--------|-------|\n`;
    markdown += `| Total Parts Instances | ${g_reportData.summary.total_parts_instances || 0} |\n`;
    markdown += `| Total Unique Part Types | ${g_reportData.summary.total_unique_part_types || 0} |\n`;
    markdown += `| Total Boards | ${g_reportData.summary.total_boards || 0} |\n`;
    markdown += `| Overall Efficiency | ${formatNumber(g_reportData.summary.overall_efficiency || 0, reportPrecision)}% |\n`;
    markdown += `| Total Project Weight | ${formatNumber(g_reportData.summary.total_project_weight_kg || 0, 2)} kg |\n`;
    markdown += `| **Total Project Cost** | **${currencySymbol}${formatNumber(g_reportData.summary.total_project_cost || 0, 2)}** |\n\n`;
    
    // Materials Used
    if (g_reportData.unique_board_types && g_reportData.unique_board_types.length > 0) {
        markdown += `## Materials Used\n\n`;
        markdown += `| Material | Price per Sheet |\n`;
        markdown += `|----------|----------------|\n`;
        g_reportData.unique_board_types.forEach(board_type => {
            const boardCurrency = board_type.currency || currency;
            const boardSymbol = window.currencySymbols[boardCurrency] || boardCurrency;
            markdown += `| ${board_type.material} | ${boardSymbol}${formatNumber(board_type.price_per_sheet || 0, 2)} |\n`;
        });
        markdown += `\n`;
    }
    
    // Unique Part Types
    if (g_reportData.unique_part_types && g_reportData.unique_part_types.length > 0) {
        markdown += `## Unique Part Types\n\n`;
        markdown += `| Name | Width (${reportUnits}) | Height (${reportUnits}) | Thickness (${reportUnits}) | Material | Grain | Edge Banding | Qty | Total Area (${currentAreaUnitLabel}) | Weight (kg) |\n`;
        markdown += `|------|--------|---------|-----------|----------|-------|--------------|-----|-------------|-------------|\n`;
        
        g_reportData.unique_part_types.forEach(part_type => {
            const width = (part_type.width || 0) / window.unitFactors[reportUnits];
            const height = (part_type.height || 0) / window.unitFactors[reportUnits];
            const thickness = (part_type.thickness || 0) / window.unitFactors[reportUnits];
            const edgeBandingDisplay = typeof part_type.edge_banding === 'object' && part_type.edge_banding.type ? part_type.edge_banding.type : (part_type.edge_banding || 'None');
            
            markdown += `| ${part_type.name} | ${formatNumber(width, reportPrecision)} | ${formatNumber(height, reportPrecision)} | ${formatNumber(thickness, reportPrecision)} | ${part_type.material} | ${part_type.grain_direction || 'Any'} | ${edgeBandingDisplay} | ${part_type.total_quantity} | ${getAreaDisplay(part_type.total_area)} | ${formatNumber(part_type.total_weight_kg || 0, 2)} |\n`;
        });
        markdown += `\n`;
    }
    
    // Sheet Inventory Summary
    if (g_reportData.unique_board_types && g_reportData.unique_board_types.length > 0) {
        markdown += `## Sheet Inventory Summary\n\n`;
        markdown += `| Material | Dimensions (${reportUnits}) | Count | Total Area (${currentAreaUnitLabel}) | Price/Sheet | Total Cost |\n`;
        markdown += `|----------|-------------|-------|-------------|-------------|------------|\n`;
        
        g_reportData.unique_board_types.forEach(board_type => {
            const boardCurrency = board_type.currency || currency;
            const boardSymbol = window.currencySymbols[boardCurrency] || boardCurrency;
            const width = parseFloat(board_type.stock_width) / window.unitFactors[reportUnits];
            const height = parseFloat(board_type.stock_height) / window.unitFactors[reportUnits];
            const dimensionsStr = `${formatNumber(width, reportPrecision)} × ${formatNumber(height, reportPrecision)}`;
            
            markdown += `| ${board_type.material} | ${dimensionsStr} | ${board_type.count} | ${getAreaDisplay(board_type.total_area)} | ${boardSymbol}${formatNumber(board_type.price_per_sheet || 0, 2)} | ${boardSymbol}${formatNumber(board_type.total_cost || 0, 2)} |\n`;
        });
        markdown += `\n`;
    }
    
    // Boards Summary with Parts
    markdown += `## Boards Summary\n\n`;
    g_boardsData.forEach((board, index) => {
        const width = (board.stock_width || 0) / window.unitFactors[reportUnits];
        const height = (board.stock_height || 0) / window.unitFactors[reportUnits];
        
        markdown += `### Board ${index + 1}: ${board.material}\n\n`;
        markdown += `- **Size:** ${formatNumber(width, reportPrecision)} × ${formatNumber(height, reportPrecision)} ${reportUnits}\n`;
        markdown += `- **Parts:** ${board.parts ? board.parts.length : 0}\n`;
        markdown += `- **Efficiency:** ${formatNumber(board.efficiency_percentage, 1)}%\n`;
        markdown += `- **Waste:** ${formatNumber(board.waste_percentage, 1)}%\n\n`;
        
        if (board.parts && board.parts.length > 0) {
            markdown += `**Parts on this board:**\n\n`;
            markdown += `| Part ID | Name | Dimensions (${reportUnits}) | Material | Grain | Edge Banding |\n`;
            markdown += `|---------|------|-------------|----------|-------|-------------|\n`;
            
            board.parts.forEach(part => {
                const partW = (part.width || 0) / window.unitFactors[reportUnits];
                const partH = (part.height || 0) / window.unitFactors[reportUnits];
                const partId = part.part_unique_id || part.part_number || part.instance_id || '-';
                const edgeBandingDisplay = typeof part.edge_banding === 'object' && part.edge_banding.type ? part.edge_banding.type : (part.edge_banding || 'None');
                
                markdown += `| ${partId} | ${part.name} | ${formatNumber(partW, reportPrecision)} × ${formatNumber(partH, reportPrecision)} | ${part.material} | ${part.grain_direction || 'Any'} | ${edgeBandingDisplay} |\n`;
            });
            markdown += `\n`;
        }
    });
    
    // Cut Sequences
    if (g_reportData.cut_sequences && g_reportData.cut_sequences.length > 0) {
        markdown += `## Cut Sequences\n\n`;
        
        g_reportData.cut_sequences.forEach(board => {
            markdown += `### Sheet ${board.board_number}: ${board.material}\n\n`;
            markdown += `**Stock Size:** ${board.stock_dimensions}\n\n`;
            markdown += `| Step | Operation | Description | Measurement |\n`;
            markdown += `|------|-----------|-------------|-------------|\n`;
            
            board.cut_sequence.forEach(step => {
                markdown += `| ${step.step} | ${step.type} | ${step.description} | ${step.measurement} |\n`;
            });
            markdown += `\n`;
        });
    }
    
    // Usable Offcuts
    if (g_reportData.usable_offcuts && g_reportData.usable_offcuts.length > 0) {
        const currentAreaUnitLabel = getAreaUnitLabel();
        const reportUnits = window.reportUnits || window.currentUnits || 'mm';
        markdown += `## Usable Offcuts\n\n`;
        markdown += `| Sheet # | Material | Width (${reportUnits}) | Height (${reportUnits}) | Area (${currentAreaUnitLabel}) |\n`;
        markdown += `|---------|----------|------------|-------------|----------|\n`;
        
        g_reportData.usable_offcuts.forEach(offcut => {
            // Convert area from m² to current area units
            const areaMM2 = offcut.area_m2 * 1000000;
            const convertedArea = getAreaDisplay(areaMM2);
            
            // ✅ NEW: Convert dimensions from mm to current units
            let width, height;
            if (offcut.estimated_width_mm !== undefined && offcut.estimated_height_mm !== undefined) {
                width = formatDimension(offcut.estimated_width_mm);
                height = formatDimension(offcut.estimated_height_mm);
            } else {
                // Fallback: Parse the old format
                const match = offcut.estimated_dimensions.match(/(\d+)\s*x\s*(\d+)/);
                if (match) {
                    width = formatDimension(parseFloat(match[1]));
                    height = formatDimension(parseFloat(match[2]));
                } else {
                    width = offcut.estimated_dimensions;
                    height = '';
                }
            }
            
            markdown += `| ${offcut.board_number} | ${offcut.material} | ${width} | ${height} | ${convertedArea} |\n`;
        });
        markdown += `\n`;
    }
    
    // Detailed Parts List
    const parts_list = g_reportData.parts_placed || g_reportData.parts || [];
    if (parts_list.length > 0) {
        markdown += `## Cut List & Part Details\n\n`;
        markdown += `| ID | Name | Dimensions (${reportUnits}) | Material | Grain | Edge Banding | Board # |\n`;
        markdown += `|----|------|-------------|----------|-------|--------------|--------|\n`;
        
        parts_list.forEach(part => {
            const partId = part.part_unique_id || part.part_number || '-';
            const width = (part.width || 0) / window.unitFactors[reportUnits];
            const height = (part.height || 0) / window.unitFactors[reportUnits];
            const dimensionsStr = `${formatNumber(width, reportPrecision)} × ${formatNumber(height, reportPrecision)}`;
            const edgeBandingDisplay = typeof part.edge_banding === 'object' && part.edge_banding.type ? part.edge_banding.type : (part.edge_banding || 'None');
            
            markdown += `| ${partId} | ${part.name} | ${dimensionsStr} | ${part.material} | ${part.grain_direction || 'Any'} | ${edgeBandingDisplay} | ${part.board_number} |\n`;
        });
        markdown += `\n`;
    }
    
    // Cost Breakdown
    if (g_reportData.unique_board_types && g_reportData.unique_board_types.length > 0) {
        markdown += `## Cost Breakdown\n\n`;
        markdown += `| Material | Sheets Required | Unit Cost | Total Cost |\n`;
        markdown += `|----------|----------------|-----------|------------|\n`;
        
        g_reportData.unique_board_types.forEach(board_type => {
            const boardCurrency = board_type.currency || currency;
            const boardSymbol = window.currencySymbols[boardCurrency] || boardCurrency;
            markdown += `| ${board_type.material} | ${board_type.count} | ${boardSymbol}${formatNumber(board_type.price_per_sheet || 0, 2)} | ${boardSymbol}${formatNumber(board_type.total_cost || 0, 2)} |\n`;
        });
        markdown += `\n`;
    }
    
    markdown += `---\n\n`;
    markdown += `*Report generated by AutoNestCut*\n`;
    
    // Copy to clipboard
    navigator.clipboard.writeText(markdown).then(() => {
        const btn = document.getElementById('copyMarkdownButton');
        const originalHTML = btn.innerHTML;
        btn.innerHTML = 'Copied!';
        btn.style.background = '#28a745';
        btn.style.borderColor = '#28a745';
        btn.style.color = 'white';
        
        setTimeout(() => {
            btn.innerHTML = originalHTML;
            btn.style.background = '';
            btn.style.borderColor = '';
            btn.style.color = '';
        }, 2000);
    }).catch(err => {
        console.error('Failed to copy to clipboard:', err);
        alert('Failed to copy to clipboard. Please try again.');
    });
}

function toggleTreeView() {
    const treeContainer = document.getElementById('treeStructure');
    const searchContainer = document.getElementById('treeSearchContainer');
    const button = document.getElementById('treeToggle');
    
    if (treeContainer.style.display === 'none' || treeContainer.style.display === '') {
        renderTreeStructure();
        treeContainer.style.display = 'block';
        searchContainer.style.display = 'flex';
        button.textContent = 'Hide Tree Structure';
    } else {
        treeContainer.style.display = 'none';
        searchContainer.style.display = 'none';
        button.textContent = 'Show Tree Structure';
    }
}

function renderTreeStructure() {
    const container = document.getElementById('treeStructure');
    
    console.log('TREE DEBUG:', {
        hasTree: !!window.hierarchyTree,
        treeLength: window.hierarchyTree ? window.hierarchyTree.length : 0,
        treeData: window.hierarchyTree
    });
    
    if (!window.hierarchyTree || window.hierarchyTree.length === 0) {
        container.innerHTML = '<p style="padding: 20px; text-align: center; color: #656d76;">No component hierarchy available</p>';
        return;
    }
    
    let html = '<div class="tree-view">';
    window.hierarchyTree.forEach(component => {
        html += renderTreeNode(component, 0);
    });
    html += '</div>';
    
    console.log('Generated tree HTML:', html.substring(0, 200));
    container.innerHTML = html;
    console.log('Tree rendered, container has', container.children.length, 'children');
    
    // Auto-expand first level
    setTimeout(() => {
        document.querySelectorAll('.tree-children').forEach((el, index) => {
            if (el.parentElement.querySelector('.tree-node').style.marginLeft === '0px') {
                el.style.display = 'block';
                const expandIcon = el.parentElement.querySelector('.tree-expand');
                if (expandIcon) expandIcon.textContent = 'Ôû╝';
            }
        });
    }, 50);
}

function renderTreeNode(node, level) {
    const indent = level * 24;
    const hasChildren = node.children && node.children.length > 0;
    const expandIcon = hasChildren ? '▼' : '•';
    
    let html = `<div class="tree-node" style="margin-left: ${indent}px; padding: 10px 8px; border-bottom: 1px solid #e1e4e8; transition: background 0.15s;" onmouseover="this.style.background='#f6f8fa'" onmouseout="this.style.background='transparent'">
        <span class="tree-expand" onclick="toggleNode(this)" style="display: inline-block; width: 24px; cursor: ${hasChildren ? 'pointer' : 'default'}; user-select: none; color: #0366d6; font-size: 12px; font-weight: bold;">${expandIcon}</span>
        <span class="tree-name" style="font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; font-weight: 600; color: #24292e; font-size: 14px;">${escapeHtml(node.name || 'Unnamed')}</span>
        <span class="tree-info" style="font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; color: #586069; margin-left: 12px; font-size: 13px; font-style: italic;">${escapeHtml(node.material || 'No material')}</span>
    </div>`;
    
    if (hasChildren) {
        html += '<div class="tree-children" style="display: none;">';
        node.children.forEach(child => {
            html += renderTreeNode(child, level + 1);
        });
        html += '</div>';
    }
    
    return html;
}

function toggleNode(element) {
    const children = element.parentElement.nextElementSibling;
    if (children && children.classList.contains('tree-children')) {
        const isHidden = children.style.display === 'none';
        children.style.display = isHidden ? 'block' : 'none';
        element.textContent = isHidden ? 'Ôû╝' : 'ÔûÂ';
    }
}

function filterTree() {
    const search = document.getElementById('treeSearch').value.toLowerCase();
    const nodes = document.querySelectorAll('.tree-node');
    nodes.forEach(node => {
        const text = node.textContent.toLowerCase();
        node.style.display = text.includes(search) ? 'block' : 'none';
    });
}

function clearTreeSearch() {
    document.getElementById('treeSearch').value = '';
    filterTree();
}

function expandAll() {
    document.querySelectorAll('.tree-children').forEach(el => el.style.display = 'block');
    document.querySelectorAll('.tree-expand').forEach(el => {
        const hasChildren = el.parentElement.nextElementSibling && el.parentElement.nextElementSibling.classList.contains('tree-children');
        if (hasChildren) el.textContent = 'Ôû╝';
    });
}

function collapseAll() {
    document.querySelectorAll('.tree-children').forEach(el => el.style.display = 'none');
    document.querySelectorAll('.tree-expand').forEach(el => {
        const hasChildren = el.parentElement.nextElementSibling && el.parentElement.nextElementSibling.classList.contains('tree-children');
        if (hasChildren) el.textContent = 'ÔûÂ';
    });
}

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
        
        if (newLeftWidth > 300 && totalWidth - newLeftWidth > 400) {
            leftSide.style.flex = `0 0 ${newLeftWidth}px`;
            rightSide.style.flex = `1 1 auto`;
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
