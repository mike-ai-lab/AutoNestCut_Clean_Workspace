// Table customization functionality
let currentTableId = null;
let tableSettings = {};
// Apply Elegant template as global default
let globalTableSettings = {
    fontSize: '14px',
    cellPadding: '14px 18px',
    headerBg: '#007cba',
    headerColor: '#ffffff',
    borderWidth: '1px',
    borderColor: '#0ea5e9',
    textAlign: 'left',
    verticalAlign: 'middle',
    textWrap: 'normal',
    rowHover: '#f0f9ff'
};

// Undo history management
let undoHistory = [];
let maxUndoSteps = 20;

// Text labels and template management
let textLabels = {
    costLevels: {
        low: 'Budget',
        avg: 'Standard', 
        high: 'Premium'
    },
    tableHeaders: {
        level: 'Cost Category',
        cost: 'Unit Cost',
        efficiency: 'Material Efficiency'
    }
};

// Initialize table customization
function initTableCustomization() {
    // Load saved settings
    loadTableSettings();
    
    // Load text labels
    loadTextLabels();
    
    // Initialize templates
    initializeTemplates();
    
    // Add resize handles to all tables
    addResizeHandlesToTables();
    
    // Apply saved settings
    applyAllTableSettings();
}

// Open table customization panel
function openTableCustomization(tableId) {
    currentTableId = tableId;
    const panel = document.getElementById('tableCustomizationPanel');
    const overlay = document.querySelector('.modal-overlay');
    const title = document.getElementById('panelTitle');
    
    title.textContent = `Settings: ${getTableDisplayName(tableId)}`;
    panel.classList.add('active');
    overlay.style.display = 'block';
    
    // Load current settings for this table
    loadTableSettingsToPanel(tableId);
}

// Close table customization panel
function closeTableCustomization() {
    const panel = document.getElementById('tableCustomizationPanel');
    const overlay = document.querySelector('.modal-overlay');
    
    panel.classList.remove('active');
    overlay.style.display = 'none';
    currentTableId = null;
}

// Get display name for table
function getTableDisplayName(tableId) {
    const names = {
        'materialsUsedTable': 'Materials Used',
        'summaryTable': 'Summary',
        'uniquePartTypesTable': 'Part Types',
        'sheetInventoryTable': 'Sheet Inventory',
        'partsTable': 'Parts List'
    };
    return names[tableId] || tableId;
}

// Load table settings to panel
function loadTableSettingsToPanel(tableId) {
    const settings = tableSettings[tableId] || {};
    
    document.getElementById('tableFontSize').value = settings.fontSize || globalTableSettings.fontSize;
    document.getElementById('tableCellPadding').value = settings.cellPadding || globalTableSettings.cellPadding;
    document.getElementById('tableHeaderBg').value = settings.headerBg || globalTableSettings.headerBg;
    document.getElementById('tableHeaderColor').value = settings.headerColor || globalTableSettings.headerColor;
    document.getElementById('tableRowHover').value = settings.rowHover || globalTableSettings.rowHover;
    document.getElementById('tableTextAlign').value = settings.textAlign || globalTableSettings.textAlign;
    document.getElementById('tableVerticalAlign').value = settings.verticalAlign || globalTableSettings.verticalAlign;
    document.getElementById('tableTextWrap').value = settings.textWrap || globalTableSettings.textWrap;
    document.getElementById('tableBorderWidth').value = settings.borderWidth || globalTableSettings.borderWidth;
    document.getElementById('tableBorderColor').value = settings.borderColor || globalTableSettings.borderColor;
    
    // Update text label inputs
    updateTextLabelInputs();
}

// Apply table setting
function applyTableSetting(property, value) {
    if (!currentTableId) return;
    
    // Save current state to undo history
    saveToUndoHistory();
    
    // Initialize table settings if not exists
    if (!tableSettings[currentTableId]) {
        tableSettings[currentTableId] = {};
    }
    
    // Update setting
    tableSettings[currentTableId][property] = value;
    
    // Merge with global settings and apply
    const mergedSettings = { ...globalTableSettings, ...tableSettings[currentTableId] };
    applySettingsToTable(currentTableId, mergedSettings);
    
    // Save settings
    saveTableSettings();
}

// Apply global table setting
function applyGlobalTableSetting(property, value) {
    // Save current state to undo history
    saveToUndoHistory();
    
    globalTableSettings[property] = value;
    
    // Apply to all tables immediately (dynamic discovery)
    document.querySelectorAll('.table-with-controls table').forEach(table => {
        const tableId = table.id || '';
        const mergedSettings = { ...globalTableSettings, ...(tableSettings[tableId] || {}) };
        applySettingsToTable(tableId, mergedSettings);
    });
    
    // Update global controls
    updateGlobalControls();
    
    // Save settings
    saveTableSettings();
}

