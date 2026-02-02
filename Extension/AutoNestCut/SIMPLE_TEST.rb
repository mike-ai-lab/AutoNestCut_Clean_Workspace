# SIMPLE TEST: Create box and manually assign materials
model = Sketchup.active_model
entities = model.entities
materials = model.materials

# Create material
mat = materials.add("TestMat_#{Time.now.to_i}")
mat.color = [255, 0, 0]

# Create component
comp_def = model.definitions.add("TestBox_#{Time.now.to_i}")

# Create box 60x40x1.8cm
group = comp_def.entities.add_group
box = group.entities.add_box([0,0,0], 600.mm, 400.mm, 18.mm)

# Apply material to specific faces
faces = []
group.entities.each { |e| faces << e if e.is_a?(Sketchup::Face) }

puts "Created #{faces.length} faces"
faces.each_with_index do |face, i|
  puts "Face #{i}: area=#{face.area.to_mm2.round(2)}mm²"
end

# Apply material to largest face (top) and 2 edge faces
if faces.length >= 6
  # Sort by area
  faces.sort_by! { |f| -f.area }
  
  # Apply to top face
  faces[0].material = mat
  puts "Applied material to top face"
  
  # Apply to 2 edge faces (smallest faces)
  faces[-2].material = mat
  faces[-1].material = mat
  puts "Applied material to 2 edge faces"
end

# Create instance
entities.add_instance(comp_def, Geom::Transformation.new)

puts "Test component created. Run cut list to test detection."