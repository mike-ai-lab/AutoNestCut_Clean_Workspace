# L-Shape Test Guide

## What is Being Tested?

This guide explains the L-shape detection and processing tests for AutoNestCut's non-rectangular shape support.

## L-Shape Definition

An **L-shape** is a polygon with 6 vertices that forms an "L" pattern:

```
┌─────────┐
│         │
│    ┌────┘
│    │
│    │
└────┘
```

### Vertex Order (Counter-Clockwise)

```
v1 (0,0) ────────── v2 (100,0)
│                        │
│                        │
│                   v3 (100,50)
│                        │
v6 (0,100)          v4 (50,50)
│                        │
│                        │
└────────────────── v5 (50,100)
```

### Coordinates Example

Standard 100x100mm L-shape with 50x50mm cutout:

```ruby
l_vertices = [
  { x: 0, y: 0 },      # Bottom-left corner
  { x: 100, y: 0 },    # Bottom-right corner
  { x: 100, y: 50 },   # Inner corner (right)
  { x: 50, y: 50 },    # Inner corner (center)
  { x: 50, y: 100 },   # Inner corner (left)
  { x: 0, y: 100 }     # Top-left corner
]
```

## Test Suite Overview

### Test 1: L-Shape Detection

**Purpose:** Verify the system correctly identifies L-shaped geometry

**Test Cases:**
1. Standard L-shape (100x100 with 50x50 cutout)
2. Rotated L-shape (90° rotation)
3. Large L-shape (typical furniture dimensions)

**Expected Results:**
- Shape type detected as `:l_shape`
- Bounding box: 100x100mm
- Area: 7500mm² (calculated as 100×50 + 50×50)
- Convex: false (L-shapes are concave)

### Test 2: L-Shape Collision Detection

**Purpose:** Verify accurate collision detection using SAT algorithm

**Test Cases:**

#### 2.1 No Collision (Separated)
```
L-Shape          Rectangle
┌────┐           ┌────┐
│  ┌─┘           │    │
└──┘             └────┘
```
Expected: No collision

#### 2.2 Collision (Overlapping)
```
L-Shape + Rectangle
┌────┐
│ ┌[█]┘  ← Overlap
└─┘
```
Expected: Collision detected

#### 2.3 In Cutout Area
```
L-Shape with Rectangle in cutout
┌────────┐
│    [█] │  ← Rectangle in cutout
│    ┌───┘
└────┘
```
Expected: **NO collision** (rectangle is in the empty cutout area)

**Critical Test:** This validates that the SAT algorithm correctly handles concave shapes!

#### 2.4 L-Shape Interlocking
```
Two L-Shapes that could interlock
┌────┐    ┌────┐
│  ┌─┘    └─┐  │
└──┘        └──┘
```
Note: Interlocking optimization not yet implemented (Phase 4)

### Test 3: L-Shape Rotation

**Purpose:** Verify rotation preserves shape properties

**Test Cases:**
- 90° rotation (standard)
- 180° rotation (flip)
- 45° rotation (arbitrary angle)

**Expected Results:**
- Area remains constant
- Bounding box updates correctly
- Shape type remains `:l_shape`

### Test 4: Bounding Box Accuracy

**Purpose:** Verify bounding box calculation

**For 100x100mm L-shape:**
- Expected bounding box: {x: 0, y: 0, width: 100, height: 100}
- Expected area: 7500mm²

### Test 5: SketchUp Component Integration

**Purpose:** Test with actual SketchUp geometry

**Requirements:**
1. Create an L-shaped face in SketchUp
2. Make it a component or group
3. Select it
4. Run test

**Expected Output:**
```
Part name: L-Shape Component
Dimensions: 100.0 x 100.0 x 18.0 mm
Shape type: l_shape
Is rectangular: NO
Vertices count: 6
Convex: false
Complexity score: 2
```

### Test 6: Nesting Simulation

**Purpose:** Verify board nesting structure supports L-shapes

**Validates:**
- Board can accept non-rectangular parts
- Collision detection methods available
- Shape-aware placement logic exists

## How to Run Tests

### Quick Test (All Tests)

```ruby
load 'TEST_L_SHAPE_DETAILED.rb'
LShapeTest.run_all_tests
```

### Individual Tests

```ruby
# Test detection only
LShapeTest.test_l_shape_detection

# Test collision only
LShapeTest.test_l_shape_collision

# Test rotation only
LShapeTest.test_l_shape_rotation

# Test bounding box
LShapeTest.test_l_shape_bounding_box

# Test with SketchUp component (requires selection)
LShapeTest.test_l_shape_with_sketchup_component

# Test nesting structure
LShapeTest.test_l_shape_nesting
```

