# FIXED TEST SCRIPT: Proper Panel with Edge Faces
model = Sketchup.active_model
entities = model.entities
materials = model.materials

# Create wood material
wood_material = materials.add("Oak_Panel_#{Time.now.to_i}")
wood_material.color = [139, 69, 19]

# Create component definition
panel_def = model.definitions.add("Test_Panel_EdgeBanding_#{Time.now.to_i}")

# Panel dimensions
width = 600.mm
height = 400.mm  
thickness = 18.mm

# Create solid box using push_pull
pts = [[0, 0, 0], [width, 0, 0], [width, height, 0], [0, height, 0]]
base_face = panel_def.entities.add_face(pts)
base_face.pushpull(thickness)

# Apply materials to faces
panel_def.entities.each do |entity|
  next unless entity.is_a?(Sketchup::Face)
  
  area = entity.area
  normal = entity.normal
  
  # Main faces (top/bottom) - largest areas
  if area > width * height * 0.8
    entity.material = wood_material
  # Edge faces - apply material to 2 edges only
  elsif normal.x.abs > 0.9  # Front/back edges
    entity.material = wood_material  # Banded
  # Leave left/right edges without material (non-banded)
  end
end

# Create instance
instance = entities.add_instance(panel_def, Geom::Transformation.new)

puts "Created test panel with:"
puts "- Main faces: Oak_Panel material"  
puts "- 2 edges banded (front/back)"
puts "- 2 edges non-banded (left/right)"
puts "Expected detection: '2 edges'"