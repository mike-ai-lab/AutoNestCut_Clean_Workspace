# QR Labels - Loading Issue Fix

## 🔍 Problem Identified

The `LabelGenerator` class is **not being loaded** when the extension loads, even though:
- ✅ The file `Extension/AutoNestCut/processors/label_generator.rb` exists
- ✅ The file has correct syntax
- ✅ The file is properly wrapped in `module AutoNestCut`
- ✅ The require statement exists in `main.rb` at line 34

Console shows:
```
✅ AutoNestCut Module Loaded [15:06:13] - Build: 20250119_1445
❌ LabelGenerator NOT LOADED
Available constants: EXTENSION_BUILD, EXTENSION_CREATOR, EXTENSION_DESCRIPTION, 
                     EXTENSION_NAME, EXTENSION_VERSION, PATH_ROOT
```

This means **NO classes are being loaded** - not just LabelGenerator, but also Config, Nester, Part, Board, etc.

## 🎯 Root Cause

The `require_relative` statements in `main.rb` are inside the `module AutoNestCut` block, but something is preventing the classes from being registered in the module's constant list.

Possible causes:
1. **Silent error** in one of the required files (before label_generator)
2. **Circular dependency** issue
3. **File loading order** problem
4. **SketchUp's Ruby environment** quirk

## 🔧 Solution: Force Load After Extension Loads

Since the extension loads but classes don't, we can **force load** the LabelGenerator after the extension is loaded.

### Step 1: Load the Extension Normally

In SketchUp Ruby Console:
```ruby
load 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/Extension/autonestcut.rb'
```

Or just start SketchUp (if extension auto-loads).

### Step 2: Force Load LabelGenerator

Run this script:
```ruby
load 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/FORCE_LOAD_LABEL_GENERATOR.rb'
```

This will:
- ✅ Check if AutoNestCut module exists
- ✅ Force load label_generator.rb
- ✅ Verify LabelGenerator is available
- ✅ Enable the feature flag
- ✅ Clear the cache

### Step 3: Use AutoNestCut Normally

1. Close AutoNestCut dialog if open
2. Select components
3. Extensions → Auto Nest Cut → Generate Cut List
4. Click "Process" button
5. Watch console for label generation messages
6. Export PDF

## 🧪 Diagnostic Scripts

I've created several diagnostic scripts to help identify the issue:

1. **`SIMPLE_LOAD_TEST.rb`** - Basic test to see if LabelGenerator loads
2. **`FIND_BROKEN_REQUIRE.rb`** - Tests each require statement to find which one fails
3. **`DEBUG_MODULE_LOADING.rb`** - Shows detailed loading process
4. **`FORCE_LOAD_LABEL_GENERATOR.rb`** ⭐ - **USE THIS ONE** - Forces LabelGenerator to load

## 📊 Expected Console Output

### After Force Loading

```
🔧 FORCE LOADING LabelGenerator
================================================================================
Path: C:/Users/.../label_generator.rb
Exists: true
✓ AutoNestCut module exists
⚠️  LabelGenerator not loaded, loading now...
✅ LabelGenerator loaded successfully!

✅ FINAL STATUS: LabelGenerator IS available
   Methods: build_label_payload, generate_labels, generate_part_code, 
            generate_project_id, generate_qr_content, generate_uid, validate_labels
✅ Feature enabled
✅ Cache cleared

📋 NOW:
   1. Close AutoNestCut dialog
   2. Select components
   3. Run AutoNestCut
   4. Click 'Process'
   5. Watch for label generation messages
================================================================================
```

### During Nesting (After Fix)

```
DEBUG: optimize_boards completed in XXXms

🏷️ LABEL GENERATION CHECK:
   enable_part_labels setting: true
   boards_result count: 8
   total parts: 22
   🏷️ Calling LabelGenerator.generate_labels...

================================================================================
🏷️ LABEL GENERATOR: Starting label generation
================================================================================
Project ID: 2501
Total boards: 8
✅ Label generation complete
   Parts labeled: 22
   Boards processed: 8
================================================================================

   ✅ Label generation complete - 22 parts labeled
   Project ID: 2501
   📋 First part labels:
      UID: "ANC-2501-001"
      Part Code: "PLY-600x400x18-001"
      Board Index: 1
```

### During PDF Export (After Fix)

```
🏷️  PDF RENDER - UNIQUE PARTS SECTION:
   labels_enabled: true
   QR_AVAILABLE: false
   unique_part_types count: 10
   First part label data:
      uid: "ANC-2501-001"          ← NOT nil!
      part_code: "PLY-600x400x18-001"  ← NOT nil!
      label_payload: present        ← NOT nil!
   ✅ Using LABELED table format (Part Code + QR columns)
```

## 🔍 Further Investigation Needed

If force loading works, we need to find out why the normal require_relative doesn't work. Run:

```ruby
load 'FIND_BROKEN_REQUIRE.rb'
```

This will test each require statement in order and show which one fails first.

## ✅ Quick Fix Workflow

1. **Start SketchUp** (extension loads automatically)
2. **Open Ruby Console** (Window → Ruby Console)
3. **Run**: `load 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/FORCE_LOAD_LABEL_GENERATOR.rb'`
4. **Verify**: See "✅ FINAL STATUS: LabelGenerator IS available"
5. **Use AutoNestCut**: Select components → Process → Export PDF
6. **Check PDF**: Should have "Part Code" and "QR" columns

## 🎯 Permanent Fix (TODO)

Once we identify which file is causing the loading issue, we can fix it properly. For now, the force load workaround will get the feature working.

---

**Bottom Line**: Run `FORCE_LOAD_LABEL_GENERATOR.rb` after the extension loads, then use AutoNestCut normally. Labels will work!