// Apply settings to specific table
function applySettingsToTable(tableId, settings) {
    const table = document.getElementById(tableId);
    if (!table) return;
    
    const fontSize = settings.fontSize || globalTableSettings.fontSize;
    const cellPadding = settings.cellPadding || globalTableSettings.cellPadding;
    const headerBg = settings.headerBg || globalTableSettings.headerBg;
    const headerColor = settings.headerColor || globalTableSettings.headerColor;
    const rowHover = settings.rowHover || globalTableSettings.rowHover;
    const textAlign = settings.textAlign || globalTableSettings.textAlign;
    const verticalAlign = settings.verticalAlign || globalTableSettings.verticalAlign;
    const textWrap = settings.textWrap || globalTableSettings.textWrap;
    const borderWidth = settings.borderWidth || globalTableSettings.borderWidth;
    const borderColor = settings.borderColor || globalTableSettings.borderColor;
    
    // Apply font size to table
    table.style.fontSize = fontSize;
    
    // Apply to all cells (th and td)
    const allCells = table.querySelectorAll('th, td');
    allCells.forEach(cell => {
        cell.style.setProperty('padding', cellPadding, 'important');
        cell.style.setProperty('text-align', textAlign, 'important');
        cell.style.setProperty('vertical-align', verticalAlign, 'important');
        
        // Handle text wrapping
        if (textWrap === 'nowrap') {
            cell.style.setProperty('white-space', 'nowrap', 'important');
            cell.style.setProperty('overflow', 'hidden', 'important');
            cell.style.setProperty('text-overflow', 'ellipsis', 'important');
            cell.style.setProperty('word-wrap', 'normal', 'important');
        } else if (textWrap === 'break-word') {
            cell.style.setProperty('white-space', 'pre-wrap', 'important');
            cell.style.setProperty('overflow', 'hidden', 'important');
            cell.style.setProperty('text-overflow', 'clip', 'important');
            cell.style.setProperty('word-wrap', 'break-word', 'important');
            cell.style.setProperty('word-break', 'break-all', 'important');
        } else { // normal wrap
            cell.style.setProperty('white-space', 'normal', 'important');
            cell.style.setProperty('overflow', 'visible', 'important');
            cell.style.setProperty('text-overflow', 'clip', 'important');
            cell.style.setProperty('word-wrap', 'break-word', 'important');
        }
        
        cell.style.setProperty('border-bottom-width', borderWidth, 'important');
        cell.style.setProperty('border-bottom-color', borderColor, 'important');
    });
    
    // Apply header-specific styles with !important
    const headers = table.querySelectorAll('th');
    headers.forEach(header => {
        header.style.setProperty('background-color', headerBg, 'important');
        header.style.setProperty('color', headerColor, 'important');
        header.style.setProperty('text-align', textAlign, 'important');
        
        // Update resize handle color to match header
        const handle = header.querySelector('.column-resize-handle');
        if (handle) {
            const darkerBg = darkenColor(headerBg, 20);
            handle.style.setProperty('background', `${darkerBg}66`, 'important'); // 40% opacity
            handle.style.setProperty('border-right-color', darkerBg, 'important');
        }
    });
    
    // Store hover color for dynamic application
    table.setAttribute('data-hover-color', rowHover);
    
    // Apply hover effect
    applyHoverEffect(table, rowHover);
}

// Apply all table settings
function applyAllTableSettings() {
    document.querySelectorAll('.table-with-controls table').forEach(table => {
        const tableId = table.id || '';
        const mergedSettings = tableSettings[tableId] ? 
            { ...globalTableSettings, ...tableSettings[tableId] } : 
            { ...globalTableSettings };
        applySettingsToTable(tableId, mergedSettings);
    });
}

// Reset table settings
function resetTableSettings() {
    if (!currentTableId) return;
    
    // Clear individual settings
    delete tableSettings[currentTableId];
    
    // Apply global settings only
    applySettingsToTable(currentTableId, globalTableSettings);
    
    // Update panel
    loadTableSettingsToPanel(currentTableId);
    
    // Save settings
    saveTableSettings();
}

// Apply all global settings
function applyAllGlobalSettings() {
    // Force apply global settings to all tables
    document.querySelectorAll('.table-with-controls table').forEach(table => {
        const tableId = table.id || '';
        applySettingsToTable(tableId, globalTableSettings);
    });
    
    // Save settings
    saveTableSettings();
    
    // Show feedback
    showApplyFeedback('Global settings applied to all tables!');
}

// Apply current table settings
function applyCurrentTableSettings() {
    if (!currentTableId) return;
    
    const mergedSettings = { ...globalTableSettings, ...(tableSettings[currentTableId] || {}) };
    applySettingsToTable(currentTableId, mergedSettings);
    
    // Save settings
    saveTableSettings();
    
    // Show feedback
    showApplyFeedback(`Settings applied to ${getTableDisplayName(currentTableId)}!`);
}

// Darken color utility function
function darkenColor(color, percent) {
    // Convert hex to RGB
    let r, g, b;
    if (color.startsWith('#')) {
        const hex = color.slice(1);
        r = parseInt(hex.substr(0, 2), 16);
        g = parseInt(hex.substr(2, 2), 16);
        b = parseInt(hex.substr(4, 2), 16);
    } else if (color.startsWith('rgb')) {
        const matches = color.match(/\d+/g);
        r = parseInt(matches[0]);
        g = parseInt(matches[1]);
        b = parseInt(matches[2]);
    } else {
        return color; // Return original if can't parse
    }
    
    // Darken by percentage
    r = Math.max(0, Math.floor(r * (100 - percent) / 100));
    g = Math.max(0, Math.floor(g * (100 - percent) / 100));
    b = Math.max(0, Math.floor(b * (100 - percent) / 100));
    
    return `rgb(${r}, ${g}, ${b})`;
}

