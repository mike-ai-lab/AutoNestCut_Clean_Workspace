# Highlighting Debug Instructions

## Changes Made

### 1. Added Console Logging
**File**: `Extension/AutoNestCut/ui/html/svg_diagram_generator.js`

The `clearAllSVGHighlights()` function now logs:
- When it's called
- How many highlighted parts it found
- Each part being cleared
- Confirmation when done

### 2. Added Clear to 3D Viewer
**File**: `Extension/AutoNestCut/ui/html/diagrams_report.js`

The `highlightPartInAssemblyViewer()` function now:
- Calls `clearAllSVGHighlights()` FIRST
- Then highlights the part in 3D viewer

## Testing Steps

1. **Open SketchUp Console** (Window > Ruby Console)
2. **Generate a cut list** with multiple parts
3. **Open Browser DevTools** (F12 in the dialog)
4. **Click a part ID** in the detailed parts list
5. **Check console** - you should see:
   ```
   🎯 Highlighting SVG part: P1 on board 1
   🧹 clearAllSVGHighlights called
   Found X highlighted parts to clear
   ✅ All highlights cleared
   ✅ Highlighted SVG part with enhanced effect: P1
   ```

6. **Click another part ID**
7. **Check console again** - should see the same pattern
8. **Verify** - Only ONE part should be highlighted (orange glow)

## If Highlighting Still Accumulates

Check the console output:
- Is `clearAllSVGHighlights` being called?
- How many parts does it find to clear?
- Are there any errors?

## Common Issues

### Issue 1: Function Not Defined
**Symptom**: Console shows "clearAllSVGHighlights is not a function"
**Solution**: The svg_diagram_generator.js file isn't loaded
**Check**: Look for script tag in main.html

### Issue 2: No Parts Found to Clear
**Symptom**: Console shows "Found 0 highlighted parts to clear"
**Solution**: The selector isn't finding the highlighted parts
**Check**: Inspect the SVG in DevTools - do highlighted parts have class="highlighted"?

### Issue 3: Highlights Not Removed Visually
**Symptom**: Console shows parts cleared but they're still orange
**Solution**: The overlay isn't being removed
**Check**: Look for `.highlight-overlay` elements in the SVG

## PDF Preview Issue

The PDF preview window should show diagrams. If it doesn't:

1. **Check if SVG diagrams exist** in the main report
2. **Look at Ruby console** for errors during PDF generation
3. **The Ruby PDF exporter** may need to be updated to capture SVG instead of canvas

The Ruby exporter is in: `Extension/AutoNestCut/exporters/`

## Next Steps

If highlighting still doesn't work after these changes:
1. Share the console output
2. Share a screenshot of the DevTools Elements tab showing the SVG structure
3. Check if there are multiple instances of the highlighting function being defined
