// AutoNestCut Configuration UI - Build 20250119_1445
let currentSettings = {};
let partsData = {};
let modelMaterials = []; // Not explicitly used but kept for context.
// showOnlyUsed removed - Stock Materials table now always shows only used materials
let defaultCurrency = 'USD'; // Initialized from settings via Ruby later
let currentUnits = 'mm';    // Initialized from settings via Ruby later
let currentPrecision = 1;   // Initialized from settings via Ruby later
let currentAreaUnits = 'm2'; // Initialized from settings via Ruby later

// Currency exchange rates (base: USD)
// These rates are only for internal client-side display conversions if needed,
// the main currency should be handled by Ruby logic for persistence.
let exchangeRates = {
    'USD': 1.0,
    'EUR': 0.85,
    'SAR': 3.74,
    'AED': 3.67,
    'GBP': 0.79,
    'CAD': 1.25,
    'AUD': 1.35
};

// Unit conversion factors FROM unit TO mm (internal SketchUp units are always inches, but UI works in mm internally for calculation)
// Here, 1 unit means 1 mm.
const unitFactors = {
    'mm': 1,
    'cm': 10,
    'm': 1000,
    'in': 25.4,
    'ft': 304.8
};

// Area conversion factors (divisor to convert area FROM mm² TO target unit's square area)
// E.g., Area_in_Target_Unit = Area_in_mm2 / areaFactors['m2']
const areaFactors = {
    'mm2': 1,        // 1 mm² / 1 = 1 mm²
    'cm2': 100,      // 100 mm² / 100 = 1 cm²
    'm2': 1000000,   // 1,000,000 mm² / 1,000,000 = 1 m²
    'in2': 645.16,   // 645.16 mm² / 645.16 = 1 in²
    'ft2': 92903.04  // 92903.04 mm² / 92903.04 = 1 ft²
};

const currencySymbols = {
    'USD': '$', 'EUR': '€', 'GBP': '£', 'CAD': 'C$', 'AUD': 'A$',
    'JPY': '¥', 'CNY': '¥', 'INR': '₹', 'BRL': 'R$', 'MXN': '$',
    'CHF': 'CHF', 'SEK': 'kr', 'NOK': 'kr', 'DKK': 'kr', 'PLN': 'zł',
    'SAR': 'ر.س', 'AED': 'د.إ', 'KWD': 'د.ك', 'QAR': 'ر.ق', 'BHD': 'د.ب',
    'OMR': 'ر.ع', 'JOD': 'د.ا', 'LBP': 'ل.ل', 'EGP': 'ج.م', 'TND': 'د.ت',
    'MAD': 'د.م', 'DZD': 'د.ج', 'LYD': 'ل.د', 'IQD': 'د.ع', 'SYP': 'ل.س',
    'TRY': '₺', 'IRR': 'ریال'
};

// Convert value from mm to current display unit
function convertFromMM(valueInMM) {
    if (typeof valueInMM !== 'number' || isNaN(valueInMM)) return 0;
    return valueInMM / unitFactors[currentUnits];
}

// Convert value from current display unit to mm
function convertToMM(valueInDisplayUnit) {
    if (typeof valueInDisplayUnit !== 'number' || isNaN(valueInDisplayUnit)) return 0;
    return valueInDisplayUnit * unitFactors[currentUnits];
}

// Convert and format number with current precision (no unit suffix)
function formatDimension(valueInMM) {
    if (typeof valueInMM !== 'number' || isNaN(valueInMM) || valueInMM === 0) return '0'; // Return '0' for 0 values explicitly
    const converted = convertFromMM(valueInMM);
    if (currentPrecision == 0 || currentPrecision === '0' || currentPrecision === 0.0) {
        return Math.round(converted).toString();
    }
    return converted.toFixed(currentPrecision);
}

function getUnitLabel() {
    return currentUnits;
}

function getAreaUnitLabel() {
    // This is for display in headers like "Total Area (m²)"
    switch(currentAreaUnits) {
        case 'mm2': return 'mm²';
        case 'cm2': return 'cm²';
        case 'm2': return 'm²';
        case 'in2': return 'in²';
        case 'ft2': return 'ft²';
        default: return 'm²'; // Default to m² for report headers
    }
}


function receiveInitialData(data) {
    console.log('=== BUILD 20250119_1445 ===');
    console.log('Received initial data:', data);
    console.log('\n=== PARTS DATA DEBUG ===');
    console.log('Parts by material:', data.parts_by_material);
    Object.keys(data.parts_by_material || {}).forEach(mat => {
        console.log(`  Material Key: "${mat}" => ${data.parts_by_material[mat].length} parts`);
    });
    console.log('========================\n');
    
    currentSettings = data.settings;
    partsData = data.parts_by_material;
    window.hierarchyTree = data.hierarchy_tree || [];
    window.assemblyData = data.assembly_data || null; // Store assembly data globally
    
    if (window.assemblyData) {
        console.log('✓ Assembly data received:', window.assemblyData);
    } else {
        console.log('✗ No assembly data available');
    }
    
    defaultCurrency = currentSettings.default_currency || 'USD';
    currentUnits = currentSettings.units || 'mm';
    currentPrecision = currentSettings.precision !== undefined ? currentSettings.precision : 1;
    currentAreaUnits = currentSettings.area_units || 'm2';
    
    populateSettings();
    updateComponentsList(data.original_components || []);
    displayPartsPreview();
    updateUnitLabels();
    renderSelectionStatusTree(data.original_components || []);
    
    setTimeout(() => {
        if (typeof displayPartsPreview === 'function') {
            displayPartsPreview();
        }
    }, 100);
    
    if (window.currentReportData || window.g_reportData) {
        if (window.renderReport) window.renderReport();
        if (window.renderDiagrams) window.renderDiagrams();
    }

    const foldToggleBtn = document.getElementById('foldToggle');
    if (foldToggleBtn) {
        if (showOnlyUsed) {
            foldToggleBtn.classList.add('active');
            foldToggleBtn.textContent = 'Show All';
        } else {
            foldToggleBtn.classList.remove('active');
            foldToggleBtn.textContent = 'Used Only';
        }
    }
    displayMaterials();
}

