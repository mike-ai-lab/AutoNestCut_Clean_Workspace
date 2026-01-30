/**
 * CLEAN PDF EXPORT IMPLEMENTATION
 * Fixes rasterization issue by using native PDF text vectors.
 */

async function exportToPDFClean() {
    try {
        console.log('=== CLEAN PDF EXPORT STARTED ===');
        showProgressOverlay('Generating Professional PDF...');
        
        // Ensure jsPDF is available (usually bundled with html2pdf or loaded separately)
        if (typeof jspdf === 'undefined' && typeof window.jspdf === 'undefined') {
            // Fallback: Check if html2pdf carries jspdf
            if (typeof html2pdf !== 'undefined' && html2pdf.worker) {
                 // Try to access it via internal reference if needed, or error out
            }
        }

        // Initialize PDF - Use 'p' for portrait, 'mm' for units, 'a4' for format
        const { jsPDF } = window.jspdf || window; 
        if (!jsPDF) throw new Error("jsPDF library not found. Please ensure html2pdf.bundle.min.js is loaded.");

        const pdf = new jsPDF({
            orientation: 'portrait',
            unit: 'mm',
            format: 'a4',
            compress: true
        });

        const pageWidth = pdf.internal.pageSize.getWidth();
        const pageHeight = pdf.internal.pageSize.getHeight();
        const margin = 15;
        let yPos = margin;

        // 1. TITLE PAGE (Vector Text)
        addTitlePageClean(pdf, pageWidth, pageHeight, margin);
        
        // 2. CUTTING DIAGRAMS (Images - Unavoidable for Canvas, but high res)
        pdf.addPage();
        yPos = margin;
        yPos = addCuttingDiagramsClean(pdf, pageWidth, pageHeight, margin, yPos);

        // 3. PROJECT SUMMARY (Vector Text)
        pdf.addPage();
        yPos = margin;
        addSummaryPageClean(pdf, pageWidth, pageHeight, margin, yPos);

        // 4. CUT LIST (Vector Text)
        if (g_reportData.parts_placed || g_reportData.parts) {
            pdf.addPage();
            yPos = margin;
            addCutListPageClean(pdf, pageWidth, pageHeight, margin, yPos);
        }

        // Save PDF
        const filename = `AutoNestCut_Report_${new Date().toISOString().split('T')[0]}.pdf`;
        pdf.save(filename);
        
        hideProgressOverlay();
        showSuccessMessage(`PDF exported successfully: ${filename}`);

    } catch (error) {
        hideProgressOverlay();
        console.error('PDF Export Error:', error);
        // Fallback to simple HTML export if PDF fails
        if (confirm(`PDF Generation failed: ${error.message}\n\nDo you want to download the HTML report instead?`)) {
            exportSimplePDF();
        }
    }
}

function addTitlePageClean(pdf, pageWidth, pageHeight, margin) {
    const centerX = pageWidth / 2;
    let yPos = 60;

    // Main Title
    pdf.setFont('helvetica', 'bold');
    pdf.setFontSize(26);
    pdf.setTextColor(0, 102, 204); // Blue branding
    pdf.text('Cut List & Nesting Report', centerX, yPos, { align: 'center' });

    yPos += 15;
    pdf.setFontSize(14);
    pdf.setTextColor(100, 100, 100);
    pdf.text('Professional Manufacturing Analysis', centerX, yPos, { align: 'center' });

    // Project Name
    yPos += 40;
    pdf.setFontSize(18);
    pdf.setTextColor(0, 0, 0);
    pdf.text(g_reportData.summary?.project_name || 'Untitled Project', centerX, yPos, { align: 'center' });

    // Details Block
    yPos += 40;
    pdf.setFontSize(11);
    pdf.setFont('helvetica', 'normal');
    
    const leftColX = margin + 40;
    const valueColX = margin + 90;

    const details = [
        ['Client:', g_reportData.summary?.client_name || '-'],
        ['Prepared by:', g_reportData.summary?.prepared_by || '-'],
        ['Date:', new Date().toLocaleDateString()],
        ['Time:', new Date().toLocaleTimeString()],
        ['Currency:', g_reportData.summary?.currency || 'USD']
    ];

    details.forEach(([label, value]) => {
        pdf.setFont('helvetica', 'bold');
        pdf.text(label, leftColX, yPos);
        pdf.setFont('helvetica', 'normal');
        pdf.text(String(value), valueColX, yPos);
        yPos += 10;
    });
}

