// Extended Card Visualization Modals - Minimal Monochrome Style
// Matching the Cost modal design: clean, professional, no colorful gradients

// Efficiency Visualization Modal
function showEfficiencyVisualization() {
    if (!g_reportData || !g_boardsData) {
        alert('No efficiency data available');
        return;
    }
    
    closeVisualizationModal();
    
    const overallEfficiency = g_reportData.summary.overall_efficiency || 0;
    
    // Aggregate efficiency by material
    const materialStats = {};
    g_boardsData.forEach(board => {
        const material = board.material;
        if (!materialStats[material]) {
            materialStats[material] = { totalEff: 0, count: 0 };
        }
        materialStats[material].totalEff += board.efficiency_percentage || 0;
        materialStats[material].count++;
    });
    
    const materials = Object.keys(materialStats).map(material => ({
        name: material,
        avgEfficiency: materialStats[material].totalEff / materialStats[material].count,
        boardCount: materialStats[material].count
    })).sort((a, b) => b.avgEfficiency - a.avgEfficiency);
    
    // Create modal
    const modal = document.createElement('div');
    modal.style.cssText = `
        position: fixed; top: 0; left: 0; width: 100%; height: 100%;
        background: rgba(0, 0, 0, 0.5); display: flex; align-items: center;
        justify-content: center; z-index: 10000; backdrop-filter: blur(4px);
    `;
    
    const modalContent = document.createElement('div');
    modalContent.style.cssText = `
        background: white; border-radius: 12px; width: 90%; max-width: 900px;
        max-height: 85vh; overflow: hidden; box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        display: flex; flex-direction: column;
    `;
    
    // Header - monochrome style
    const header = document.createElement('div');
    header.style.cssText = `
        padding: 24px 32px; border-bottom: 1px solid #e1e4e8;
        display: flex; justify-content: space-between; align-items: center;
        background: #f6f8fa;
    `;
    header.innerHTML = `
        <div>
            <h2 style="margin: 0; font-size: 24px; font-weight: 700; color: #24292e;">Material Efficiency</h2>
            <p style="margin: 8px 0 0 0; font-size: 14px; color: #656d76;">Overall efficiency: ${formatNumber(overallEfficiency, 1)}%</p>
        </div>
        <button onclick="closeVisualizationModal()" style="background: none; border: none; font-size: 28px; color: #656d76; cursor: pointer; width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 6px; transition: all 0.2s;" onmouseover="this.style.background='#e1e4e8'" onmouseout="this.style.background='none'">&times;</button>
    `;
    
    // Content area
    const content = document.createElement('div');
    content.style.cssText = `padding: 32px; overflow-y: auto; flex: 1;`;
    
    // Two-column layout: Bar chart + Summary table
    const vizContainer = document.createElement('div');
    vizContainer.style.cssText = `display: grid; grid-template-columns: 1fr 1fr; gap: 32px; margin-bottom: 32px;`;
    
    // Left: Bar chart
    const chartContainer = document.createElement('div');
    chartContainer.innerHTML = `<h3 style="margin: 0 0 20px 0; font-size: 16px; font-weight: 600; color: #24292e;">Efficiency by Material</h3>`;
    
    const barsContainer = document.createElement('div');
    barsContainer.style.cssText = `display: flex; flex-direction: column; gap: 12px;`;
    
    const colors = ['#0366d6', '#2188ff', '#79b8ff', '#c8e1ff', '#0969da', '#218bff'];
    
    materials.forEach((material, index) => {
        const barWrapper = document.createElement('div');
        barWrapper.style.cssText = `display: flex; flex-direction: column; gap: 4px;`;
        
        const labelRow = document.createElement('div');
        labelRow.style.cssText = `display: flex; justify-content: space-between; font-size: 13px; color: #24292e;`;
        labelRow.innerHTML = `
            <span style="font-weight: 500;">${escapeHtml(material.name)}</span>
            <span style="font-weight: 600;">${formatNumber(material.avgEfficiency, 1)}%</span>
        `;
        
        const barTrack = document.createElement('div');
        barTrack.style.cssText = `width: 100%; height: 24px; background: #f6f8fa; border-radius: 4px; overflow: hidden;`;
        
        const barFill = document.createElement('div');
        barFill.style.cssText = `
            height: 100%; background: ${colors[index % colors.length]}; width: ${material.avgEfficiency}%;
            transition: width 0.6s ease; display: flex; align-items: center; justify-content: flex-end;
            padding-right: 8px; color: white; font-size: 11px; font-weight: 600;
        `;
        barFill.textContent = `${formatNumber(material.avgEfficiency, 1)}%`;
        
        barTrack.appendChild(barFill);
        barWrapper.appendChild(labelRow);
        barWrapper.appendChild(barTrack);
        barsContainer.appendChild(barWrapper);
    });
    
    chartContainer.appendChild(barsContainer);
    
    // Right: Summary table
    const tableContainer = document.createElement('div');
    tableContainer.innerHTML = `
        <h3 style="margin: 0 0 20px 0; font-size: 16px; font-weight: 600; color: #24292e;">Material Summary</h3>
        <div style="border: 1px solid #d0d7de; border-radius: 6px; overflow: hidden;">
            <table style="width: 100%; border-collapse: collapse;">
                <thead>
                    <tr style="background: #f6f8fa;">
                        <th style="padding: 12px; text-align: left; font-size: 12px; font-weight: 600; color: #656d76; border-bottom: 1px solid #d0d7de;">Material</th>
                        <th style="padding: 12px; text-align: center; font-size: 12px; font-weight: 600; color: #656d76; border-bottom: 1px solid #d0d7de;">Sheets</th>
                        <th style="padding: 12px; text-align: right; font-size: 12px; font-weight: 600; color: #656d76; border-bottom: 1px solid #d0d7de;">Avg Efficiency</th>
                    </tr>
                </thead>
                <tbody>
                    ${materials.map((material, index) => `
                        <tr style="border-bottom: 1px solid #e1e4e8; ${index % 2 === 0 ? 'background: #fafbfc;' : ''}">
                            <td style="padding: 12px; font-size: 13px; color: #24292e;">${escapeHtml(material.name)}</td>
                            <td style="padding: 12px; text-align: center; font-size: 13px; color: #24292e; font-weight: 600;">${material.boardCount}</td>
                            <td style="padding: 12px; text-align: right; font-size: 13px; color: #24292e; font-weight: 600;">${formatNumber(material.avgEfficiency, 1)}%</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
    
    vizContainer.appendChild(chartContainer);
    vizContainer.appendChild(tableContainer);
    content.appendChild(vizContainer);
    
    // Bottom stats - 3 key metrics
    const totalSheets = materials.reduce((sum, m) => sum + m.boardCount, 0);
    const bestMaterial = materials[0];
    const avgEfficiency = materials.reduce((sum, m) => sum + m.avgEfficiency, 0) / materials.length;
    
    const statsContainer = document.createElement('div');
    statsContainer.style.cssText = `
        display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px;
        padding: 24px; background: #f6f8fa; border-radius: 8px;
    `;
    
    statsContainer.innerHTML = `
        <div style="text-align: center;">
            <div style="font-size: 12px; color: #656d76; margin-bottom: 4px;">Total Sheets</div>
            <div style="font-size: 24px; font-weight: 700; color: #24292e;">${totalSheets}</div>
        </div>
        <div style="text-align: center;">
            <div style="font-size: 12px; color: #656d76; margin-bottom: 4px;">Average Efficiency</div>
            <div style="font-size: 24px; font-weight: 700; color: #24292e;">${formatNumber(avgEfficiency, 1)}%</div>
        </div>
        <div style="text-align: center;">
            <div style="font-size: 12px; color: #656d76; margin-bottom: 4px;">Best Material</div>
            <div style="font-size: 16px; font-weight: 700; color: #24292e;">${escapeHtml(bestMaterial.name)}</div>
            <div style="font-size: 12px; color: #656d76;">${formatNumber(bestMaterial.avgEfficiency, 1)}%</div>
        </div>
    `;
    
    content.appendChild(statsContainer);
    
    // Assemble modal
    modalContent.appendChild(header);
    modalContent.appendChild(content);
    modal.appendChild(modalContent);
    
    modal.onclick = (e) => { if (e.target === modal) closeVisualizationModal(); };
    
    document.body.appendChild(modal);
    currentModal = modal;
}


