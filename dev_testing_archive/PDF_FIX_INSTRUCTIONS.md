# PDF Diagram Images Fix - Implementation Guide

## Problem
The PDF preview window is not rendering cutting diagram images. Only assembly images are showing.

## Root Cause
The cutting diagrams are rendered as Canvas elements in JavaScript, but they're not being captured as base64 images before sending to the PDF generator.

## Solution Implemented

### 1. Added Canvas Capture Function (diagrams_report.js)
```javascript
function captureDiagramImages() {
    const diagrams = [];
    const canvases = document.querySelectorAll('.diagram-canvas');
    
    canvases.forEach((canvas, index) => {
        try {
            const dataURL = canvas.toDataURL('image/png');
            diagrams.push({
                index: index,
                image: dataURL,
                board: canvas.boardData
            });
        } catch (e) {
            console.error('Failed to capture diagram:', e);
        }
    });
    
    return diagrams;
}
```

### 2. Updated exportInteractiveHTML (diagrams_report.js)
Now captures diagram images before sending:
```javascript
const diagramImages = captureDiagramImages();
const reportDataJSON = JSON.stringify({
    diagrams: g_boardsData,
    diagram_images: diagramImages,  // NEW
    report: g_reportData,
    ...
});
```

### 3. Updated print_pdf Callback (dialog_manager.rb)
Now accepts and passes diagram images:
```ruby
diagram_images = report_data[:diagram_images] || []
html_content = generate_simple_printable_html(
  report_data[:report],
  report_data[:diagrams],
  assembly_data,
  diagram_images  # NEW parameter
)
```

### 4. Updated generate_simple_printable_html (dialog_manager.rb)
Now renders captured diagram images in the PDF HTML:
```ruby
# Embed captured diagram image if available
diagram_img = diagram_images.find { |img| img[:index] == idx || img['index'] == idx }
if diagram_img && (diagram_img[:image] || diagram_img['image'])
  image_data = diagram_img[:image] || diagram_img['image']
  html += "<img src=\"#{image_data}\" class=\"diagram-image\" alt=\"Cutting diagram for sheet #{idx + 1}\">\n"
end
```

## REMAINING TASK

### Update showPDFPreview in main.html

The showPDFPreview function (line ~1579 in main.html) needs to be updated to:
1. Call captureDiagramImages() before sending data
2. Include diagram_images in the data sent to Ruby

**Current code:**
```javascript
function showPDFPreview() {
    const reportData = currentReportData;
    const boardsData = g_boardsData || [];
    
    // ... generates HTML tables ...
    
    callRuby('print_pdf', JSON.stringify(dataToSend));
}
```

**Needs to be updated to:**
```javascript
function showPDFPreview() {
    const reportData = currentReportData;
    const boardsData = g_boardsData || [];
    
    // CAPTURE DIAGRAM IMAGES
    const diagramImages = captureDiagramImages();
    
    // ... generates HTML tables ...
    
    const dataToSend = {
        report: actualReportData,
        diagrams: boardsData,
        diagram_images: diagramImages,  // ADD THIS
        assembly_data: window.assemblyData || null
    };
    
    callRuby('print_pdf', JSON.stringify(dataToSend));
}
```

## Testing
1. Generate a cut list with multiple boards
2. Click "Export to PDF" or "Print to PDF"
3. Verify the PDF preview window shows:
   - Cutting diagram images (not just text)
   - Assembly view images
   - All tables and data

## Files Modified
- ✅ Extension/AutoNestCut/ui/html/diagrams_report.js
- ✅ Extension/AutoNestCut/ui/dialog_manager.rb
- ⏳ Extension/AutoNestCut/ui/html/main.html (NEEDS UPDATE)
