// Card Visualization Modals
// Separate file to keep main.html clean and organized

// Global modal state
let currentModal = null;

// Initialize card click handlers
function initializeCardVisualizations() {
    // Total Cost Card
    const totalCostCard = document.getElementById('summaryTotalCost');
    if (totalCostCard && totalCostCard.parentElement) {
        totalCostCard.parentElement.onclick = () => showTotalCostVisualization();
    }
    
    // Add more card handlers here as we implement them
}

// Close modal function
function closeVisualizationModal() {
    if (currentModal) {
        currentModal.remove();
        currentModal = null;
    }
}

// Total Cost Visualization Modal
function showTotalCostVisualization() {
    if (!g_reportData || !g_reportData.unique_board_types) {
        alert('No cost data available');
        return;
    }
    
    // Close any existing modal
    closeVisualizationModal();
    
    const currency = g_reportData.summary.currency || window.defaultCurrency || 'USD';
    const currencySymbol = window.currencySymbols[currency] || currency;
    const totalCost = g_reportData.summary.total_project_cost || 0;
    
    // Create modal
    const modal = document.createElement('div');
    modal.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.5);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 10000;
        backdrop-filter: blur(4px);
    `;
    
    const modalContent = document.createElement('div');
    modalContent.style.cssText = `
        background: white;
        border-radius: 12px;
        width: 90%;
        max-width: 900px;
        max-height: 85vh;
        overflow: hidden;
        box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
        display: flex;
        flex-direction: column;
    `;
    
    // Header
    const header = document.createElement('div');
    header.style.cssText = `
        padding: 24px 32px;
        border-bottom: 1px solid #e1e4e8;
        display: flex;
        justify-content: space-between;
        align-items: center;
        background: #f6f8fa;
    `;
    header.innerHTML = `
        <div>
            <h2 style="margin: 0; font-size: 24px; font-weight: 700; color: #24292e;">Total Cost Breakdown</h2>
            <p style="margin: 8px 0 0 0; font-size: 14px; color: #656d76;">Project total: ${currencySymbol}${formatNumber(totalCost, 2)}</p>
        </div>
        <button onclick="closeVisualizationModal()" style="background: none; border: none; font-size: 28px; color: #656d76; cursor: pointer; width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 6px; transition: all 0.2s;" onmouseover="this.style.background='#e1e4e8'" onmouseout="this.style.background='none'">&times;</button>
    `;
    
    // Content area
    const content = document.createElement('div');
    content.style.cssText = `
        padding: 32px;
        overflow-y: auto;
        flex: 1;
    `;
    
    // Prepare data for visualization
    const materials = g_reportData.unique_board_types.map(bt => ({
        name: bt.material,
        cost: bt.total_cost || 0,
        count: bt.count,
        pricePerSheet: bt.price_per_sheet || 0,
        percentage: totalCost > 0 ? ((bt.total_cost || 0) / totalCost * 100) : 0
    })).sort((a, b) => b.cost - a.cost);
    
    // Create visualization
    const vizContainer = document.createElement('div');
    vizContainer.style.cssText = `
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 32px;
        margin-bottom: 32px;
    `;
    
    // Left side - Bar chart
    const chartContainer = document.createElement('div');
    chartContainer.innerHTML = `
        <h3 style="margin: 0 0 20px 0; font-size: 16px; font-weight: 600; color: #24292e;">Cost Distribution</h3>
    `;
    
    const barsContainer = document.createElement('div');
    barsContainer.style.cssText = `
        display: flex;
        flex-direction: column;
        gap: 12px;
    `;
    
    // Color palette for bars
    const colors = ['#0366d6', '#2188ff', '#79b8ff', '#c8e1ff', '#0969da', '#218bff'];
    
    materials.forEach((material, index) => {
        const barWrapper = document.createElement('div');
        barWrapper.style.cssText = `
            display: flex;
            flex-direction: column;
            gap: 4px;
        `;
        
        const labelRow = document.createElement('div');
        labelRow.style.cssText = `
            display: flex;
            justify-content: space-between;
            font-size: 13px;
            color: #24292e;
        `;
        labelRow.innerHTML = `
            <span style="font-weight: 500;">${escapeHtml(material.name)}</span>
            <span style="font-weight: 600;">${currencySymbol}${formatNumber(material.cost, 2)}</span>
        `;
        
        const barTrack = document.createElement('div');
        barTrack.style.cssText = `
            width: 100%;
            height: 24px;
            background: #f6f8fa;
            border-radius: 4px;
            overflow: hidden;
            position: relative;
        `;
        
        const barFill = document.createElement('div');
        barFill.style.cssText = `
            height: 100%;
            background: ${colors[index % colors.length]};
            width: ${material.percentage}%;
            transition: width 0.6s ease;
            display: flex;
            align-items: center;
            justify-content: flex-end;
            padding-right: 8px;
            color: white;
            font-size: 11px;
            font-weight: 600;
        `;
        barFill.textContent = `${formatNumber(material.percentage, 1)}%`;
        
        barTrack.appendChild(barFill);
        barWrapper.appendChild(labelRow);
        barWrapper.appendChild(barTrack);
        barsContainer.appendChild(barWrapper);
    });
    
    chartContainer.appendChild(barsContainer);
    
    // Right side - Detailed breakdown table
    const tableContainer = document.createElement('div');
    tableContainer.innerHTML = `
        <h3 style="margin: 0 0 20px 0; font-size: 16px; font-weight: 600; color: #24292e;">Material Details</h3>
        <div style="border: 1px solid #d0d7de; border-radius: 6px; overflow: hidden;">
            <table style="width: 100%; border-collapse: collapse;">
                <thead>
                    <tr style="background: #f6f8fa;">
                        <th style="padding: 12px; text-align: left; font-size: 12px; font-weight: 600; color: #656d76; border-bottom: 1px solid #d0d7de;">Material</th>
                        <th style="padding: 12px; text-align: center; font-size: 12px; font-weight: 600; color: #656d76; border-bottom: 1px solid #d0d7de;">Sheets</th>
                        <th style="padding: 12px; text-align: right; font-size: 12px; font-weight: 600; color: #656d76; border-bottom: 1px solid #d0d7de;">Price/Sheet</th>
                        <th style="padding: 12px; text-align: right; font-size: 12px; font-weight: 600; color: #656d76; border-bottom: 1px solid #d0d7de;">Total</th>
                    </tr>
                </thead>
                <tbody>
                    ${materials.map((material, index) => `
                        <tr style="border-bottom: 1px solid #e1e4e8; ${index % 2 === 0 ? 'background: #fafbfc;' : ''}">
                            <td style="padding: 12px; font-size: 13px; color: #24292e;">${escapeHtml(material.name)}</td>
                            <td style="padding: 12px; text-align: center; font-size: 13px; color: #24292e; font-weight: 600;">${material.count}</td>
                            <td style="padding: 12px; text-align: right; font-size: 13px; color: #656d76;">${currencySymbol}${formatNumber(material.pricePerSheet, 2)}</td>
                            <td style="padding: 12px; text-align: right; font-size: 13px; color: #24292e; font-weight: 600;">${currencySymbol}${formatNumber(material.cost, 2)}</td>
                        </tr>
                    `).join('')}
                </tbody>
                <tfoot>
                    <tr style="background: #f6f8fa; font-weight: 700;">
                        <td colspan="3" style="padding: 12px; text-align: right; font-size: 14px; color: #24292e;">Total Project Cost:</td>
                        <td style="padding: 12px; text-align: right; font-size: 14px; color: #0366d6;">${currencySymbol}${formatNumber(totalCost, 2)}</td>
                    </tr>
                </tfoot>
            </table>
        </div>
    `;
    
    vizContainer.appendChild(chartContainer);
    vizContainer.appendChild(tableContainer);
    content.appendChild(vizContainer);
    
    // Summary stats
    const statsContainer = document.createElement('div');
    statsContainer.style.cssText = `
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 16px;
        padding: 24px;
        background: #f6f8fa;
        border-radius: 8px;
    `;
    
    const totalSheets = materials.reduce((sum, m) => sum + m.count, 0);
    const avgCostPerSheet = totalSheets > 0 ? totalCost / totalSheets : 0;
    const mostExpensiveMaterial = materials[0];
    
    statsContainer.innerHTML = `
        <div style="text-align: center;">
            <div style="font-size: 12px; color: #656d76; margin-bottom: 4px;">Total Sheets</div>
            <div style="font-size: 24px; font-weight: 700; color: #24292e;">${totalSheets}</div>
        </div>
        <div style="text-align: center;">
            <div style="font-size: 12px; color: #656d76; margin-bottom: 4px;">Avg Cost/Sheet</div>
            <div style="font-size: 24px; font-weight: 700; color: #24292e;">${currencySymbol}${formatNumber(avgCostPerSheet, 2)}</div>
        </div>
        <div style="text-align: center;">
            <div style="font-size: 12px; color: #656d76; margin-bottom: 4px;">Most Expensive</div>
            <div style="font-size: 16px; font-weight: 700; color: #24292e;">${escapeHtml(mostExpensiveMaterial.name)}</div>
            <div style="font-size: 12px; color: #656d76;">${currencySymbol}${formatNumber(mostExpensiveMaterial.cost, 2)}</div>
        </div>
    `;
    
    content.appendChild(statsContainer);
    
    // Assemble modal
    modalContent.appendChild(header);
    modalContent.appendChild(content);
    modal.appendChild(modalContent);
    
    // Close on background click
    modal.onclick = (e) => {
        if (e.target === modal) {
            closeVisualizationModal();
        }
    };
    
    document.body.appendChild(modal);
    currentModal = modal;
    
    // Animate bars
    setTimeout(() => {
        const bars = barsContainer.querySelectorAll('[style*="width"]');
        bars.forEach(bar => {
            bar.style.width = bar.style.width; // Trigger animation
        });
    }, 50);
}

// Call this when the report is loaded
if (typeof window !== 'undefined') {
    window.initializeCardVisualizations = initializeCardVisualizations;
    window.closeVisualizationModal = closeVisualizationModal;
    window.showTotalCostVisualization = showTotalCostVisualization;
}
