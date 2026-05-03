// Export validation functionality to ensure PDF and HTML exports contain complete data

function validateExports() {
    console.log('Validating export completeness...');
    
    if (!currentReportData || !g_reportData) {
        console.warn('No report data available for validation');
        return false;
    }
    
    const validationResults = {
        ui_tables: validateUITables(),
        data_completeness: validateDataCompleteness(),
        column_consistency: validateColumnConsistency()
    };
    
    console.log('Validation results:', validationResults);
    return validationResults;
}

function validateUITables() {
    const expectedTables = [
        'summaryTable',
        'materialsUsedTable', 
        'uniquePartTypesTable',
        'sheetInventoryTable',
        'partsTable',
        'offcutsTable'
    ];
    
    const results = {};
    
    expectedTables.forEach(tableId => {
        const table = document.getElementById(tableId);
        if (table) {
            const rows = table.querySelectorAll('tbody tr');
            results[tableId] = {
                exists: true,
                hasData: rows.length > 0,
                rowCount: rows.length,
                columns: table.querySelectorAll('thead th').length
            };
        } else {
            results[tableId] = {
                exists: false,
                hasData: false,
                rowCount: 0,
                columns: 0
            };
        }
    });
    
    return results;
}

function validateDataCompleteness() {
    const reportData = g_reportData;
    const results = {};
    
    // Check summary data
    results.summary = {
        hasProjectInfo: !!(reportData.summary?.project_name || reportData.summary?.client_name),
        hasCostInfo: !!(reportData.summary?.total_project_cost),
        hasEfficiencyInfo: !!(reportData.summary?.overall_efficiency)
    };
    
    // Check parts data
    results.parts = {
        hasUniqueTypes: !!(reportData.unique_part_types?.length),
        hasPlacedParts: !!(reportData.parts_placed?.length),
        uniqueTypesCount: reportData.unique_part_types?.length || 0,
        placedPartsCount: reportData.parts_placed?.length || 0
    };
    
    // Check boards data
    results.boards = {
        hasBoardTypes: !!(reportData.unique_board_types?.length),
        boardTypesCount: reportData.unique_board_types?.length || 0,
        hasDiagrams: !!(g_boardsData?.length),
        diagramsCount: g_boardsData?.length || 0
    };
    
    // Check additional data
    results.additional = {
        hasCutSequences: !!(reportData.cut_sequences?.length),
        hasOffcuts: !!(reportData.usable_offcuts?.length),
        cutSequencesCount: reportData.cut_sequences?.length || 0,
        offcutsCount: reportData.usable_offcuts?.length || 0
    };
    
    return results;
}

function validateColumnConsistency() {
    const results = {};
    
    // Define expected column structures for each table
    const expectedColumns = {
        summaryTable: ['Metric', 'Value'],
        materialsUsedTable: ['Material', 'Price per Sheet'],
        uniquePartTypesTable: ['Name', 'W', 'H', 'Thick', 'Material', 'Grain', 'Edge Banding', 'Total Qty', 'Total Area'],
        sheetInventoryTable: ['Material', 'Dimensions', 'Count', 'Total Area', 'Price/Sheet', 'Total Cost'],
        partsTable: ['ID', 'Name', 'Dimensions', 'Material', 'Grain', 'Edge Banding', 'Board#', 'Cost', 'Level'],
        offcutsTable: ['Sheet #', 'Material', 'Estimated Size', 'Area (m²)']
    };
    
    Object.keys(expectedColumns).forEach(tableId => {
        const table = document.getElementById(tableId);
        if (table) {
            const headers = Array.from(table.querySelectorAll('thead th')).map(th => th.textContent.trim());
            const expected = expectedColumns[tableId];
            
            results[tableId] = {
                actualColumns: headers,
                expectedColumns: expected,
                hasAllColumns: expected.every(col => headers.some(h => h.includes(col.split(' ')[0]))),
                extraColumns: headers.filter(h => !expected.some(e => h.includes(e.split(' ')[0]))),
                missingColumns: expected.filter(e => !headers.some(h => h.includes(e.split(' ')[0])))
            };
        } else {
            results[tableId] = {
                actualColumns: [],
                expectedColumns: expectedColumns[tableId],
                hasAllColumns: false,
                extraColumns: [],
                missingColumns: expectedColumns[tableId]
            };
        }
    });
    
    return results;
}

function generateValidationReport() {
    const validation = validateExports();
    
    let report = '# Export Validation Report\\n\\n';
    report += `Generated: ${new Date().toLocaleString()}\\n\\n`;
    
    // UI Tables Status
    report += '## UI Tables Status\\n\\n';
    Object.keys(validation.ui_tables).forEach(tableId => {
        const table = validation.ui_tables[tableId];
        const status = table.exists && table.hasData ? '✅' : '❌';
        report += `${status} **${tableId}**: ${table.exists ? 'Exists' : 'Missing'}, ${table.rowCount} rows, ${table.columns} columns\\n`;
    });
    
    // Data Completeness
    report += '\\n## Data Completeness\\n\\n';
    report += `- Summary: ${validation.data_completeness.summary.hasProjectInfo ? '✅' : '❌'} Project Info, ${validation.data_completeness.summary.hasCostInfo ? '✅' : '❌'} Cost Info\\n`;
    report += `- Parts: ${validation.data_completeness.parts.uniqueTypesCount} unique types, ${validation.data_completeness.parts.placedPartsCount} placed parts\\n`;
    report += `- Boards: ${validation.data_completeness.boards.boardTypesCount} board types, ${validation.data_completeness.boards.diagramsCount} diagrams\\n`;
    report += `- Additional: ${validation.data_completeness.additional.cutSequencesCount} cut sequences, ${validation.data_completeness.additional.offcutsCount} offcuts\\n`;
    
    // Column Consistency
    report += '\\n## Column Consistency Issues\\n\\n';
    Object.keys(validation.column_consistency).forEach(tableId => {
        const table = validation.column_consistency[tableId];
        if (!table.hasAllColumns || table.extraColumns.length > 0) {
            report += `**${tableId}**:\\n`;
            if (table.missingColumns.length > 0) {
                report += `  - Missing: ${table.missingColumns.join(', ')}\\n`;
            }
            if (table.extraColumns.length > 0) {
                report += `  - Extra: ${table.extraColumns.join(', ')}\\n`;
            }
        }
    });
    
    return report;
}

