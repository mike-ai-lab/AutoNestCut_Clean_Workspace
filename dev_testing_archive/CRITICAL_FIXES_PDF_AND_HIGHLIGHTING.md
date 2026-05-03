# CRITICAL FIXES - PDF Preview & Highlighting Issues

## Issues Fixed
1. **PDF Preview missing diagram images** - captureDiagramImages() function was called but not defined
2. **Highlighting accumulation on diagrams** - Previous highlights were not cleared before drawing new ones

## Fix 1: Add captureDiagramImages() Function

Add this function to `Extension/AutoNestCut/ui/html/main.html` (around line 6100, before the showPDFPreview function):

```javascript
// Capture diagram images from canvas elements for PDF export
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
```

## Fix 2: Clear Previous Highlights Before Drawing New Ones

In `Extension/AutoNestCut/ui/html/diagrams_report.js`, find the `handleCanvasClick` function and add highlight clearing at the start:

```javascript
function handleCanvasClick(e, canvas) {
    console.log('🖱️ Canvas clicked');
    
    // CRITICAL FIX: Clear ALL previous highlights from ALL canvases before drawing new highlight
    const allCanvases = document.querySelectorAll('canvas.diagram-canvas');
    allCanvases.forEach(c => {
        if (c.drawCanvas && typeof c.drawCanvas === 'function') {
            c.drawCanvas(); // Redraw canvas to clear any highlights
        }
    });
    
    const rect = canvas.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    // Rest of the function continues...
    if (!canvas.partData) return;
    
    for (let i = 0; i < canvas.partData.length; i++) {
        const pd = canvas.partData[i];
        if (x >= pd.x && x <= pd.x + pd.width && y >= pd.y && y <= pd.y + pd.height) {
            console.log('✅ Part clicked:', pd.part);
            
            // Highlight this part on THIS canvas
            highlightPartOnCanvas(canvas, pd);
            
            // Update current highlight tracking
            currentHighlightedPiece = pd.part;
            currentHighlightedCanvas = canvas;
            
            // Trigger 3D viewer and table highlighting
            if (typeof highlightPartIn3DViewer === 'function') {
                const partIndex = findPartIndexInAssembly(pd.part);
                if (partIndex >= 0) {
                    highlightPartIn3DViewer(partIndex);
                    highlightPartInTable(partIndex);
                }
            }
            
            break;
        }
    }
}
```

## Fix 3: Add highlightPartOnCanvas Function

Add this function to `Extension/AutoNestCut/ui/html/diagrams_report.js`:

```javascript
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
    ctx.strokeRect(partData.x, partData.y, partData.width, partData.height);
    
    // Glow effect
    ctx.shadowColor = '#00FF00';
    ctx.shadowBlur = 10;
    ctx.strokeRect(partData.x, partData.y, partData.width, partData.height);
    
    ctx.restore();
    
    console.log('✅ Highlighted part on canvas');
}
```

## Fix 4: Update Part ID Button Click Handler

Find where part ID buttons are created in the parts table and ensure they clear highlights:

```javascript
// When creating part ID buttons in the table, add this click handler:
partIdButton.addEventListener('click', function(e) {
    e.preventDefault();
    e.stopPropagation();
    
    // CRITICAL FIX: Clear all canvas highlights first
    const allCanvases = document.querySelectorAll('canvas.diagram-canvas');
    allCanvases.forEach(canvas => {
        if (canvas.drawCanvas && typeof canvas.drawCanvas === 'function') {
            canvas.drawCanvas(); // Redraw to clear highlights
        }
    });
    
    // Find the part on the correct diagram
    const boardNumber = parseInt(row.cells[4].textContent); // Sheet # column
    const targetCanvas = allCanvases[boardNumber - 1];
    
    if (targetCanvas && targetCanvas.partData) {
        // Find matching part
        const matchingPart = targetCanvas.partData.find(pd => 
            pd.part.part_unique_id === partId || 
            pd.part.instance_id === partId
        );
        
        if (matchingPart) {
            highlightPartOnCanvas(targetCanvas, matchingPart);
            
            // Scroll diagram into view
            targetCanvas.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
    }
    
    // Highlight in 3D viewer and table
    const partIndex = findPartIndexInAssembly({ part_unique_id: partId });
    if (partIndex >= 0) {
        highlightPartIn3DViewer(partIndex);
        highlightPartInTable(partIndex);
    }
});
```

## Testing Instructions

1. **Test PDF Preview with Diagrams:**
   - Generate a cut list with multiple boards
   - Click "Print to PDF" button
   - Verify that the PDF preview window shows all diagram images clearly
   - Check browser console for "📸 Captured diagram X" messages

2. **Test Highlighting Clearing:**
   - Click on a part in the 3D viewer
   - Verify it highlights in the diagram
   - Click on a different part
   - Verify the previous highlight is cleared and only the new part is highlighted
   - Click part ID buttons in the table
   - Verify highlights clear and update correctly

3. **Test Cross-Highlighting:**
   - Click a part in the diagram → should highlight in 3D viewer and table
   - Click a part in the 3D viewer → should highlight in diagram and table
   - Click a part ID button → should highlight in all three places
   - Verify no accumulation of highlights

## Implementation Priority

1. **IMMEDIATE**: Add `captureDiagramImages()` function (Fix 1)
2. **IMMEDIATE**: Add highlight clearing in `handleCanvasClick()` (Fix 2)
3. **HIGH**: Add `highlightPartOnCanvas()` function (Fix 3)
4. **MEDIUM**: Update part ID button handlers (Fix 4)

## Files to Modify

- `Extension/AutoNestCut/ui/html/main.html` - Add captureDiagramImages function
- `Extension/AutoNestCut/ui/html/diagrams_report.js` - Add highlight clearing and highlightPartOnCanvas function

## Expected Results

✅ PDF preview shows all diagram images clearly
✅ Highlighting clears previous highlights before showing new ones
✅ No accumulation of yellow/green highlights on diagrams
✅ Smooth cross-highlighting between 3D viewer, diagrams, and table
