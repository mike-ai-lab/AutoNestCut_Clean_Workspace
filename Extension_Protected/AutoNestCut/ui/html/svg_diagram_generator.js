/**
 * SVG Diagram Generator for AutoNestCut
 * Exactly replicates canvas-based diagram rendering in scalable SVG format
 * No blur on resize, infinite scalability, perfect print quality
 */

// Main function to generate SVG diagram for a board
function generateBoardSVG(board, containerWidth, reportUnits, reportPrecision) {
    try {
        // Validate input data
        if (!board || !board.stock_width || !board.stock_height) {
            console.error('Invalid board data:', board);
            return null;
        }
        
        // Safety checks for browser context
        if (typeof document === 'undefined' || typeof window === 'undefined') {
            console.error('SVG generation requires browser context');
            return null;
        }
        
        const padding = 40;
        const maxCanvasDim = Math.min(containerWidth - 24, 600);
        const boardWidth = parseFloat(board.stock_width) || 1000;
        const boardHeight = parseFloat(board.stock_height) || 1000;
        
        const scale = Math.min(
            (maxCanvasDim - 2 * padding) / boardWidth,
            (maxCanvasDim - 2 * padding) / boardHeight
        );
        
        // Add extra space at bottom for sheet grain arrow (100px should be enough)
        const bottomMargin = 100;
        const svgWidth = boardWidth * scale + 2 * padding;
        const svgHeight = boardHeight * scale + 2 * padding + bottomMargin;
        
        // Create SVG element
        const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        svg.setAttribute('viewBox', `0 0 ${svgWidth} ${svgHeight}`);
        svg.setAttribute('width', '100%');
        svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
        svg.classList.add('diagram-canvas');
        
        // Add definitions for grain patterns
        const defs = createSVGDefs();
        svg.appendChild(defs);
        
        // Draw board background (light grey like canvas)
        const boardBg = createSVGElement('rect', {
            x: padding,
            y: padding,
            width: boardWidth * scale,
            height: boardHeight * scale,
            fill: '#fafafa'
        });
        svg.appendChild(boardBg);
        
        // Draw board outline
        const boardRect = createSVGElement('rect', {
            x: padding,
            y: padding,
            width: boardWidth * scale,
            height: boardHeight * scale,
            fill: 'none',
            stroke: '#333',
            'stroke-width': 2.5
        });
        svg.appendChild(boardRect);
        
        // Draw board dimensions (top and left labels)
        const displayWidth = boardWidth / (window.unitFactors?.[reportUnits] || 1);
        const displayHeight = boardHeight / (window.unitFactors?.[reportUnits] || 1);
        
        // Use global formatNumber function from diagrams_report.js
        const formatNum = window.formatNumber || function(val, prec) { return val.toFixed(prec || 1); };
        
        // Top dimension label
        const topLabel = createSVGElement('text', {
            x: padding + (boardWidth * scale) / 2,
            y: padding - 8,
            'text-anchor': 'middle',
            'font-family': "'Inter', -apple-system, sans-serif",
            'font-size': Math.max(13, 15 * scale),
            'font-weight': '600',
            fill: '#1a1a1a'
        });
        topLabel.textContent = `${formatNum(displayWidth, reportPrecision)}${reportUnits}`;
        svg.appendChild(topLabel);
        
        // Left dimension label (rotated)
        const leftLabel = createSVGElement('text', {
            x: padding - 18,
            y: padding + (boardHeight * scale) / 2,
            'text-anchor': 'middle',
            'font-family': "'Inter', -apple-system, sans-serif",
            'font-size': Math.max(13, 15 * scale),
            'font-weight': '600',
            fill: '#1a1a1a',
            transform: `rotate(-90, ${padding - 18}, ${padding + (boardHeight * scale) / 2})`
        });
        leftLabel.textContent = `${formatNum(displayHeight, reportPrecision)}${reportUnits}`;
        svg.appendChild(leftLabel);
        
        // Draw offcuts FIRST (so they appear behind parts)
        const offcuts = board.offcuts || [];
        if (offcuts && offcuts.length > 0) {
            offcuts.forEach((offcut) => {
                try {
                    const offcutGroup = createOffcutSVG(offcut, scale, padding);
                    if (offcutGroup) {
                        svg.appendChild(offcutGroup);
                    }
                } catch (offcutError) {
                    console.error('Error creating offcut:', offcutError);
                }
            });
        }
        
        // Draw parts
        const parts = board.parts || [];
        let sheetGrainDirection = null;
        if (parts && Array.isArray(parts)) {
            parts.forEach((part, partIndex) => {
                try {
                    const partGroup = createPartSVG(part, scale, padding, partIndex, reportUnits, reportPrecision);
                    if (partGroup) {
                        svg.appendChild(partGroup);
                    }
                    // Capture grain direction from first part (all parts have same grain now)
                    if (partIndex === 0 && part.grain_direction && part.grain_direction !== 'Any') {
                        sheetGrainDirection = part.grain_direction;
                    }
                } catch (partError) {
                    console.error('Error creating part:', partError);
                }
            });
        }
        
        // Add sheet-level grain arrow below the board
        if (sheetGrainDirection) {
            const sheetArrowGroup = createSheetGrainArrow(
                padding,
                padding + boardHeight * scale,
                boardWidth * scale,
                sheetGrainDirection
            );
            if (sheetArrowGroup) {
                svg.appendChild(sheetArrowGroup);
            }
        }
        
        return svg;
        
    } catch (error) {
        console.error('Error generating SVG diagram:', error);
        console.error('Error stack:', error.stack);
        return null;
    }
}

