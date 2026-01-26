/**
 * CLEAN PDF EXPORT IMPLEMENTATION
 * Completely new implementation to replace corrupted professional_pdf_export.js
 * Focuses on rendering cutting diagrams and assembly views correctly
 */

async function exportToPDFClean() {
    try {
        console.log('=== CLEAN PDF EXPORT STARTED ===');
        showProgressOverlay('Generating PDF Report...');
        
        // Use html2pdf if available, otherwise fallback to simple approach
        if (typeof html2pdf === 'undefined') {
            console.log('html2pdf not available, using simple HTML export');
            exportSimplePDF();
            return;
        }
        
        if (!g_reportData || !g_boardsData) {
            throw new Error('No report data available');
        }

        // Create PDF
        const pdf = new jsPDF({
            orientation: 'portrait',
            unit: 'mm',
            format: 'a4',
            compress: false
        });

        const pageWidth = pdf.internal.pageSize.getWidth();
        const pageHeight = pdf.internal.pageSize.getHeight();
        const margin = 15;
        let yPos = margin;

        // PAGE 1: TITLE PAGE
        console.log('Adding title page...');
        addTitlePageClean(pdf, pageWidth, pageHeight, margin);
        pdf.addPage();
        yPos = margin;

        // PAGE 2+: CUTTING DIAGRAMS (MAIN FOCUS)
        console.log('Adding cutting diagrams...');
        yPos = addCuttingDiagramsClean(pdf, pageWidth, pageHeight, margin, yPos);

        // PAGE N: SUMMARY
        pdf.addPage();
        yPos = margin;
        console.log('Adding summary...');
        addSummaryPageClean(pdf, pageWidth, pageHeight, margin, yPos);

        // Save PDF
        const filename = `AutoNestCut_Report_${new Date().toISOString().split('T')[0]}.pdf`;
        pdf.save(filename);
        
        hideProgressOverlay();
        showSuccessMessage(`PDF exported successfully: ${filename}`);
        console.log('=== CLEAN PDF EXPORT COMPLETED ===');

    } catch (error) {
        hideProgressOverlay();
        console.error('PDF Export Error:', error);
        showError(`PDF Export Failed: ${error.message}`);
    }
}

function addTitlePageClean(pdf, pageWidth, pageHeight, margin) {
    const centerX = pageWidth / 2;
    let yPos = pageHeight / 3;

    // Title
    pdf.setFontSize(28);
    pdf.setFont('Helvetica', 'bold');
    pdf.text('AutoNestCut Report', centerX, yPos, { align: 'center' });

    yPos += 20;
    pdf.setFontSize(14);
    pdf.setFont('Helvetica', 'normal');
    pdf.text(g_reportData.summary?.project_name || 'Untitled Project', centerX, yPos, { align: 'center' });

    yPos += 30;
    pdf.setFontSize(11);
    
    const titleInfo = [
        ['Client:', g_reportData.summary?.client_name || 'N/A'],
        ['Prepared by:', g_reportData.summary?.prepared_by || 'N/A'],
        ['Date:', new Date().toLocaleDateString()],
        ['Total Parts:', g_reportData.summary?.total_parts_instances || 0],
        ['Material Sheets:', g_reportData.summary?.total_boards || 0],
        ['Efficiency:', `${formatNumber(g_reportData.summary?.overall_efficiency || 0, 1)}%`]
    ];

    titleInfo.forEach(([label, value]) => {
        pdf.setFont('Helvetica', 'bold');
        pdf.text(label, margin + 20, yPos);
        pdf.setFont('Helvetica', 'normal');
        pdf.text(String(value), margin + 60, yPos);
        yPos += 8;
    });
}

