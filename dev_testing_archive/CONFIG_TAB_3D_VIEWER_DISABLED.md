# Config Tab 3D Viewer - Temporarily Disabled

## Date: 2025-01-31

## Decision
The 3D viewer in the Configuration tab has been **commented out** (not deleted) to:
1. Reduce feature duplication (Report tab already has a full-featured 3D viewer)
2. Simplify the user experience
3. Improve performance by not initializing two 3D renderers
4. Reserve the code for future unique development

## What Was Changed

### File: `Extension/AutoNestCut/ui/html/main.html`

**Lines ~600-695**: The entire 3D canvas container section is now wrapped in HTML comments:
```html
<!-- ============================================ -->
<!-- 3D VIEWER - COMMENTED OUT FOR FUTURE USE -->
<!-- Will be developed into something unique -->
<!-- Currently available in Report tab -->
<!-- ============================================ -->
<!--
<div class="parts-canvas-container" id="partsCanvasContainer">
    ... all 3D viewer HTML ...
</div>
-->
<!-- ============================================ -->
<!-- END 3D VIEWER COMMENT BLOCK -->
<!-- ============================================ -->
```

**Layout Changes**:
- Parts Preview table now takes full width (was 50/50 split with 3D viewer)
- Added helpful hint: "💡 3D Viewer available in Report tab"
- Removed "Maximize Both Sections" button (no longer needed)
- Kept "Maximize View" button for the parts table

## What Still Works

✅ **Parts Preview Table**: Fully functional, shows all detected parts
✅ **Table Highlighting**: Click rows to see part details
✅ **Maximize Table**: Full-screen view of parts table
✅ **Report Tab 3D Viewer**: Complete 3D assembly viewer with:
   - Exploded views
   - Part highlighting
   - Material visualization
   - Interactive controls
   - Texture support

## Future Development Ideas

When time permits, the Config tab 3D viewer could be developed into something unique:

1. **Quick Preview Mode**: Lightweight single-part viewer (not full assembly)
2. **Material Visualizer**: Show how different materials look on parts
3. **Dimension Inspector**: Interactive dimension measurement tool
4. **Part Comparison**: Side-by-side view of similar parts
5. **Nesting Preview**: Show how parts will be arranged on sheets

## How to Re-enable

If you want to re-enable the 3D viewer:

1. Open `Extension/AutoNestCut/ui/html/main.html`
2. Find the comment block (search for "3D VIEWER - COMMENTED OUT")
3. Remove the opening `<!--` and closing `-->` tags
4. Restore the original layout CSS (change `flex: 1; max-width: 100%` back to `flex: 1`)
5. Restore the "Maximize Both Sections" button

## Benefits of This Change

- **Cleaner UI**: Config tab focuses on configuration, not visualization
- **Better Performance**: One less WebGL context to manage
- **Clearer User Flow**: 
  - Config tab = Setup (select parts, configure materials)
  - Report tab = Results (view cut list, inspect 3D assembly)
- **Easier Maintenance**: One 3D viewer to maintain and debug
- **Future Flexibility**: Code preserved for unique feature development

## Notes

- All 3D viewer JavaScript functions remain intact (used by Report tab)
- No functionality was removed, only relocated/hidden
- Users are guided to the Report tab for 3D visualization
- The fix for assembly part highlighting (from earlier today) still applies to the Report tab viewer