/* COMMENTED OUT: addMaterial function - not needed for used-only materials view
function addMaterial() {
    const materialName = `New_Material_${Date.now()}`;
    
    currentSettings.stock_materials = currentSettings.stock_materials || {};
    currentSettings.stock_materials[materialName] = {
        width: 2440,
        height: 1220,
        thickness: 18,
        price: 0,
        currency: defaultCurrency // Use global default currency
    };
    
    displayMaterials();
    callRuby('save_materials', JSON.stringify(currentSettings.stock_materials));
}
*/

function removeMaterial(material) {
    console.log(`🗑️ Attempting to remove material: ${material}`);
    if (confirm(`Are you sure you want to remove material "${material}"?`)) {
        console.log(`✓ User confirmed deletion of: ${material}`);
        delete currentSettings.stock_materials[material];
        displayMaterials();
        console.log(`📤 Calling save_materials callback...`);
        callRuby('save_materials', JSON.stringify(currentSettings.stock_materials));
    } else {
        console.log(`✗ User cancelled deletion of: ${material}`);
    }
}

function updateMaterialName(input, oldName) {
    const newName = input.value.trim();
    if (newName !== oldName && newName !== '') {
        if (currentSettings.stock_materials[newName]) {
            alert(`Material with name "${newName}" already exists. Please choose a unique name.`);
            input.value = oldName; // Revert input value
            return;
        }
        currentSettings.stock_materials[newName] = currentSettings.stock_materials[oldName];
        
        // Remove auto_generated flag when user edits the material name
        // This allows users to "claim" auto-created materials by renaming them
        if (currentSettings.stock_materials[newName].auto_generated) {
            delete currentSettings.stock_materials[newName].auto_generated;
        }
        
        delete currentSettings.stock_materials[oldName];
        displayMaterials(); // Re-render to update UI (especially if sorted)
        callRuby('save_materials', JSON.stringify(currentSettings.stock_materials));
    } else if (newName === '') {
        alert('Material name cannot be empty.');
        input.value = oldName;
    }
}

function updateMaterialProperty(input, material, prop) {
    if (!currentSettings.stock_materials[material]) return;

    let value = parseFloat(input.value);
    if (isNaN(value)) {
        alert(`Invalid value for ${prop}. Please enter a number.`);
        input.value = prop === 'price' || prop === 'density' ? currentSettings.stock_materials[material][prop] : formatDimension(currentSettings.stock_materials[material][prop]);
        return;
    }

    if (prop === 'price' || prop === 'density') {
        currentSettings.stock_materials[material][prop] = value;
    } else {
        currentSettings.stock_materials[material][prop] = convertToMM(value);
    }
    
    callRuby('save_materials', JSON.stringify(currentSettings.stock_materials));
}


function formatPrice(price, currency) {
    const symbol = currencySymbols[currency] || currency;
    return `${symbol}${parseFloat(price || 0).toFixed(2)}`;
}

function populateSettings() {
    const kerfInput = document.getElementById('kerf_width');
    const rotationInput = document.getElementById('allow_rotation');
    const projectNameInput = document.getElementById('project_name');
    const clientNameInput = document.getElementById('client_name');
    
    if (kerfInput) {
        kerfInput.value = formatDimension(currentSettings.kerf_width || 3.0);
    }
    if (rotationInput) {
        rotationInput.checked = currentSettings.allow_rotation !== false;
    }
    if (projectNameInput) {
        projectNameInput.value = currentSettings.project_name || '';
    }
    if (clientNameInput) {
        clientNameInput.value = currentSettings.client_name || '';
    }
    
    const preparedByInput = document.getElementById('prepared_by');
    if (preparedByInput) {
        preparedByInput.value = currentSettings.prepared_by || '';
    }
    
    // Set global settings controls with proper checks
    // Using setTimeout to ensure DOM elements are fully available after potential re-renders
    setTimeout(() => {
        const unitsSelect = document.getElementById('settingsUnits');
        if (unitsSelect) unitsSelect.value = currentUnits;
        
        const precisionSelect = document.getElementById('settingsPrecision');
        if (precisionSelect) precisionSelect.value = currentPrecision.toString();
        
        const areaUnitsSelect = document.getElementById('settingsAreaUnits');
        if (areaUnitsSelect) areaUnitsSelect.value = currentAreaUnits;
        
        const modalCurrencySelect = document.getElementById('settingsCurrency');
        if (modalCurrencySelect) modalCurrencySelect.value = defaultCurrency;
        
        // This dropdown is now removed from main.html, so this block is technically obsolete
        // const materialListDefaultCurrencySelect = document.getElementById('defaultCurrency');
        // if (materialListDefaultCurrencySelect) materialListDefaultCurrencySelect.value = defaultCurrency;
    }, 50);
    
    // Initialize stock_materials if it doesn't exist
    if (!currentSettings.stock_materials) {
        currentSettings.stock_materials = {};
    }
    
    // Auto-load materials from detected parts
    const detectedMaterials = new Set();
    Object.keys(partsData).forEach(material => {
        detectedMaterials.add(material);
    });
    
    // Add detected materials to stock_materials if not already present with standard dimensions
    detectedMaterials.forEach(material => {
        if (!currentSettings.stock_materials[material]) {
            currentSettings.stock_materials[material] = { 
                width: 2440, 
                height: 1220, 
                thickness: 18, 
                price: 0, 
                currency: defaultCurrency 
            };
        }
    });
    
    displayMaterials();
}

