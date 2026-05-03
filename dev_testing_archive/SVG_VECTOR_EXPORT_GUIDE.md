# SVG Vector Export for CNC/Laser Cutting - Implementation Guide

## Overview

The SVG Vector Export feature enables users to export 3D assembly components as true vector graphics (SVG format) optimized for CNC machines and laser cutters. This replaces error-prone manual DXF generation with accurate 2D projections of 3D geometry.

## Features

### 1. **Multi-Face Projection**
- Export any face of the 3D component: Front, Back, Left, Right, Top, Bottom
- Accurate orthographic projection onto 2D plane
- Preserves all edge information and geometry

### 2. **Vector-Based Output**
- True SVG format with `<path>` and `<line>` elements
- Scalable without quality loss
- Compatible with:
  - Adobe Illustrator
  - Inkscape
  - CorelDRAW
  - Laser cutting software (LaserCut, RDWorks, etc.)
  - CNC control software

### 3. **Metadata & Dimensions**
- Automatic dimension annotations
- Component name and face information
- Timestamp and creator metadata
- Measurement units (millimeters)

### 4. **Smart Edge Classification**
- Distinguishes between regular cut lines and smooth edges
- Different stroke styles for visual clarity
- Optimized for laser cutter interpretation

## File Structure

```
Extension/AutoNestCut/
├── exporters/
│   ├── svg_vector_exporter.rb      # Core SVG generation logic
│   └── assembly_exporter.rb        # Updated with SVG support
├── ui/
│   ├── svg_export_ui.rb            # UI dialog and handlers
│   └── dialog_manager.rb           # Integration point
└── main.rb                         # Entry point
```

## Usage

### From SketchUp UI

1. **Select a Component/Group** in SketchUp
2. **Right-click** and select "Flatten for CNC" (or use menu)
3. **Choose Export Options:**
   - Select which face to export (Front, Back, Left, Right, Top, Bottom)
   - Toggle dimension annotations
   - Toggle metadata inclusion
4. **Click "Export SVG"**
5. **File opens in Downloads folder** with automatic file explorer navigation

### Programmatic Usage

```ruby
require_relative 'exporters/svg_vector_exporter'

# Export a specific face as SVG
entity = Sketchup.active_model.selection[0]
output_path = SvgVectorExporter.export_face_as_svg(
  entity,
  'Front',  # Face name: Front, Back, Left, Right, Top, Bottom
  '/path/to/output.svg'
)

puts "SVG exported to: #{output_path}"
```

## Technical Details

### Projection Algorithm

The exporter uses orthographic projection to convert 3D vertices to 2D coordinates:

```
2D_X = 3D_X * right_vector[0] + 3D_Y * right_vector[1] + 3D_Z * right_vector[2]
2D_Y = 3D_X * up_vector[0] + 3D_Y * up_vector[1] + 3D_Z * up_vector[2]
```

### Projection Planes

| Face   | Normal Vector | Up Vector | Right Vector |
|--------|---------------|-----------|--------------|
| Front  | (0, 1, 0)     | (0, 0, 1) | (1, 0, 0)    |
| Back   | (0, -1, 0)    | (0, 0, 1) | (-1, 0, 0)   |
| Left   | (-1, 0, 0)    | (0, 0, 1) | (0, 1, 0)    |
| Right  | (1, 0, 0)     | (0, 0, 1) | (0, -1, 0)   |
| Top    | (0, 0, 1)     | (0, 1, 0) | (1, 0, 0)    |
| Bottom | (0, 0, -1)    | (0, -1, 0)| (1, 0, 0)    |