## Creating L-Shape Components in SketchUp

### Method 1: Draw Manually

1. Select Rectangle tool
2. Draw 100mm x 100mm rectangle
3. Draw 50mm x 50mm rectangle in corner
4. Select Push/Pull tool
5. Push inner rectangle to create cutout
6. Make component

### Method 2: Ruby Console

```ruby
model = Sketchup.active_model
entities = model.active_entities

# Start operation
model.start_operation('Create L-Shape', true)

# Create L-shape face
points = [
  [0, 0, 0],
  [100.mm, 0, 0],
  [100.mm, 50.mm, 0],
  [50.mm, 50.mm, 0],
  [50.mm, 100.mm, 0],
  [0, 100.mm, 0]
]

face = entities.add_face(points)

# Make it a component
definition = model.definitions.add("L-Shape")
instance = definition.entities.add_face(points)
component = entities.add_instance(definition, Geom::Transformation.new)

model.commit_operation
```

## Expected Test Results

### ✅ PASS Criteria

- **Detection:** Shape type = `:l_shape`
- **Collision:** Correctly detects overlaps and non-overlaps
- **Cutout Test:** Rectangle in cutout does NOT collide
- **Rotation:** Area preserved, bounding box updates
- **Bounding Box:** Matches expected dimensions
- **Area:** Matches calculated area (7500mm² for standard L)

### ❌ FAIL Indicators

- Shape detected as `:rectangle` or `:polygon` instead of `:l_shape`
- Collision detection fails cutout test
- Area changes after rotation
- Bounding box incorrect

## Troubleshooting

### Issue: L-Shape Detected as Rectangle

**Cause:** Component may have bounding box instead of actual face

**Solution:**
1. Ensure component has a single L-shaped face
2. Check face is properly closed (no gaps)
3. Verify 6 vertices in correct order

### Issue: Collision in Cutout Area

**Cause:** SAT algorithm may not be working correctly

**Solution:**
1. Check vertex order (should be counter-clockwise)
2. Verify shape is properly detected as L-shape
3. Review SAT implementation in shape.rb

### Issue: Area Incorrect

**Cause:** Vertex order or calculation error

**Solution:**
1. Verify vertices are in counter-clockwise order
2. Check for self-intersecting polygons
3. Recalculate expected area manually

## Performance Benchmarks

### Expected Performance

| Test | Expected Time |
|------|---------------|
| Shape Detection | < 1ms |
| Collision Check | < 0.01ms |
| Rotation | < 1ms |
| Bounding Box | < 0.1ms |

### Performance Notes

- L-shape collision is ~10x slower than rectangle
- Still acceptable for typical projects (< 100 parts)
- Bounding box pre-check optimizes performance

## Visual Reference

### L-Shape Variations

```
Standard L          Rotated 90°        Rotated 180°       Rotated 270°
┌────┐              ┌────┐             ┌────┐             ┌────┐
│  ┌─┘              └─┐  │             │  └─┐             │  ┌─┘
└──┘                  └──┘             └────┘             └──┘
```

### Collision Scenarios

```
No Collision        Collision          In Cutout          Edge Touch
┌──┐  ┌──┐         ┌──┐               ┌────┐             ┌──┐┌──┐
│  │  │  │         │ [█] │             │ [█]│             │  ││  │
└──┘  └──┘         └──┘               └┘   └             └──┘└──┘
```

## Next Steps

After L-shape tests pass:

1. ✅ Validate with real SketchUp geometry
2. ✅ Test nesting with multiple L-shapes
3. ✅ Test mixed rectangular and L-shaped parts
4. 🔄 Proceed to Phase 3 (rendering updates)
5. 📋 Plan Phase 4 (interlocking optimization)

## Summary

The L-shape test suite validates:
- ✅ Accurate shape detection (6 vertices, angle pattern)
- ✅ Correct collision detection (SAT algorithm)
- ✅ Proper handling of concave geometry
- ✅ Rotation support (arbitrary angles)
- ✅ Integration with Part and Board classes

**Critical Success Factor:** The cutout test (2.3) is the most important - it proves the system handles concave shapes correctly!

---

**Test File:** `TEST_L_SHAPE_DETAILED.rb`
**Documentation:** `NON_RECTANGULAR_SHAPES_IMPLEMENTATION.md`
**Status:** Ready for Testing ✅