function displayMaterials() {
    const container = document.getElementById('materials_tbody');
    if (!container) {
        console.error('Materials tbody element not found');
        return;
    }
    container.innerHTML = '';
    
    // PERFORMANCE FIX: Only load used materials to prevent memory leaks
    // Full database management available in separate Material Database dialog
    const usedMaterials = new Set();
    Object.keys(partsData).forEach(material => {
        usedMaterials.add(material);
    });
    
    // Only process materials that are actually used in the current model
    currentSettings.stock_materials = currentSettings.stock_materials || {};
    
    // Get sort option
    const sortBy = document.getElementById('sortBy')?.value || 'alphabetical';
    
    // Create material entries ONLY for used materials
    let materialEntries = [];
    usedMaterials.forEach(materialName => {
        // Get material data from stock_materials, or create default if missing
        const data = currentSettings.stock_materials[materialName] || {
            width: 2440,
            height: 1220,
            thickness: 18,
            price: 0,
            density: 600,
            currency: defaultCurrency,
            auto_generated: true
        };
        
        const usageCount = partsData[materialName]?.length || 0;
        
        // Filter out useless materials
        const isUseless = /tomtom|default/i.test(materialName);
        if (!isUseless) {
            materialEntries.push({
                name: materialName,
                data: data,
                isUsed: true,
                usageCount: usageCount
            });
        }
    });
    
    // Update material count indicator
    const countSpan = document.getElementById('materialCount');
    if (countSpan) {
        countSpan.textContent = materialEntries.length;
    }
    
    // Sort materials
    if (sortBy === 'alphabetical') {
        materialEntries.sort((a, b) => a.name.localeCompare(b.name));
    } else if (sortBy === 'usage') {
        materialEntries.sort((a, b) => b.isUsed - a.isUsed || a.name.localeCompare(b.name));
    } else if (sortBy === 'mostUsed') {
        materialEntries.sort((a, b) => b.usageCount - a.usageCount || a.name.localeCompare(b.name));
    }
    
    const unitLabel = getUnitLabel();
    
    materialEntries.forEach(entry => {
        const { name: material, data, isUsed } = entry;
        let width, height, thickness, price, currency;
        
        if (Array.isArray(data)) { // Legacy array format handling
            width = data[0] || 2440;
            height = data[1] || 1220;
            thickness = 18;
            price = 0;
            currency = defaultCurrency;
        } else {
            width = data.width || 2440;
            height = data.height || 1220;
            thickness = data.thickness || 18;
            price = data.price || 0;
            currency = defaultCurrency;
        }
        
        const tr = document.createElement('tr');
        
        // Check if this is an auto-generated material
        const isAutoCreated = data.auto_generated === true;
        
        // Material Name Cell with Google Sheets style
        const materialNameCell = document.createElement('td');
        materialNameCell.className = 'material-name-cell';
        const materialNameContent = document.createElement('div');
        materialNameContent.className = 'cell-content';
        
        const materialNameInput = document.createElement('textarea');
        materialNameInput.className = 'data-input';
        materialNameInput.value = material;
        materialNameInput.rows = 1;
        materialNameInput.addEventListener('input', function() {
            this.style.height = 'auto';
            this.style.height = (this.scrollHeight) + 'px';
        });
        materialNameInput.addEventListener('change', function() {
            updateMaterialName(this, material);
        });
        
        materialNameContent.appendChild(materialNameInput);
        
        // Add AUTO badge if auto-generated
        if (isAutoCreated) {
            const badgesContainer = document.createElement('div');
            badgesContainer.className = 'badges-container';
            const autoBadge = document.createElement('span');
            autoBadge.className = 'badge auto';
            autoBadge.textContent = 'AUTO';
            autoBadge.title = 'Auto-created material';
            badgesContainer.appendChild(autoBadge);
            materialNameContent.appendChild(badgesContainer);
        }
        
        materialNameCell.appendChild(materialNameContent);
        tr.appendChild(materialNameCell);
        
        // Width Cell
        const widthCell = document.createElement('td');
        const widthContent = document.createElement('div');
        widthContent.className = 'cell-content';
        const widthInput = document.createElement('input');
        widthInput.type = 'number';
        widthInput.className = 'data-input';
        widthInput.value = formatDimension(width);
        widthInput.addEventListener('change', function() {
            updateMaterialProperty(this, material, 'width');
        });
        widthContent.appendChild(widthInput);
        widthCell.appendChild(widthContent);
        tr.appendChild(widthCell);
        
        // Height Cell
        const heightCell = document.createElement('td');
        const heightContent = document.createElement('div');
        heightContent.className = 'cell-content';
        const heightInput = document.createElement('input');
        heightInput.type = 'number';
        heightInput.className = 'data-input';
        heightInput.value = formatDimension(height);
        heightInput.addEventListener('change', function() {
            updateMaterialProperty(this, material, 'height');
        });
        heightContent.appendChild(heightInput);
        heightCell.appendChild(heightContent);
        tr.appendChild(heightCell);
        
        // Thickness Cell
        const thicknessCell = document.createElement('td');
        const thicknessContent = document.createElement('div');
        thicknessContent.className = 'cell-content';
        const thicknessInput = document.createElement('input');
        thicknessInput.type = 'number';
        thicknessInput.className = 'data-input';
        thicknessInput.value = formatDimension(thickness);
        thicknessInput.addEventListener('change', function() {
            updateMaterialProperty(this, material, 'thickness');
        });
        thicknessContent.appendChild(thicknessInput);
        thicknessCell.appendChild(thicknessContent);
        tr.appendChild(thicknessCell);
        
        // Density Cell
        const densityCell = document.createElement('td');
        const densityContent = document.createElement('div');
        densityContent.className = 'cell-content';
        const densityInput = document.createElement('input');
        densityInput.type = 'number';
        densityInput.className = 'data-input';
        densityInput.value = data.density || 600;
        densityInput.step = '1';
        densityInput.addEventListener('change', function() {
            updateMaterialProperty(this, material, 'density');
        });
        densityContent.appendChild(densityInput);
        densityCell.appendChild(densityContent);
        tr.appendChild(densityCell);
        
        // Price Cell
        const priceCell = document.createElement('td');
        const priceContent = document.createElement('div');
        priceContent.className = 'cell-content';
        const priceInput = document.createElement('input');
        priceInput.type = 'number';
        priceInput.className = 'data-input';
        priceInput.value = parseFloat(price).toFixed(2);
        priceInput.step = '0.01';
        priceInput.addEventListener('change', function() {
            updateMaterialProperty(this, material, 'price');
        });
        priceContent.appendChild(priceInput);
        priceCell.appendChild(priceContent);
        tr.appendChild(priceCell);
        
        // Actions Cell
        const actionsCell = document.createElement('td');
        actionsCell.className = 'actions-cell';
        const actionsContent = document.createElement('div');
        actionsContent.className = 'cell-content';
        actionsContent.style.flexDirection = 'row';
        actionsContent.style.gap = '6px';
        
        // Highlight button
        const highlightBtn = document.createElement('button');
        highlightBtn.className = 'action-btn';
        highlightBtn.title = 'Highlight in SketchUp';
        highlightBtn.innerHTML = `
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/>
                <circle cx="12" cy="12" r="3"/>
            </svg>
        `;
        highlightBtn.addEventListener('click', function() {
            highlightMaterial(material);
        });
        actionsContent.appendChild(highlightBtn);
        
        // Delete button
        const deleteBtn = document.createElement('button');
        deleteBtn.className = 'action-btn delete';
        deleteBtn.title = 'Delete';
        deleteBtn.innerHTML = `
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="3,6 5,6 21,6"/>
                <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
                <line x1="10" y1="11" x2="10" y2="17"/>
                <line x1="14" y1="11" x2="14" y2="17"/>
            </svg>
        `;
        deleteBtn.addEventListener('click', function() {
            removeMaterial(material);
        });
        actionsContent.appendChild(deleteBtn);
        
        actionsCell.appendChild(actionsContent);
        tr.appendChild(actionsCell);
        
        container.appendChild(tr);
    });
}

