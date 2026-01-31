if (typeof resizerInitialized === 'undefined') {
    var resizerInitialized = false;
}

function initResizer() {
    if (resizerInitialized) return;
    
    const resizer = document.getElementById('resizer');
    const leftSide = document.getElementById('diagramsContainer');
    const rightSide = document.getElementById('reportContainer');
    const container = document.querySelector('.report-main-layout') || document.querySelector('.container');
    
    if (!resizer || !leftSide || !rightSide) {
        // Retry after a short delay if elements aren't ready
        setTimeout(initResizer, 100);
        return;
    }
    
    // The diagram list doesn't need special handling since parent scrolls
    const diagramList = document.getElementById('reportDiagramList') || leftSide.querySelector('.report-diagram-list');
    if (diagramList) {
        console.log('Diagram list found - parent container handles scrolling');
    }
    
    // Ensure proper overflow settings
    if (container) {
        container.style.overflow = 'hidden';
        container.style.height = '100%';
    }
    
    // CRITICAL: Apply overflow auto directly to the diagrams container
    leftSide.style.overflow = 'auto'; // This is the key fix!
    leftSide.style.display = 'flex';
    leftSide.style.flexDirection = 'column';
    leftSide.style.height = '100%';
    
    rightSide.style.overflowY = 'auto';
    rightSide.style.overflowX = 'hidden';
    
    let isResizing = false;
    
    // Remove any existing event listeners to prevent duplicates
    resizer.removeEventListener('mousedown', handleMouseDown);
    
    function handleMouseDown(e) {
        isResizing = true;
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
        resizer.style.background = '#3b82f6'; // Visual feedback
        e.preventDefault();
    }
    
    function handleMouseMove(e) {
        if (!isResizing) return;
        
        const containerRect = container ? container.getBoundingClientRect() : document.body.getBoundingClientRect();
        const newLeftWidth = e.clientX - containerRect.left;
        const totalWidth = containerRect.width;
        
        // Ensure minimum widths for both sides
        const minLeftWidth = 200;
        const minRightWidth = 400;
        
        if (newLeftWidth >= minLeftWidth && (totalWidth - newLeftWidth) >= minRightWidth) {
            leftSide.style.width = `${newLeftWidth}px`;
            leftSide.style.flexShrink = '0';
            leftSide.style.flexGrow = '0';
            
            // Maintain scrolling after resize
            if (diagramList) {
                diagramList.style.overflowY = 'auto';
            }
            rightSide.style.overflowY = 'auto';
        }
    }
    
    function handleMouseUp() {
        if (isResizing) {
            isResizing = false;
            document.body.style.cursor = '';
            document.body.style.userSelect = '';
            resizer.style.background = ''; // Remove visual feedback
        }
    }
    
    resizer.addEventListener('mousedown', handleMouseDown);
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
    
    // Add touch support for mobile devices
    resizer.addEventListener('touchstart', (e) => {
        isResizing = true;
        document.body.style.userSelect = 'none';
        resizer.style.background = '#3b82f6';
        e.preventDefault();
    });
    
    document.addEventListener('touchmove', (e) => {
        if (!isResizing) return;
        
        const touch = e.touches[0];
        const containerRect = container ? container.getBoundingClientRect() : document.body.getBoundingClientRect();
        const newLeftWidth = touch.clientX - containerRect.left;
        const totalWidth = containerRect.width;
        
        const minLeftWidth = 200;
        const minRightWidth = 400;
        
        if (newLeftWidth >= minLeftWidth && (totalWidth - newLeftWidth) >= minRightWidth) {
            leftSide.style.width = `${newLeftWidth}px`;
            leftSide.style.flexShrink = '0';
            leftSide.style.flexGrow = '0';
            
            // Maintain scrolling after touch resize
            if (diagramList) {
                diagramList.style.overflowY = 'auto';
            }
            rightSide.style.overflowY = 'auto';
        }
        e.preventDefault();
    });
    
    document.addEventListener('touchend', () => {
        if (isResizing) {
            isResizing = false;
            document.body.style.userSelect = '';
            resizer.style.background = '';
        }
    });
    
    resizerInitialized = true;
    console.log('Resizer initialized successfully');
    
    // Add test content if diagram list is empty (for debugging)
    if (diagramList && diagramList.children.length <= 1) {
        console.log('Adding test content to verify scrolling...');
        const testContent = document.createElement('div');
        testContent.innerHTML = `
            <div style="margin-bottom: 12px; padding: 12px; background: white; border: 1px solid #e2e8f0; border-radius: 6px;">
                <div style="font-weight: 600; margin-bottom: 4px;">Test Board 1</div>
                <div style="font-size: 12px; color: #64748b;">2440 x 1220 mm</div>
            </div>
            <div style="margin-bottom: 12px; padding: 12px; background: white; border: 1px solid #e2e8f0; border-radius: 6px;">
                <div style="font-weight: 600; margin-bottom: 4px;">Test Board 2</div>
                <div style="font-size: 12px; color: #64748b;">2440 x 1220 mm</div>
            </div>
            <div style="margin-bottom: 12px; padding: 12px; background: white; border: 1px solid #e2e8f0; border-radius: 6px;">
                <div style="font-weight: 600; margin-bottom: 4px;">Test Board 3</div>
                <div style="font-size: 12px; color: #64748b;">2440 x 1220 mm</div>
            </div>
            <div style="margin-bottom: 12px; padding: 12px; background: white; border: 1px solid #e2e8f0; border-radius: 6px;">
                <div style="font-weight: 600; margin-bottom: 4px;">Test Board 4</div>
                <div style="font-size: 12px; color: #64748b;">2440 x 1220 mm</div>
            </div>
            <div style="margin-bottom: 12px; padding: 12px; background: white; border: 1px solid #e2e8f0; border-radius: 6px;">
                <div style="font-weight: 600; margin-bottom: 4px;">Test Board 5</div>
                <div style="font-size: 12px; color: #64748b;">2440 x 1220 mm</div>
            </div>
            <div style="margin-bottom: 12px; padding: 12px; background: white; border: 1px solid #e2e8f0; border-radius: 6px;">
                <div style="font-weight: 600; margin-bottom: 4px;">Test Board 6</div>
                <div style="font-size: 12px; color: #64748b;">2440 x 1220 mm</div>
            </div>
            <div style="margin-bottom: 12px; padding: 12px; background: white; border: 1px solid #e2e8f0; border-radius: 6px;">
                <div style="font-weight: 600; margin-bottom: 4px;">Test Board 7</div>
                <div style="font-size: 12px; color: #64748b;">2440 x 1220 mm</div>
            </div>
            <div style="margin-bottom: 12px; padding: 12px; background: white; border: 1px solid #e2e8f0; border-radius: 6px;">
                <div style="font-weight: 600; margin-bottom: 4px;">Test Board 8</div>
                <div style="font-size: 12px; color: #64748b;">2440 x 1220 mm</div>
            </div>
        `;
        diagramList.innerHTML = testContent.innerHTML;
        
        // Log scrolling info after adding content
        setTimeout(() => {
            console.log('After adding test content:', {
                scrollHeight: diagramList.scrollHeight,
                clientHeight: diagramList.clientHeight,
                canScroll: diagramList.scrollHeight > diagramList.clientHeight,
                overflowY: window.getComputedStyle(diagramList).overflowY
            });
        }, 100);
    }
}

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initResizer);
} else {
    initResizer();
}

// Make initResizer globally available for re-initialization
window.initResizer = initResizer;