// Apply current table settings to global
function applyToGlobal() {
    if (!currentTableId || !tableSettings[currentTableId]) return;
    
    // Save current state to undo history
    saveToUndoHistory();
    
    // Copy individual settings to global
    const individualSettings = tableSettings[currentTableId];
    Object.keys(individualSettings).forEach(key => {
        if (key !== 'columnWidths') { // Don't copy column widths
            globalTableSettings[key] = individualSettings[key];
        }
    });
    
    // Apply to all tables
    applyAllGlobalSettings();
    
    // Update global controls
    updateGlobalControls();
    
    // Show feedback
    showApplyFeedback(`${getTableDisplayName(currentTableId)} settings applied globally!`);
}

function showApplyFeedback(message) {
    // Toast messages removed
}

// Reset all table settings
function resetAllTableSettings() {
    // Clear all settings and reset to Compact template
    tableSettings = {};
    globalTableSettings = {
        fontSize: '12px',
        cellPadding: '4px 8px',
        headerBg: '#6b7280',
        headerColor: '#ffffff',
        borderWidth: '1px',
        borderColor: '#9ca3af',
        textAlign: 'left',
        verticalAlign: 'top',
        textWrap: 'nowrap',
        rowHover: '#f3f4f6'
    };
    
    // Apply to all tables
    applyAllTableSettings();
    
    // Update controls
    updateGlobalControls();
    
    // Save settings
    saveTableSettings();
    
    // Show feedback
    showApplyFeedback('All table settings reset to Compact template!');
}

// Update global controls
function updateGlobalControls() {
    const controls = {
        'globalFontSize': globalTableSettings.fontSize,
        'globalCellPadding': globalTableSettings.cellPadding,
        'globalHeaderBg': globalTableSettings.headerBg,
        'globalHeaderColor': globalTableSettings.headerColor,
        'globalRowHover': globalTableSettings.rowHover,
        'globalTextAlign': globalTableSettings.textAlign,
        'globalVerticalAlign': globalTableSettings.verticalAlign,
        'globalTextWrap': globalTableSettings.textWrap,
        'globalBorderWidth': globalTableSettings.borderWidth,
        'globalBorderColor': globalTableSettings.borderColor
    };
    
    Object.keys(controls).forEach(id => {
        const element = document.getElementById(id);
        if (element && controls[id]) {
            element.value = controls[id];
        }
    });
}

// Add resize handles to tables
function addResizeHandlesToTables() {
    const tables = document.querySelectorAll('.table-with-controls table');
    tables.forEach(table => {
        // Only add handles if not already added
        if (!table.querySelector('.column-resize-handle')) {
            addResizeHandlesToTable(table);
        }
    });
}

// Add resize handles to specific table
function addResizeHandlesToTable(table) {
    const headers = table.querySelectorAll('th');
    headers.forEach((header, index) => {
        if (index < headers.length - 1) { // Don't add to last column
            const handle = document.createElement('div');
            handle.className = 'column-resize-handle';
            handle.title = 'Drag to resize column';
            
            // Add multiple event listeners for better responsiveness
            handle.addEventListener('mousedown', (e) => startResize(e, table, index));
            handle.addEventListener('mouseenter', () => {
                const headerBg = window.getComputedStyle(header).backgroundColor;
                const darkerBg = darkenColor(headerBg, 30);
                handle.style.background = darkerBg;
            });
            handle.addEventListener('mouseleave', () => {
                if (!handle.classList.contains('resizing')) {
                    const headerBg = window.getComputedStyle(header).backgroundColor;
                    const darkerBg = darkenColor(headerBg, 20);
                    handle.style.background = `${darkerBg}66`; // 40% opacity
                }
            });
            
            header.appendChild(handle);
        }
    });
}

// Start column resize
function startResize(e, table, columnIndex) {
    e.preventDefault();
    const startX = e.clientX;
    const startWidth = table.querySelectorAll('th')[columnIndex].offsetWidth;
    
    const handle = e.target;
    handle.classList.add('resizing');
    
    function doResize(e) {
        const diff = e.clientX - startX;
        const newWidth = Math.max(50, startWidth + diff); // Minimum 50px
        
        // Update column width
        const headers = table.querySelectorAll('th');
        const cells = table.querySelectorAll('td');
        
        headers[columnIndex].style.width = newWidth + 'px';
        
        // Update corresponding cells
        const rows = table.querySelectorAll('tr');
        rows.forEach(row => {
            const cell = row.children[columnIndex];
            if (cell) {
                cell.style.width = newWidth + 'px';
            }
        });
    }
    
    function stopResize() {
        handle.classList.remove('resizing');
        document.removeEventListener('mousemove', doResize);
        document.removeEventListener('mouseup', stopResize);
        
        // Save column widths
        saveColumnWidths(table);
    }
    
    document.addEventListener('mousemove', doResize);
    document.addEventListener('mouseup', stopResize);
}