function addCuttingDiagramsClean(pdf, pageWidth, pageHeight, margin, startY) {
    let yPos = startY;
    
    pdf.setFontSize(16);
    pdf.setFont('helvetica', 'bold');
    pdf.setTextColor(0, 102, 204);
    pdf.text('Cutting Diagrams', margin, yPos);
    yPos += 10;
    
    // Line separator
    pdf.setDrawColor(200, 200, 200);
    pdf.line(margin, yPos, pageWidth - margin, yPos);
    yPos += 10;

    const diagramsContainer = document.getElementById('diagramsContainer');
    if (!diagramsContainer) return yPos;

    const canvases = Array.from(diagramsContainer.querySelectorAll('canvas'));
    
    canvases.forEach((canvas, index) => {
        // Redraw to ensure fresh content
        if (canvas.drawCanvas) canvas.drawCanvas();

        const boardData = g_boardsData[index];
        const title = boardData ? `${boardData.material} - Sheet ${index + 1}` : `Sheet ${index + 1}`;

        // Check page space
        if (yPos + 100 > pageHeight - margin) {
            pdf.addPage();
            yPos = margin;
        }

        // Header
        pdf.setFontSize(12);
        pdf.setFont('helvetica', 'bold');
        pdf.setTextColor(0, 0, 0);
        pdf.text(title, margin, yPos);
        yPos += 6;

        // Info string
        if (boardData) {
            pdf.setFontSize(10);
            pdf.setFont('helvetica', 'normal');
            pdf.setTextColor(80, 80, 80);
            const eff = formatNumber(boardData.efficiency_percentage || 0, 1);
            pdf.text(`Efficiency: ${eff}% | Waste: ${formatNumber(100-eff, 1)}%`, margin, yPos);
            yPos += 8;
        }

        // Image
        try {
            const imgData = canvas.toDataURL('image/png', 1.0); // Max quality
            const imgProps = pdf.getImageProperties(imgData);
            const pdfImgWidth = pageWidth - (margin * 2);
            const pdfImgHeight = (imgProps.height * pdfImgWidth) / imgProps.width;

            // If image is too tall for remaining page, push to next page
            if (yPos + pdfImgHeight > pageHeight - margin) {
                pdf.addPage();
                yPos = margin + 10; // Margin + top padding
            }

            pdf.addImage(imgData, 'PNG', margin, yPos, pdfImgWidth, pdfImgHeight);
            yPos += pdfImgHeight + 15;
        } catch (e) {
            console.error('Canvas export error:', e);
        }
    });

    return yPos;
}

