# 3D Viewer Update - Reload Instructions

## What Was Done

The 3D viewer in `main.html` has been updated with:
1. ✅ Exploded view slider (vertical slider on the right side)
2. ✅ Assembly rendering support (renders full assemblies from Ruby data)
3. ✅ Part highlighting in assembly mode
4. ✅ Texture toggling for assembly meshes
5. ✅ Enhanced cache busting in `main.rb`

## The Issue

**SketchUp aggressively caches HTML dialogs**, even with cache-busting. The changes ARE in the file, but SketchUp is showing you the old cached version.

## Solution: Force SketchUp to Reload

### Method 1: Close and Reopen the Dialog (Recommended)
1. **Close the AutoNestCut dialog completely** (click the X button)
2. **Reload the extension** in SketchUp Ruby Console:
   ```ruby
   load 'Extension/autonestcut.rb'
   ```
3. **Reopen the dialog** from the Extensions menu

### Method 2: Restart SketchUp (Nuclear Option)
1. Save your work
2. Close SketchUp completely
3. Reopen SketchUp
4. Load your model
5. Open AutoNestCut dialog

### Method 3: Clear SketchUp Cache (Windows)
1. Close SketchUp
2. Delete cache folder:
   ```
   %LOCALAPPDATA%\SketchUp\SketchUp 20XX\SketchUp\Cache
   ```
3. Restart SketchUp

## Verify the Changes

Once reloaded, you should see:
- A vertical "EXPLODE" slider on the right side of the 3D viewer (when assembly data is available)
- The slider should be hidden when no assembly data is present
- Parts should highlight (not isolate) when clicked in assembly mode

## Technical Details

The 3D viewer uses:
- **THREE.js r128** (loaded from CDN)
- **OrbitControls** for camera manipulation
- **Custom assembly rendering** with exploded view support

The implementation is in `Extension/AutoNestCut/ui/html/main.html` starting around line 1070.

## Cache Busting Enhancement

Updated `Extension/AutoNestCut/main.rb` to add:
- No-cache meta tags
- Timestamp comments to force HTML to be seen as "different"
- This should prevent future caching issues

## If Still Not Working

If you still see the old version after trying all methods above:
1. Check the browser console in the dialog (if SketchUp allows)
2. Verify the file was actually saved (check file modification timestamp)
3. Try opening the HTML file directly in a browser to verify changes are there
4. Check if there are multiple copies of the extension installed
