# Nesting Efficiency Fix - Grid Step Optimization

## Problem Identified

From the screenshot showing Board 1 with **46.8% efficiency**, the nesting algorithm was placing parts very inefficiently:

### Issues Observed:
1. **P4** (700x378mm) placed with large gaps around it
2. Huge empty space between P4 and P3
3. Small 405mm parts stacked vertically instead of optimally placed
4. **P6** (L-shape 600x378mm) placed at bottom-left with poor space utilization
5. Overall efficiency of only **46.8%** (should be 55-65% for mixed shapes)

### Root Cause:
The `find_position_with_grid_search` method was using a **50mm grid step**, meaning it only tried positions at:
- X: 0, 50, 100, 150, 200, 250, 300... mm
- Y: 0, 50, 100, 150, 200, 250, 300... mm

This coarse grid caused the algorithm to:
- Miss many valid tight-fitting positions
- Leave large gaps between parts
- Fail to utilize available space efficiently

## Solution Implemented

### Changes to `Extension/AutoNestCut/models/board.rb`:

**1. Prioritize Free Rectangle Positions**
- Try free rectangle corners FIRST (where rectangular parts would go)
- These are the most efficient positions
- Sorted by Y then X for bottom-left preference

**2. Reduced Grid Step Size**
- Changed from **50mm** to **10mm** grid step
- This provides 5x more position candidates
- Allows much tighter packing

**3. Improved Search Order**
```ruby
# OLD APPROACH:
1. Grid search with 50mm steps (coarse)
2. Free rectangles as fallback

# NEW APPROACH:
1. Free rectangles FIRST (most efficient)
2. Fine grid search with 10mm steps (comprehensive)
```

### Code Changes:

**Before**:
```ruby
def find_position_with_grid_search(part, kerf_width)
  grid_step = 50.0 # Too coarse!
  
  # Grid search first
  y = 0
  while y + effective_part_height <= @stock_height
    x = 0
    while x + effective_part_width <= @stock_width
      # Try position...
      x += grid_step
    end
    y += grid_step
  end
  
  # Free rectangles as fallback
  @free_rectangles.each do |fr_x, fr_y, fr_w, fr_h|
    # Try position...
  end
end
```

**After**:
```ruby
def find_position_with_grid_search(part, kerf_width)
  # FIRST: Try free rectangle corners (most efficient)
  @free_rectangles.sort_by { |fr| [fr[1], fr[0]] }.each do |fr_x, fr_y, fr_w, fr_h|
    if effective_part_width <= fr_w && effective_part_height <= fr_h
      if can_fit_part_within_board_bounds?(part, fr_x, fr_y, kerf_width)
        if !collides_with_existing_parts?(part, fr_x, fr_y, kerf_width)
          return [fr_x, fr_y]
        end
      end
    end
  end
  
  # SECOND: Fine grid search with 10mm steps
  grid_step = 10.0 # Much finer!
  
  y = 0
  while y + effective_part_height <= @stock_height
    x = 0
    while x + effective_part_width <= @stock_width
      # Try position...
      x += grid_step
    end
    y += grid_step
  end
end
```

## Expected Improvements

### Efficiency Gains:
- **Before**: 46.8% efficiency (your screenshot)
- **Expected After**: 55-65% efficiency for mixed rectangular/irregular shapes
- **Improvement**: ~10-20% better material utilization

### Better Placement:
- Parts will be placed closer together
- Less wasted space between parts
- Better utilization of free rectangles
- Tighter packing overall

### Performance Impact:
- Grid search now tries 5x more positions (10mm vs 50mm steps)
- But free rectangles are tried FIRST (fast path)
- Most parts will find positions in free rectangles
- Grid search only used when free rectangles don't work
- Overall performance should be similar or slightly slower, but much better results

## Testing Instructions

1. **Reload the extension** in SketchUp:
   ```ruby
   # In Ruby Console:
   load 'Extension/autonestcut.rb'
   ```

2. **Run the test script** with your components selected:
   ```ruby
   load 'TEST_NESTING_EFFICIENCY.rb'
   ```

3. **Generate a new report** with the same components:
   - Select the same components from your screenshot
   - Run AutoNestCut
   - Compare the new efficiency percentage

4. **Expected Results**:
   - Efficiency should increase from 46.8% to 55-65%
   - Parts should be placed more tightly
   - Less wasted space visible in diagrams

## Why This Fix Works

### Free Rectangles First:
- Free rectangles represent the "best" available spaces
- They're already sorted and optimized
- Trying them first ensures we use the most efficient positions

### Finer Grid:
- 10mm steps provide much better granularity
- Can find positions that 50mm steps would miss
- Allows parts to fit into smaller gaps

### Bottom-Left Preference:
- Sorting free rectangles by [Y, X] ensures bottom-left placement
- This creates more usable space at the top-right
- Better for subsequent parts

## Verification

After applying this fix, you should see:

✅ **Higher efficiency** (55-65% instead of 46.8%)
✅ **Tighter packing** (less visible gaps)
✅ **Better space utilization** (parts closer together)
✅ **Fewer boards needed** (for large projects)

If efficiency is still below 50%, there may be other issues with:
- Part dimensions (check if parts are too large for sheet)
- Kerf width (check if kerf is too large)
- Shape collision detection (check if shapes are colliding incorrectly)

## Additional Notes

### Why Not Even Finer Grid (5mm or 1mm)?
- 10mm provides good balance between accuracy and performance
- Finer grids would be much slower (4x slower for 5mm, 100x slower for 1mm)
- 10mm is sufficient for most woodworking applications
- Free rectangles already provide exact positions for most cases

### Why Not Just Use Free Rectangles?
- Free rectangles work perfectly for rectangular parts
- For irregular shapes, free rectangles may not account for the actual shape geometry
- Grid search is needed as a fallback for complex shapes
- But trying free rectangles first ensures we use them when possible

---

**Status**: Fix applied to `Extension/AutoNestCut/models/board.rb`
**Test Script**: `TEST_NESTING_EFFICIENCY.rb` created for verification
**Expected Result**: 10-20% efficiency improvement for your test case