function updateComponentsList(components) {
    const tbody = document.getElementById('componentsTableBody');
    const countSpan = document.getElementById('totalComponentsCount');
    
    if (!tbody) return;
    
    if (!components || components.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" style="text-align: center; color: #656d76; padding: 20px;">No components found</td></tr>';
        if (countSpan) countSpan.textContent = '0';
        return;
    }
    
    if (countSpan) countSpan.textContent = components.length;
    
    const unitLabel = getUnitLabel();
    tbody.innerHTML = '';
    
    components.forEach(comp => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${escapeHtml(comp.name || 'Unnamed')}</td>
            <td>${formatDimension(comp.width || 0)}</td>
            <td>${formatDimension(comp.height || 0)}</td>
            <td>${formatDimension(comp.thickness || 0)}</td>
            <td>${escapeHtml(comp.material || 'No material')}</td>
        `;
        tbody.appendChild(tr);
    });
}

function displayPartsPreview() {
    const tbody = document.getElementById('partsTableBody');
    if (!tbody) return;
    
    tbody.innerHTML = '';
    
    // CRITICAL FIX: If assembly data exists, populate from assembly parts to ensure 1:1 index mapping
    if (window.assemblyData && window.assemblyData.geometry && window.assemblyData.geometry.parts) {
        console.log('📊 Populating parts table from assembly data');
        const assemblyParts = window.assemblyData.geometry.parts;
        
        assemblyParts.forEach((part, partIndex) => {
            const tr = document.createElement('tr');
            tr.style.cursor = 'pointer';
            
            // CRITICAL: Store the index as a data attribute for reverse lookup
            tr.setAttribute('data-part-index', partIndex);
            
            // Pass the partIndex to match the 3D viewer mesh index
            tr.onclick = function() {
                selectPart(this, part.name, part.width || 0, part.height || 0, part.thickness || 0, partIndex);
            };
            
            const width = part.width || 0;
            const height = part.height || 0;
            const thickness = part.thickness || 0;
            const area = (width * height) / areaFactors[currentAreaUnits];
            
            const materialName = part.material || 'No Material';
            const materialData = currentSettings.stock_materials?.[materialName];
            const isAutoGenerated = materialData?.auto_generated === true;
            const autoTag = isAutoGenerated 
                ? ' <span style="display: inline-block; background: #ffc107; color: #856404; padding: 2px 6px; border-radius: 3px; font-size: 11px; font-weight: 600; margin-left: 4px;">AUTO</span>'
                : '';
            
            tr.innerHTML = `
                <td>${escapeHtml(part.name || 'Unnamed')}</td>
                <td>${formatDimension(width)}</td>
                <td>${formatDimension(height)}</td>
                <td>${formatDimension(thickness)}</td>
                <td>${escapeHtml(materialName)}${autoTag}</td>
                <td>1</td>
                <td>${area.toFixed(4)}</td>
            `;
            tbody.appendChild(tr);
        });
        
        console.log('✅ Parts table populated with', assemblyParts.length, 'rows (from assembly data)');
        return;
    }
    
    // FALLBACK: Use partsData if no assembly data available
    if (!partsData || Object.keys(partsData).length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align: center; color: #656d76; padding: 20px;">No parts to display</td></tr>';
        return;
    }
    
    const unitLabel = getUnitLabel();
    const areaLabel = getAreaUnitLabel();
    
    let globalPartIndex = 0;
    
    Object.keys(partsData).forEach(material => {
        const parts = partsData[material] || [];
        parts.forEach(part => {
            const displayName = part.name || 'Unnamed';
            const quantity = part.total_quantity || part.quantity || 1;
            
            // CRITICAL FIX: Create individual rows for each instance
            // This ensures each row maps to a specific 3D mesh by index
            for (let instanceNum = 0; instanceNum < quantity; instanceNum++) {
                const tr = document.createElement('tr');
                tr.style.cursor = 'pointer';
                
                // CRITICAL: Store the index as a data attribute for reverse lookup
                tr.setAttribute('data-part-index', globalPartIndex);
                
                // Pass the globalPartIndex to match the 3D viewer mesh index
                const currentIndex = globalPartIndex;
                tr.onclick = function() {
                    selectPart(this, displayName, part.width, part.height, part.thickness, currentIndex);
                };
                
                const area = (part.width * part.height) / areaFactors[currentAreaUnits];
                
                const materialData = currentSettings.stock_materials?.[material];
                const isAutoGenerated = materialData?.auto_generated === true;
                const autoTag = isAutoGenerated 
                    ? ' <span style="display: inline-block; background: #ffc107; color: #856404; padding: 2px 6px; border-radius: 3px; font-size: 11px; font-weight: 600; margin-left: 4px;">AUTO</span>'
                    : '';
                
                // Show instance number if there are multiple instances
                const instanceLabel = quantity > 1 ? ` #${instanceNum + 1}` : '';
                
                tr.innerHTML = `
                    <td>${escapeHtml(displayName)}${instanceLabel}</td>
                    <td>${formatDimension(part.width || 0)}</td>
                    <td>${formatDimension(part.height || 0)}</td>
                    <td>${formatDimension(part.thickness || 0)}</td>
                    <td>${escapeHtml(material)}${autoTag}</td>
                    <td>1</td>
                    <td>${area.toFixed(4)}</td>
                `;
                tbody.appendChild(tr);
                
                globalPartIndex++;
            }
        });
    });
    
    console.log('✅ Parts table populated with', globalPartIndex, 'rows');
}

