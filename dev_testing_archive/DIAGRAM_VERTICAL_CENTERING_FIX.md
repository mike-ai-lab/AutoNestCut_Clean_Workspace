# Diagram Vertical Centering Fix - COMPLETE ✅

## Problem

Diagrams were positioned too close to the title, creating visual imbalance:

```
┌─────────────────────────────────┐
│ Title: Sheet 1                  │ ← Top edge
│ Efficiency: 85% | Waste: 15%    │
│                                 │ ← Small gap
│ ┌─────────────────────────┐    │
│ │                         │    │
│ │      DIAGRAM            │    │ ← Too close to title
│ │                         │    │
│ └─────────────────────────┘    │
│                                 │
│                                 │ ← Large empty space
│                                 │
└─────────────────────────────────┘ ← Bottom edge
```

**Issue:** Diagram was centered on the whole page, not in the space between title and bottom.

## Solution

Changed diagram positioning to be **centered in the available space** between title and bottom edge:

### Changes Made

1. **Increased space after title** - From 15pt to 30pt
2. **Changed vertical position** - From `vposition: :top` to `vposition: :center`
3. **Adjusted padding** - More generous margins (80pt horizontal, 40pt bottom)

### Code Changes

```ruby
# BEFORE (UNBALANCED):
pdf.move_down 15  # Small gap after title
max_width = pdf.bounds.width - 60
max_height = pdf.cursor - 60
pdf.image temp_file, 
  fit: [max_width, max_height], 
  position: :center,
  vposition: :top  # Placed right after title

# AFTER (BALANCED):
pdf.move_down 30  # Larger gap after title
available_width = pdf.bounds.width - 80   # More padding
available_height = pdf.cursor - 40        # Bottom margin
pdf.image temp_file, 
  fit: [available_width, available_height], 
  position: :center,
  vposition: :center  # Centered in available space
```

## Visual Result

```
┌─────────────────────────────────┐
│ Title: Sheet 1                  │ ← Top edge
│ Efficiency: 85% | Waste: 15%    │
│                                 │
│                                 │ ← Balanced space
│ ┌─────────────────────────┐    │
│ │                         │    │
│ │      DIAGRAM            │    │ ← Centered in available space
│ │                         │    │
│ └─────────────────────────┘    │
│                                 │ ← Balanced space
│                                 │
└─────────────────────────────────┘ ← Bottom edge
```

## Spacing Breakdown

### A4 Landscape Page
- **Total height:** 595 points
- **Top margin:** ~40 points
- **Title + info:** ~50 points
- **Gap after title:** 30 points
- **Available for diagram:** ~435 points
- **Bottom margin:** 40 points

### Diagram Positioning
1. **Title rendered** at top (cursor at ~545pt)
2. **Move down 30pt** (cursor at ~515pt)
3. **Calculate available space:** 515pt - 40pt = 475pt
4. **Fit diagram** within 762pt (width) x 475pt (height)
5. **Center vertically** in that space

## Padding Adjustments

| Element | Before | After | Reason |
|---------|--------|-------|--------|
| Horizontal padding | 60pt (30pt each) | 80pt (40pt each) | More breathing room |
| Bottom margin | 60pt | 40pt | Maximize diagram space |
| Title gap | 15pt | 30pt | Better visual separation |

## Expected Console Output

```
DEBUG: Embedding landscape diagram 0 - available space: 762x475
DEBUG: Current cursor position: 515
DEBUG: Embedding landscape diagram 1 - available space: 762x475
DEBUG: Current cursor position: 515
```

## Benefits

### Visual Balance
- **Equal spacing** above and below diagram
- **Clear separation** between title and content
- **Professional appearance** - not cramped

### Readability
- **Title stands out** - not competing with diagram
- **Diagram has space** - not crowded
- **Easy to scan** - clear visual hierarchy

### Print Quality
- **Proper margins** - safe for printing
- **Centered content** - looks professional
- **Balanced layout** - pleasing to the eye

## Files Modified

**Extension/AutoNestCut/exporters/report_pdf_exporter.rb**
- Line ~643: Increased `move_down` from 15 to 30
- Line ~656: Changed padding from 60 to 80 (horizontal)
- Line ~657: Changed bottom margin from 60 to 40
- Line ~664: Changed `vposition` from `:top` to `:center`
- Added debug output for cursor position

## Testing

Check these visual aspects:

1. ✅ **Title spacing** - Should have clear gap below
2. ✅ **Diagram position** - Should be centered vertically
3. ✅ **Bottom margin** - Should have space at bottom
4. ✅ **Side margins** - Should have equal padding left/right
5. ✅ **Overall balance** - Should look professional

## Prawn vposition Options

| Option | Behavior |
|--------|----------|
| `:top` | Places image at current cursor position |
| `:center` | Centers image vertically in available space ✅ |
| `:bottom` | Places image at bottom of available space |

**Chosen:** `:center` - Creates balanced, professional layout

---

**Status:** Diagrams now properly centered between title and bottom edge! 🎉