// Save column widths
function saveColumnWidths(table) {
    const tableId = table.id;
    if (!tableId) return;
    
    const headers = table.querySelectorAll('th');
    const widths = Array.from(headers).map(th => th.style.width || 'auto');
    
    if (!tableSettings[tableId]) {
        tableSettings[tableId] = {};
    }
    tableSettings[tableId].columnWidths = widths;
    
    saveTableSettings();
}

// Apply column widths
function applyColumnWidths(table) {
    const tableId = table.id;
    if (!tableId || !tableSettings[tableId] || !tableSettings[tableId].columnWidths) return;
    
    const headers = table.querySelectorAll('th');
    const widths = tableSettings[tableId].columnWidths;
    
    headers.forEach((header, index) => {
        if (widths[index] && widths[index] !== 'auto') {
            header.style.width = widths[index];
            
            // Apply to corresponding cells
            const rows = table.querySelectorAll('tr');
            rows.forEach(row => {
                const cell = row.children[index];
                if (cell) {
                    cell.style.width = widths[index];
                }
            });
        }
    });
}

// Save table settings to localStorage
function saveTableSettings() {
    try {
        localStorage.setItem('autoNestCutTableSettings', JSON.stringify({
            global: globalTableSettings,
            individual: tableSettings
        }));
    } catch (e) {
    }
}

// Load table settings from localStorage
function loadTableSettings() {
    try {
        // First, check if we have embedded table settings from exported HTML
        if (typeof EMBEDDED_DATA !== 'undefined' && EMBEDDED_DATA.tableSettings) {
            const embeddedSettings = EMBEDDED_DATA.tableSettings;
            if (embeddedSettings.global) {
                globalTableSettings = embeddedSettings.global;
            }
            if (embeddedSettings.individual) {
                tableSettings = embeddedSettings.individual;
            }
            return; // Use embedded settings, don't check localStorage
        }
        
        const saved = localStorage.getItem('autoNestCutTableSettings');
        if (saved) {
            const data = JSON.parse(saved);
            if (data.global) {
                globalTableSettings = data.global;
            }
            if (data.individual) {
                tableSettings = data.individual;
            }
        } else {
            // No saved settings - ensure elegant template is default
            globalTableSettings = {
                fontSize: '14px',
                cellPadding: '14px 18px',
                headerBg: '#007cba',
                headerColor: '#ffffff',
                borderWidth: '1px',
                borderColor: '#0ea5e9',
                textAlign: 'left',
                verticalAlign: 'middle',
                textWrap: 'normal',
                rowHover: '#f0f9ff'
            };
            tableSettings = {};
            saveTableSettings();
        }
    } catch (e) {
    }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    console.log('[TABLE_CUSTOMIZATION] DOMContentLoaded fired');
    // Delay initialization to ensure tables are rendered
    setTimeout(() => {
        console.log('[TABLE_CUSTOMIZATION] Initializing table customization...');
        initTableCustomization();
        // Ensure all dynamically created tables have IDs; if missing, assign
        const tables = document.querySelectorAll('.table-with-controls table');
        console.log('[TABLE_CUSTOMIZATION] Found', tables.length, 'tables');
        tables.forEach((table, idx) => {
            if (!table.id) {
                table.id = `reportTable_${idx}`;
                console.log('[TABLE_CUSTOMIZATION] Assigned ID to table:', table.id);
            }
        });
        // Force apply settings immediately after initialization
        console.log('[TABLE_CUSTOMIZATION] Applying all table settings...');
        applyAllTableSettings();
        console.log('[TABLE_CUSTOMIZATION] Global settings:', globalTableSettings);
    }, 500);
});

// Also initialize when window loads (fallback)
window.addEventListener('load', function() {
    console.log('[TABLE_CUSTOMIZATION] Window load fired');
    setTimeout(() => {
        console.log('[TABLE_CUSTOMIZATION] Re-initializing on window load...');
        initTableCustomization();
        applyAllTableSettings();
    }, 1000);
});

// Also hook into report rendering - DEFERRED to ensure renderReport exists
setTimeout(() => {
    if (typeof window !== 'undefined' && typeof window.renderReport === 'function') {
        const originalRenderReport = window.renderReport;
        window.renderReport = function(...args) {
            console.log('[TABLE_CUSTOMIZATION] renderReport called');
            const result = originalRenderReport.apply(this, args);
            setTimeout(() => {
                console.log('[TABLE_CUSTOMIZATION] Re-initializing after report render...');
                reinitializeTableCustomization();
            }, 300);
            return result;
        };
        console.log('[TABLE_CUSTOMIZATION] Successfully hooked into renderReport');
    }
}, 1000);

// Apply hover effect to table
function applyHoverEffect(table, hoverColor) {
    // Remove existing hover styles
    const existingStyle = document.getElementById(`hover-style-${table.id}`);
    if (existingStyle) {
        existingStyle.remove();
    }
    
    // Create new hover style
    const style = document.createElement('style');
    style.id = `hover-style-${table.id}`;
    style.textContent = `
        #${table.id} tbody tr:hover {
            background-color: ${hoverColor} !important;
        }
    `;
    document.head.appendChild(style);
}

