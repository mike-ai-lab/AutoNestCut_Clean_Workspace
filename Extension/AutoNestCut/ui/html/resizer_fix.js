if (typeof resizerInitialized === 'undefined') {
    var resizerInitialized = false;
}

function initResizer() {
    if (resizerInitialized) return;
    
    const resizer = document.getElementById('resizer');
    const leftSide = document.getElementById('diagramsContainer');
    const rightSide = document.getElementById('reportContainer');
    const container = document.querySelector('.container');
    
    if (!resizer || !leftSide || !rightSide || !container) {
        // Retry after a short delay if elements aren't ready
        setTimeout(initResizer, 100);
        return;
    }
    
    // Set up individual scrolling for each container
    container.style.overflowY = 'hidden';
    container.style.overflowX = 'hidden';
    leftSide.style.overflowY = 'auto';
    rightSide.style.overflowY = 'auto';
    rightSide.style.overflowX = 'hidden';
    
    let isResizing = false;
    
    // Remove any existing event listeners to prevent duplicates
    resizer.removeEventListener('mousedown', handleMouseDown);
    
    function handleMouseDown(e) {
        isResizing = true;
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';
        e.preventDefault();
    }
    
    function handleMouseMove(e) {
        if (!isResizing) return;
        
        const containerRect = container.getBoundingClientRect();
        const newLeftWidth = e.clientX - containerRect.left;
        const totalWidth = containerRect.width;
        
        // Ensure minimum widths for both sides
        const minLeftWidth = 300;
        const minRightWidth = 400;
        
        if (newLeftWidth >= minLeftWidth && (totalWidth - newLeftWidth) >= minRightWidth) {
            leftSide.style.flex = `0 0 ${newLeftWidth}px`;
            rightSide.style.flex = `1 1 auto`;
            
            // Maintain individual scrolling after resize
            leftSide.style.overflowY = 'auto';
            rightSide.style.overflowY = 'auto';
        }
    }
    
    function handleMouseUp() {
        if (isResizing) {
            isResizing = false;
            document.body.style.cursor = '';
            document.body.style.userSelect = '';
        }
    }
    
    resizer.addEventListener('mousedown', handleMouseDown);
    document.addEventListener('mousemove', handleMouseMove);
    document.addEventListener('mouseup', handleMouseUp);
    
    // Add touch support for mobile devices
    resizer.addEventListener('touchstart', (e) => {
        isResizing = true;
        document.body.style.userSelect = 'none';
        e.preventDefault();
    });
    
    document.addEventListener('touchmove', (e) => {
        if (!isResizing) return;
        
        const touch = e.touches[0];
        const containerRect = container.getBoundingClientRect();
        const newLeftWidth = touch.clientX - containerRect.left;
        const totalWidth = containerRect.width;
        
        if (newLeftWidth > 300 && totalWidth - newLeftWidth > 400) {
            leftSide.style.flex = `0 0 ${newLeftWidth}px`;
            rightSide.style.flex = `1 1 auto`;
            
            // Maintain individual scrolling after touch resize
            leftSide.style.overflowY = 'auto';
            rightSide.style.overflowY = 'auto';
        }
        e.preventDefault();
    });
    
    document.addEventListener('touchend', () => {
        if (isResizing) {
            isResizing = false;
            document.body.style.userSelect = '';
        }
    });
    
    resizerInitialized = true;
    }

// Initialize when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initResizer);
} else {
    initResizer();
}

// Make initResizer globally available for re-initialization
window.initResizer = initResizer;
