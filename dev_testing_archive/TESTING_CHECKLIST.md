# Testing Checklist - New Configuration Tab

## ✅ Pre-Testing Setup

- [ ] Backup created: `config_tab_current_backup.html`
- [ ] New file exists: `config_tab_new_complete.html`
- [ ] `dialog_manager.rb` updated
- [ ] SketchUp closed and reopened

---

## 🚀 Basic Functionality Tests

### Extension Loading
- [ ] Extension loads without errors
- [ ] Toolbar button appears
- [ ] Menu items present under Extensions > AutoNestCut

### Dialog Opening
- [ ] Click toolbar button opens dialog
- [ ] Dialog shows new design (not old)
- [ ] No console errors in dialog
- [ ] All sections visible

---

## 📋 Section Tests

### 1. Project Configuration Section
- [ ] Section header visible
- [ ] Click header to collapse
- [ ] Click again to expand
- [ ] Animation is smooth (not jumpy)
- [ ] Form fields visible when expanded:
  - [ ] Project Name input
  - [ ] Client Name input
  - [ ] Prepared By input
  - [ ] Kerf Width input
  - [ ] Allow Rotation checkbox
- [ ] Can type in all fields
- [ ] Values save correctly

### 2. Selection Status Section
- [ ] Section header visible
- [ ] Collapses/expands smoothly
- [ ] Shows "No selection" when nothing selected
- [ ] Shows tree view when components selected
- [ ] Tree structure displays correctly

### 3. Components Found Section
- [ ] Section header shows count: "Components Found (X)"
- [ ] Count updates when selection changes
- [ ] Collapses/expands smoothly
- [ ] Table shows when expanded:
  - [ ] Component column
  - [ ] Width column
  - [ ] Height column
  - [ ] Thickness column
  - [ ] Material column
- [ ] Shows "No components found" when empty
- [ ] Populates with data when components selected

### 4. Parts Preview + 3D Canvas
- [ ] Two containers side-by-side
- [ ] Equal width for both containers
- [ ] Clean spacing between containers
- [ ] No overlapping

#### Parts Table (Left)
- [ ] Blue header: "Parts Preview"
- [ ] Table scrolls if many parts
- [ ] Columns visible:
  - [ ] Component Name
  - [ ] Width (mm)
  - [ ] Height (mm)
  - [ ] Thickness (mm)
  - [ ] Material
  - [ ] Qty
  - [ ] Area (m²)
- [ ] Rows highlight on hover
- [ ] Click row to select

#### 3D Canvas (Right)
- [ ] Blue header: "3D Component Viewer"
- [ ] Placeholder text visible initially:
  - [ ] "Click any component to view in 3D"
  - [ ] "Rotate: Left Click + Drag"
  - [ ] "Zoom: Scroll"
- [ ] Text is NOT clipped or cut off
- [ ] Text is centered properly
- [ ] Click part in table shows 3D model
- [ ] Placeholder disappears when model shows
- [ ] 3D model renders correctly
- [ ] Model rotates automatically
- [ ] Can drag to rotate manually
- [ ] Scroll to zoom works
- [ ] Info panel at bottom shows:
  - [ ] Selected part name
  - [ ] Dimensions
  - [ ] Volume

### 5. Stock Materials & Pricing Section
- [ ] Section header visible
- [ ] Collapses/expands smoothly
- [ ] Toolbar visible with buttons:
  - [ ] Add Material
  - [ ] Load Defaults
  - [ ] Import CSV
  - [ ] Export Database
- [ ] Filter controls visible:
  - [ ] "Used Only" checkbox
  - [ ] Sort dropdown
- [ ] Table shows materials:
  - [ ] Material Name
  - [ ] Width (mm)
  - [ ] Height (mm)
  - [ ] Thickness (mm)
  - [ ] Density (kg/m³)
  - [ ] Price per Sheet
  - [ ] Actions (Edit/Delete buttons)
  - [ ] Status (Used/Unused indicator)
- [ ] Can click Edit button
- [ ] Can click Delete button
- [ ] Status indicator shows correct color

---

## 🎨 Visual Tests

### Spacing & Layout
- [ ] 40px gap between sections
- [ ] 20px padding in container
- [ ] No elements touching edges
- [ ] Clean visual hierarchy