// Re-initialize when report is updated
function reinitializeTableCustomization() {
    console.log('[TABLE_CUSTOMIZATION] reinitializeTableCustomization called');
    setTimeout(() => {
        // Load settings first
        loadTableSettings();
        console.log('[TABLE_CUSTOMIZATION] Loaded settings:', globalTableSettings);
        
        // Add resize handles
        addResizeHandlesToTables();
        
        // Force apply settings to all tables
        console.log('[TABLE_CUSTOMIZATION] Applying all table settings...');
        applyAllTableSettings();
        
        // Apply column widths
        const tables = document.querySelectorAll('.table-with-controls table');
        console.log('[TABLE_CUSTOMIZATION] Applied settings to', tables.length, 'tables');
        tables.forEach(table => {
            applyColumnWidths(table);
        });
    }, 100);
}

// ======================================================================================
// TEMPLATE MANAGEMENT SYSTEM
// ======================================================================================

// Predefined templates
const predefinedTemplates = {
    'modern': {
        name: 'Modern',
        description: 'Clean modern look with subtle colors',
        settings: {
            fontSize: '14px',
            cellPadding: '12px 16px',
            headerBg: '#f8fafc',
            headerColor: '#1f2937',
            borderWidth: '1px',
            borderColor: '#e5e7eb',
            textAlign: 'left',
            verticalAlign: 'middle',
            textWrap: 'normal',
            rowHover: '#f1f5f9'
        }
    },
    'professional': {
        name: 'Professional',
        description: 'Business-ready with strong contrast',
        settings: {
            fontSize: '13px',
            cellPadding: '10px 14px',
            headerBg: '#1f2937',
            headerColor: '#ffffff',
            borderWidth: '2px',
            borderColor: '#374151',
            textAlign: 'left',
            verticalAlign: 'middle',
            textWrap: 'normal',
            rowHover: '#f9fafb'
        }
    },
    'compact': {
        name: 'Compact',
        description: 'Space-efficient for detailed data',
        settings: {
            fontSize: '12px',
            cellPadding: '4px 8px',
            headerBg: '#6b7280',
            headerColor: '#ffffff',
            borderWidth: '1px',
            borderColor: '#9ca3af',
            textAlign: 'left',
            verticalAlign: 'top',
            textWrap: 'nowrap',
            rowHover: '#f3f4f6'
        }
    },
    'elegant': {
        name: 'Elegant',
        description: 'Sophisticated design with soft colors',
        settings: {
            fontSize: '14px',
            cellPadding: '14px 18px',
            headerBg: '#007cba',
            headerColor: '#ffffff',
            borderWidth: '1px',
            borderColor: '#0ea5e9',
            textAlign: 'left',
            verticalAlign: 'middle',
            textWrap: 'normal',
            rowHover: '#f0f9ff'
        }
    },
    'minimal': {
        name: 'Minimal',
        description: 'Clean and simple with minimal borders',
        settings: {
            fontSize: '14px',
            cellPadding: '8px 12px',
            headerBg: '#ffffff',
            headerColor: '#374151',
            borderWidth: '0px',
            borderColor: '#ffffff',
            textAlign: 'left',
            verticalAlign: 'middle',
            textWrap: 'normal',
            rowHover: '#f9fafb'
        }
    }
};

// Initialize templates
function initializeTemplates() {
    populateTemplateSelectors();
}

// Populate template selectors
function populateTemplateSelectors() {
    const globalSelector = document.getElementById('templateSelector');
    const individualSelector = document.getElementById('individualTemplateSelector');
    
    if (globalSelector) {
        populateSelector(globalSelector);
    }
    if (individualSelector) {
        populateSelector(individualSelector);
    }
}

function populateSelector(selector) {
    // Clear existing options except first
    while (selector.children.length > 1) {
        selector.removeChild(selector.lastChild);
    }
    
    // Add predefined templates
    const predefinedGroup = document.createElement('optgroup');
    predefinedGroup.label = 'Built-in Templates';
    Object.keys(predefinedTemplates).forEach(key => {
        const option = document.createElement('option');
        option.value = `predefined:${key}`;
        option.textContent = predefinedTemplates[key].name;
        predefinedGroup.appendChild(option);
    });
    selector.appendChild(predefinedGroup);
    
    // Add custom templates
    const customTemplates = getCustomTemplates();
    if (Object.keys(customTemplates).length > 0) {
        const customGroup = document.createElement('optgroup');
        customGroup.label = 'My Templates';
        Object.keys(customTemplates).forEach(key => {
            const option = document.createElement('option');
            option.value = `custom:${key}`;
            option.textContent = customTemplates[key].name;
            customGroup.appendChild(option);
        });
        selector.appendChild(customGroup);
    }
}

// Load selected template
function loadSelectedTemplate() {
    const selector = document.getElementById('templateSelector');
    const value = selector.value;
    if (!value) return;
    
    const [type, key] = value.split(':');
    let template;
    
    if (type === 'predefined') {
        template = predefinedTemplates[key];
    } else {
        const customTemplates = getCustomTemplates();
        template = customTemplates[key];
    }
    
    if (template) {
        // Apply template to global settings
        Object.keys(template.settings).forEach(prop => {
            globalTableSettings[prop] = template.settings[prop];
        });
        
        // Apply to all tables
        applyAllGlobalSettings();
        
        // Update controls
        updateGlobalControls();
        
        showApplyFeedback(`Template "${template.name}" applied globally!`);
    }
}