// Sheets Visualization Modal
function showSheetsVisualization() {
    if (!g_reportData || !g_reportData.unique_board_types) {
        alert('No sheet data available');
        return;
    }
    
    closeVisualizationModal();
    
    const boardTypes = g_reportData.unique_board_types;
    const totalSheets = boardTypes.reduce((sum, bt) => sum + bt.count, 0);
    const reportUnits = window.currentUnits || 'mm';
    const reportPrecision = window.currentPrecision ?? 1;
    
    // Create modal
    const modal = document.createElement('div');
    modal.style.cssText = `
        position: fixed; top: 0; left: 0; width: 100%; height: 100%;
        background: rgba(0, 0, 0, 0.5); display: flex; align-items: center;
        justify-content: center; z-index: 10000; backdrop-filter: blur(4px);
    `;
    
    const modalContent = document.createElement('div');
    modalContent.style.cssText = `
        background: white; border-radius: 12px; width: 90%; max-width: 900px;
        max-height: 85vh; overflow: hidden; box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        display: flex; flex-direction: column;
    `;
    
    // Header - monochrome style
    const header = document.createElement('div');
    header.style.cssText = `
        padding: 24px 32px; border-bottom: 1px solid #e1e4e8;
        display: flex; justify-content: space-between; align-items: center;
        background: #f6f8fa;
    `;
    header.innerHTML = `
        <div>
            <h2 style="margin: 0; font-size: 24px; font-weight: 700; color: #24292e;">Sheet Requirements</h2>
            <p style="margin: 8px 0 0 0; font-size: 14px; color: #656d76;">Total sheets needed: ${totalSheets}</p>
        </div>
        <button onclick="closeVisualizationModal()" style="background: none; border: none; font-size: 28px; color: #656d76; cursor: pointer; width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 6px; transition: all 0.2s;" onmouseover="this.style.background='#e1e4e8'" onmouseout="this.style.background='none'">&times;</button>
    `;
    
    // Content area
    const content = document.createElement('div');
    content.style.cssText = `padding: 32px; overflow-y: auto; flex: 1;`;
    
    // Two-column layout
    const vizContainer = document.createElement('div');
    vizContainer.style.cssText = `display: grid; grid-template-columns: 1fr 1fr; gap: 32px; margin-bottom: 32px;`;
    
    // Left: Bar chart
    const chartContainer = document.createElement('div');
    chartContainer.innerHTML = `<h3 style="margin: 0 0 20px 0; font-size: 16px; font-weight: 600; color: #24292e;">Sheet Distribution</h3>`;
    
    const barsContainer = document.createElement('div');
    barsContainer.style.cssText = `display: flex; flex-direction: column; gap: 12px;`;
    
    const colors = ['#0366d6', '#2188ff', '#79b8ff', '#c8e1ff', '#0969da', '#218bff'];
    const maxCount = Math.max(...boardTypes.map(bt => bt.count));
    
    boardTypes.forEach((board, index) => {
        const percentage = (board.count / maxCount) * 100;
        const barWrapper = document.createElement('div');
        barWrapper.style.cssText = `display: flex; flex-direction: column; gap: 4px;`;
        
        const labelRow = document.createElement('div');
        labelRow.style.cssText = `display: flex; justify-content: space-between; font-size: 13px; color: #24292e;`;
        labelRow.innerHTML = `
            <span style="font-weight: 500;">${escapeHtml(board.material)}</span>
            <span style="font-weight: 600;">${board.count} sheets</span>
        `;
        
        const barTrack = document.createElement('div');
        barTrack.style.cssText = `width: 100%; height: 24px; background: #f6f8fa; border-radius: 4px; overflow: hidden;`;
        
        const barFill = document.createElement('div');
        barFill.style.cssText = `
            height: 100%; background: ${colors[index % colors.length]}; width: ${percentage}%;
            transition: width 0.6s ease; display: flex; align-items: center; padding-left: 8px;
            color: white; font-size: 11px; font-weight: 600;
        `;
        barFill.textContent = `${formatNumber((board.count / totalSheets) * 100, 1)}%`;
        
        barTrack.appendChild(barFill);
        barWrapper.appendChild(labelRow);
        barWrapper.appendChild(barTrack);
        barsContainer.appendChild(barWrapper);
    });
    
    chartContainer.appendChild(barsContainer);
    
    // Right: Summary table
    const tableContainer = document.createElement('div');
    tableContainer.innerHTML = `
        <h3 style="margin: 0 0 20px 0; font-size: 16px; font-weight: 600; color: #24292e;">Material Specifications</h3>
        <div style="border: 1px solid #d0d7de; border-radius: 6px; overflow: hidden;">
            <table style="width: 100%; border-collapse: collapse;">
                <thead>
                    <tr style="background: #f6f8fa;">
                        <th style="padding: 12px; text-align: left; font-size: 12px; font-weight: 600; color: #656d76; border-bottom: 1px solid #d0d7de;">Material</th>
                        <th style="padding: 12px; text-align: center; font-size: 12px; font-weight: 600; color: #656d76; border-bottom: 1px solid #d0d7de;">Size</th>
                        <th style="padding: 12px; text-align: right; font-size: 12px; font-weight: 600; color: #656d76; border-bottom: 1px solid #d0d7de;">Quantity</th>
                    </tr>
                </thead>
                <tbody>
                    ${boardTypes.map((board, index) => {
                        const width = (board.stock_width || 0) / window.unitFactors[reportUnits];
                        const height = (board.stock_height || 0) / window.unitFactors[reportUnits];
                        const thickness = (board.thickness || 0) / window.unitFactors[reportUnits];
                        return `
                        <tr style="border-bottom: 1px solid #e1e4e8; ${index % 2 === 0 ? 'background: #fafbfc;' : ''}">
                            <td style="padding: 12px; font-size: 13px; color: #24292e;">${escapeHtml(board.material)}</td>
                            <td style="padding: 12px; text-align: center; font-size: 12px; color: #656d76;">${formatNumber(width, reportPrecision)}×${formatNumber(height, reportPrecision)}×${formatNumber(thickness, reportPrecision)} ${reportUnits}</td>
                            <td style="padding: 12px; text-align: right; font-size: 13px; color: #24292e; font-weight: 600;">${board.count}</td>
                        </tr>
                    `}).join('')}
                </tbody>
            </table>
        </div>
    `;
    
    vizContainer.appendChild(chartContainer);
    vizContainer.appendChild(tableContainer);
    content.appendChild(vizContainer);
    
    // Bottom stats
    const materialTypes = boardTypes.length;
    const totalArea = boardTypes.reduce((sum, bt) => sum + (bt.total_area || 0), 0) / 1000000; // Convert to m²
    const largestMaterial = boardTypes.reduce((max, bt) => bt.count > max.count ? bt : max, boardTypes[0]);
    
    const statsContainer = document.createElement('div');
    statsContainer.style.cssText = `
        display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px;
        padding: 24px; background: #f6f8fa; border-radius: 8px;
    `;
    
    statsContainer.innerHTML = `
        <div style="text-align: center;">
            <div style="font-size: 12px; color: #656d76; margin-bottom: 4px;">Total Sheets</div>
            <div style="font-size: 24px; font-weight: 700; color: #24292e;">${totalSheets}</div>
        </div>
        <div style="text-align: center;">
            <div style="font-size: 12px; color: #656d76; margin-bottom: 4px;">Material Types</div>
            <div style="font-size: 24px; font-weight: 700; color: #24292e;">${materialTypes}</div>
        </div>
        <div style="text-align: center;">
            <div style="font-size: 12px; color: #656d76; margin-bottom: 4px;">Most Used</div>
            <div style="font-size: 16px; font-weight: 700; color: #24292e;">${escapeHtml(largestMaterial.material)}</div>
            <div style="font-size: 12px; color: #656d76;">${largestMaterial.count} sheets</div>
        </div>
    `;
    
    content.appendChild(statsContainer);
    
    // Assemble modal
    modalContent.appendChild(header);
    modalContent.appendChild(content);
    modal.appendChild(modalContent);
    
    modal.onclick = (e) => { if (e.target === modal) closeVisualizationModal(); };
    
    document.body.appendChild(modal);
    currentModal = modal;
}


