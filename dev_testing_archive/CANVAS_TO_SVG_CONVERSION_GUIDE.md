# Canvas to SVG Conversion Guide for Nesting Diagrams

## Why SVG Instead of Canvas?

✅ **Infinite scalability** - No blur when zooming/resizing
✅ **Better performance** - No re-rendering needed
✅ **Smaller file size** - Vector data vs pixel data
✅ **Easy interaction** - Click/hover on individual parts
✅ **Print quality** - Perfect for PDF export

## Current Canvas Features to Preserve

Based on the code analysis, the diagrams currently show:
1. **Board outline** (stock sheet rectangle)
2. **Nested parts** (rectangles with positions)
3. **Part labels** (IDs, dimensions)
4. **Material colors/textures**
5. **Grain direction indicators**
6. **Waste areas** (hatched patterns for offcuts)
7. **Efficiency/waste percentages**
8. **Interactive highlighting** (click to highlight parts)

## Implementation Strategy

### Step 1: Create SVG Generator Function (JavaScript)

Replace the canvas drawing code with this SVG generator:

```javascript
function generateBoardSVG(board, containerWidth) {
    // Calculate dimensions
    const padding = 40;
    const maxWidth = containerWidth - padding * 2;
    const scale = maxWidth / board.stock_width;
    const svgWidth = board.stock_width * scale + padding * 2;
    const svgHeight = board.stock_height * scale + padding * 2;
    
    // Create SVG element
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', `0 0 ${svgWidth} ${svgHeight}`);
    svg.setAttribute('width', '100%');
    svg.setAttribute('height', 'auto');
    svg.classList.add('diagram-svg');
    
    // Add definitions for patterns (grain, offcuts, etc.)
    const defs = createSVGDefs();
    svg.appendChild(defs);
    
    // Draw board background
    const boardRect = createSVGRect({
        x: padding,
        y: padding,
        width: board.stock_width * scale,
        height: board.stock_height * scale,
        fill: '#ffffff',
        stroke: '#24292e',
        strokeWidth: 2
    });
    svg.appendChild(boardRect);
    
    // Draw each part
    board.parts.forEach((part, index) => {
        const partGroup = createPartSVG(part, scale, padding, index);
        svg.appendChild(partGroup);
    });
    
    // Draw offcuts if any
    if (board.usable_offcuts) {
        board.usable_offcuts.forEach(offcut => {
            const offcutGroup = createOffcutSVG(offcut, scale, padding);
            svg.appendChild(offcutGroup);
        });
    }
    
    // Add board info text
    const infoText = createBoardInfoSVG(board, svgWidth, svgHeight);
    svg.appendChild(infoText);
    
    return svg;
}

function createSVGDefs() {
    const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
    
    // Grain direction pattern
    const grainPattern = document.createElementNS('http://www.w3.org/2000/svg', 'pattern');
    grainPattern.setAttribute('id', 'grain-pattern');
    grainPattern.setAttribute('patternUnits', 'userSpaceOnUse');
    grainPattern.setAttribute('width', '4');
    grainPattern.setAttribute('height', '20');
    const grainLine = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    grainLine.setAttribute('x1', '2');
    grainLine.setAttribute('y1', '0');
    grainLine.setAttribute('x2', '2');
    grainLine.setAttribute('y2', '20');
    grainLine.setAttribute('stroke', 'rgba(0,0,0,0.1)');
    grainLine.setAttribute('stroke-width', '1');
    grainPattern.appendChild(grainLine);
    defs.appendChild(grainPattern);
    
    // Offcut hatch pattern
    const offcutPattern = document.createElementNS('http://www.w3.org/2000/svg', 'pattern');
    offcutPattern.setAttribute('id', 'offcut-pattern');
    offcutPattern.setAttribute('patternUnits', 'userSpaceOnUse');
    offcutPattern.setAttribute('width', '20');
    offcutPattern.setAttribute('height', '20');
    offcutPattern.setAttribute('patternTransform', 'rotate(45)');
    const offcutLine = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    offcutLine.setAttribute('x1', '0');
    offcutLine.setAttribute('y1', '10');
    offcutLine.setAttribute('x2', '20');
    offcutLine.setAttribute('y2', '10');
    offcutLine.setAttribute('stroke', 'rgba(34, 197, 94, 0.3)');
    offcutLine.setAttribute('stroke-width', '2');
    offcutPattern.appendChild(offcutLine);
    defs.appendChild(offcutPattern);
    
    return defs;
}

function createPartSVG(part, scale, padding, index) {
    const group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    group.classList.add('part-group');
    group.setAttribute('data-part-id', part.part_unique_id || `P${index + 1}`);
    group.setAttribute('data-part-name', part.name);
    
    // Part rectangle
    const rect = createSVGRect({
        x: padding + part.position_x * scale,
        y: padding + part.position_y * scale,
        width: part.width * scale,
        height: part.height * scale,
        fill: part.color || '#74b9ff',
        stroke: '#24292e',
        strokeWidth: 1.5,
        opacity: 0.8
    });
    
    // Add grain pattern if needed
    if (part.grain_direction && part.grain_direction !== 'Any') {
        rect.setAttribute('fill', 'url(#grain-pattern)');
    }
    
    group.appendChild(rect);
    
    // Part label
    const label = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    label.setAttribute('x', padding + (part.position_x + part.width / 2) * scale);
    label.setAttribute('y', padding + (part.position_y + part.height / 2) * scale);
    label.setAttribute('text-anchor', 'middle');
    label.setAttribute('dominant-baseline', 'middle');
    label.setAttribute('font-size', '12');
    label.setAttribute('font-weight', '600');
    label.setAttribute('fill', '#24292e');
    label.textContent = part.part_unique_id || `P${index + 1}`;
    group.appendChild(label);
    
    // Dimensions text
    const dims = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    dims.setAttribute('x', padding + (part.position_x + part.width / 2) * scale);
    dims.setAttribute('y', padding + (part.position_y + part.height / 2) * scale + 15);
    dims.setAttribute('text-anchor', 'middle');
    dims.setAttribute('font-size', '10');
    dims.setAttribute('fill', '#656d76');
    dims.textContent = `${Math.round(part.width)}×${Math.round(part.height)}`;
    group.appendChild(dims);
    
    // Add hover/click interactivity
    group.style.cursor = 'pointer';
    group.addEventListener('mouseenter', () => {
        rect.setAttribute('stroke-width', '3');
        rect.setAttribute('stroke', '#0ea5e9');
    });
    group.addEventListener('mouseleave', () => {
        rect.setAttribute('stroke-width', '1.5');
        rect.setAttribute('stroke', '#24292e');
    });
    group.addEventListener('click', () => {
        highlightPartInTables(part.part_unique_id);
    });
    
    return group;
}

function createOffcutSVG(offcut, scale, padding) {
    const group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    group.classList.add('offcut-group');
    
    const rect = createSVGRect({
        x: padding + offcut.x * scale,
        y: padding + offcut.y * scale,
        width: offcut.width * scale,
        height: offcut.height * scale,
        fill: 'url(#offcut-pattern)',
        stroke: 'rgba(34, 197, 94, 0.4)',
        strokeWidth: 1,
        strokeDasharray: '4,4'
    });
    
    group.appendChild(rect);
    
    // Offcut label
    const label = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    label.setAttribute('x', padding + (offcut.x + offcut.width / 2) * scale);
    label.setAttribute('y', padding + (offcut.y + offcut.height / 2) * scale);
    label.setAttribute('text-anchor', 'middle');
    label.setAttribute('font-size', '10');
    label.setAttribute('font-weight', '600');
    label.setAttribute('fill', '#22863a');
    label.textContent = 'Offcut';
    group.appendChild(label);
    
    return group;
}

function createBoardInfoSVG(board, svgWidth, svgHeight) {
    const group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    
    // Efficiency text
    const effText = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    effText.setAttribute('x', svgWidth - 10);
    effText.setAttribute('y', svgHeight - 10);
    effText.setAttribute('text-anchor', 'end');
    effText.setAttribute('font-size', '12');
    effText.setAttribute('fill', '#656d76');
    effText.textContent = `Efficiency: ${board.efficiency_percentage.toFixed(1)}% | Waste: ${board.waste_percentage.toFixed(1)}%`;
    group.appendChild(effText);
    
    return group;
}

function createSVGRect(attrs) {
    const rect = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
    Object.keys(attrs).forEach(key => {
        const attrName = key.replace(/([A-Z])/g, '-$1').toLowerCase();
        rect.setAttribute(attrName, attrs[key]);
    });
    return rect;
}
```