// Load individual template
function loadIndividualTemplate() {
    const selector = document.getElementById('individualTemplateSelector');
    const value = selector.value;
    if (!value || !currentTableId) return;
    
    const [type, key] = value.split(':');
    let template;
    
    if (type === 'predefined') {
        template = predefinedTemplates[key];
    } else {
        const customTemplates = getCustomTemplates();
        template = customTemplates[key];
    }
    
    if (template) {
        // Apply template to current table
        if (!tableSettings[currentTableId]) {
            tableSettings[currentTableId] = {};
        }
        
        Object.keys(template.settings).forEach(prop => {
            tableSettings[currentTableId][prop] = template.settings[prop];
        });
        
        // Apply settings
        const mergedSettings = { ...globalTableSettings, ...tableSettings[currentTableId] };
        applySettingsToTable(currentTableId, mergedSettings);
        
        // Update panel
        loadTableSettingsToPanel(currentTableId);
        
        // Save settings
        saveTableSettings();
        
        showApplyFeedback(`Template "${template.name}" applied to ${getTableDisplayName(currentTableId)}!`);
    }
}

// Save current global template
function saveCurrentGlobalTemplate() {
    showTemplateNameDialog('global');
}

// Save current settings as template
function saveCurrentAsTemplate() {
    if (!currentTableId) return;
    showTemplateNameDialog('individual');
}

