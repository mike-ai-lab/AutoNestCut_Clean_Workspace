# Canvas Resolution Fix for Diagram Scaling

## Problem
When the diagram canvases scale up with the resizer, they become blurry because HTML canvas elements have a fixed pixel resolution. CSS scaling stretches the pixels rather than redrawing at higher resolution.

## Solution: High-DPI Canvas Rendering

You need to implement these fixes in the JavaScript code that draws the diagrams:

### 1. Set Canvas Resolution Based on Device Pixel Ratio

```javascript
function setupHighDPICanvas(canvas, width, height) {
    // Get the device pixel ratio (2 for Retina displays, 1 for standard)
    const dpr = window.devicePixelRatio || 1;
    
    // Set the canvas internal resolution (actual pixels)
    canvas.width = width * dpr;
    canvas.height = height * dpr;
    
    // Set the canvas display size (CSS pixels)
    canvas.style.width = width + 'px';
    canvas.style.height = height + 'px';
    
    // Scale the drawing context to match
    const ctx = canvas.getContext('2d');
    ctx.scale(dpr, dpr);
    
    return ctx;
}
```

### 2. Redraw Canvas on Resize

Add a ResizeObserver to detect when the container size changes and redraw:

```javascript
// Store the original diagram data for redrawing
let diagramData = {};

function initializeDiagramCanvas(canvasId, data) {
    const canvas = document.getElementById(canvasId);
    const container = canvas.parentElement;
    
    // Store data for redrawing
    diagramData[canvasId] = data;
    
    // Initial draw
    drawDiagram(canvas, data);
    
    // Watch for container size changes
    const resizeObserver = new ResizeObserver(entries => {
        for (let entry of entries) {
            const width = entry.contentRect.width;
            // Redraw at new size
            drawDiagram(canvas, diagramData[canvasId], width);
        }
    });
    
    resizeObserver.observe(container);
}

function drawDiagram(canvas, data, containerWidth = null) {
    // Calculate canvas size
    const width = containerWidth || canvas.parentElement.offsetWidth;
    const height = calculateHeight(data, width); // Your logic here
    
    // Setup high-DPI canvas
    const ctx = setupHighDPICanvas(canvas, width, height);
    
    // Clear canvas
    ctx.clearRect(0, 0, width, height);
    
    // Draw your diagram here
    // ... your existing drawing code ...
}
```

### 3. Alternative: CSS Image Rendering

If you can't modify the JavaScript, add this CSS as a temporary fix:

```css
.diagram-canvas {
    image-rendering: -webkit-optimize-contrast;
    image-rendering: crisp-edges;
    image-rendering: pixelated;
}
```

**Note:** This won't be as good as redrawing at higher resolution, but it helps slightly.

### 4. Best Practice: Responsive Canvas Sizing

```javascript
function getResponsiveCanvasSize(containerWidth) {
    // Define aspect ratio
    const aspectRatio = 4 / 3; // or whatever your diagrams use
    
    // Calculate dimensions
    const width = Math.min(containerWidth - 32, 800); // Max 800px
    const height = width / aspectRatio;
    
    return { width, height };
}
```

## Implementation Steps

1. **Find the JavaScript file** that draws the diagrams (likely in `Extension/AutoNestCut/ui/html/` or embedded in an HTML file)

2. **Locate the canvas drawing code** - look for `canvas.getContext('2d')` or similar

3. **Implement the high-DPI setup** before any drawing operations

4. **Add ResizeObserver** to redraw when the container size changes

5. **Test on both standard and high-DPI displays** (Retina screens)

## Files to Check

- `Extension/AutoNestCut/ui/html/config.html` (or similar)
- Any JavaScript files in `Extension/AutoNestCut/ui/html/`
- Look for inline `<script>` tags in HTML files

## Expected Result

- Diagrams remain sharp when scaled up
- No pixelation or blurriness
- Smooth scaling in both directions
- Works on Retina/high-DPI displays