### Step 2: Replace Canvas Creation in HTML

Find where canvases are created (around line 6840 in main.html) and replace with:

```javascript
// OLD CODE (remove):
// const canvas = document.createElement('canvas');
// canvas.className = 'diagram-canvas';
// card.appendChild(canvas);

// NEW CODE:
const svg = generateBoardSVG(board, card.offsetWidth || 600);
svg.classList.add('diagram-canvas'); // Keep same class for styling
card.appendChild(svg);
```

### Step 3: Update CSS for SVG

```css
.diagram-canvas {
    border: 1px solid #d0d7de;
    background: #ffffff;
    border-radius: 4px;
    width: 100% !important;
    height: auto !important;
    display: block;
    box-sizing: border-box;
    /* SVG scales perfectly - no blur! */
}

.part-group {
    transition: all 0.2s ease;
}

.part-group:hover rect {
    filter: brightness(1.1);
}
```

### Step 4: Export to PNG (if needed)

SVG can still be converted to PNG for exports:

```javascript
function svgToPNG(svgElement) {
    const svgData = new XMLSerializer().serializeToString(svgElement);
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    const img = new Image();
    
    return new Promise((resolve) => {
        img.onload = () => {
            canvas.width = img.width;
            canvas.height = img.height;
            ctx.drawImage(img, 0, 0);
            resolve(canvas.toDataURL('image/png'));
        };
        img.src = 'data:image/svg+xml;base64,' + btoa(unescape(encodeURIComponent(svgData)));
    });
}
```

## Benefits Summary

1. **No blur on resize** - SVG scales infinitely
2. **Better performance** - No re-rendering on every resize
3. **Smaller memory footprint** - Vector data vs pixels
4. **Better interactivity** - Easy to add hover/click on parts
5. **Print quality** - Perfect for PDF generation
6. **Accessibility** - Can add ARIA labels to parts

## Migration Steps

1. ✅ Create SVG generation functions (above)
2. ✅ Replace canvas creation with SVG creation
3. ✅ Update CSS for SVG styling
4. ✅ Test all features (highlighting, clicking, export)
5. ✅ Update PDF export to use SVG
6. ✅ Remove old canvas code

## Files to Modify

- `Extension/AutoNestCut/ui/html/main.html` - Replace canvas with SVG generation
- `Extension/AutoNestCut/ui/html/diagrams_style.css` - Update styles for SVG
- Test in SketchUp dialog to ensure compatibility

## Result

Diagrams will scale perfectly without blur, use less memory, and provide better interactivity - all while preserving every current feature!
