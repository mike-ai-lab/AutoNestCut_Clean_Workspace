# Stock Materials Module - Debug Instructions

## What Was Fixed

1. **Removed Duplicate Class Definition**: There were TWO complete `StockMaterialsManager` class definitions in the file. The second one (without logging) was overwriting the first one (with extensive logging). This is why you saw no console logs.

2. **Added Initialization Delay**: Added a 100ms `setTimeout` before initializing the manager to ensure the DOM is fully ready and all button elements exist before attaching event listeners.

3. **Enhanced Debug Logging**: The initialization now logs:
   - Whether button elements are found
   - Whether the tbody element exists
   - The manager instance details
   - The materials count after initialization

## How to Test

### Step 1: Open the Configuration Tab
1. Load the extension in SketchUp
2. Open the configuration dialog
3. Navigate to the "Configuration" tab
4. Open your browser's Developer Tools (F12)
5. Look at the Console tab

### Step 2: Check Console Logs
You should see extensive logging like this:
```
=== Loading Stock Materials Module ===
Stock Materials HTML injected
Checking for button elements...
addMaterialBtn found: true
loadDefaultsBtn found: true
materials_tbody found: true
Creating StockMaterialsManager instance...
StockMaterialsManager constructor called
StockMaterialsManager init called
Setting up event listeners...
Add Material button found
Load Defaults button found
Event listeners setup complete
Loading materials...
SketchUp API not available, loading from localStorage
Loaded materials: 0
No materials found, auto-loading defaults...
Auto-loading default materials...
Default materials loaded: 6
Displaying materials...
Filtered materials count: 6
Materials displayed successfully
=== Stock Materials Module Loaded Successfully ===
```

### Step 3: Verify Table Contents
The table should automatically display 6 default materials:
- Plywood 18mm
- MDF 18mm
- Plywood 12mm
- MDF 12mm
- Chipboard 18mm
- OSB 18mm

### Step 4: Test Buttons
Click each button and verify console logs appear:
- **Add Material**: Should show "Add Material clicked" and prompt for name
- **Load Defaults**: Should show "Load Defaults clicked" and confirmation dialog
- **Import CSV**: Should open file picker
- **Export Database**: Should download CSV file

## If It Still Doesn't Work

### Check 1: Verify No JavaScript Errors
Look for red error messages in the console. Common issues:
- Syntax errors
- Missing elements
- Timing issues

### Check 2: Clear Browser Cache
SketchUp's HtmlDialog caches aggressively:
1. Close the dialog
2. Reload the extension in SketchUp Ruby Console:
   ```ruby
   load 'Extension/AutoNestCut/main.rb'
   ```
3. Reopen the dialog

### Check 3: Clear LocalStorage
Open console and run:
```javascript
localStorage.clear();
location.reload();
```

### Check 4: Manual Test
Open console and run:
```javascript
// Check if manager exists
console.log('Manager:', window.stockMaterialsManager);

// Check materials data
console.log('Materials:', window.stockMaterialsManager.materialsData);

// Manually trigger display
window.stockMaterialsManager.displayMaterials();

// Manually load defaults
window.stockMaterialsManager.autoLoadDefaults();
```

## File Structure

The Stock Materials module is now organized as follows:

1. **Class Definition** (lines ~4800-5100): The `StockMaterialsManager` class with all methods
2. **Loader Function** (lines ~5180-5260): `loadStockMaterialsModule()` that injects HTML and initializes
3. **Global Functions** (lines ~5265-5290): Backward compatibility wrappers
4. **Initialization** (lines ~5255-5260): DOM ready check and loader call

## Next Steps

Once this is working, we can:
1. Remove the extensive debug logging (keep only critical logs)
2. Add more features (search, filter, bulk operations)
3. Improve the UI/UX
4. Add validation and error handling
5. Integrate with Ruby backend for persistent storage

## Separate Files (For Reference)

The code is also available in separate files for easier development:
- `Extension/AutoNestCut/ui/html/stock_materials.html` - HTML template
- `Extension/AutoNestCut/ui/html/stock_materials.js` - JavaScript class

These are kept for reference and future modularization, but the embedded version in `main.html` is what's actually used due to SketchUp's HtmlDialog limitations.