function fixExportInconsistencies() {
    console.log('Attempting to fix export inconsistencies...');
    
    const validation = validateExports();
    let fixesApplied = 0;
    
    // Fix missing tables by re-rendering
    Object.keys(validation.ui_tables).forEach(tableId => {
        const table = validation.ui_tables[tableId];
        if (!table.exists || !table.hasData) {
            console.log(`Attempting to fix missing/empty table: ${tableId}`);
            
            // Try to re-render the specific table
            switch(tableId) {
                case 'summaryTable':
                    if (g_reportData?.summary) {
                        renderSummaryTable();
                        fixesApplied++;
                    }
                    break;
                case 'uniquePartTypesTable':
                    if (g_reportData?.unique_part_types) {
                        renderUniquePartTypesTable();
                        fixesApplied++;
                    }
                    break;
                case 'sheetInventoryTable':
                    if (g_reportData?.unique_board_types) {
                        renderSheetInventoryTable();
                        fixesApplied++;
                    }
                    break;
                case 'partsTable':
                    if (g_reportData?.parts_placed) {
                        renderPartsTable();
                        fixesApplied++;
                    }
                    break;
                case 'offcutsTable':
                    if (g_reportData?.usable_offcuts) {
                        renderOffcutsTable(g_reportData);
                        fixesApplied++;
                    }
                    break;
            }
        }
    });
    
    // Re-initialize table customization after fixes
    if (fixesApplied > 0) {
        setTimeout(() => {
            if (typeof reinitializeTableCustomization === 'function') {
                reinitializeTableCustomization();
            }
        }, 100);
    }
    
    console.log(`Applied ${fixesApplied} fixes to export inconsistencies`);
    return fixesApplied;
}

// Helper functions for individual table rendering
function renderSummaryTable() {
    const table = document.getElementById('summaryTable');
    if (table && g_reportData?.summary) {
        table.innerHTML = generateSummaryTableHTML(g_reportData);
    }
}

function renderUniquePartTypesTable() {
    const table = document.getElementById('uniquePartTypesTable');
    if (table && g_reportData?.unique_part_types) {
        table.innerHTML = generateUniquePartsTableHTML(g_reportData);
    }
}

function renderSheetInventoryTable() {
    const table = document.getElementById('sheetInventoryTable');
    if (table && g_reportData?.unique_board_types) {
        const reportUnits = window.currentUnits || 'mm';
        const reportPrecision = window.currentPrecision ?? 1;
        const currentAreaUnitLabel = getAreaUnitLabel();
        const currency = g_reportData.summary?.currency || window.defaultCurrency || 'USD';
        
        let html = `<thead><tr><th>Material</th><th>Dimensions (${reportUnits})</th><th>Count</th><th>Total Area (${currentAreaUnitLabel})</th><th>Price/Sheet</th><th>Total Cost</th></tr></thead><tbody>`;
        
        g_reportData.unique_board_types.forEach(board_type => {
            const boardCurrency = board_type.currency || currency;
            const boardSymbol = window.currencySymbols[boardCurrency] || boardCurrency;
            const width = (board_type.stock_width || 0) / window.unitFactors[reportUnits];
            const height = (board_type.stock_height || 0) / window.unitFactors[reportUnits];
            const dimensionsStr = `${formatNumber(width, reportPrecision)} × ${formatNumber(height, reportPrecision)}`;
            
            html += `<tr>
                <td title="${escapeHtml(board_type.material)}">${escapeHtml(board_type.material)}</td>
                <td>${dimensionsStr}</td>
                <td class="total-highlight">${board_type.count}</td>
                <td style="text-align:right;">${getAreaDisplay(board_type.total_area)}</td>
                <td>${boardSymbol}${formatNumber(board_type.price_per_sheet || 0, 2)}</td>
                <td class="total-highlight">${boardSymbol}${formatNumber(board_type.total_cost || 0, 2)}</td>
            </tr>`;
        });
        
        html += '</tbody>';
        table.innerHTML = html;
    }
}

function renderPartsTable() {
    const table = document.getElementById('partsTable');
    if (table && g_reportData?.parts_placed) {
        // Use the existing parts table rendering logic from diagrams_report.js
        // This ensures consistency with the main rendering
        if (typeof renderReport === 'function') {
            renderReport();
        }
    }
}

// Export validation functions globally
window.validateExports = validateExports;
window.generateValidationReport = generateValidationReport;
window.fixExportInconsistencies = fixExportInconsistencies;