# TEST SCRIPT: Material-Based Edge Banding Detection
# This script demonstrates how to set up components with materials for automatic edge banding detection

# Create a test panel component
model = Sketchup.active_model
entities = model.entities
materials = model.materials

# Create a wood material for the main panel
wood_material = materials.add("Oak_Panel")
wood_material.color = [139, 69, 19]  # Brown color

# Create a component definition for a panel
panel_def = model.definitions.add("Test_Panel_With_Edge_Banding")

# Create a rectangular panel (600mm x 400mm x 18mm)
width = 600.mm
height = 400.mm
thickness = 18.mm

# Create the main panel faces (top and bottom)
pts1 = [[0, 0, 0], [width, 0, 0], [width, height, 0], [0, height, 0]]
pts2 = [[0, 0, thickness], [width, 0, thickness], [width, height, thickness], [0, height, thickness]]

# Create faces
bottom_face = panel_def.entities.add_face(pts1)
top_face = panel_def.entities.add_face(pts2)

# Apply wood material to main faces
bottom_face.material = wood_material
top_face.material = wood_material

# Create thickness faces (edges) - SketchUp automatically creates these
# We need to find and assign materials to the edge faces
edge_faces = []
panel_def.entities.each do |entity|
  if entity.is_a?(Sketchup::Face)
    # Skip the main faces (largest areas)
    if entity.area < bottom_face.area * 0.5
      edge_faces << entity
    end
  end
end

# Apply material to 2 edges for testing (front and back)
if edge_faces.length >= 2
  edge_faces[0].material = wood_material  # First edge banded
  edge_faces[1].material = wood_material  # Second edge banded
  # Leave other edges without material
end

# Create component instance
panel_instance = entities.add_instance(panel_def, Geom::Transformation.new)
panel_instance.move!([0, 0, 0])

puts "Test panel created with material-based edge banding:"
puts "- Main faces: Oak_Panel material"
puts "- Front/Back edges: Oak_Panel material (BANDED)"
puts "- Left/Right edges: No material or reversed (NOT BANDED)"
puts ""
puts "Expected edge banding detection: '2 edges'"
puts ""
puts "To test different configurations:"
puts "1. Apply material to all 4 thickness faces = 'All 4 edges'"
puts "2. Apply material to no thickness faces = 'None'"
puts "3. Apply material to 1 thickness face = '1 edge'"
puts "4. Apply material to 3 thickness faces = '3 edges'"
puts ""
puts "Use Extensions → AutoNestCut → Generate Cut List to test detection"