function addCuttingDiagramsClean(pdf, pageWidth, pageHeight, margin, startY) {
    let yPos = startY;
    const contentWidth = pageWidth - (2 * margin);
    const maxDiagramHeight = 120;

    // Section title
    pdf.setFontSize(16);
    pdf.setFont('Helvetica', 'bold');
    pdf.text('Cutting Diagrams', margin, yPos);
    yPos += 12;

    // Divider line
    pdf.setDrawColor(100);
    pdf.line(margin, yPos, pageWidth - margin, yPos);
    yPos += 8;

    const diagramsContainer = document.getElementById('diagramsContainer');
    if (!diagramsContainer) {
        pdf.setFontSize(10);
        pdf.text('No diagrams container found', margin, yPos);
        return yPos;
    }

    const canvases = diagramsContainer.querySelectorAll('canvas');
    console.log(`Found ${canvases.length} canvases to export`);

    if (canvases.length === 0) {
        pdf.setFontSize(10);
        pdf.text('No cutting diagrams available', margin, yPos);
        return yPos;
    }

    canvases.forEach((canvas, index) => {
        try {
            console.log(`Processing canvas ${index + 1}/${canvases.length}`);

            // Ensure canvas is rendered
            if (canvas.drawCanvas && typeof canvas.drawCanvas === 'function') {
                console.log(`  - Calling drawCanvas for canvas ${index}`);
                canvas.drawCanvas();
            }

            // Get canvas dimensions
            const canvasWidth = canvas.width;
            const canvasHeight = canvas.height;
            console.log(`  - Canvas dimensions: ${canvasWidth}x${canvasHeight}`);

            // Convert to image data
            const imageData = canvas.toDataURL('image/png');
            
            if (!imageData || imageData.length < 100) {
                console.warn(`  - Canvas ${index} produced invalid image data (length: ${imageData?.length || 0})`);
                return;
            }

            console.log(`  - Image data generated (${(imageData.length / 1024).toFixed(2)} KB)`);

            // Check if we need a new page
            if (yPos + maxDiagramHeight > pageHeight - margin) {
                console.log(`  - Adding new page (yPos: ${yPos}, needed: ${maxDiagramHeight})`);
                pdf.addPage();
                yPos = margin;
            }

            // Add diagram label
            pdf.setFontSize(12);
            pdf.setFont('Helvetica', 'bold');
            const boardData = g_boardsData[index];
            const boardLabel = boardData ? `${boardData.material} Board ${index + 1}` : `Sheet ${index + 1}`;
            pdf.text(boardLabel, margin, yPos);
            yPos += 8;

            // Add board info
            if (boardData) {
                pdf.setFontSize(9);
                pdf.setFont('Helvetica', 'normal');
                const reportUnits = window.currentUnits || 'mm';
                const width = boardData.stock_width / window.unitFactors[reportUnits];
                const height = boardData.stock_height / window.unitFactors[reportUnits];
                const efficiency = boardData.efficiency_percentage || 0;
                const waste = boardData.waste_percentage || 0;
                
                pdf.text(`Size: ${formatNumber(width, 1)}×${formatNumber(height, 1)} ${reportUnits} | Efficiency: ${formatNumber(efficiency, 1)}% | Waste: ${formatNumber(waste, 1)}%`, margin, yPos);
                yPos += 6;
            }

            // Calculate image dimensions to fit page
            const maxWidth = contentWidth;
            const maxHeight = pageHeight - yPos - margin - 10;
            
            let imgWidth = maxWidth;
            let imgHeight = (canvasHeight / canvasWidth) * imgWidth;
            
            if (imgHeight > maxHeight) {
                imgHeight = maxHeight;
                imgWidth = (canvasWidth / canvasHeight) * imgHeight;
            }

            console.log(`  - Adding image to PDF (${imgWidth.toFixed(1)}x${imgHeight.toFixed(1)} mm)`);

            // Add image to PDF
            pdf.addImage(imageData, 'PNG', margin, yPos, imgWidth, imgHeight);
            yPos += imgHeight + 10;

        } catch (error) {
            console.error(`Error processing canvas ${index}:`, error);
            pdf.setFontSize(10);
            pdf.setFont('Helvetica', 'normal');
            pdf.text(`Error rendering diagram ${index + 1}: ${error.message}`, margin, yPos);
            yPos += 10;
        }
    });

    return yPos;
}

