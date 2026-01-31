// ============================================================================
// UNIT SYSTEM DEBUG LOGGER
// Add this script to main.html to debug unit usage across the extension
// ============================================================================

(function() {
    'use strict';
    
    // Debug function
    window.debugUnitSystem = function(section, data = {}) {
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
        
        // Check for hardcoded "mm" strings
        if (data.htmlContent) {
            const mmMatches = data.htmlContent.match(/\bmm\b/g);
            if (mmMatches && mmMatches.length > 0) {
                console.warn(`⚠️ [HARDCODED MM] ${section}: Found ${mmMatches.length} hardcoded "mm" references`);
            }
        }
    };
    
    // Monitor all table renders
    const originalCreateElement = document.createElement;
    let tableCount = 0;
    
    // Log initial settings
    console.log('═══════════════════════════════════════════════════════════');
    console.log('🔧 UNIT SYSTEM DEBUG MODE ENABLED');
    console.log('═══════════════════════════════════════════════════════════');
    console.log('Current Settings:');
    console.log('  Units:', window.currentUnits || 'NOT SET');
    console.log('  Precision:', window.currentPrecision ?? 'NOT SET');
    console.log('  Area Units:', window.currentAreaUnits || 'NOT SET');
    console.log('  Currency:', window.defaultCurrency || 'NOT SET');
    console.log('═══════════════════════════════════════════════════════════\n');
    
    // Hook into renderReport to debug
    const originalRenderReport = window.renderReport;
    if (originalRenderReport) {
        window.renderReport = function(reportData) {
            console.log('\n📊 [RENDER REPORT] Starting...');
            window.debugUnitSystem('Report Render Start', {
                hasSummary: !!reportData?.summary,
                hasUniqueParts: !!reportData?.unique_part_types,
                hasBoardTypes: !!reportData?.unique_board_types
            });
            return originalRenderReport.apply(this, arguments);
        };
    }
    
    // Hook into renderDiagrams to debug
    const originalRenderDiagrams = window.renderDiagrams;
    if (originalRenderDiagrams) {
        window.renderDiagrams = function(diagrams) {
            console.log('\n📐 [RENDER DIAGRAMS] Starting...');
            window.debugUnitSystem('Diagrams Render Start', {
                diagramCount: diagrams?.length || 0
            });
            
            // Check each diagram for unit usage
            if (diagrams && diagrams.length > 0) {
                diagrams.forEach((board, idx) => {
                    window.debugUnitSystem(`Diagram ${idx + 1}`, {
                        material: board.material,
                        stock_width: board.stock_width,
                        stock_height: board.stock_height,
                        thickness: board.thickness,
                        parts_count: board.parts_count
                    });
                });
            }
            
            return originalRenderDiagrams.apply(this, arguments);
        };
    }
    
    // Monitor DOM mutations for hardcoded "mm"
    const observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            mutation.addedNodes.forEach(function(node) {
                if (node.nodeType === 1) { // Element node
                    const text = node.textContent || '';
                    const html = node.innerHTML || '';
                    
                    // Check for hardcoded "mm" that's not part of a unit conversion
                    const mmPattern = /(\d+\.?\d*)\s*mm(?!\s*[×x])/gi;
                    const matches = text.match(mmPattern);
                    
                    if (matches && matches.length > 0 && window.currentUnits !== 'mm') {
                        console.warn(`⚠️ [HARDCODED MM DETECTED]`, {
                            element: node.tagName,
                            className: node.className,
                            matches: matches,
                            expectedUnit: window.currentUnits,
                            sample: text.substring(0, 100)
                        });
                    }
                }
            });
        });
    });
    
    // Start observing
    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
    
    console.log('✅ Unit debug monitoring active\n');
    
})();