// Create SVG pattern definitions for grain patterns
function createSVGDefs() {
    const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
    
    // Vertical grain pattern (for length grain direction)
    const grainPatternV = createSVGElement('pattern', {
        id: 'grain-pattern-vertical',
        patternUnits: 'userSpaceOnUse',
        width: 8,
        height: 8
    });
    const grainLineV = createSVGElement('line', {
        x1: 0, y1: 0, x2: 0, y2: 8,
        stroke: '#6b4423',
        'stroke-width': 0.8,
        opacity: 0.25
    });
    grainPatternV.appendChild(grainLineV);
    defs.appendChild(grainPatternV);
    
    // Horizontal grain pattern (for width grain direction)
    const grainPatternH = createSVGElement('pattern', {
        id: 'grain-pattern-horizontal',
        patternUnits: 'userSpaceOnUse',
        width: 8,
        height: 8
    });
    const grainLineH = createSVGElement('line', {
        x1: 0, y1: 0, x2: 8, y2: 0,
        stroke: '#6b4423',
        'stroke-width': 0.8,
        opacity: 0.25
    });
    grainPatternH.appendChild(grainLineH);
    defs.appendChild(grainPatternH);
    
    return defs;
}

// Create SVG group for a part - exactly replicates canvas rendering
function createPartSVG(part, scale, padding, partIndex, reportUnits, reportPrecision) {
    // Validate part data
    const partPosX = parseFloat(part.x) || 0;
    const partPosY = parseFloat(part.y) || 0;
    const partW = parseFloat(part.width) || 10;
    const partH = parseFloat(part.height) || 10;
    
    const partX = padding + partPosX * scale;
    const partY = padding + partPosY * scale;
    const partWidth = partW * scale;
    const partHeight = partH * scale;
    
    // Use global formatNumber function from diagrams_report.js
    const formatNum = window.formatNumber || function(val, prec) { return val.toFixed(prec || 1); };
    
    const group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    group.classList.add('part-group');
    
    // CRITICAL: Store unique_id as data attribute for 3D viewer → SVG highlighting
    if (part.unique_id) {
        group.setAttribute('data-unique-id', part.unique_id);
    }
    
    // Draw part with grain pattern (exactly like canvas drawPartWithGrain)
    const baseColor = getMaterialColor(part.material);
    const partRect = createSVGElement('rect', {
        x: partX,
        y: partY,
        width: partWidth,
        height: partHeight,
        fill: baseColor
    });
    group.appendChild(partRect);
    
    // Add grain pattern overlay if grain direction is specified
    if (part.grain_direction && part.grain_direction !== 'Any') {
        let patternUrl = null;
        if (part.grain_direction === 'L' || part.grain_direction === 'length') {
            patternUrl = 'url(#grain-pattern-vertical)';
        } else if (part.grain_direction === 'W' || part.grain_direction === 'width') {
            patternUrl = 'url(#grain-pattern-horizontal)';
        }
        
        if (patternUrl) {
            const grainOverlay = createSVGElement('rect', {
                x: partX,
                y: partY,
                width: partWidth,
                height: partHeight,
                fill: patternUrl
            });
            group.appendChild(grainOverlay);
        }
    }
    
    // Draw part outline
    const partOutline = createSVGElement('rect', {
        x: partX,
        y: partY,
        width: partWidth,
        height: partHeight,
        fill: 'none',
        stroke: '#1a1a1a',
        'stroke-width': 1.5
    });
    group.appendChild(partOutline);
    
    // Draw edge banding indicators if present
    if (part.edge_banding && part.edge_banding !== 'None') {
        console.log('🔵 Edge banding detected for part:', part.name || part.part_unique_id);
        console.log('🔵 Edge banding full data:', JSON.stringify(part.edge_banding, null, 2));
        
        // Handle both object format { type: 'PVC_White', edges: ['top', 'bottom'] } 
        // and string format 'PVC_White' or 'All'
        let edgeBandingType = 'None';
        let edgesToDraw = [];
        
        if (typeof part.edge_banding === 'object' && part.edge_banding !== null) {
            edgeBandingType = part.edge_banding.type || 'None';
            const rawEdges = part.edge_banding.edges || [];
            
            // Handle different edge formats:
            // 1. Array of actual edge names: ['top', 'bottom', 'left', 'right']
            // 2. Array with count strings: ['4 edges', '2 edges', '1 edge']
            if (rawEdges.length > 0) {
                const firstEdge = rawEdges[0];
                
                // Check if it's a count string like "4 edges", "2 edges", "1 edge"
                if (typeof firstEdge === 'string' && firstEdge.includes('edge')) {
                    const match = firstEdge.match(/(\d+)\s*edge/);
                    if (match) {
                        const edgeCount = parseInt(match[1]);
                        // For now, assume all 4 edges if "4 edges", otherwise default to all
                        if (edgeCount === 4) {
                            edgesToDraw = ['top', 'bottom', 'left', 'right'];
                        } else if (edgeCount === 2) {
                            // Default to front edges (top and bottom) for 2 edges
                            edgesToDraw = ['top', 'bottom'];
                        } else if (edgeCount === 1) {
                            // Default to front edge (top) for 1 edge
                            edgesToDraw = ['top'];
                        } else {
                            edgesToDraw = ['top', 'bottom', 'left', 'right'];
                        }
                    }
                } else {
                    // It's already an array of edge names
                    edgesToDraw = rawEdges;
                }
            }
            
            console.log('🔵 Parsed from object - Type:', edgeBandingType, 'Edges:', edgesToDraw);
        } else if (typeof part.edge_banding === 'string') {
            edgeBandingType = part.edge_banding;
            edgesToDraw = ['top', 'bottom', 'left', 'right']; // Default to all edges
            console.log('🔵 Parsed from string - Type:', edgeBandingType, 'Edges:', edgesToDraw);
        }
        
        // Skip if type is 'None' or no edges specified
        if (edgeBandingType !== 'None' && edgesToDraw.length > 0) {
            // Draw edge banding as colored borders on specified edges
            const bandingColor = '#2563eb'; // Blue color for edge banding (matching image)
            const bandingWidth = 5; // Thicker to be more visible
            
            console.log('🔵 DRAWING edges:', edgesToDraw, 'for part:', part.name);
            
            // Check which edges to draw
            const drawTop = edgesToDraw.includes('top');
            const drawBottom = edgesToDraw.includes('bottom');
            const drawLeft = edgesToDraw.includes('left');
            const drawRight = edgesToDraw.includes('right');
            
            if (drawTop) {
                const topBanding = createSVGElement('line', {
                    x1: partX,
                    y1: partY,
                    x2: partX + partWidth,
                    y2: partY,
                    stroke: bandingColor,
                    'stroke-width': bandingWidth,
                    'stroke-linecap': 'butt'
                });
                group.appendChild(topBanding);
                console.log('✅ Drew top edge banding');
            }
            
            if (drawBottom) {
                const bottomBanding = createSVGElement('line', {
                    x1: partX,
                    y1: partY + partHeight,
                    x2: partX + partWidth,
                    y2: partY + partHeight,
                    stroke: bandingColor,
                    'stroke-width': bandingWidth,
                    'stroke-linecap': 'butt'
                });
                group.appendChild(bottomBanding);
                console.log('✅ Drew bottom edge banding');
            }
            
            if (drawLeft) {
                const leftBanding = createSVGElement('line', {
                    x1: partX,
                    y1: partY,
                    x2: partX,
                    y2: partY + partHeight,
                    stroke: bandingColor,
                    'stroke-width': bandingWidth,
                    'stroke-linecap': 'butt'
                });
                group.appendChild(leftBanding);
                console.log('✅ Drew left edge banding');
            }
            
            if (drawRight) {
                const rightBanding = createSVGElement('line', {
                    x1: partX + partWidth,
                    y1: partY,
                    x2: partX + partWidth,
                    y2: partY + partHeight,
                    stroke: bandingColor,
                    'stroke-width': bandingWidth,
                    'stroke-linecap': 'butt'
                });
                group.appendChild(rightBanding);
                console.log('✅ Drew right edge banding');
            }
        } else {
            console.log('⚪ Edge banding type is None or no edges specified - Type:', edgeBandingType, 'Edges:', edgesToDraw);
        }
    } else {
        console.log('⚪ No edge banding for part:', part.name || part.part_unique_id, 'Value:', part.edge_banding);
    }
    
    // Draw part width dimension (top label) - only if part is wide enough
    if (partWidth > 50) {
        const widthLabel = createSVGElement('text', {
            x: partX + partWidth / 2,
            y: partY + 6,
            'text-anchor': 'middle',
            'dominant-baseline': 'text-before-edge',
            'font-family': "'Inter', -apple-system, sans-serif",
            'font-size': Math.max(11, 13 * scale),
            'font-weight': '500',
            fill: '#1a1a1a'
        });
        const partDisplayW = partW / (window.unitFactors?.[reportUnits] || 1);
        widthLabel.textContent = formatNum(partDisplayW, reportPrecision);
        group.appendChild(widthLabel);
    }
    
    // Draw part height dimension (left label, rotated) - only if part is tall enough
    if (partHeight > 50) {
        const heightLabel = createSVGElement('text', {
            x: partX + 6,
            y: partY + partHeight / 2,
            'text-anchor': 'middle',
            'dominant-baseline': 'text-before-edge',
            'font-family': "'Inter', -apple-system, sans-serif",
            'font-size': Math.max(11, 13 * scale),
            'font-weight': '500',
            fill: '#1a1a1a',
            transform: `rotate(-90, ${partX + 6}, ${partY + partHeight / 2})`
        });
        const partDisplayH = partH / (window.unitFactors?.[reportUnits] || 1);
        heightLabel.textContent = formatNum(partDisplayH, reportPrecision);
        group.appendChild(heightLabel);
    }
    
    // Draw part ID label (centered) - only if part is large enough
    if (partWidth > 30 && partHeight > 20) {
        const labelContent = String(part.part_unique_id || part.part_number || part.instance_id || `P${partIndex + 1}`);
        const maxChars = Math.max(6, Math.floor(partWidth / 8));
        const displayLabel = labelContent.length > maxChars ? labelContent.slice(0, maxChars - 1) + '…' : labelContent;
        
        let labelX = partX + partWidth / 2;
        let labelY = partY + partHeight / 2;
        
        // Adjust label position for narrow/tall parts
        if (partWidth < 50 && partHeight > partWidth * 2) {
            labelY = partY + partHeight * 0.7;
        }
        if (partHeight < 35 && partWidth > partHeight * 2) {
            labelX = partX + partWidth * 0.7;
        }
        
        const idLabel = createSVGElement('text', {
            x: labelX,
            y: labelY,
            'text-anchor': 'middle',
            'dominant-baseline': 'middle',
            'font-family': "'Inter', -apple-system, sans-serif",
            'font-size': Math.max(15, 18 * scale),
            'font-weight': '700',
            fill: '#1a1a1a',
            'pointer-events': 'none'
        });
        idLabel.textContent = displayLabel;
        group.appendChild(idLabel);
    }
    
    // Add interactivity - store part data and add click handler
    group.setAttribute('data-part-id', part.part_unique_id || part.part_number || part.instance_id || `P${partIndex + 1}`);
    group.setAttribute('data-part-name', part.name || '');
    group.style.cursor = 'pointer';
    
    // Add hover effect
    group.addEventListener('mouseenter', function() {
        if (!group.classList.contains('highlighted')) {
            partOutline.setAttribute('stroke', '#0ea5e9');
            partOutline.setAttribute('stroke-width', '2.5');
        }
    });
    
    group.addEventListener('mouseleave', function() {
        // Only reset if not currently highlighted
        if (!group.classList.contains('highlighted')) {
            partOutline.setAttribute('stroke', '#1a1a1a');
            partOutline.setAttribute('stroke-width', '1.5');
        }
    });
    
    // Add click handler to highlight in assembly viewer
    group.addEventListener('click', function() {
        // CRITICAL FIX: Use unique_id (persistent_id) for 3D viewer matching
        // The 3D viewer expects part_unique_id to match group.userData.uniqueId (persistent_id)
        const persistentId = part.unique_id || part.part_unique_id;
        const displayId = part.instance_id || part.part_number || `P${partIndex + 1}`;
        
        console.log(`🖱️ Clicked SVG part: ${part.name}`);
        console.log(`   Display ID: ${displayId}`);
        console.log(`   Persistent ID: ${persistentId}`);
        
        // CRITICAL FIX: Use centralized clear function
        console.log('🧹 Clearing ALL highlights from SVG click');
        
        if (typeof window.clearAllHighlights === 'function') {
            window.clearAllHighlights();
        } else {
            // Fallback to manual clearing
            if (typeof window.clearAllSVGHighlights === 'function') {
                window.clearAllSVGHighlights();
            }
            if (typeof clearPieceHighlight === 'function') {
                clearPieceHighlight();
            }
            if (window.reportAssemblyGroups && window.reportAssemblyGroups.length > 0) {
                window.reportAssemblyGroups.forEach(group => {
                    group.traverse((child) => {
                        if (child.isMesh && child.material) {
                            const originalMat = group.userData.originalMaterial || {};
                            child.material.emissive.setHex(0x000000);
                            child.material.emissiveIntensity = 0;
                            child.material.color.setHex(originalMat.color || 0xcccccc);
                            child.material.opacity = originalMat.opacity || 0.85;
                            child.material.needsUpdate = true;
                        }
                        if (child.isLineSegments) {
                            child.material.color.setHex(group.userData.originalEdgeColor || 0x666666);
                            child.material.needsUpdate = true;
                        }
                    });
                });
            }
        }
        
        // Then highlight this part in 3D viewer
        if (typeof highlightPartInAssemblyViewer === 'function') {
            // CRITICAL FIX: Pass persistent_id as part_unique_id for exact matching
            // The 3D viewer uses this to match against group.userData.uniqueId
            const partWithId = {
                ...part,
                part_unique_id: persistentId,  // Use persistent_id for 3D viewer matching
                instance_id: displayId,        // Keep display ID for logging
                name: part.name
            };
            highlightPartInAssemblyViewer(partWithId);
        }
    });
    
    return group;
}

