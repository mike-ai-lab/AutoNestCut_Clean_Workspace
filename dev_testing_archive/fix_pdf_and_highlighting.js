// ============================================================================
// CRITICAL FIXES FOR PDF PREVIEW AND HIGHLIGHTING
// Add these functions to Extension/AutoNestCut/ui/html/main.html
// Insert around line 6100, before showPDFPreview function
// ============================================================================

// FIX 1: Capture diagram images from canvas elements for PDF export
function captureDiagramImages() {
    console.log('📸 Capturing diagram images for PDF...');
    const diagramImages = [];
    const diagramsContainer = document.getElementById('diagramsContainer');
    
    if (!diagramsContainer) {
        console.warn('⚠️ Diagrams container not found');
        return diagramImages;
    }
    
    const canvases = diagramsContainer.querySelectorAll('canvas.diagram-canvas');
    console.log(`📊 Found ${canvases.length} diagram canvases`);
    
    canvases.forEach((canvas, index) => {
        try {
            // Temporarily increase quality for PDF capture
            const originalCapturingFlag = window.capturingForPDF;
            window.capturingForPDF = true;
            
            // Redraw canvas at high quality if drawCanvas method exists
            if (typeof canvas.drawCanvas === 'function') {
                canvas.drawCanvas();
            }
            
            // Capture as high-quality PNG
            const imageData = canvas.toDataURL('image/png', 1.0);
            
            // Restore original flag
            window.capturingForPDF = originalCapturingFlag;
            
            diagramImages.push({
                index: index,
                image: imageData
            });
            
            console.log(`✅ Captured diagram ${index + 1}: ${imageData.length} bytes`);
        } catch (error) {
            console.error(`❌ Failed to capture diagram ${index}:`, error);
        }
    });
    
    console.log(`📸 Total diagrams captured: ${diagramImages.length}`);
    return diagramImages;
}

// ============================================================================
// Add these functions to Extension/AutoNestCut/ui/html/diagrams_report.js
// ============================================================================

// FIX 2: Highlight a specific part on a canvas with proper clearing
function highlightPartOnCanvas(canvas, partData) {
    if (!canvas || !partData) return;
    
    const ctx = canvas.getContext('2d');
    
    // Draw highlight overlay on the specific part
    ctx.save();
    
    // Semi-transparent yellow highlight
    ctx.fillStyle = 'rgba(255, 235, 59, 0.4)';
    ctx.fillRect(partData.x, partData.y, partData.width, partData.height);
    
    // Thick green border
    ctx.strokeStyle = '#00FF00';
    ctx.lineWidth = 4;
    ctx.strokeRect(partData.x, partData.y, 