// Show template name dialog (modal instead of prompt)
function showTemplateNameDialog(type) {
    const modal = document.createElement('div');
    modal.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0,0,0,0.5);
        z-index: 10000;
        display: flex;
        align-items: center;
        justify-content: center;
    `;
    
    const dialog = document.createElement('div');
    dialog.style.cssText = `
        background: white;
        padding: 24px;
        border-radius: 8px;
        box-shadow: 0 8px 32px rgba(0,0,0,0.3);
        max-width: 400px;
        width: 90%;
    `;
    
    dialog.innerHTML = `
        <h3 style="margin: 0 0 16px 0; font-size: 18px; font-weight: 600; color: #24292e;">Save Template</h3>
        <p style="margin: 0 0 16px 0; font-size: 14px; color: #656d76;">Enter a name for your template:</p>
        <input type="text" id="templateNameInput" placeholder="e.g., My Custom Style" style="
            width: 100%;
            padding: 10px 12px;
            border: 1px solid #d0d7de;
            border-radius: 6px;
            font-size: 14px;
            box-sizing: border-box;
            margin-bottom: 16px;
        " />
        <div style="display: flex; gap: 8px; justify-content: flex-end;">
            <button onclick="this.closest('div').parentElement.remove()" style="
                background: #f6f8fa;
                border: 1px solid #d0d7de;
                padding: 10px 16px;
                border-radius: 6px;
                cursor: pointer;
                font-size: 14px;
                font-weight: 500;
                color: #24292e;
            ">Cancel</button>
            <button onclick="saveTemplateWithName('${type}')" style="
                background: #007cba;
                color: white;
                border: none;
                padding: 10px 16px;
                border-radius: 6px;
                cursor: pointer;
                font-size: 14px;
                font-weight: 500;
            ">Save</button>
        </div>
    `;
    
    modal.appendChild(dialog);
    document.body.appendChild(modal);
    
    // Focus input and allow Enter key
    const input = document.getElementById('templateNameInput');
    input.focus();
    input.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') {
            saveTemplateWithName(type);
        }
    });
    
    // Close on background click
    modal.addEventListener('click', (e) => {
        if (e.target === modal) modal.remove();
    });
}

// Save template with name from dialog
function saveTemplateWithName(type) {
    const input = document.getElementById('templateNameInput');
    let name = input.value.trim();
    
    if (!name) {
        alert('Please enter a template name');
        return;
    }
    
    // Check if it's a built-in template name and add prefix
    if (predefinedTemplates[name.toLowerCase()]) {
        name = `Custom_${name}`;
    }
    
    if (type === 'global') {
        const template = {
            name: name,
            description: 'Custom template based on current global settings',
            settings: { ...globalTableSettings },
            created: new Date().toISOString(),
            type: 'custom'
        };
        
        saveCustomTemplate(name, template);
        console.log('[TABLE_CUSTOMIZATION] Saved global template:', name);
    } else if (type === 'individual' && currentTableId) {
        const currentSettings = { ...globalTableSettings, ...(tableSettings[currentTableId] || {}) };
        
        const template = {
            name: name,
            description: `Custom template created from ${getTableDisplayName(currentTableId)}`,
            settings: currentSettings,
            created: new Date().toISOString(),
            type: 'custom'
        };
        
        saveCustomTemplate(name, template);
        console.log('[TABLE_CUSTOMIZATION] Saved individual template:', name);
    }
    
    populateTemplateSelectors();
    
    // Close dialog
    document.getElementById('templateNameInput').closest('div').parentElement.remove();
    
    showApplyFeedback(`Template "${name}" saved successfully!`);
}

// Export global settings
function exportGlobalSettings() {
    const exportData = {
        name: 'Global Table Settings',
        description: 'Exported global table settings',
        type: 'global',
        settings: globalTableSettings,
        exported: new Date().toISOString(),
        version: '1.0'
    };
    
    downloadJSON(exportData, 'table-settings-global.json');
}

// Import global settings
function importGlobalSettings() {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = '.json';
    input.onchange = (e) => {
        const file = e.target.files[0];
        if (!file) return;
        
        const reader = new FileReader();
        reader.onload = (e) => {
            try {
                const data = JSON.parse(e.target.result);
                if (validateSettingsJSON(data)) {
                    // Apply imported settings
                    Object.keys(data.settings).forEach(prop => {
                        if (globalTableSettings.hasOwnProperty(prop)) {
                            globalTableSettings[prop] = data.settings[prop];
                        }
                    });
                    
                    // Apply to all tables
                    applyAllGlobalSettings();
                    updateGlobalControls();
                    
                    showApplyFeedback('Settings imported successfully!');
                } else {
                    alert('Invalid settings file format.');
                }
            } catch (error) {
                alert('Error reading settings file: ' + error.message);
            }
        };
        reader.readAsText(file);
    };
    input.click();
}

// Template Manager Modal
function openTemplateManager() {
    const modal = document.getElementById('templateManagerModal');
    modal.style.display = 'block';
    
    // Populate template grids
    populatePredefinedTemplates();
    populateCustomTemplates();
}

function closeTemplateManager() {
    const modal = document.getElementById('templateManagerModal');
    modal.style.display = 'none';
}

function showTemplateCategory(category) {
    // Update tabs
    document.querySelectorAll('.category-tab').forEach(tab => {
        tab.classList.remove('active');
    });
    document.querySelector(`[onclick="showTemplateCategory('${category}')"]`).classList.add('active');
    
    // Update content
    document.querySelectorAll('.template-category').forEach(cat => {
        cat.classList.remove('active');
    });
    document.getElementById(category + 'Templates').classList.add('active');
}

function populatePredefinedTemplates() {
    const grid = document.getElementById('predefinedTemplateGrid');
    grid.innerHTML = '';
    
    Object.keys(predefinedTemplates).forEach(key => {
        const template = predefinedTemplates[key];
        const card = createTemplateCard(template, key, 'predefined');
        grid.appendChild(card);
    });
}

function populateCustomTemplates() {
    const grid = document.getElementById('customTemplateGrid');
    grid.innerHTML = '';
    
    const customTemplates = getCustomTemplates();
    Object.keys(customTemplates).forEach(key => {
        const template = customTemplates[key];
        const card = createTemplateCard(template, key, 'custom');
        grid.appendChild(card);
    });
}

function createTemplateCard(template, key, type) {
    const card = document.createElement('div');
    card.className = 'template-card';
    card.innerHTML = `
        <h5>${template.name}</h5>
        <p>${template.description}</p>
        <div class="template-preview">
            Font: ${template.settings.fontSize} | Padding: ${template.settings.cellPadding}
        </div>
        <div class="template-actions-card">
            <button onclick="applyTemplate('${type}', '${key}')" class="primary">Apply</button>
            ${type === 'custom' ? `
                <button onclick="exportTemplate('${key}')">Export</button>
                <button onclick="deleteTemplate('${key}')">Delete</button>
            ` : ''}
        </div>
    `;
    return card;
}

function applyTemplate(type, key) {
    let template;
    if (type === 'predefined') {
        template = predefinedTemplates[key];
    } else {
        const customTemplates = getCustomTemplates();
        template = customTemplates[key];
    }
    
    if (template) {
        // Apply to global settings
        Object.keys(template.settings).forEach(prop => {
            globalTableSettings[prop] = template.settings[prop];
        });
        
        applyAllGlobalSettings();
        updateGlobalControls();
        
        showApplyFeedback(`Template "${template.name}" applied!`);
        closeTemplateManager();
    }
}

// Custom template management
function getCustomTemplates() {
    try {
        return JSON.parse(localStorage.getItem('autoNestCutCustomTemplates') || '{}');
    } catch (e) {
        return {};
    }
}

function saveCustomTemplate(key, template) {
    const templates = getCustomTemplates();
    templates[key] = template;
    localStorage.setItem('autoNestCutCustomTemplates', JSON.stringify(templates));
}

function deleteTemplate(key) {
    if (confirm(`Delete template "${key}"?`)) {
        const templates = getCustomTemplates();
        delete templates[key];
        localStorage.setItem('autoNestCutCustomTemplates', JSON.stringify(templates));
        
        populateCustomTemplates();
        populateTemplateSelectors();
        showApplyFeedback(`Template "${key}" deleted.`);
    }
}

function exportTemplate(key) {
    const templates = getCustomTemplates();
    const template = templates[key];
    if (template) {
        downloadJSON(template, `table-template-${key}.json`);
    }
}

function exportAllTemplates() {
    const templates = getCustomTemplates();
    const exportData = {
        templates: templates,
        exported: new Date().toISOString(),
        version: '1.0'
    };
    downloadJSON(exportData, 'all-table-templates.json');
}

function importTemplateFile(input) {
    const file = input.files[0];
    if (!file) return;
    
    const reader = new FileReader();
    reader.onload = (e) => {
        try {
            const data = JSON.parse(e.target.result);
            
            if (data.templates) {
                // Multiple templates
                const templates = getCustomTemplates();
                Object.keys(data.templates).forEach(key => {
                    templates[key] = data.templates[key];
                });
                localStorage.setItem('autoNestCutCustomTemplates', JSON.stringify(templates));
                showApplyFeedback(`${Object.keys(data.templates).length} templates imported!`);
            } else if (data.settings) {
                // Single template
                const key = data.name || 'Imported Template';
                saveCustomTemplate(key, data);
                showApplyFeedback(`Template "${key}" imported!`);
            }
            
            populateCustomTemplates();
            populateTemplateSelectors();
        } catch (error) {
            alert('Error importing template: ' + error.message);
        }
    };
    reader.readAsText(file);
    
    // Reset input
    input.value = '';
}

// Text label management
function updateTextLabel(level, value) {
    if (!value || value.trim() === '') {
        value = getDefaultLabel(level);
    }
    
    textLabels.costLevels[level] = value;
    window.textLabels = textLabels; // Make sure it's globally accessible
    saveTextLabels();
    
    // Refresh report if it exists to show updated labels
    if (typeof renderReport === 'function' && window.g_reportData) {
        setTimeout(() => {
            renderReport();
        }, 100);
    }
    
    showApplyFeedback(`${level.charAt(0).toUpperCase() + level.slice(1)} cost label updated to "${value}"`);
}

function getDefaultLabel(level) {
    const defaults = { low: 'Budget', avg: 'Standard', high: 'Premium' };
    return defaults[level] || level;
}

function saveTextLabels() {
    try {
        localStorage.setItem('autoNestCutTextLabels', JSON.stringify(textLabels));
    } catch (e) {
    }
}

function loadTextLabels() {
    try {
        const saved = localStorage.getItem('autoNestCutTextLabels');
        if (saved) {
            const data = JSON.parse(saved);
            if (data.costLevels) {
                textLabels.costLevels = { ...textLabels.costLevels, ...data.costLevels };
            }
        }
        // Make globally accessible
        window.textLabels = textLabels;
    } catch (e) {
        // Ensure defaults are available
        window.textLabels = textLabels;
    }
}

function updateTextLabelInputs() {
    const inputs = {
        'lowCostLabel': textLabels.costLevels.low,
        'avgCostLabel': textLabels.costLevels.avg,
        'highCostLabel': textLabels.costLevels.high
    };
    
    Object.keys(inputs).forEach(id => {
        const element = document.getElementById(id);
        if (element) {
            element.value = inputs[id];
        }
    });
}

// Utility functions
function downloadJSON(data, filename) {
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
}

function validateSettingsJSON(data) {
    if (!data || typeof data !== 'object') return false;
    if (!data.settings || typeof data.settings !== 'object') return false;
    
    // Check for required properties
    const requiredProps = ['fontSize', 'cellPadding', 'headerBg', 'headerColor'];
    return requiredProps.every(prop => data.settings.hasOwnProperty(prop));
}

// Override panel animations
function openTableCustomization(tableId) {
    currentTableId = tableId;
    const panel = document.getElementById('tableCustomizationPanel');
    const title = document.getElementById('panelTitle');
    title.textContent = `${getTableDisplayName(tableId)}`;
    panel.style.right = '0';
    loadTableSettingsToPanel(tableId);
}

function closeTableCustomization() {
    const panel = document.getElementById('tableCustomizationPanel');
    panel.style.right = '-350px';
    currentTableId = null;
}

function toggleGlobalTableSettings() {
    const panel = document.getElementById('globalTableModal');
    if (panel) panel.style.left = '0';
}

function closeGlobalTableSettings() {
    const panel = document.getElementById('globalTableModal');
    if (panel) panel.style.left = '-360px';
}

// Undo functionality
function saveToUndoHistory() {
    const state = {
        tableSettings: JSON.parse(JSON.stringify(tableSettings)),
        globalTableSettings: JSON.parse(JSON.stringify(globalTableSettings)),
        timestamp: Date.now()
    };
    
    undoHistory.push(state);
    
    // Limit history size
    if (undoHistory.length > maxUndoSteps) {
        undoHistory.shift();
    }
}

function undoLastChange() {
    if (undoHistory.length === 0) {
        showApplyFeedback('No changes to undo');
        return;
    }
    
    // Get previous state
    const previousState = undoHistory.pop();
    
    // Restore state
    tableSettings = JSON.parse(JSON.stringify(previousState.tableSettings));
    globalTableSettings = JSON.parse(JSON.stringify(previousState.globalTableSettings));
    
    // Apply to all tables
    applyAllTableSettings();
    
    // Update controls
    updateGlobalControls();
    if (currentTableId) {
        loadTableSettingsToPanel(currentTableId);
    }
    
    // Save restored state
    saveTableSettings();
    
    showApplyFeedback('Changes undone');
}

function clearUndoHistory() {
    undoHistory = [];
}