// Create sheet-level grain arrow below the board
function createSheetGrainArrow(boardX, boardBottomY, boardWidth, grainDirection) {
    if (!grainDirection || grainDirection === 'Any') return null;
    
    const group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    group.classList.add('sheet-grain-arrow');
    
    const centerX = boardX + boardWidth / 2;
    const arrowY = boardBottomY + 25; // Position below the board
    const arrowLength = Math.min(boardWidth * 0.3, 80);
    
    if (grainDirection === 'L' || grainDirection === 'length') {
        // Vertical arrow (grain runs along length/height)
        const arrowStartY = arrowY;
        const arrowEndY = arrowY + arrowLength;
        
        // Arrow line
        const line = createSVGElement('line', {
            x1: centerX,
            y1: arrowStartY,
            x2: centerX,
            y2: arrowEndY,
            stroke: '#1a1a1a',
            'stroke-width': 3
        });
        group.appendChild(line);
        
        // Arrow head (pointing down)
        const arrowHead = createSVGElement('polygon', {
            points: `${centerX},${arrowEndY} ${centerX - 6},${arrowEndY - 10} ${centerX + 6},${arrowEndY - 10}`,
            fill: '#1a1a1a'
        });
        group.appendChild(arrowHead);
        
        // Label
        const label = createSVGElement('text', {
            x: centerX + 15,
            y: arrowY + arrowLength / 2,
            'text-anchor': 'start',
            'dominant-baseline': 'middle',
            'font-family': "'Inter', -apple-system, sans-serif",
            'font-size': 13,
            'font-weight': '600',
            fill: '#1a1a1a'
        });
        label.textContent = 'Grain Direction';
        group.appendChild(label);
        
    } else if (grainDirection === 'W' || grainDirection === 'width') {
        // Horizontal arrow (grain runs along width)
        const arrowStartX = centerX - arrowLength / 2;
        const arrowEndX = centerX + arrowLength / 2;
        
        // Arrow line
        const line = createSVGElement('line', {
            x1: arrowStartX,
            y1: arrowY,
            x2: arrowEndX,
            y2: arrowY,
            stroke: '#1a1a1a',
            'stroke-width': 3
        });
        group.appendChild(line);
        
        // Arrow head (pointing right)
        const arrowHead = createSVGElement('polygon', {
            points: `${arrowEndX},${arrowY} ${arrowEndX - 10},${arrowY - 6} ${arrowEndX - 10},${arrowY + 6}`,
            fill: '#1a1a1a'
        });
        group.appendChild(arrowHead);
        
        // Label
        const label = createSVGElement('text', {
            x: centerX,
            y: arrowY + 20,
            'text-anchor': 'middle',
            'dominant-baseline': 'text-before-edge',
            'font-family': "'Inter', -apple-system, sans-serif",
            'font-size': 13,
            'font-weight': '600',
            fill: '#1a1a1a'
        });
        label.textContent = 'Grain Direction';
        group.appendChild(label);
    }
    
    return group;
}