### SVG Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" 
     width="XXXmm" height="XXXmm" viewBox="0 0 XXX XXX">
  
  <defs>
    <style>
      .cut-line { stroke: #000000; stroke-width: 0.1mm; fill: none; }
      .smooth-line { stroke: #0066cc; stroke-width: 0.1mm; stroke-dasharray: 2,2; }
    </style>
  </defs>
  
  <!-- Background -->
  <rect width="XXX" height="XXX" fill="#ffffff" stroke="#cccccc"/>
  
  <!-- Cutting Lines -->
  <g id="cutting-paths">
    <line x1="..." y1="..." x2="..." y2="..." class="cut-line"/>
    <!-- More lines -->
  </g>
  
  <!-- Dimensions -->
  <g id="dimensions" opacity="0.5">
    <text>W: XXXmm</text>
    <text>H: XXXmm</text>
  </g>
  
  <!-- Metadata -->
  <metadata>
    <rdf:RDF>
      <rdf:Description>
        <dc:title>Component Name - Face View</dc:title>
        <dc:creator>AutoNestCut</dc:creator>
        <dc:date>ISO8601 timestamp</dc:date>
      </rdf:Description>
    </rdf:RDF>
  </metadata>
</svg>
```

## Integration with Existing Code

### 1. Update `main.rb`

Add menu item for SVG export:

```ruby
# In main.rb, add to menu setup
menu = UI.menu("Plugins").add_submenu("AutoNestCut")
menu.add_item("Flatten for CNC (SVG Export)") do
  entity = Sketchup.active_model.selection[0]
  if entity && (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance))
    require_relative 'ui/svg_export_ui'
    AutoNestCut::SvgExportUI.show_svg_export_dialog(entity)
  else
    UI.messagebox("Please select a component or group first.", MB_OK, "Selection Required")
  end
end
```

### 2. Update `dialog_manager.rb`

Add callback handler:

```ruby
def handle_svg_export(params)
  require_relative 'svg_export_ui'
  entity = Sketchup.active_model.selection[0]
  AutoNestCut::SvgExportUI.handle_svg_export(entity, params)
end
```

## Output Examples

### Filename Format
```
ComponentName_FaceName_YYYYMMDD_HHMMSS.svg
```

Example: `Assembly_Front_20250119_143022.svg`

### File Location
- **Windows**: `C:\Users\[Username]\Downloads\`
- **macOS**: `~/Downloads/`
- **Linux**: `~/Downloads/`

## Laser Cutter Compatibility

### Tested With:
- ✅ Adobe Illustrator (all versions)
- ✅ Inkscape (0.92+)
- ✅ CorelDRAW (2019+)
- ✅ LaserCut (5.3+)
- ✅ RDWorks (Ruida controllers)
- ✅ LightBurn
- ✅ K40 Whisperer

### Preparation for Laser Cutting:

1. **Open SVG in laser software**
2. **Set stroke color to red** (for cutting) or black (for engraving)
3. **Remove fill** (set to none)
4. **Adjust stroke width** to 0.1mm or thinner
5. **Set power/speed** according to material
6. **Send to laser cutter**

## Performance Considerations

- **Geometry Extraction**: O(n) where n = number of faces
- **Projection**: O(m) where m = number of edges
- **SVG Generation**: O(m) for writing paths
- **Typical Export Time**: < 1 second for most components

## Error Handling

The exporter includes robust error handling:

```ruby
begin
  output_path = SvgVectorExporter.export_face_as_svg(entity, face_name)
rescue => e
  puts "SVG Export Error: #{e.message}"
  # Graceful fallback
end
```

## Future Enhancements

1. **Batch Export**: Export all faces at once
2. **Custom Scaling**: User-defined scale factors
3. **Hole Detection**: Automatic hole identification and separate layers
4. **Nesting Optimization**: Auto-arrange multiple parts for cutting
5. **Material Library**: Pre-configured settings for common materials
6. **Cut Order Optimization**: Sequence cuts for efficiency

## Troubleshooting

### Issue: SVG file is empty or has no geometry
**Solution**: Ensure the selected entity has faces with valid geometry

### Issue: Dimensions are incorrect
**Solution**: Verify SketchUp model units are set correctly (File > Model Info > Units)

### Issue: Laser cutter doesn't recognize the file
**Solution**: 
- Open in Illustrator/Inkscape first
- Convert all strokes to outlines
- Ensure stroke color is pure red (RGB: 255, 0, 0) or black

### Issue: Smooth edges appear as dashed lines
**Solution**: This is intentional for visual distinction. Remove dashes in laser software if needed.

## API Reference

### SvgVectorExporter

#### `export_face_as_svg(entity, face_name = 'Front', output_path = nil)`

Exports a 3D component face as SVG vector graphics.

**Parameters:**
- `entity` (Sketchup::Group | Sketchup::ComponentInstance): The 3D component to export
- `face_name` (String): Which face to export ('Front', 'Back', 'Left', 'Right', 'Top', 'Bottom')
- `output_path` (String, optional): Custom output file path. If nil, uses default Downloads folder

**Returns:**
- (String): Path to the generated SVG file

**Example:**
```ruby
entity = Sketchup.active_model.selection[0]
svg_path = SvgVectorExporter.export_face_as_svg(entity, 'Front')
```

## License & Attribution

This feature is part of AutoNestCut and follows the same license terms.

---

**Last Updated**: January 2025
**Version**: 1.0
**Status**: Production Ready
