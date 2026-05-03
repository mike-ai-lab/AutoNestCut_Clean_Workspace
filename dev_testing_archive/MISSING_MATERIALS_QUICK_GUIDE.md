# Missing Materials Dialog - Quick User Guide

## When Does This Appear?

This dialog appears when you run AutoNestCut and some materials in your model are not found in your materials database.

---

## Quick Start (60 Materials in 10 Seconds)

### All Materials Same Type?
1. ✅ Click **"Select All"** checkbox (top left)
2. ✅ Click **"Create Standard Sheet"** button (top right)
3. ✅ Enter dimensions: Width, Height, Price
4. ✅ Check **"Add all to favorites"** ⭐
5. ✅ Click **"Apply to Selected"**
6. ✅ Click **"Continue"**

**Done!** All materials configured in one go.

---

## The Three Action Types

### 📦 Use Existing Material
**When to use**: Material already exists in your database with a different name

**What it does**: Maps the missing material to an existing stock material

**Example**: 
- Missing: "Plywood_18mm_Kitchen"
- Map to: "Standard Plywood 18mm" (from database)

### 📋 Create Standard Sheet
**When to use**: Need to create a new sheet material (most common)

**What it does**: Creates a new material with standard sheet dimensions

**Example**:
- Material: "Plywood 18mm"
- Dimensions: 2440×1220mm
- Price: $50.00
- ✅ Save to database
- ✅ Add to favorites

### ✂️ Create Custom Part
**When to use**: Specialty materials cut to exact size (glass, metal, etc.)

**What it does**: Creates parts with exact component dimensions (not saved to database)

**Example**:
- Material: "Glass 6mm"
- Each component gets its exact dimensions
- Not saved (one-time use)

---

## Bulk Actions Guide

### Select Multiple Materials

**Method 1: Select All**
- Click "Select All" checkbox at top
- All materials selected instantly

**Method 2: Individual Selection**
- Click checkbox next to each material
- Selection counter shows "X selected"

**Method 3: Mixed Selection**
- Select some materials
- Apply action
- Select different materials
- Apply different action

### Apply Bulk Actions

1. **Select materials** (checkboxes)
2. **Click bulk action button** (top right)
3. **Configure once** in modal
4. **Click "Apply to Selected"**
5. **Done!** All selected materials configured

---

## Material Preview

### What You See Before Creating

Each material shows a **preview panel** with full details:

#### For Standard Sheet:
```
📋 New Standard Sheet Material
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Material Name: [Edit here]
Thickness: 18mm (from component)
Width: 2440mm [Edit]
Height: 1220mm [Edit]
Price: $50.00 [Edit]

⭐ Add to Favorites
💾 Save to Database
```

#### For Existing Material:
```
📦 Material Mapping Preview
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Select Stock Material:
[Dropdown with matching materials]
```

#### For Custom Part:
```
✂️ Custom Cut-to-Size Parts
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Material: Glass 6mm
Thickness: 6mm
Parts: 5 component(s) with exact dimensions
⚠️ Not saved to database
```

---

## Favorites Feature

### Why Use Favorites?

When you create many new materials, favorites help you find them later.

### How to Use:

**Step 1: During Material Creation**
- Check ⭐ **"Add to Favorites"** when creating materials
- Can be done individually or in bulk

**Step 2: Later in Materials Stock**
- Open Materials Stock window
- Click **"Favorites"** filter
- See only the materials you marked
- Easy to edit, manage, or remove

**Example Workflow**:
```
1. Create 20 new materials → Mark as favorites
2. Continue with nesting
3. Later: Need to adjust prices
4. Open Materials Stock → Filter: Favorites
5. See only those 20 materials
6. Edit quickly without searching
```

---

## Common Workflows

### Workflow 1: All Same Material Type (Fastest)
**Scenario**: 60 plywood sheets, all 18mm, all 2440×1220

```
1. Select All
2. Create Standard Sheet (bulk)
3. Set: 2440×1220, $50
4. Add to favorites
5. Apply
6. Continue
```
⏱️ **Time: 10 seconds**

---

### Workflow 2: Multiple Material Types
**Scenario**: 40 plywood, 15 glass, 5 existing stock

```
1. Select first 40 materials
2. Create Standard Sheet → Apply
3. Select next 15 materials
4. Create Custom Parts → Apply
5. Select last 5 materials
6. Use Existing Material → Select stock → Apply
7. Continue
```
⏱️ **Time: 30 seconds**

---

### Workflow 3: Individual Configuration
**Scenario**: 5 materials, each needs different settings

```
For each material:
1. Click action button (Standard/Existing/Custom)
2. Configure in preview panel
3. Check "Add to Favorites" if needed
4. Move to next material
5. Continue when all resolved
```
⏱️ **Time: 2 minutes**

---

## Progress Tracking

### Footer Information
```
60 material(s) to resolve • 45 resolved
```

- **Left number**: Total materials needing action
- **Right number**: Materials you've configured
- **Continue button**: Disabled until all resolved

### Visual Feedback
- ✅ **Resolved materials**: Show configured action in preview
- ⚠️ **Unresolved materials**: No action selected yet
- 🔵 **Selected materials**: Blue border and background

---

## Tips & Tricks

### 💡 Tip 1: Group by Thickness
Select all materials with same thickness, apply bulk action, repeat for next thickness.

### 💡 Tip 2: Use Favorites Liberally
Mark materials as favorites during creation. You can always remove the favorite later.

### 💡 Tip 3: Standard Dimensions
Most common: 2440×1220mm (8'×4')
Also common: 2800×2070mm, 3050×1220mm

### 💡 Tip 4: Price Later
Set price to $0 now, update in Materials Stock later using favorites filter.

### 💡 Tip 5: Expandable Component List
Click "View X component(s)" to see which parts use each material.

---

## Keyboard Shortcuts

- **Tab**: Navigate between fields
- **Enter**: Confirm in modal
- **Escape**: Close modal (cancel)
- **Space**: Toggle checkbox (when focused)

---

## Troubleshooting

### "Continue" Button Disabled?
- ✅ Check footer: "X resolved" must equal "X to resolve"
- ✅ Ensure all materials have an action selected
- ✅ For "Use Existing", ensure material is selected from dropdown

### Can't Find Matching Material?
- ✅ Use "Create Standard Sheet" instead
- ✅ Or create material in Materials Stock first, then retry

### Made a Mistake?
- ✅ Just select the material again and choose different action
- ✅ Or click Cancel and start over

### Too Many Materials?
- ✅ Use bulk actions! Select groups and apply
- ✅ Don't configure one-by-one

---

## Summary

### Key Features
- ✅ Bulk selection and actions
- ✅ Material preview before creation
- ✅ Favorites integration
- ✅ Progress tracking
- ✅ Three action types

### Time Savings
- **Before**: 30 minutes for 60 materials
- **After**: 10-30 seconds for 60 materials
- **Savings**: 99% faster!

### Remember
1. **Select** materials (individually or all)
2. **Choose** action (bulk buttons or individual)
3. **Configure** once (applies to all selected)
4. **Add to favorites** for easy management
5. **Continue** when all resolved

---

**Need Help?** Check the component list to see which parts use each material, or use the preview panel to verify settings before applying.

**Pro Tip**: For large projects, use bulk actions for 99% of materials, then fine-tune the few special cases individually. 🚀