// Create offcut SVG - exactly replicates canvas drawCrossedOffcut
function createOffcutSVG(offcut, scale, padding) {
    const offcutX = padding + (offcut.x || 0) * scale;
    const offcutY = padding + (offcut.y || 0) * scale;
    const offcutWidth = (offcut.width || offcut.w || 0) * scale;
    const offcutHeight = (offcut.height || offcut.h || 0) * scale;
    
    if (offcutWidth <= 0 || offcutHeight <= 0) return null;
    
    const group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    group.classList.add('offcut-group');
    
    // Light green background
    const bg = createSVGElement('rect', {
        x: offcutX,
        y: offcutY,
        width: offcutWidth,
        height: offcutHeight,
        fill: 'rgba(220, 252, 231, 0.2)'
    });
    group.appendChild(bg);
    
    // Dashed border
    const border = createSVGElement('rect', {
        x: offcutX,
        y: offcutY,
        width: offcutWidth,
        height: offcutHeight,
        fill: 'none',
        stroke: 'rgba(34, 197, 94, 0.4)',
        'stroke-width': 1,
        'stroke-dasharray': '4,4'
    });
    group.appendChild(border);
    
    // X pattern (two diagonal lines)
    // First diagonal (top-left to bottom-right)
    const diag1 = createSVGElement('line', {
        x1: offcutX,
        y1: offcutY,
        x2: offcutX + offcutWidth,
        y2: offcutY + offcutHeight,
        stroke: 'rgba(34, 197, 94, 0.3)',
        'stroke-width': 1.5
    });
    group.appendChild(diag1);
    
    // Second diagonal (top-right to bottom-left)
    const diag2 = createSVGElement('line', {
        x1: offcutX + offcutWidth,
        y1: offcutY,
        x2: offcutX,
        y2: offcutY + offcutHeight,
        stroke: 'rgba(34, 197, 94, 0.3)',
        'stroke-width': 1.5
    });
    group.appendChild(diag2);
    
    return group;
}