function addSummaryPageClean(pdf, pageWidth, pageHeight, margin, startY) {
    let yPos = startY;
    const contentWidth = pageWidth - (2 * margin);

    // Section title
    pdf.setFontSize(16);
    pdf.setFont('Helvetica', 'bold');
    pdf.text('Project Summary', margin, yPos);
    yPos += 12;

    // Divider line
    pdf.setDrawColor(100);
    pdf.line(margin, yPos, pageWidth - margin, yPos);
    yPos += 8;

    pdf.setFontSize(11);
    pdf.setFont('Helvetica', 'normal');

    const reportUnits = window.currentUnits || 'mm';
    const reportPrecision = window.currentPrecision ?? 1;
    const currency = g_reportData.summary?.currency || window.defaultCurrency || 'USD';
    const currencySymbol = window.currencySymbols?.[currency] || currency;

    const summaryData = [
        ['Total Parts:', g_reportData.summary?.total_parts_instances || 0],
        ['Unique Components:', g_reportData.summary?.total_unique_part_types || 0],
        ['Material Sheets:', g_reportData.summary?.total_boards || 0],
        ['Overall Efficiency:', `${formatNumber(g_reportData.summary?.overall_efficiency || 0, 1)}%`],
        ['Total Project Weight:', `${formatNumber(g_reportData.summary?.total_project_weight_kg || 0, 2)} kg`],
        ['Total Project Cost:', `${currencySymbol}${formatNumber(g_reportData.summary?.total_project_cost || 0, 2)}`]
    ];

    summaryData.forEach(([label, value]) => {
        pdf.setFont('Helvetica', 'bold');
        pdf.text(label, margin, yPos);
        pdf.setFont('Helvetica', 'normal');
        pdf.text(String(value), margin + 80, yPos);
        yPos += 8;
    });

    // Materials section
    yPos += 15;
    pdf.setFontSize(14);
    pdf.setFont('Helvetica', 'bold');
    pdf.text('Materials Used', margin, yPos);
    yPos += 10;

    if (g_reportData.unique_board_types && g_reportData.unique_board_types.length > 0) {
        pdf.setFontSize(9);
        pdf.setFont('Helvetica', 'normal');

        g_reportData.unique_board_types.forEach(board => {
            if (yPos > pageHeight - margin - 15) {
                pdf.addPage();
                yPos = margin;
            }

            const boardWidth = board.stock_width / window.unitFactors[reportUnits];
            const boardHeight = board.stock_height / window.unitFactors[reportUnits];
            const boardSymbol = window.currencySymbols?.[board.currency || currency] || (board.currency || currency);

            pdf.text(`• ${board.material}: ${formatNumber(boardWidth, 1)}×${formatNumber(boardHeight, 1)} ${reportUnits} | Count: ${board.count} | Price: ${boardSymbol}${formatNumber(board.price_per_sheet || 0, 2)}`, margin + 5, yPos);
            yPos += 6;
        });
    }
}

// Helper functions
function formatNumber(value, decimals = 2) {
    if (typeof value !== 'number' || isNaN(value)) {
        return '-';
    }
    return parseFloat(value).toFixed(decimals);
}

function showProgressOverlay(message) {
    const overlay = document.createElement('div');
    overlay.id = 'progressOverlay';
    overlay.innerHTML = `
        <div style="position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.5); z-index: 9999; display: flex; flex-direction: column; align-items: center; justify-content: center;">
            <div style="width: 60px; height: 60px; border: 4px solid rgba(255,255,255,0.3); border-top: 4px solid #007cba; border-radius: 50%; animation: spin 1s linear infinite;"></div>
            <div style="color: white; margin-top: 20px; font-size: 16px; font-weight: 500;">${message}</div>
            <style>
                @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
            </style>
        </div>
    `;
    document.body.appendChild(overlay);
}

function hideProgressOverlay() {
    const overlay = document.getElementById('progressOverlay');
    if (overlay) overlay.remove();
}

function showSuccessMessage(message) {
    const modal = document.createElement('div');
    modal.style.cssText = 'position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.6); z-index: 10000; display: flex; align-items: center; justify-content: center;';
    
    const dialog = document.createElement('div');
    dialog.style.cssText = 'background: white; padding: 30px; border-radius: 8px; max-width: 500px; width: 90%; box-shadow: 0 8px 32px rgba(0,0,0,0.3);';
    
    dialog.innerHTML = `
        <div style="text-align: center;">
            <div style="width: 60px; height: 60px; background: #e8f5e9; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px;">
                <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#28a745" stroke-width="2">
                    <polyline points="20 6 9 17 4 12"/>
                </svg>
            </div>
            <h3 style="margin: 0 0 12px 0; color: #28a745; font-size: 20px;">Success!</h3>
            <p style="margin: 0 0 20px 0; color: #555; font-size: 14px; line-height: 1.6;">${message}</p>
            <button onclick="this.closest('[style*=\'position: fixed\']').remove()" style="background: #28a745; color: white; border: none; padding: 10px 24px; border-radius: 6px; cursor: pointer; font-size: 14px; font-weight: 500;">Close</button>
        </div>
    `;
    
    modal.appendChild(dialog);
    document.body.appendChild(modal);
}