### Colors
- [ ] Primary blue (#2323FF) on headers
- [ ] White backgrounds
- [ ] Gray borders (#d0d7de)
- [ ] Hover states work

### Typography
- [ ] Inter font loads correctly
- [ ] Text is readable
- [ ] Font sizes appropriate
- [ ] No text overflow

### Animations
- [ ] All sections collapse smoothly
- [ ] All sections expand smoothly
- [ ] No jumpy movements
- [ ] 0.3s duration feels right

---

## 🔄 Data Flow Tests

### Ruby → JavaScript
- [ ] Initial data loads
- [ ] Parts data displays
- [ ] Materials data displays
- [ ] Settings populate correctly

### JavaScript → Ruby
- [ ] Save materials works
- [ ] Update settings works
- [ ] Process button works
- [ ] Export functions work

### Callbacks
- [ ] `ready` callback fires
- [ ] `update_global_setting` works
- [ ] `save_materials` works
- [ ] `process` works
- [ ] `export_csv` works
- [ ] `export_interactive_html` works
- [ ] All other callbacks functional

---

## 🎯 Integration Tests

### With Existing Features
- [ ] Nesting process works
- [ ] Report generation works
- [ ] PDF export works
- [ ] CSV export works
- [ ] Material highlighting works
- [ ] Component refresh works

### Error Handling
- [ ] Invalid data shows error
- [ ] Missing data shows message
- [ ] Network errors handled
- [ ] Console shows helpful errors

---

## 🐛 Edge Cases

### Empty States
- [ ] No components selected
- [ ] No materials defined
- [ ] No parts to display
- [ ] All show appropriate messages

### Large Data Sets
- [ ] 100+ parts load correctly
- [ ] Table scrolls smoothly
- [ ] 3D canvas performs well
- [ ] No lag or freezing

### User Actions
- [ ] Rapid clicking doesn't break
- [ ] Multiple selections work
- [ ] Undo/redo compatible
- [ ] Browser back button safe

---

## 📱 Browser Compatibility

### SketchUp WebDialog
- [ ] Works in SketchUp 2020
- [ ] Works in SketchUp 2021
- [ ] Works in SketchUp 2022
- [ ] Works in SketchUp 2023+

### External Testing (Optional)
- [ ] Chrome browser
- [ ] Firefox browser
- [ ] Edge browser

---

## 🔐 Security Tests

### Data Safety
- [ ] No data leaks
- [ ] Local storage only
- [ ] No external calls (except Three.js CDN)
- [ ] No tracking

### Input Validation
- [ ] Numeric fields accept numbers only
- [ ] Required fields validated
- [ ] No SQL injection possible
- [ ] No XSS vulnerabilities

---

## 📊 Performance Tests

### Load Time
- [ ] Dialog opens in <1 second
- [ ] Initial data loads quickly
- [ ] No noticeable delay

### Runtime Performance
- [ ] Smooth scrolling
- [ ] Responsive interactions
- [ ] No memory leaks
- [ ] CPU usage reasonable

### 3D Canvas
- [ ] Renders at 60fps
- [ ] Rotation is smooth
- [ ] Zoom is responsive
- [ ] No stuttering

---

## 🎉 Final Checks

### User Experience
- [ ] Interface is intuitive
- [ ] Actions are clear
- [ ] Feedback is immediate
- [ ] No confusion

### Documentation
- [ ] INTEGRATION_SUMMARY.md complete
- [ ] QUICK_REFERENCE.md helpful
- [ ] This checklist useful

### Rollback Plan
- [ ] Backup file exists
- [ ] Rollback instructions clear
- [ ] Can revert if needed

---

## ✅ Sign-Off

### Tested By: _______________
### Date: _______________
### SketchUp Version: _______________
### Result: ⬜ PASS  ⬜ FAIL  ⬜ NEEDS WORK

### Notes:
```
[Add any issues, observations, or recommendations here]
```

---

## 🚀 Deployment Checklist

If all tests pass:
- [ ] Commit changes to version control
- [ ] Tag release version
- [ ] Update changelog
- [ ] Notify users of update
- [ ] Monitor for issues

---

**Testing Date**: _______________
**Tester**: _______________
**Status**: ⬜ In Progress  ⬜ Complete  ⬜ Failed