// Use getMaterialColor from diagrams_report.js (already defined globally)
function getMaterialColor(material) {
    // Use global function if available, otherwise provide fallback
    if (window.getMaterialColor) {
        return window.getMaterialColor(material);
    }
    // Fallback to default grey if function not available
    return '#D3D3D3';
}

// Helper function to create SVG elements with attributes
function createSVGElement(tag, attrs) {
    const element = document.createElementNS('http://www.w3.org/2000/svg', tag);
    Object.keys(attrs).forEach(key => {
        element.setAttribute(key, attrs[key]);
    });
    return element;
}

// Function to highlight a part in SVG diagrams (called from tables/lists)
function highlightPartInSVGDiagram(partId, boardNumber) {
    console.log(`🎯 highlightPartInSVGDiagram: ${partId} on board ${boardNumber}`);
    
    const diagramContainer = document.getElementById('diagramsContainer');
    if (!diagramContainer) {
        console.warn('Diagrams container not found');
        return;
    }
    
    // Find the diagram card for this board
    const diagrams = diagramContainer.querySelectorAll('.diagram-card');
    const boardIndex = boardNumber - 1;
    
    if (boardIndex < 0 || boardIndex >= diagrams.length) {
        console.warn(`Board ${boardNumber} not found`);
        return;
    }
    
    const targetCard = diagrams[boardIndex];
    const svg = targetCard.querySelector('svg.diagram-canvas');
    
    if (!svg) {
        console.warn(`SVG for board ${boardNumber} not found`);
        return;
    }
    
    // CRITICAL FIX: Search by data-unique-id (persistent_id) instead of data-part-id
    // This allows 3D viewer clicks (which use persistent_id) to find the correct SVG element
    let targetGroup = svg.querySelector(`.part-group[data-unique-id="${partId}"]`);
    
    // Fallback: If not found by unique_id, try by data-part-id (for table clicks using display ID)
    if (!targetGroup) {
        targetGroup = svg.querySelector(`.part-group[data-part-id="${partId}"]`);
    }
    
    if (!targetGroup) {
        console.warn(`Part group not found: ${partId}`);
        return;
    }
    
    // Create unique key for this part
    const partKey = `${partId}_${boardNumber}`;
    
    // Check if clicking the same part (toggle off)
    if (currentlyHighlightedPart === partKey) {
        console.log(`✅ Toggling OFF: ${partKey}`);
        clearAllHighlights();
        return;
    }
    
    // Clear all previous highlights
    clearAllHighlights();
    
    // Add highlight class (CSS handles the visual styling)
    targetGroup.classList.add('highlighted');
    
    // Update global state
    currentlyHighlightedPart = partKey;
    console.log(`✅ Highlighted: ${partKey}`);
    
    // Scroll the diagram card into view
    targetCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
}