function showError(message) {
    const modal = document.createElement('div');
    modal.style.cssText = 'position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.6); z-index: 10000; display: flex; align-items: center; justify-content: center;';
    
    const dialog = document.createElement('div');
    dialog.style.cssText = 'background: white; padding: 30px; border-radius: 8px; max-width: 500px; width: 90%; box-shadow: 0 8px 32px rgba(0,0,0,0.3);';
    
    dialog.innerHTML = `
        <div style="text-align: center;">
            <div style="width: 60px; height: 60px; background: #fee; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 20px;">
                <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="#d73a49" stroke-width="2">
                    <circle cx="12" cy="12" r="10"/>
                    <line x1="12" y1="8" x2="12" y2="12"/>
                    <line x1="12" y1="16" x2="12.01" y2="16"/>
                </svg>
            </div>
            <h3 style="margin: 0 0 12px 0; color: #d73a49; font-size: 20px;">Error</h3>
            <p style="margin: 0 0 20px 0; color: #555; font-size: 14px; line-height: 1.6;">${message}</p>
            <button onclick="this.closest('[style*=\'position: fixed\']').remove()" style="background: #d73a49; color: white; border: none; padding: 10px 24px; border-radius: 6px; cursor: pointer; font-size: 14px; font-weight: 500;">Close</button>
        </div>
    `;
    
    modal.appendChild(dialog);
    document.body.appendChild(modal);
}

/**
 * FALLBACK: Export HTML report that can be printed to PDF
 * This works within SketchUp extension environment
 */
