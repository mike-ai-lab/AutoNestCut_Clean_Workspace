# Irregular Shapes - Quick Start Guide

## What's New?

AutoNestCut now supports **non-rectangular shapes**! You can nest L-shapes, T-shapes, circles, and other irregular geometries with accurate area calculations and intelligent placement.

## Supported Shapes

✅ **L-Shapes** - Corner pieces, brackets  
✅ **T-Shapes** - Beams, dividers  
✅ **U-Shapes** - Channels, brackets  
✅ **Plus-Shapes** - Cross braces  
✅ **Circles** - Round table tops, wheels  
✅ **Hexagons** - Decorative tiles  
✅ **Trapezoids** - Tapered panels  
✅ **Any Polygon** - Up to 50 vertices  

## How to Use

### 1. Create Your Shape in SketchUp

```
1. Draw the shape profile on a face
2. Use Push/Pull to extrude to thickness
3. Make it a Group or Component
4. Assign material (optional)
```

### 2. Run AutoNestCut

```
1. Select your components (mix rectangular and irregular)
2. Extensions → AutoNestCut → Generate Cut List
3. Configure settings
4. Generate report
```

### 3. View Results

Your irregular shapes will:
- ✅ Show actual shape outline (not bounding box)
- ✅ Calculate accurate area (saves material)
- ✅ Nest without overlapping
- ✅ Display correctly in diagrams

## Try It Now!

### Generate Test Shapes

Open SketchUp Ruby Console and run:

```ruby
load 'GENERATE_IRREGULAR_SHAPES.rb'
```

This creates 7 test shapes you can nest immediately!

### Test the Feature

```ruby
load 'TEST_ALL_IRREGULAR_SHAPES.rb'
```

This validates shape detection and nesting.

## Key Benefits

### Accurate Material Calculation
**Before**: L-shape counted as full rectangle (403,200 mm²)  
**Now**: Actual L-shape area (271,673 mm²)  
**Savings**: 33% more accurate material estimates!

### Better Nesting
- Parts nest using actual geometry
- No wasted space from bounding boxes
- Intelligent placement algorithm

### Visual Accuracy
- Diagrams show real shapes
- Grain patterns follow shape
- Professional-looking reports

## Tips

💡 **Keep shapes simple** - Under 50 vertices for best performance  
💡 **Use single faces** - One continuous face per component  
💡 **Test first** - Use test generator to verify before production  
💡 **Mix shapes** - Combine rectangular and irregular parts freely  

## Troubleshooting

**Q: My shape shows as a rectangle**  
A: Make sure it's a single face, not multiple faces

**Q: Parts overlap in diagram**  
A: Reload extension and regenerate report

**Q: Nesting is slow**  
A: Simplify shapes with many vertices

## Need Help?

- Check `NON_RECTANGULAR_SHAPES_COMPLETE.md` for detailed documentation
- Run test scripts to validate your setup
- Contact support with screenshots if issues persist

---

**Status**: ✅ Feature is live and ready to use!

**Enjoy more accurate nesting with irregular shapes!** 🎉
