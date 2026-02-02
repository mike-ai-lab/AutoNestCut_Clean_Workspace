# WORKING TEST: Create proper box with materials
model = Sketchup.active_model
entities = model.entities
materials = model.materials

# Create material
mat = materials.add("TestMat_#{Time.now.to_i}")
mat.color = [255, 0, 0]

# Create component
comp_def = model.definitions.add("TestBox_#{Time.now.to_i}")

# Create rectangle and extrude
pts = [[0,0,0], [600.mm,0,0], [600.mm,400.mm,0], [0,400.mm,0]]
face = comp_def.entities.add_face(pts)
face.pushpull(18.mm)

# Find all faces and apply materials
faces = []
comp_def.entities.each { |e| faces << e if e.is_a?(Sketchup::Face) }
faces.sort_by! { |f| -f.area }

puts "Created #{faces.length} faces"

# Apply material to top face and 2 edge faces
faces[0].material = mat  # Top face
if faces.length >= 4
  faces[-2].material = mat  # Edge 1
  faces[-1].material = mat  # Edge 2
end

# Create instance
entities.add_instance(comp_def, Geom::Transformation.new)

puts "Test ready - generate cut list now"