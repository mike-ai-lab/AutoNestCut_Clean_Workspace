# Generator script for material database HTML
# This creates the complete HTML file with all features

html_content = <<~HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Material Database Manager</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #f8f9fa; overflow: hidden; }
        .container { height: 100vh; display: flex; flex-direction: column; }
        .materials-section { background: white; flex: 1; display: flex; flex-direction: column; overflow: hidden; }
        .section-header { background: linear-gradient(135deg, #007cba 0%, #005a87 100%); color: white; padding: 20px 24px; display: flex; justify-content: space-between; align-items: center; }
        .header-left { display: flex; flex-direction: column; gap: 4px; }
        .section-header h2 { font-size: 18px; font-weight: 700; margin: 0; }
        .header-stats { font-size: 12px; opacity: 0.9; display: flex; gap: 16px; }
        .stat-item { display: flex; align-items: center; gap: 4px; }
        .header-controls { display: flex; gap: 12px; }
        .icon-btn { background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.3); color: white; width: 36px; height: 36px; border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all 0.2s; }
        .icon-btn:hover { background: rgba(255,255,255,0.3); transform: translateY(-1px); }
        .icon-btn svg { width: 16px; height: 16px; stroke: currentColor; stroke-width: 2; fill: none; }
        .toolbar { background: #f8f9fa; border-bottom: 1px solid #d0d7de; padding: 16px 24px; display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
        .toolbar-btn { background: white; border: 1px solid #d0d7de; color: #1a1a1a; padding: 8px 16px; border-radius: 6px; cursor: pointer; font-size: 13px; font-weight: 600; display: flex; align-items: center; gap: 6px; transition: all 0.2s; }
        .toolbar-btn:hover { background: #f0f4f8; border-color: #8c959f; }
        .toolbar-btn.primary { background: #007cba; color: white; border-color: #007cba; }
        .toolbar-btn.primary:hover { background: #005a87; }
        .toolbar-btn svg { width: 14px; height: 14px; stroke: currentColor; stroke-width: 2; fill: none; }
        .sort-select { padding: 8px 12px; border: 1px solid #d0d7de; border-radius: 6px; font-size: 13px; background: white; cursor: pointer; }
        .table-wrapper { overflow-y: auto; overflow-x: auto; flex: 1; }
        table { width: 100%; border-collapse: collapse; font-size: 14px; }
        thead { background: #f0f4f8; position: sticky; top: 0; z-index: 10; }
        th { padding: 14px 16px; text-align: left; font-weight: 700; color: #1a1a1a; border-bottom: 2px solid #d0d7de; font-size: 13px; white-space: nowrap; }
        th:nth-child(2), th:nth-child(3), th:nth-child(4), th:nth-child(5) { text-align: right; }
        td { padding: 14px 16px; border-bottom: 1px solid #e1e5e9; color: #1a1a1a; }
        td:nth-child(2), td:nth-child(3), td:nth-child(4), td:nth-child(5) { text-align: right; font-family: 'Courier New', monospace; font-size: 13px; }
        tbody tr { transition: background-color 0.15s; }
        tbody tr:hover { background: #f8f9fa; }
        tbody tr.flagged { background: #fff3cd; }
        tbody tr.flagged:hover { background: #ffe69c; }
        .material-name { font-weight: 600; color: #007cba; cursor: pointer; }
        .material-name:hover { text-decoration: underline; }
        .material-name.auto-generated { color: #6f42c1; }
        .material-actions { display: flex; gap: 6px; justify-content: flex-end; }
        .action-btn { background: white; border: 1px solid #d0d7de; color: #1a1a1a; width: 32px; height: 32px; border-radius: 4px; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: all 0.2s; }
        .action-btn:hover { background: #f0f4f8; border-color: #8c959f; }
        .action-btn.delete:hover { background: #fee; border-color: #d73a49; color: #d73a49; }
        .action-btn svg { width: 14px; height: 14px; stroke: currentColor; stroke-width: 2; fill: none; }
        input[type="text"], input[type="number"] { width: 100%; padding: 6px 8px; border: 1px solid #d0d7de; border-radius: 4px; font-size: 13px; font-family: 'Courier New', monospace; }
        input[type="text"]:focus, input[type="number"]:focus { outline: none; border-color: #007cba; box-shadow: 0 0 0 3px rgba(0, 124, 186, 0.1); }
        .editable-cell { padding: 8px 16px; }
        .badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: 600; margin-left: 6px; }
        .badge.auto { background: #f3e8ff; color: #6f42c1; }
        .badge.flagged { background: #fff3cd; color: #856404; }
        .empty-state { padding: 60px 24px; text-align: center; color: #656d76; }
    </style>
</head>
<body>
    <div class="container">
        <div class="materials-section">
            <div class="section-header">
                <div class="header-left">
                    <h2>Material Database Manager</h2>
                    <div class="header-stats">
                        <div class="stat-item">
                            <span>Total: <strong id="totalCount">0</strong></span>
                        </div>
                        <div class="stat-item">
                            <span>Auto: <strong id="autoCount">0</strong></span>
                        </div>
                        <div class="stat-item">
                            <span>Flagged: <strong id="flaggedCount">0</strong></span>
                        </div>
                        <div class="stat-item">
                            <span id="lastUpdated">Loading...</span>
                        </div>
                    </div>
                </div>
                <div class="header-controls">
                    <button class="icon-btn" id="refreshBtn" title="Refresh">
                        <svg viewBox="0 0 24 24"><path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8M21 3v5h-5M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16M3 21v-5h5"/></svg>
                    </button>
                </div>
            </div>
            
            <div class="toolbar">
                <button class="toolbar-btn primary" id="addMaterialBtn">
                    <svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>
                    Add Material
                </button>
                <button class="toolbar-btn" id="saveBtn">
                    <svg viewBox="0 0 24 24"><path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/></svg>
                    Save Changes
                </button>
                <select class="sort-select" id="sortSelect">
                    <option value="name-asc">Sort: A-Z</option>
                    <option value="name-desc">Sort: Z-A</option>
                    <option value="thickness-asc">Thickness ↑</option>
                    <option value="thickness-desc">Thickness ↓</option>
                    <option value="price-asc">Price ↑</option>
                    <option value="price-desc">Price ↓</option>
                </select>
            </div>
            
            <div class="table-wrapper">
                <table id="materialsTable">
                    <thead>
                        <tr>
                            <th>Material Name</th>
                            <th>Width (mm)</th>
                            <th>Height (mm)</th>
                            <th>Thickness (mm)</th>
                            <th>Price</th>
                            <th>Currency</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody id="materialsBody"></tbody>
                </table>
            </div>
        </div>
    </div>

    <script>
        let materialsData = {};
        let lastUpdateTime = null;
        let hasUnsavedChanges = false;

        document.addEventListener('DOMContentLoaded', function() {
            setupEventListeners();
            requestMaterialsData();
            startUpdateTimer();
        });

        function setupEventListeners() {
            document.getElementById('refreshBtn').addEventListener('click', refreshData);
            document.getElementById('addMaterialBtn').addEventListener('click', addNewMaterial);
            document.getElementById('saveBtn').addEventListener('click', saveChanges);
            document.getElementById('sortSelect').addEventListener('change', () => renderTable(materialsData));
            
            // Event delegation for delete buttons
            document.getElementById('materialsBody').addEventListener('click', function(e) {
                const deleteBtn = e.target.closest('.delete');
                if (deleteBtn) {
                    const materialName = deleteBtn.dataset.materialName;
                    const row = deleteBtn.closest('tr');
                    if (materialName && row) {
                        deleteMaterial(materialName, row);
                    }
                }
            });
        }

        function requestMaterialsData() {
            if (window.sketchup) window.sketchup.get_materials_data();
        }

        function refreshData() {
            if (hasUnsavedChanges && !confirm('You have unsaved changes. Refresh anyway?')) return;
            requestMaterialsData();
            hasUnsavedChanges = false;
        }

        function receiveMaterialsData(data) {
            materialsData = JSON.parse(data);
            lastUpdateTime = new Date();
            renderTable(materialsData);
            updateTimestamp();
            hasUnsavedChanges = false;
        }

        function renderTable(materials) {
            const tbody = document.getElementById('materialsBody');
            tbody.innerHTML = '';

            let materialsArray = Object.entries(materials).map(([name, data]) => ({ name, ...data }));
            materialsArray = sortMaterials(materialsArray, document.getElementById('sortSelect').value);

            let autoCount = 0, flaggedCount = 0;
            materialsArray.forEach(mat => {
                if (isAutoGenerated(mat)) autoCount++;
                if (isFlagged(mat)) flaggedCount++;
            });

            document.getElementById('totalCount').textContent = materialsArray.length;
            document.getElementById('autoCount').textContent = autoCount;
            document.getElementById('flaggedCount').textContent = flaggedCount;

            materialsArray.forEach(mat => tbody.appendChild(createMaterialRow(mat)));

            if (materialsArray.length === 0) {
                tbody.innerHTML = '<tr><td colspan="7" class="empty-state">No materials. Click "Add Material" to start.</td></tr>';
            }
        }

        function sortMaterials(materials, sortBy) {
            const sorted = [...materials];
            const [field, dir] = sortBy.split('-');
            const mult = dir === 'asc' ? 1 : -1;
            
            if (field === 'name') sorted.sort((a, b) => mult * a.name.localeCompare(b.name));
            else sorted.sort((a, b) => mult * ((a[field] || 0) - (b[field] || 0)));
            
            return sorted;
        }

        function isAutoGenerated(mat) {
            return mat.auto_generated || mat.name.startsWith('Auto_user_') || mat.name.startsWith('no_material_');
        }

        function isFlagged(mat) {
            if (mat.flagged_no_material) return true;
            const w = mat.width || 0, h = mat.height || 0;
            return (w > 0 && h > 0 && (w < 100 || h < 100 || w > 5000 || h > 5000 || (w < 500 && h > 3000) || (h < 500 && w > 3000)));
        }

        function createMaterialRow(mat) {
            const row = document.createElement('tr');
            const isAuto = isAutoGenerated(mat);
            const flagged = isFlagged(mat);
            
            if (flagged) row.classList.add('flagged');
            row.dataset.originalName = mat.name;
            
            row.innerHTML = `
                <td>
                    <input type="text" class="material-name ${isAuto ? 'auto-generated' : ''}" value="${escapeHtml(mat.name)}" data-original="${escapeHtml(mat.name)}">
                    ${isAuto ? '<span class="badge auto">AUTO</span>' : ''}
                    ${flagged ? '<span class="badge flagged">⚠ CHECK</span>' : ''}
                </td>
                <td class="editable-cell"><input type="number" class="edit-width" value="${mat.width || 2440}" step="1" min="1"></td>
                <td class="editable-cell"><input type="number" class="edit-height" value="${mat.height || 1220}" step="1" min="1"></td>
                <td class="editable-cell"><input type="number" class="edit-thickness" value="${mat.thickness || 18}" step="0.1" min="0.1"></td>
                <td class="editable-cell"><input type="number" class="edit-price" value="${mat.price || 0}" step="0.01" min="0"></td>
                <td class="editable-cell"><input type="text" class="edit-currency" value="${mat.currency || 'USD'}" maxlength="3"></td>
                <td>
                    <div class="material-actions">
                        <button class="action-btn delete" data-material-name="${escapeHtml(mat.name)}" title="Delete">
                            <svg viewBox="0 0 24 24"><polyline points="3,6 5,6 21,6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
                        </button>
                    </div>
                </td>
            `;
            
            row.querySelectorAll('input').forEach(input => {
                input.addEventListener('change', () => hasUnsavedChanges = true);
            });
            
            return row;
        }

        function addNewMaterial() {
            const name = prompt('Enter material name:');
            if (!name || !name.trim()) return;
            if (materialsData[name]) { alert('Material exists!'); return; }
            
            materialsData[name] = { width: 2440, height: 1220, thickness: 18, price: 0, currency: 'USD', density: 600 };
            renderTable(materialsData);
            hasUnsavedChanges = true;
        }

        function deleteMaterial(name, row) {
            if (!confirm(`Delete "${name}"?`)) return;
            delete materialsData[name];
            row.remove();
            hasUnsavedChanges = true;
            updateCounts();
        }

        function updateCounts() {
            const rows = document.querySelectorAll('#materialsBody tr');
            document.getElementById('totalCount').textContent = rows.length;
        }

        function saveChanges() {
            const rows = document.querySelectorAll('#materialsBody tr');
            const updated = {};
            
            rows.forEach(row => {
                const nameInput = row.querySelector('.material-name');
                if (!nameInput) return;
                
                const originalName = nameInput.dataset.original;
                const newName = nameInput.value.trim();
                
                if (!newName) return; // Skip empty names
                
                const width = parseFloat(row.querySelector('.edit-width').value);
                const height = parseFloat(row.querySelector('.edit-height').value);
                const thickness = parseFloat(row.querySelector('.edit-thickness').value);
                const price = parseFloat(row.querySelector('.edit-price').value);
                const currency = row.querySelector('.edit-currency').value.toUpperCase();
                
                const oldData = materialsData[originalName] || {};
                
                // Clear flagged_no_material if user renamed the material (acknowledging it)
                const wasFlagged = oldData.flagged_no_material === true;
                const wasRenamed = newName !== originalName;
                const shouldUnflag = wasFlagged && wasRenamed;
                
                updated[newName] = {
                    width, 
                    height, 
                    thickness, 
                    price, 
                    currency,
                    density: oldData.density || 600,
                    auto_generated: oldData.auto_generated,
                    created_at: oldData.created_at,
                    original_sketchup_material: oldData.original_sketchup_material,
                    flagged_no_material: shouldUnflag ? false : oldData.flagged_no_material
                };
            });
            
            if (window.sketchup) {
                window.sketchup.save_materials_data(JSON.stringify(updated));
            }
            
            materialsData = updated;
            lastUpdateTime = new Date();
            updateTimestamp();
            hasUnsavedChanges = false;
            
            // Re-render to show unflagged items
            renderTable(materialsData);
        }

        function startUpdateTimer() {
            updateTimestamp();
            setInterval(updateTimestamp, 30000);
        }

        function updateTimestamp() {
            const elem = document.getElementById('lastUpdated');
            if (!lastUpdateTime) { elem.textContent = 'Not loaded'; return; }
            
            const diff = Math.floor((new Date() - lastUpdateTime) / 1000);
            elem.textContent = diff < 60 ? 'Just now' : diff < 3600 ? `${Math.floor(diff/60)}m ago` : `${Math.floor(diff/3600)}h ago`;
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        window.receiveMaterialsData = receiveMaterialsData;
    </script>
</body>
</html>
HTML

# Write to file
File.write('Extension/AutoNestCut/ui/html/material_database.html', html_content)
puts "✓ Material database HTML generated successfully!"
puts "  File: Extension/AutoNestCut/ui/html/material_database.html"
puts "  Size: #{html_content.length} bytes"
