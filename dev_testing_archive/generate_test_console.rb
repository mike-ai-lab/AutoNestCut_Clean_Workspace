# Test Console Generator for AutoNestCut
# Creates components with edge banding, grain directions, and materials
# Components are laid out in a neat grid on the Z-axis (vertical stacking)

model = Sketchup.active_model
entities = model.entities
materials = model.materials

# Create materials
plywood = materials.add('Plywood_18mm')
plywood.color = Sketchup::Color.new(210, 180, 140)

mdf = materials.add('MDF_18mm')
mdf.color = Sketchup::Color.new(160, 140, 120)

melamine = materials.add('Melamine_White')
melamine.color = Sketchup::Color.new(240, 240, 240)

# Helper to create component with attributes
# edge_banding format: 'PVC_White:top,bottom,left,right' or 'PVC_White' for all edges or 'None'
def create_panel(name, width, height, thickness, material, grain = 'Any', edge_banding = 'None')
  model = Sketchup.active_model
  definition = model.definitions.add(name)
  
  # Create box - convert Length objects to numeric values
  w = width.is_a?(Length) ? width.to_f : width
  h = height.is_a?(Length) ? height.to_f : height
  t = thickness.is_a?(Length) ? thickness.to_f : thickness
  
  pts = [
    [0, 0, 0],
    [w, 0, 0],
    [w, h, 0],
    [0, h, 0]
  ]
  face = definition.entities.add_face(pts)
  face.pushpull(-t)
  
  # Apply material
  definition.entities.each { |e| e.material = material if e.is_a?(Sketchup::Face) }
  
  # Set attributes
  definition.set_attribute('AutoNestCut', 'grain_direction', grain)
  definition.set_attribute('AutoNestCut', 'edge_banding', edge_banding)
  
  definition
end

# Convert mm to inches (SketchUp internal units)
def mm(value)
  value.mm
end

model.start_operation('Generate Test Console', true)

# Layout configuration
z_position = 0  # Start at ground level
z_spacing = 50.mm  # 50mm vertical spacing between components
x_offset = 0  # Horizontal offset for current row
y_offset = 0  # Depth offset
row_max_width = 3000.mm  # Maximum width before starting new row
current_row_width = 0

# Helper to place component in grid layout
def place_component(entities, definition, z_pos, x_off, y_off)
  entities.add_instance(definition, Geom::Transformation.new([x_off, y_off, z_pos]))
end

# 1. Cabinet Sides (2x) - Plywood with vertical grain, front and back edges (top, bottom)
side_def = create_panel('Side Panel', mm(600), mm(800), mm(18), plywood, 'L', 'PVC_White:top,bottom')
place_component(entities, side_def, z_position, x_offset, y_offset)
x_offset += mm(650)  # Width + spacing
place_component(entities, side_def, z_position, x_offset, y_offset)
x_offset += mm(650)
z_position += z_spacing

# 2. Top Panel - Melamine with all 4 edges banding
top_def = create_panel('Top Panel', mm(900), mm(600), mm(18), melamine, 'Any', 'PVC_White:top,bottom,left,right')
place_component(entities, top_def, z_position, 0, y_offset)
z_position += z_spacing

# 3. Bottom Panel - Plywood with horizontal grain, no banding
bottom_def = create_panel('Bottom Shelf', mm(864), mm(582), mm(18), plywood, 'W', 'None')
place_component(entities, bottom_def, z_position, 0, y_offset)
z_position += z_spacing

# 4. Back Panel - MDF, no grain, no banding
back_def = create_panel('Back Panel', mm(864), mm(750), mm(6), mdf, 'Any', 'None')
place_component(entities, back_def, z_position, 0, y_offset)
z_position += z_spacing

# 5-6. Doors (2x) - Melamine with vertical grain, all 4 edges
door_def = create_panel('Door', mm(430), mm(700), mm(18), melamine, 'L', 'PVC_White:top,bottom,left,right')
place_component(entities, door_def, z_position, 0, y_offset)
place_component(entities, door_def, z_position, mm(480), y_offset)
z_position += z_spacing

# 7-8. Shelves (2x) - Plywood with front edge only (top)
shelf_def = create_panel('Shelf', mm(864), mm(582), mm(18), plywood, 'W', 'PVC_White:top')
place_component(entities, shelf_def, z_position, 0, y_offset)
z_position += z_spacing
place_component(entities, shelf_def, z_position, 0, y_offset)
z_position += z_spacing

# 9-10. Drawer Fronts (2x) - Melamine with all 4 edges
drawer_def = create_panel('Drawer Front', mm(420), mm(150), mm(18), melamine, 'W', 'PVC_White:top,bottom,left,right')
place_component(entities, drawer_def, z_position, 0, y_offset)
place_component(entities, drawer_def, z_position, mm(470), y_offset)
z_position += z_spacing

# 11-14. Drawer Sides (4x) - No edge banding
drawer_side_def = create_panel('Drawer Side', mm(550), mm(120), mm(12), plywood, 'L', 'None')
place_component(entities, drawer_side_def, z_position, 0, y_offset)
place_component(entities, drawer_side_def, z_position, mm(600), y_offset)
z_position += z_spacing
place_component(entities, drawer_side_def, z_position, 0, y_offset)
place_component(entities, drawer_side_def, z_position, mm(600), y_offset)
z_position += z_spacing

# 15-16. Drawer Bottoms (2x) - MDF, no grain, no banding
drawer_bottom_def = create_panel('Drawer Bottom', mm(540), mm(530), mm(6), mdf, 'Any', 'None')
place_component(entities, drawer_bottom_def, z_position, 0, y_offset)
place_component(entities, drawer_bottom_def, z_position, mm(590), y_offset)
z_position += z_spacing

# 17. Divider - Plywood with vertical grain, left and right edges
divider_def = create_panel('Vertical Divider', mm(582), mm(700), mm(18), plywood, 'L', 'PVC_White:left,right')
place_component(entities, divider_def, z_position, 0, y_offset)
z_position += z_spacing

# 18-19. Plinth/Kick Board (2x) - MDF, horizontal grain, top edge only
plinth_def = create_panel('Plinth', mm(900), mm(100), mm(18), mdf, 'W', 'PVC_White:top')
place_component(entities, plinth_def, z_position, 0, y_offset)
place_component(entities, plinth_def, z_position, mm(950), y_offset)
z_position += z_spacing

model.commit_operation

UI.messagebox("Test components created with neat Z-axis layout!\n\n✅ Features:\n- 3 materials (Plywood, MDF, Melamine)\n- Various grain directions (L, W, Any)\n- Edge banding with specific edges:\n  * All 4 edges: top,bottom,left,right\n  * 2 edges: top,bottom OR left,right\n  * 1 edge: top\n  * None\n- Different thicknesses (6mm, 12mm, 18mm)\n- Clean vertical stacking (50mm spacing)\n- NO OVERLAPPING!\n\n✅ Select all and run AutoNestCut!")