// Global state for tracking currently highlighted part
let currentlyHighlightedPart = null;

// Helper function to clear all SVG highlights
function clearAllSVGHighlights() {
    console.log('🧹 clearAllSVGHighlights: Removing all highlight classes');
    
    // Remove highlighted class from all part groups
    const allHighlighted = document.querySelectorAll('.part-group.highlighted');
    const count = allHighlighted.length;
    
    allHighlighted.forEach(group => {
        group.classList.remove('highlighted');
    });
    
    // Reset global state
    currentlyHighlightedPart = null;
    
    console.log(`✅ Cleared ${count} highlight(s)`);
}

// CENTRALIZED FUNCTION: Clear ALL highlights (SVG + Canvas + 3D)
function clearAllHighlights() {
    console.log('🧹 clearAllHighlights: MASTER CLEAR');
    
    // 1. Clear SVG highlights (CSS classes only)
    clearAllSVGHighlights();
    
    // 2. Clear canvas highlights
    if (typeof clearPieceHighlight === 'function') {
        clearPieceHighlight();
    }
    
    // 3. Clear 3D viewer highlights
    if (window.reportAssemblyGroups && window.reportAssemblyGroups.length > 0) {
        window.reportAssemblyGroups.forEach(group => {
            group.traverse((child) => {
                if (child.isMesh && child.material) {
                    const originalMat = group.userData.originalMaterial || {};
                    child.material.emissive.setHex(0x000000);
                    child.material.emissiveIntensity = 0;
                    child.material.color.setHex(originalMat.color || 0xcccccc);
                    child.material.opacity = originalMat.opacity || 0.85;
                    child.material.needsUpdate = true;
                }
                if (child.isLineSegments) {
                    child.material.color.setHex(group.userData.originalEdgeColor || 0x666666);
                    child.material.needsUpdate = true;
                }
            });
        });
    }
    
    console.log('✅ All highlights cleared');
}

// Make functions available globally (with safety check)
if (typeof window !== 'undefined') {
    window.generateBoardSVG = generateBoardSVG;
    window.highlightPartInSVGDiagram = highlightPartInSVGDiagram;
    window.clearAllSVGHighlights = clearAllSVGHighlights;
    window.clearAllHighlights = clearAllHighlights; // NEW: Master clear function
} else {
    console.warn('Window object not available - SVG functions not registered globally');
}

