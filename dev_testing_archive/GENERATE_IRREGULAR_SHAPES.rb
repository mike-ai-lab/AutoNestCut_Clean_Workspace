# Generate various irregular shapes for testing non-rectangular nesting
# This script creates L-shape, T-shape, U-shape, Plus-shape, Circle, and Polygon components

model = Sketchup.active_model
entities = model.active_entities
model.start_operation('Generate Irregular Shapes', true)

# Clear selection
model.selection.clear

# Material for all shapes
material_name = "Plywood_Test"
material = model.materials[material_name]
unless material
  material = model.materials.add(material_name)
  material.color = [202, 166, 113]
end

# Thickness for all shapes
thickness = 18.mm

# Position offset for arranging shapes
x_offset = 0
y_spacing = 1000.mm

# ============================================================================
# 1. L-SHAPE (6 vertices)
# ============================================================================
puts "\n=== Creating L-Shape ==="
l_group = entities.add_group
l_entities = l_group.entities

# L-shape dimensions
l_width = 720.mm
l_height = 560.mm
l_cutout_width = 408.63.mm
l_cutout_height = 238.13.mm

# Create L-shape face
l_points = [
  [0, 0, 0],
  [l_width, 0, 0],
  [l_width, l_height - l_cutout_height, 0],
  [l_width - l_cutout_width, l_height - l_cutout_height, 0],
  [l_width - l_cutout_width, l_height, 0],
  [0, l_height, 0]
]

l_face = l_entities.add_face(l_points)
l_face.pushpull(-thickness)
l_face.material = material
l_face.back_material = material

l_group.name = "L-Shape Component"
l_group.set_attribute('AutoNestCut', 'grain_direction', 'Any')
l_group.material = material

puts "✓ L-Shape created: #{l_width.to_mm}x#{l_height.to_mm}mm with cutout"

# ============================================================================
# 2. T-SHAPE (8 vertices)
# ============================================================================
puts "\n=== Creating T-Shape ==="
t_group = entities.add_group
t_entities = t_group.entities
t_group.transformation = Geom::Transformation.new([0, y_spacing, 0])

# T-shape dimensions
t_top_width = 800.mm
t_top_height = 200.mm
t_stem_width = 300.mm
t_stem_height = 500.mm

# Create T-shape face
t_points = [
  [0, 0, 0],
  [t_top_width, 0, 0],
  [t_top_width, t_top_height, 0],
  [(t_top_width + t_stem_width) / 2, t_top_height, 0],
  [(t_top_width + t_stem_width) / 2, t_top_height + t_stem_height, 0],
  [(t_top_width - t_stem_width) / 2, t_top_height + t_stem_height, 0],
  [(t_top_width - t_stem_width) / 2, t_top_height, 0],
  [0, t_top_height, 0]
]

t_face = t_entities.add_face(t_points)
t_face.pushpull(-thickness)
t_face.material = material
t_face.back_material = material

t_group.name = "T-Shape Component"
t_group.set_attribute('AutoNestCut', 'grain_direction', 'Any')
t_group.material = material

puts "✓ T-Shape created: #{t_top_width.to_mm}x#{(t_top_height + t_stem_height).to_mm}mm"

# ============================================================================
# 3. U-SHAPE (8 vertices)
# ============================================================================
puts "\n=== Creating U-Shape ==="
u_group = entities.add_group
u_entities = u_group.entities
u_group.transformation = Geom::Transformation.new([0, y_spacing * 2, 0])

# U-shape dimensions
u_width = 700.mm
u_height = 600.mm
u_inner_width = 400.mm
u_inner_height = 400.mm
u_wall_thickness = 150.mm

# Create U-shape face (outer rectangle minus inner rectangle)
u_points = [
  [0, 0, 0],
  [u_width, 0, 0],
  [u_width, u_height, 0],
  [u_width - u_wall_thickness, u_height, 0],
  [u_width - u_wall_thickness, u_wall_thickness, 0],
  [u_wall_thickness, u_wall_thickness, 0],
  [u_wall_thickness, u_height, 0],
  [0, u_height, 0]
]

u_face = u_entities.add_face(u_points)
u_face.pushpull(-thickness)
u_face.material = material
u_face.back_material = material

u_group.name = "U-Shape Component"
u_group.set_attribute('AutoNestCut', 'grain_direction', 'Any')
u_group.material = material

puts "✓ U-Shape created: #{u_width.to_mm}x#{u_height.to_mm}mm"

# ============================================================================
# 4. PLUS/CROSS SHAPE (12 vertices)
# ============================================================================
puts "\n=== Creating Plus-Shape ==="
plus_group = entities.add_group
plus_entities = plus_group.entities
plus_group.transformation = Geom::Transformation.new([0, y_spacing * 3, 0])

# Plus-shape dimensions
plus_size = 600.mm
plus_arm_width = 200.mm