function addSummaryPageClean(pdf, pageWidth, pageHeight, margin, startY) {
    let yPos = startY;
    
    pdf.setFontSize(16);
    pdf.setFont('helvetica', 'bold');
    pdf.setTextColor(0, 102, 204);
    pdf.text('Project Summary', margin, yPos);
    yPos += 15;

    // Define table content
    const summaryData = [
        ['Metric', 'Value'],
        ['Total Parts', String(g_reportData.summary?.total_parts_instances || 0)],
        ['Total Boards', String(g_reportData.summary?.total_boards || 0)],
        ['Overall Efficiency', `${formatNumber(g_reportData.summary?.overall_efficiency || 0, 1)}%`],
        ['Total Weight', `${formatNumber(g_reportData.summary?.total_project_weight_kg || 0, 2)} kg`],
        ['Total Cost', `${g_reportData.summary?.currency || '$'} ${formatNumber(g_reportData.summary?.total_project_cost || 0, 2)}`]
    ];

    // Simple Table Renderer (Vector Text)
    drawSimpleTable(pdf, summaryData, margin, yPos, pageWidth - (margin*2));
    
    // Move down based on table size approx
    yPos += (summaryData.length * 10) + 20;

    // Materials Table
    pdf.setFontSize(16);
    pdf.setFont('helvetica', 'bold');
    pdf.setTextColor(0, 102, 204);
    pdf.text('Materials Used', margin, yPos);
    yPos += 15;

    const materialsData = [['Material', 'Sheets', 'Price/Sheet', 'Total']];
    if (g_reportData.unique_board_types) {
        g_reportData.unique_board_types.forEach(b => {
            materialsData.push([
                b.material,
                String(b.count),
                formatNumber(b.price_per_sheet, 2),
                formatNumber(b.total_cost, 2)
            ]);
        });
    }

    drawSimpleTable(pdf, materialsData, margin, yPos, pageWidth - (margin*2));
}

function addCutListPageClean(pdf, pageWidth, pageHeight, margin, startY) {
    let yPos = startY;
    pdf.setFontSize(16);
    pdf.setFont('helvetica', 'bold');
    pdf.setTextColor(0, 102, 204);
    pdf.text('Part List', margin, yPos);
    yPos += 15;

    const headers = ['Part', 'W x H (mm)', 'Mat.', 'Qty', 'Sheet'];
    const colWidths = [50, 40, 50, 20, 20]; // approx mm widths
    
    // Draw Header
    drawRow(pdf, headers, margin, yPos, colWidths, true);
    yPos += 10;

    pdf.setFont('helvetica', 'normal');
    pdf.setFontSize(10);
    pdf.setTextColor(0, 0, 0);

    const parts = g_reportData.unique_part_types || [];
    parts.forEach(part => {
        if (yPos > pageHeight - margin) {
            pdf.addPage();
            yPos = margin;
            drawRow(pdf, headers, margin, yPos, colWidths, true); // Re-draw header
            yPos += 10;
        }

        const rowData = [
            part.name,
            `${Math.round(part.width)} x ${Math.round(part.height)}`,
            part.material,
            String(part.total_quantity),
            '-'
        ];
        drawRow(pdf, rowData, margin, yPos, colWidths, false);
        yPos += 8;
    });
}

// Helper to draw a row of text vectors
function drawRow(pdf, cells, x, y, widths, isHeader) {
    let currentX = x;
    if (isHeader) {
        pdf.setFont('helvetica', 'bold');
        pdf.setFillColor(240, 240, 240);
        pdf.rect(x, y - 6, widths.reduce((a,b)=>a+b,0), 10, 'F');
        pdf.setTextColor(0,0,0);
    } else {
        pdf.setFont('helvetica', 'normal');
    }

    cells.forEach((cell, i) => {
        pdf.text(String(cell).substring(0, 25), currentX + 2, y); // Clip long text
        currentX += widths[i] || 30;
    });
}

function drawSimpleTable(pdf, data, x, y, width) {
    const rowHeight = 10;
    const colWidth = width / data[0].length;
    
    data.forEach((row, i) => {
        const isHeader = i === 0;
        if (isHeader) {
            pdf.setFont('helvetica', 'bold');
            pdf.setFillColor(240, 240, 240);
            pdf.rect(x, y - 6, width, rowHeight, 'F');
        } else {
            pdf.setFont('helvetica', 'normal');
        }
        
        row.forEach((cell, j) => {
            pdf.text(String(cell), x + (j * colWidth) + 2, y);
        });
        
        // Horizontal line
        pdf.setDrawColor(220);
        pdf.line(x, y + 2, x + width, y + 2);
        
        y += rowHeight;
    });
}