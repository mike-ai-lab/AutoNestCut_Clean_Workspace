# QR Labels Visual Guide

## 🎯 What You Should See

### Step 1: Run Test Script

**Command:**
```ruby
load 'TEST_QR_LABELS_SIMPLE.rb'
```

**Expected Output:**
```
================================================================================
🏷️  QR LABELS SIMPLE TEST
================================================================================
✅ LabelGenerator is loaded
✅ Feature is enabled

🗑️  Clearing cache...
✅ Cache cleared

================================================================================
✅ ALL CHECKS PASSED!
================================================================================

📋 NEXT STEPS:
   1. Close AutoNestCut dialog if open
   2. Select components in SketchUp
   3. Run AutoNestCut from menu
   4. Click 'Process' button
   5. Watch console for these messages:
      🏷️ LABEL GENERATION CHECK:
      🏷️ Calling LabelGenerator.generate_labels...
      ✅ Label generation complete - X parts labeled
      UID: "ANC-XXXX-XXX"
   6. Export PDF and check for Part Code + QR columns

⚠️  CRITICAL: You MUST click 'Process' to run fresh nesting!
   Do NOT use cached results!
================================================================================
```

---

### Step 2: Run AutoNestCut

1. **Select components** in SketchUp
2. **Extensions → Auto Nest Cut → Generate Cut List**
3. **Click "Process" button** in the dialog

---

### Step 3: Watch Console Output

**What you should see:**

```
DEBUG: Calling nester.optimize_boards NOW...
DEBUG: optimize_boards completed in 1234.5ms

🏷️  LABEL GENERATION CHECK:
   enable_part_labels setting: true
   boards_result count: 11
   total parts: 42
   🏷️  Calling LabelGenerator.generate_labels...

================================================================================
🏷️  LABEL GENERATOR: Starting label generation
================================================================================
Project ID: 2501
Total boards: 11
✅ Label generation complete
   Parts labeled: 42
   Boards processed: 11
================================================================================

   ✅ Label generation complete - 42 parts labeled
   Project ID: 2501
   📋 First part labels:
      UID: "ANC-2501-001"
      Part Code: "PLY-600x400x18-001"
      Board Index: 1

DEBUG: Total thread execution time: 1456.7ms
```

**Key indicators:**
- ✅ `🏷️ LABEL GENERATION CHECK:` appears
- ✅ `enable_part_labels setting: true`
- ✅ `🏷️ Calling LabelGenerator.generate_labels...`
- ✅ `✅ Label generation complete - X parts labeled`
- ✅ `UID: "ANC-2501-001"` (NOT nil)
- ✅ `Part Code: "PLY-600x400x18-001"` (NOT nil)

---

### Step 4: Export PDF

Click "Export PDF" button in AutoNestCut dialog.

**Console output during export:**

```
DEBUG: print_pdf callback STARTED - Using Ruby PDF Exporter
...
🏷️  PDF RENDER - UNIQUE PARTS SECTION:
   labels_enabled: true
   QR_AVAILABLE: true
   unique_part_types count: 9
   First part label data:
      uid: "ANC-2501-001"
      part_code: "PLY-600x400x18-001"
      label_payload: present
   ✅ Using LABELED table format (Part Code + QR columns)
...
🏷️  PDF RENDER - PARTS LIST SECTION:
   labels_enabled: true
   parts_placed count: 42
   ✅ Using LABELED table format (Part Code + QR columns)
...
DEBUG: ✓ PDF generated successfully
```

**Key indicators:**
- ✅ `labels_enabled: true`
- ✅ `uid: "ANC-2501-001"` (NOT nil)
- ✅ `part_code: "PLY-600x400x18-001"` (NOT nil)
- ✅ `✅ Using LABELED table format`

---

### Step 5: Check PDF

Open the exported PDF and verify:

#### Unique Parts Section
**Table headers:**
```
| Part Code | QR | Name | Width (mm) | Height (mm) | Thickness (mm) | Material | Grain | Qty | Area (m²) |
```