function exportSimplePDF() {
    try {
        console.log('=== SIMPLE PDF EXPORT (HTML REPORT) ===');
        
        if (!g_reportData || !g_boardsData) {
            throw new Error('No report data available');
        }

        const reportUnits = window.currentUnits || 'mm';
        const reportPrecision = window.currentPrecision ?? 1;
        const currency = g_reportData.summary?.currency || window.defaultCurrency || 'USD';
        const currencySymbol = window.currencySymbols?.[currency] || currency;

        // Build HTML content
        let htmlContent = `
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>AutoNestCut Report</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Arial, sans-serif; padding: 20px; line-height: 1.6; background: white; }
        .page-break { page-break-after: always; margin-bottom: 40px; }
        .title-page { text-align: center; padding: 60px 20px; }
        .title-page h1 { font-size: 32px; margin-bottom: 20px; color: #333; }
        .title-page h2 { font-size: 18px; margin-bottom: 40px; color: #666; }
        .title-info { text-align: left; max-width: 600px; margin: 0 auto; }
        .title-info p { margin: 10px 0; font-size: 14px; }
        .title-info strong { display: inline-block; width: 150px; }
        h2 { font-size: 20px; margin: 30px 0 15px 0; color: #333; border-bottom: 2px solid #007cba; padding-bottom: 10px; }
        h3 { font-size: 16px; margin: 20px 0 10px 0; color: #555; }
        .diagram-section { margin: 20px 0; page-break-inside: avoid; }
        .diagram-section img { max-width: 100%; height: auto; border: 1px solid #ddd; margin: 10px 0; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { border: 1px solid #ddd; padding: 10px; text-align: left; }
        th { background-color: #f5f5f5; font-weight: bold; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .summary-item { margin: 10px 0; font-size: 14px; }
        .summary-item strong { display: inline-block; width: 200px; }
        @media print { body { padding: 0; } .page-break { margin-bottom: 0; } }
    </style>
</head>
<body>
`;

        // TITLE PAGE
        htmlContent += `
    <div class="title-page page-break">
        <h1>AutoNestCut Report</h1>
        <h2>${g_reportData.summary?.project_name || 'Untitled Project'}</h2>
        <div class="title-info">
            <p><strong>Client:</strong> ${g_reportData.summary?.client_name || 'N/A'}</p>
            <p><strong>Prepared by:</strong> ${g_reportData.summary?.prepared_by || 'N/A'}</p>
            <p><strong>Date:</strong> ${new Date().toLocaleDateString()}</p>
            <p><strong>Total Parts:</strong> ${g_reportData.summary?.total_parts_instances || 0}</p>
            <p><strong>Material Sheets:</strong> ${g_reportData.summary?.total_boards || 0}</p>
            <p><strong>Overall Efficiency:</strong> ${formatNumber(g_reportData.summary?.overall_efficiency || 0, 1)}%</p>
        </div>
    </div>
`;

        // CUTTING DIAGRAMS
        htmlContent += `<h2>Cutting Diagrams</h2>`;
        
        const diagramsContainer = document.getElementById('diagramsContainer');
        if (diagramsContainer) {
            const canvases = diagramsContainer.querySelectorAll('canvas');
            
            canvases.forEach((canvas, index) => {
                try {
                    // Ensure canvas is rendered
                    if (canvas.drawCanvas && typeof canvas.drawCanvas === 'function') {
                        canvas.drawCanvas();
                    }
                    
                    const imageData = canvas.toDataURL('image/png');
                    const boardData = g_boardsData[index];
                    const boardLabel = boardData ? `${boardData.material} Board ${index + 1}` : `Sheet ${index + 1}`;
                    
                    htmlContent += `
    <div class="diagram-section page-break">
        <h3>${boardLabel}</h3>
`;
                    
                    if (boardData) {
                        const width = boardData.stock_width / window.unitFactors[reportUnits];
                        const height = boardData.stock_height / window.unitFactors[reportUnits];
                        const efficiency = boardData.efficiency_percentage || 0;
                        const waste = boardData.waste_percentage || 0;
                        
                        htmlContent += `
        <p style="font-size: 12px; color: #666;">
            Size: ${formatNumber(width, 1)}×${formatNumber(height, 1)} ${reportUnits} | 
            Efficiency: ${formatNumber(efficiency, 1)}% | 
            Waste: ${formatNumber(waste, 1)}%
        </p>
`;
                    }
                    
                    htmlContent += `
        <img src="${imageData}" alt="Cutting diagram for ${boardLabel}" style="max-width: 100%; height: auto; border: 1px solid #ddd;">
    </div>
`;
                } catch (error) {
                    console.error(`Error processing canvas ${index}:`, error);
                    htmlContent += `<p style="color: red;">Error rendering diagram ${index + 1}</p>`;
                }
            });
        }

        // SUMMARY PAGE
        htmlContent += `
    <div class="page-break">
        <h2>Project Summary</h2>
        <div class="summary-item"><strong>Total Parts:</strong> ${g_reportData.summary?.total_parts_instances || 0}</div>
        <div class="summary-item"><strong>Unique Components:</strong> ${g_reportData.summary?.total_unique_part_types || 0}</div>
        <div class="summary-item"><strong>Material Sheets:</strong> ${g_reportData.summary?.total_boards || 0}</div>
        <div class="summary-item"><strong>Overall Efficiency:</strong> ${formatNumber(g_reportData.summary?.overall_efficiency || 0, 1)}%</div>
        <div class="summary-item"><strong>Total Project Weight:</strong> ${formatNumber(g_reportData.summary?.total_project_weight_kg || 0, 2)} kg</div>
        <div class="summary-item"><strong>Total Project Cost:</strong> ${currencySymbol}${formatNumber(g_reportData.summary?.total_project_cost || 0, 2)}</div>
        
        <h2>Materials Used</h2>
        <table>
            <thead>
                <tr>
                    <th>Material</th>
                    <th>Dimensions (${reportUnits})</th>
                    <th>Count</th>
                    <th>Price/Sheet</th>
                    <th>Total Cost</th>
                </tr>
            </thead>
            <tbody>
`;

        if (g_reportData.unique_board_types && g_reportData.unique_board_types.length > 0) {
            g_reportData.unique_board_types.forEach(board => {
                const boardWidth = board.stock_width / window.unitFactors[reportUnits];
                const boardHeight = board.stock_height / window.unitFactors[reportUnits];
                const boardSymbol = window.currencySymbols?.[board.currency || currency] || (board.currency || currency);
                
                htmlContent += `
                <tr>
                    <td>${board.material}</td>
                    <td>${formatNumber(boardWidth, 1)}×${formatNumber(boardHeight, 1)}</td>
                    <td>${board.count}</td>
                    <td>${boardSymbol}${formatNumber(board.price_per_sheet || 0, 2)}</td>
                    <td>${boardSymbol}${formatNumber((board.price_per_sheet || 0) * board.count, 2)}</td>
                </tr>
`;
            });
        }

        htmlContent += `
            </tbody>
        </table>
    </div>
</body>
</html>
`;

        // Create blob and download
        const blob = new Blob([htmlContent], { type: 'text/html' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `AutoNestCut_Report_${new Date().toISOString().split('T')[0]}.html`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
        
        hideProgressOverlay();
        showSuccessMessage('Report HTML downloaded! Open it in your browser and use Print > Save as PDF to create the PDF file.');

    } catch (error) {
        hideProgressOverlay();
        console.error('Simple PDF Export Error:', error);
        showError(`PDF Export Failed: ${error.message}`);
    }
}

console.log('✓ Clean PDF Export module loaded');