// Small HTML escape used by parts preview
function escapeHtml(str) {
    return String(str).replace(/[&<>\"']/g, function (c) {
        return {'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":"&#39;"}[c];
    });
}

function processNesting() {
    // Update settings from form - convert kerf width to mm
    const kerfInput = document.getElementById('kerf_width');
    currentSettings.kerf_width = convertToMM(parseFloat(kerfInput.value));
    currentSettings.allow_rotation = document.getElementById('allow_rotation').checked;
    currentSettings.project_name = document.getElementById('project_name').value || 'Untitled Project';
    currentSettings.client_name = document.getElementById('client_name').value || '';
    currentSettings.prepared_by = document.getElementById('prepared_by').value || '';
    
    // Convert stock_materials to proper format for Ruby
    const convertedSettings = {
        kerf_width: currentSettings.kerf_width,
        allow_rotation: currentSettings.allow_rotation,
        project_name: currentSettings.project_name,
        client_name: currentSettings.client_name,
        prepared_by: currentSettings.prepared_by,
        default_currency: defaultCurrency,
        units: currentUnits,
        precision: currentPrecision,
        area_units: currentAreaUnits, // Pass area units to Ruby
        stock_materials: {} // Ruby expects this
    };
    
    Object.keys(currentSettings.stock_materials || {}).forEach(material => {
        const data = currentSettings.stock_materials[material];
        convertedSettings.stock_materials[material] = {
            width: data.width || 2440,
            height: data.height || 1220,
            thickness: data.thickness || 18,
            price: data.price || 0,
            density: data.density || 600,
            currency: defaultCurrency
        };
    });
    
    // Send to SketchUp
    callRuby('process', JSON.stringify(convertedSettings));
}

/* COMMENTED OUT: loadDefaults and importCSV functions - not needed for used-only materials view
function loadDefaults() {
    callRuby('load_default_materials');
}

function importCSV() {
    callRuby('import_materials_csv');
}
*/

function exportDatabase() {
    callRuby('export_materials_database');
}

/* REMOVED: toggleFold function - Stock Materials table now always shows only used materials
function toggleFold() {
    showOnlyUsed = !showOnlyUsed;
    const button = document.getElementById('foldToggle');
    const visuallyHiddenSpan = button.querySelector('.visually-hidden');

    if (showOnlyUsed) {
        button.classList.add('active');
        if (visuallyHiddenSpan) visuallyHiddenSpan.textContent = 'Show All Materials';
    } else {
        button.classList.remove('active');
        if (visuallyHiddenSpan) visuallyHiddenSpan.textContent = 'Show Used Only';
    }
    displayMaterials();
}
*/

function highlightMaterial(material) {
    callRuby('highlight_material', material);
}

function clearHighlight() {
    callRuby('clear_highlight');
}

/* COMMENTED OUT: purgeOldAutoMaterials and related functions - not needed for used-only materials view
function purgeOldAutoMaterials() {
    console.log(`🧹 Starting purge of old auto-materials...`);
    
    // Get list of materials to purge
    const materials = currentSettings.stock_materials || {};
    const activeMaterials = Object.keys(partsData || {});
    
    console.log(`📊 Total materials: ${Object.keys(materials).length}`);
    console.log(`📊 Active materials: ${activeMaterials.length}`);
    
    const toPurge = Object.keys(materials).filter(name => 
        name.startsWith('Auto_user_') && !activeMaterials.includes(name)
    );
    
    console.log(`🎯 Materials to purge: ${toPurge.length}`);
    toPurge.forEach(m => console.log(`  - ${m}`));
    
    if (toPurge.length === 0) {
        console.log(`ℹ️ No old auto-created materials to purge`);
        showMessage('No old auto-created materials to purge.\nAll Auto_user_* materials are currently in use.');
        return;
    }
    
    // Show custom confirmation dialog (not browser confirm which doesn't work in SketchUp)
    showPurgeConfirmationDialog(toPurge);
}

function showPurgeConfirmationDialog(toPurge) {
    console.log(`📋 Showing custom confirmation dialog for ${toPurge.length} materials`);
    
    const modal = document.createElement('div');
    modal.style.cssText = `position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 10000; display: flex; align-items: center; justify-content: center;`;
    
    const dialog = document.createElement('div');
    dialog.style.cssText = `background: white; padding: 20px; border-radius: 8px; max-width: 600px; width: 90%; max-height: 70vh; overflow-y: auto; box-shadow: 0 4px 20px rgba(0,0,0,0.3);`;
    
    const listHtml = toPurge.map(m => `<li style="margin: 5px 0; font-size: 12px; color: #333;">${escapeHtml(m)}</li>`).join('');
    
    dialog.innerHTML = `
        <h3 style="margin: 0 0 15px 0; color: #d73a49; font-size: 18px;">🧹 Purge Old Auto-Materials</h3>
        <p style="margin: 0 0 10px 0; color: #333; font-size: 14px;">Will remove ${toPurge.length} old auto-created materials that are not currently in use:</p>
        <ul style="margin: 0 0 20px 0; padding-left: 20px; max-height: 300px; overflow-y: auto; background: #f5f5f5; padding: 10px 20px; border-radius: 4px; border-left: 3px solid #ffc107;">
            ${listHtml}
        </ul>
        <div style="display: flex; gap: 10px; justify-content: flex-end;">
            <button id="purge-cancel-btn" style="background: #6c757d; color: white; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; font-size: 14px; font-weight: 600;">Cancel</button>
            <button id="purge-confirm-btn" style="background: #dc3545; color: white; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; font-size: 14px; font-weight: 600;">Purge Materials</button>
        </div>
    `;
    
    modal.appendChild(dialog);
    document.body.appendChild(modal);
    
    // Add event listeners to buttons
    const cancelBtn = dialog.querySelector('#purge-cancel-btn');
    const confirmBtn = dialog.querySelector('#purge-confirm-btn');
    
    cancelBtn.addEventListener('click', () => {
        console.log(`✗ User cancelled purge operation`);
        modal.remove();
    });
    
    confirmBtn.addEventListener('click', () => {
        console.log(`✓ User confirmed purge`);
        confirmPurge(toPurge);
        modal.remove();
    });
    
    // Close modal when clicking outside
    modal.addEventListener('click', (e) => {
        if (e.target === modal) {
            console.log(`✗ User cancelled purge (clicked outside)`);
            modal.remove();
        }
    });
}

function confirmPurge(toPurge) {
    console.log(`✓ User confirmed purge, calling Ruby callback...`);
    console.log(`📞 Invoking: sketchup.purge_old_auto_materials()`);
    
    try {
        if (typeof sketchup === 'object') {
            console.log(`✓ sketchup object exists`);
            sketchup.purge_old_auto_materials();
            console.log(`✓ Callback invoked successfully`);
        } else {
            console.error(`✗ sketchup object not available`);
        }
    } catch (e) {
        console.error(`✗ Error invoking callback:`, e);
    }
}

function removePurgedMaterials(purgedList) {
    console.log(`🗑️ [JS] Removing purged materials from currentSettings...`);
    console.log(`📋 Purged list:`, purgedList);
    
    if (!Array.isArray(purgedList)) {
        console.error(`✗ purgedList is not an array:`, purgedList);
        return;
    }
    
    let removedCount = 0;
    purgedList.forEach(materialName => {
        if (currentSettings.stock_materials && currentSettings.stock_materials[materialName]) {
            delete currentSettings.stock_materials[materialName];
            removedCount++;
            console.log(`  ✓ Removed: ${materialName}`);
        }
    });
    
    console.log(`✓ [JS] Removed ${removedCount} materials from currentSettings`);
}
*/

function getCurrentSettings() {
    // Update settings from form - convert kerf width to mm
    const kerfInput = document.getElementById('kerf_width');
    currentSettings.kerf_width = convertToMM(parseFloat(kerfInput.value));
    currentSettings.allow_rotation = document.getElementById('allow_rotation').checked;
    
    // Convert stock_materials to proper format for Ruby
    const convertedSettings = {
        kerf_width: currentSettings.kerf_width,
        allow_rotation: currentSettings.allow_rotation,
        default_currency: defaultCurrency, // Include default currency
        units: currentUnits, // Include units
        precision: currentPrecision, // Include precision
        area_units: currentAreaUnits, // Include area units
        stock_materials: {}
    };
    
    Object.keys(currentSettings.stock_materials || {}).forEach(material => {
        const data = currentSettings.stock_materials[material];
        convertedSettings.stock_materials[material] = {
            width: data.width || 2440,
            height: data.height || 1220,
            thickness: data.thickness || 18,
            price: data.price || 0,
            density: data.density || 600,
            currency: defaultCurrency
        };
    });
    
    return convertedSettings;
}

function callRuby(method, args) {
    if (typeof sketchup === 'object') {
        try {
            if (args !== undefined) {
                sketchup[method](args);
            } else {
                sketchup[method]();
            }
            console.log(`✓ Called Ruby: ${method}`);
        } catch (e) {
            console.error(`✗ Error calling Ruby method '${method}':`, e);
        }
    } else {
        console.warn(`✗ sketchup object not available`);
    }
}

function showError(message) {
    const modal = document.createElement('div');
    modal.style.cssText = `position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 10000; display: flex; align-items: center; justify-content: center;`;
    
    const dialog = document.createElement('div');
    dialog.style.cssText = `background: white; padding: 20px; border-radius: 8px; max-width: 500px; width: 90%; box-shadow: 0 4px 20px rgba(0,0,0,0.3);`;
    
    dialog.innerHTML = `
        <h3 style="margin: 0 0 15px 0; color: #d73a49; font-size: 18px;">⚠️ Component Dimension Error</h3>
        <p style="margin: 0 0 20px 0; line-height: 1.5; white-space: pre-line;">${message}</p>
        <div style="text-align: right;">
            <button onclick="this.closest('[style*=\"position: fixed\"]').remove()" style="background: #0366d6; color: white; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer; font-size: 14px;">OK</button>
        </div>
    `;
    
    modal.appendChild(dialog);
    document.body.appendChild(modal);
    
    modal.addEventListener('click', (e) => {
        if (e.target === modal) modal.remove();
    });
}

function showMessage(message) {
    const modal = document.createElement('div');
    modal.style.cssText = `position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.3); z-index: 10000; display: flex; align-items: center; justify-content: center;`;
    
    const dialog = document.createElement('div');
    dialog.style.cssText = `background: white; padding: 20px; border-radius: 8px; max-width: 500px; width: 90%; box-shadow: 0 4px 20px rgba(0,0,0,0.3);`;
    
    dialog.innerHTML = `
        <h3 style="margin: 0 0 15px 0; color: #28a745; font-size: 18px;">✓ Success</h3>
        <p style="margin: 0 0 20px 0; line-height: 1.5;">${message}</p>
        <div style="text-align: right;">
            <button id="message-ok-btn" style="background: #28a745; color: white; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer; font-size: 14px;">OK</button>
        </div>
    `;
    
    modal.appendChild(dialog);
    document.body.appendChild(modal);
    
    // Add event listener to OK button
    const okBtn = dialog.querySelector('#message-ok-btn');
    if (okBtn) {
        okBtn.addEventListener('click', () => {
            if (modal.parentNode) modal.remove();
        });
    }
    
    // Close modal when clicking outside
    modal.addEventListener('click', (e) => {
        if (e.target === modal) modal.remove();
    });
    
    // Auto-close after 3 seconds
    setTimeout(() => {
        if (modal.parentNode) modal.remove();
    }, 3000);
}


function updateUnits() {
    const select = document.getElementById('settingsUnits');
    if (!select) return;
    
    currentUnits = select.value;
    
    // Update backend setting immediately
    callRuby('update_global_setting', JSON.stringify({key: 'units', value: currentUnits}));
    // localStorage.setItem('autoNestCutUnits', currentUnits); // Remove localStorage, use Ruby for persistence
    
    updateUnitLabels();
    displayMaterials();
    displayPartsPreview();
    
    if (typeof renderReport === 'function' && typeof renderDiagrams === 'function') {
        renderReport();
        renderDiagrams();
    }
}

function updatePrecision() {
    const select = document.getElementById('settingsPrecision');
    if (!select) return;
    
    currentPrecision = parseInt(select.value);
    
    // Update backend setting immediately
    callRuby('update_global_setting', JSON.stringify({key: 'precision', value: currentPrecision}));
    // localStorage.setItem('autoNestCutPrecision', currentPrecision); // Remove localStorage, use Ruby for persistence
    
    displayMaterials();
    displayPartsPreview();
    
    if (typeof renderReport === 'function' && typeof renderDiagrams === 'function') {
        renderReport();
        renderDiagrams();
    }
}

function openSettings() {
    const modal = document.getElementById('settingsModal');
    if (modal) {
        modal.style.display = 'block';
        
        const unitsSelect = document.getElementById('settingsUnits');
        const precisionSelect = document.getElementById('settingsPrecision');
        const currencySelect = document.getElementById('settingsCurrency');
        const areaUnitsSelect = document.getElementById('settingsAreaUnits');
        
        if (unitsSelect) unitsSelect.value = currentUnits;
        if (precisionSelect) precisionSelect.value = currentPrecision.toString();
        if (areaUnitsSelect) areaUnitsSelect.value = currentAreaUnits;
        if (currencySelect) currencySelect.value = defaultCurrency;
        
        // Allow clicking outside to close
        modal.onclick = (e) => {
            if (e.target === modal) closeSettings();
        };
    }
}

function closeSettings() {
    const modal = document.getElementById('settingsModal');
    if (modal) {
        modal.style.display = 'none';
        modal.onclick = null; // Remove event listener to prevent memory leaks
    }
}

// These functions for exchange rates are no longer tied to main UI currency management
// and are effectively for a future feature or separate logic if needed.
function updateExchangeRate() {
    // ... (existing logic, not directly used in main currency flow)
}
function convertReportCurrency() {
    // ... (existing logic, not directly used in main currency flow)
}

function updateAreaUnits() {
    const select = document.getElementById('settingsAreaUnits');
    if (!select) return;
    
    currentAreaUnits = select.value;
    
    // Update backend setting immediately
    callRuby('update_global_setting', JSON.stringify({key: 'area_units', value: currentAreaUnits}));
    // localStorage.setItem('autoNestCutAreaUnits', currentAreaUnits); // Remove localStorage, use Ruby for persistence
    
    // Update report if it exists
    if (typeof renderReport === 'function') {
        renderReport();
    }
}

function updateCurrency() {
    const select = document.getElementById('settingsCurrency');
    if (!select) return;
    
    defaultCurrency = select.value;
    
    // Update backend setting immediately
    callRuby('update_global_setting', JSON.stringify({key: 'default_currency', value: defaultCurrency}));
    
    // Update current materials to use the new default currency
    Object.keys(currentSettings.stock_materials || {}).forEach(material => {
        const data = currentSettings.stock_materials[material];
        data.currency = defaultCurrency; // Explicitly update material's currency
    });
    callRuby('save_materials', JSON.stringify(currentSettings.stock_materials)); // Save updated materials list
    
    displayMaterials(); // Re-render materials list to reflect currency changes (though column is gone)
    
    // Update report if it exists
    if (typeof renderReport === 'function') {
        renderReport();
    }
}


function updateUnitLabels() {
    const unitText = currentUnits;
    
    // Update data-translate elements
    document.querySelectorAll('[data-translate="width_mm"]').forEach(el => {
        el.textContent = `Width (${unitText})`;
    });
    document.querySelectorAll('[data-translate="height_mm"]').forEach(el => {
        el.textContent = `Height (${unitText})`;
    });
    document.querySelectorAll('[data-translate="thickness_mm"]').forEach(el => {
        el.textContent = `Thickness (${unitText})`;
    });
    
    // Update kerf width label
    const kerfLabel = document.querySelector('label[for="kerf_width"]');
    if (kerfLabel) {
        kerfLabel.textContent = `Kerf Width (${unitText}):`;
    }
    
    // Update any other unit labels in the interface (e.g., in parts preview headers)
    document.querySelectorAll('.parts-preview-table thead th').forEach(el => {
        const text = el.textContent;
        if (text === 'W' || text === 'H' || text === 'T') {
            el.textContent = `${text} (${unitText})`;
        }
    });

    // Update parts preview table headers if they include W, H, T
    document.querySelectorAll('.parts-preview-table thead th').forEach(th => {
        const originalText = th.dataset.originalText || th.textContent;
        th.dataset.originalText = originalText; // Store original text
        if (originalText.startsWith('W (') || originalText.startsWith('H (') || originalText.startsWith('T (')) {
            // Skip, as these were formatted by default, or handle later if more complex
        } else if (originalText === 'W' || originalText === 'H' || originalText === 'T') {
            th.textContent = `${originalText} (${unitText})`;
        }
    });
}



// Initialize when page loads
window.addEventListener('load', function() {
    currentUnits = 'mm';
    currentPrecision = 1;
    currentAreaUnits = 'm2';
    defaultCurrency = 'USD';
    
    callRuby('ready');
    // Resizer is initialized by resizer_fix.js

    const foldToggleBtn = document.getElementById('foldToggle');
    if (foldToggleBtn) {
        if (showOnlyUsed) {
            foldToggleBtn.classList.add('active');
            const visuallyHiddenSpan = document.createElement('span');
            visuallyHiddenSpan.className = 'visually-hidden';
            visuallyHiddenSpan.textContent = 'Show All Materials';
            foldToggleBtn.appendChild(visuallyHiddenSpan);
        } else {
            const visuallyHiddenSpan = document.createElement('span');
            visuallyHiddenSpan.className = 'visually-hidden';
            visuallyHiddenSpan.textContent = 'Show Used Only';
            foldToggleBtn.appendChild(visuallyHiddenSpan);
        }
    }
});

window.showError = showError;


// Selection Status Tree for Configuration Tab
function renderSelectionStatusTree(components) {
    const container = document.getElementById('selectionStatusTree');
    if (!container || !components || components.length === 0) {
        if (container) container.innerHTML = '<p style="color: #656d76; text-align: center; padding: 20px;">No components selected</p>';
        return;
    }
    
    let html = '<div class="status-tree-view">';
    components.forEach(comp => {
        const isProcessed = comp.processed !== false; // Assume processed unless explicitly false
        const statusColor = isProcessed ? '#22863a' : '#d73a49';
        const statusIcon = isProcessed ? '✓' : '✗';
        const statusText = isProcessed ? 'Processed' : 'Skipped';
        
        html += `<div style="padding: 10px; margin-bottom: 8px; border-left: 4px solid ${statusColor}; background: ${isProcessed ? '#f0f9ff' : '#fff5f5'}; border-radius: 4px; transition: all 0.15s;" onmouseover="this.style.background='${isProcessed ? '#e0f2fe' : '#fee2e2'}'" onmouseout="this.style.background='${isProcessed ? '#f0f9ff' : '#fff5f5'}'">
            <div style="display: flex; align-items: center; gap: 12px;">
                <span style="font-size: 18px; color: ${statusColor}; font-weight: bold;">${statusIcon}</span>
                <div style="flex: 1;">
                    <div style="font-weight: 600; color: #24292e; font-size: 14px;">${escapeHtml(comp.name || 'Unnamed')}</div>
                    <div style="font-size: 12px; color: #586069; margin-top: 2px;">${escapeHtml(comp.material || 'No material')}</div>
                </div>
                <span style="font-size: 11px; font-weight: 600; color: ${statusColor}; text-transform: uppercase; letter-spacing: 0.5px;">${statusText}</span>
            </div>
        </div>`;
    });
    html += '</div>';
    
    container.innerHTML = html;
}