# Create plus-shape face
plus_points = [
  [plus_arm_width, 0, 0],
  [plus_size - plus_arm_width, 0, 0],
  [plus_size - plus_arm_width, plus_arm_width, 0],
  [plus_size, plus_arm_width, 0],
  [plus_size, plus_size - plus_arm_width, 0],
  [plus_size - plus_arm_width, plus_size - plus_arm_width, 0],
  [plus_size - plus_arm_width, plus_size, 0],
  [plus_arm_width, plus_size, 0],
  [plus_arm_width, plus_size - plus_arm_width, 0],
  [0, plus_size - plus_arm_width, 0],
  [0, plus_arm_width, 0],
  [plus_arm_width, plus_arm_width, 0]
]

plus_face = plus_entities.add_face(plus_points)
plus_face.pushpull(-thickness)
plus_face.material = material
plus_face.back_material = material

plus_group.name = "Plus-Shape Component"
plus_group.set_attribute('AutoNestCut', 'grain_direction', 'Any')
plus_group.material = material

puts "✓ Plus-Shape created: #{plus_size.to_mm}x#{plus_size.to_mm}mm"

# ============================================================================
# 5. CIRCLE (approximated with 24 vertices)
# ============================================================================
puts "\n=== Creating Circle ==="
circle_group = entities.add_group
circle_entities = circle_group.entities
circle_group.transformation = Geom::Transformation.new([0, y_spacing * 4, 0])

# Circle dimensions
circle_radius = 300.mm
circle_segments = 24

# Create circle face
circle_center = [circle_radius, circle_radius, 0]
circle_normal = [0, 0, 1]
circle_edges = circle_entities.add_circle(circle_center, circle_normal, circle_radius, circle_segments)
circle_face = circle_entities.add_face(circle_edges)
circle_face.pushpull(-thickness)
circle_face.material = material
circle_face.back_material = material

circle_group.name = "Circle Component"
circle_group.set_attribute('AutoNestCut', 'grain_direction', 'Any')
circle_group.material = material

puts "✓ Circle created: diameter #{(circle_radius * 2).to_mm}mm with #{circle_segments} segments"

# ============================================================================
# 6. HEXAGON (6 vertices polygon)
# ============================================================================
puts "\n=== Creating Hexagon ==="
hex_group = entities.add_group
hex_entities = hex_group.entities
hex_group.transformation = Geom::Transformation.new([0, y_spacing * 5, 0])

# Hexagon dimensions
hex_radius = 300.mm
hex_segments = 6

# Create hexagon face
hex_center = [hex_radius, hex_radius, 0]
hex_normal = [0, 0, 1]
hex_edges = hex_entities.add_circle(hex_center, hex_normal, hex_radius, hex_segments)
hex_face = hex_entities.add_face(hex_edges)
hex_face.pushpull(-thickness)
hex_face.material = material
hex_face.back_material = material

hex_group.name = "Hexagon Component"
hex_group.set_attribute('AutoNestCut', 'grain_direction', 'Any')
hex_group.material = material

puts "✓ Hexagon created: #{(hex_radius * 2).to_mm}mm across"

# ============================================================================
# 7. TRAPEZOID (4 vertices but not rectangle)
# ============================================================================
puts "\n=== Creating Trapezoid ==="
trap_group = entities.add_group
trap_entities = trap_group.entities
trap_group.transformation = Geom::Transformation.new([0, y_spacing * 6, 0])

# Trapezoid dimensions
trap_bottom = 800.mm
trap_top = 500.mm
trap_height = 400.mm

# Create trapezoid face
trap_points = [
  [0, 0, 0],
  [trap_bottom, 0, 0],
  [trap_bottom - (trap_bottom - trap_top) / 2, trap_height, 0],
  [(trap_bottom - trap_top) / 2, trap_height, 0]
]

trap_face = trap_entities.add_face(trap_points)
trap_face.pushpull(-thickness)
trap_face.material = material
trap_face.back_material = material

trap_group.name = "Trapezoid Component"
trap_group.set_attribute('AutoNestCut', 'grain_direction', 'Any')
trap_group.material = material

puts "✓ Trapezoid created: #{trap_bottom.to_mm}mm base, #{trap_top.to_mm}mm top, #{trap_height.to_mm}mm height"

model.commit_operation

puts "\n" + "="*80
puts "✅ ALL IRREGULAR SHAPES GENERATED SUCCESSFULLY!"
puts "="*80
puts "\nShapes created:"
puts "  1. L-Shape (6 vertices)"
puts "  2. T-Shape (8 vertices)"
puts "  3. U-Shape (8 vertices)"
puts "  4. Plus-Shape (12 vertices)"
puts "  5. Circle (24 vertices)"
puts "  6. Hexagon (6 vertices)"
puts "  7. Trapezoid (4 vertices)"
puts "\nAll shapes have:"
puts "  - Material: #{material_name}"
puts "  - Thickness: #{thickness.to_mm}mm"
puts "  - Grain direction: Any"
puts "\nSelect any or all shapes and run AutoNestCut to test nesting!"
puts "="*80