// Parts Visualization Modal
function showPartsVisualization() {
    if (!g_reportData || !g_reportData.unique_part_types) {
        alert('No parts data available');
        return;
    }
    
    closeVisualizationModal();
    
    const partTypes = g_reportData.unique_part_types;
    const totalParts = partTypes.reduce((sum, pt) => sum + pt.total_quantity, 0);
    
    // Aggregate by material
    const materialParts = {};
    partTypes.forEach(part => {
        const material = part.material;
        if (!materialParts[material]) {
            materialParts[material] = { count: 0, types: 0 };
        }
        materialParts[material].count += part.total_quantity;
        materialParts[material].types++;
    });
    
    const materials = Object.keys(materialParts).map(material => ({
        name: material,
        count: materialParts[material].count,
        types: materialParts[material].types
    })).sort((a, b) => b.count - a.count);
    
    // Create modal
    const modal = document.createElement('div');
    modal.style.cssText = `
        position: fixed; top: 0; left: 0; width: 100%; height: 100%;
        background: rgba(0, 0, 0, 0.5); display: flex; align-items: center;
        justify-content: center; z-index: 10000; backdrop-filter: blur(4px);
    `;
    
    const modalContent = document.createElement('div');
    modalContent.style.cssText = `
        background: white; border-radius: 12px; width: 90%; max-width: 900px;
        max-height: 85vh; overflow: hidden; box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        display: flex; flex-direction: column;
    `;
    
    // Header - monochrome style
    const header = document.createElement('div');
    header.style.cssText = `
        padding: 24px 32px; border-bottom: 1px solid #e1e4e8;
        display: flex; justify-content: space-between; align-items: center;
        background: #f6f8fa;
    `;
    header.innerHTML = `
        <div>
            <h2 style="margin: 0; font-size: 24px; font-weight: 700; color: #24292e;">Parts Breakdown</h2>
            <p style="margin: 8px 0 0 0; font-size: 14px; color: #656d76;">Total parts: ${totalParts} | Unique types: ${partTypes.length}</p>
        </div>
        <button onclick="closeVisualizationModal()" style="background: none; border: none; font-size: 28px; color: #656d76; cursor: pointer; width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 6px; transition: all 0.2s;" onmouseover="this.style.background='#e1e4e8'" onmouseout="this.style.background='none'">&times;</button>
    `;
    
    // Content area
    const content = document.createElement('div');
    content.style.cssText = `padding: 32px; overflow-y: auto; flex: 1;`;
    
    // Two-column layout
    const vizContainer = document.createElement('div');
    vizContainer.style.cssText = `display: grid; grid-template-columns: 1fr 1fr; gap: 32px; margin-bottom: 32px;`;
    
    // Left: Bar chart
    const chartContainer = document.createElement('div');
    chartContainer.innerHTML = `<h3 style="margin: 0 0 20px 0; font-size: 16px; font-weight: 600; color: #24292e;">Parts by Material</h3>`;
    
    const barsContainer = document.createElement('div');
    barsContainer.style.cssText = `display: flex; flex-direction: column; gap: 12px;`;
    
    const colors = ['#0366d6', '#2188ff', '#79b8ff', '#c8e1ff', '#0969da', '#218bff'];
    const maxCount = Math.max(...materials.map(m => m.count));
    
    materials.forEach((material, index) => {
        const percentage = (material.count / maxCount) * 100;
        const barWrapper = document.createElement('div');
        barWrapper.style.cssText = `display: flex; flex-direction: column; gap: 4px;`;
        
        const labelRow = document.createElement('div');
        labelRow.style.cssText = `display: flex; justify-content: space-between; font-size: 13px; color: #24292e;`;
        labelRow.innerHTML = `
            <span style="font-weight: 500;">${escapeHtml(material.name)}</span>
            <span style="font-weight: 600;">${material.count} parts</span>
        `;
        
        const barTrack = document.createElement('div');
        barTrack.style.cssText = `width: 100%; height: 24px; background: #f6f8fa; border-radius: 4px; overflow: hidden;`;
        
        const barFill = document.createElement('div');
        barFill.style.cssText = `
            height: 100%; background: ${colors[index % colors.length]}; width: ${percentage}%;
            transition: width 0.6s ease; display: flex; align-items: center; padding-left: 8px;
            color: white; font-size: 11px; font-weight: 600;
        `;
        barFill.textContent = `${formatNumber((material.count / totalParts) * 100, 1)}%`;
        
        barTrack.appendChild(barFill);
        barWrapper.appendChild(labelRow);
        barWrapper.appendChild(barTrack);
        barsContainer.appendChild(barWrapper);
    });
    
    chartContainer.appendChild(barsContainer);
    
    // Right: Summary table
    const tableContainer = document.createElement('div');
    tableContainer.innerHTML = `
        <h3 style="margin: 0 0 20px 0; font-size: 16px; font-weight: 600; color: #24292e;">Material Summary</h3>
        <div style="border: 1px solid #d0d7de; border-radius: 6px; overflow: hidden;">
            <table style="width: 100%; border-collapse: collapse;">
                <thead>
                    <tr style="background: #f6f8fa;">
                        <th style="padding: 12px; text-align: left; font-size: 12px; font-weight: 600; color: #656d76; border-bottom: 1px solid #d0d7de;">Material</th>
                        <th style="padding: 12px; text-align: center; font-size: 12px; font-weight: 600; color: #656d76; border-bottom: 1px solid #d0d7de;">Types</th>
                        <th style="padding: 12px; text-align: right; font-size: 12px; font-weight: 600; color: #656d76; border-bottom: 1px solid #d0d7de;">Quantity</th>
                    </tr>
                </thead>
                <tbody>
                    ${materials.map((material, index) => `
                        <tr style="border-bottom: 1px solid #e1e4e8; ${index % 2 === 0 ? 'background: #fafbfc;' : ''}">
                            <td style="padding: 12px; font-size: 13px; color: #24292e;">${escapeHtml(material.name)}</td>
                            <td style="padding: 12px; text-align: center; font-size: 13px; color: #656d76;">${material.types}</td>
                            <td style="padding: 12px; text-align: right; font-size: 13px; color: #24292e; font-weight: 600;">${material.count}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        </div>
    `;
    
    vizContainer.appendChild(chartContainer);
    vizContainer.appendChild(tableContainer);
    content.appendChild(vizContainer);
    
    // Bottom stats
    const avgQtyPerType = totalParts / partTypes.length;
    const mostCommonPart = partTypes.reduce((max, pt) => pt.total_quantity > max.total_quantity ? pt : max, partTypes[0]);
    const materialCount = materials.length;
    
    const statsContainer = document.createElement('div');
    statsContainer.style.cssText = `
        display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px;
        padding: 24px; background: #f6f8fa; border-radius: 8px;
    `;
    
    statsContainer.innerHTML = `
        <div style="text-align: center;">
            <div style="font-size: 12px; color: #656d76; margin-bottom: 4px;">Total Parts</div>
            <div style="font-size: 24px; font-weight: 700; color: #24292e;">${totalParts}</div>
        </div>
        <div style="text-align: center;">
            <div style="font-size: 12px; color: #656d76; margin-bottom: 4px;">Avg per Type</div>
            <div style="font-size: 24px; font-weight: 700; color: #24292e;">${formatNumber(avgQtyPerType, 1)}</div>
        </div>
        <div style="text-align: center;">
            <div style="font-size: 12px; color: #656d76; margin-bottom: 4px;">Most Common</div>
            <div style="font-size: 16px; font-weight: 700; color: #24292e;">${escapeHtml(mostCommonPart.name)}</div>
            <div style="font-size: 12px; color: #656d76;">${mostCommonPart.total_quantity} pieces</div>
        </div>
    `;
    
    content.appendChild(statsContainer);
    
    // Assemble modal
    modalContent.appendChild(header);
    modalContent.appendChild(content);
    modal.appendChild(modalContent);
    
    modal.onclick = (e) => { if (e.target === modal) closeVisualizationModal(); };
    
    document.body.appendChild(modal);
    currentModal = modal;
}

// Update initialization to include all modals
function initializeCardVisualizations() {
    const totalCostCard = document.getElementById('summaryTotalCost');
    if (totalCostCard && totalCostCard.parentElement) {
        totalCostCard.parentElement.onclick = () => showTotalCostVisualization();
    }
    
    const efficiencyCard = document.getElementById('summaryOverallEfficiency');
    if (efficiencyCard && efficiencyCard.parentElement) {
        efficiencyCard.parentElement.onclick = () => showEfficiencyVisualization();
    }
    
    const sheetsCard = document.getElementById('summaryTotalBoards');
    if (sheetsCard && sheetsCard.parentElement) {
        sheetsCard.parentElement.onclick = () => showSheetsVisualization();
    }
    
    const partsCard = document.getElementById('summaryTotalParts');
    if (partsCard && partsCard.parentElement) {
        partsCard.parentElement.onclick = () => showPartsVisualization();
    }
}

// Export functions
if (typeof window !== 'undefined') {
    window.showEfficiencyVisualization = showEfficiencyVisualization;
    window.showSheetsVisualization = showSheetsVisualization;
    window.showPartsVisualization = showPartsVisualization;
}