**Example row:**
```
| PLY-600x400x18-001 | ANC-2501-001 | Cupboard_Side | 600.0 | 400.0 | 18.0 | Plywood | Vertical | 2 | 0.48 |
```

#### Cut List & Part Details Section
**Table headers:**
```
| Part Code | QR | Name | Dimensions (mm) | Material | Sheet # | Grain |
```

**Example row:**
```
| PLY-600x400x18-001 | ANC-2501-001 | Cupboard_Side | 600.0 x 400.0 | Plywood | 1 | Vertical |
```

---

## ❌ What You're Currently Seeing (Wrong)

### Console Output (Current - Wrong)
```
DEBUG: print_pdf callback STARTED - Using Ruby PDF Exporter
...
→ Rendering parts list section (NEW PAGE) (42 parts)...
...
DEBUG: ✓ PDF generated successfully
```

**Missing:**
- ❌ No `🏷️ LABEL GENERATION CHECK:`
- ❌ No `🏷️ Calling LabelGenerator.generate_labels...`
- ❌ No `UID: "ANC-2501-001"`

**This proves you're using cached results!**

### PDF Output (Current - Wrong)
**Unique Parts Section:**
```
| Name | Width (mm) | Height (mm) | Thickness (mm) | Material | Grain | Edge Banding | Qty | Total Area (m²) | Weight (kg) |
```

**Cut List Section:**
```
| Part ID | Name | Dimensions (mm) | Material | Sheet # | Grain | Edge Banding |
```

**Missing:**
- ❌ No "Part Code" column
- ❌ No "QR" column

---

## 🔍 Comparison

### BEFORE (Cached Results - What You See Now)
```
Console:
  → Rendering parts list section (NEW PAGE) (42 parts)...
  
PDF:
  | Part ID | Name | Dimensions | Material | Sheet # | Grain | Edge Banding |
  | P1      | Side | 600 x 400  | Plywood  | 1       | Vert  | None         |
```

### AFTER (Fresh Nesting - What You Should See)
```
Console:
  🏷️ LABEL GENERATION CHECK:
  🏷️ Calling LabelGenerator.generate_labels...
  ✅ Label generation complete - 42 parts labeled
  UID: "ANC-2501-001"
  
PDF:
  | Part Code          | QR           | Name | Dimensions | Material | Sheet # | Grain |
  | PLY-600x400x18-001 | ANC-2501-001 | Side | 600 x 400  | Plywood  | 1       | Vert  |
```

---

## 🚨 Critical Difference

**The key is in the console output DURING NESTING:**

### ❌ Cached (Wrong)
```
DEBUG: optimize_boards completed in 1234.5ms
DEBUG: Total thread execution time: 1456.7ms
```
No label generation messages!

### ✅ Fresh (Correct)
```
DEBUG: optimize_boards completed in 1234.5ms

🏷️ LABEL GENERATION CHECK:
   enable_part_labels setting: true
   🏷️ Calling LabelGenerator.generate_labels...
   ✅ Label generation complete - 42 parts labeled
   UID: "ANC-2501-001"

DEBUG: Total thread execution time: 1456.7ms
```
Label generation happens between nesting and thread completion!

---

## 📋 Quick Checklist

Run through this checklist:

1. [ ] Run `TEST_QR_LABELS_SIMPLE.rb`
2. [ ] See "✅ ALL CHECKS PASSED!"
3. [ ] Close AutoNestCut dialog
4. [ ] Select components
5. [ ] Run AutoNestCut
6. [ ] Click "Process" button
7. [ ] See `🏷️ LABEL GENERATION CHECK:` in console
8. [ ] See `UID: "ANC-XXXX-XXX"` in console (not nil)
9. [ ] Export PDF
10. [ ] See "Part Code" column in PDF
11. [ ] See "QR" column in PDF
12. [ ] See part codes like "PLY-600x400x18-001"

If ALL checkboxes are checked, the feature is working! ✅

