# Clear cache and test edge banding
model = Sketchup.active_model

# Clear any cached results
if defined?(AutoNestCut::CutListGenerator)
  AutoNestCut::CutListGenerator.instance_variable_set(:@cached_results, {})
  puts "Cache cleared"
end

# Create new test component with unique name
comp_def = model.definitions.add("EdgeTest_#{rand(10000)}")
pts = [[0,0,0], [600.mm,0,0], [600.mm,400.mm,0], [0,400.mm,0]]
face = comp_def.entities.add_face(pts)
face.pushpull(18.mm)

# Create material
mat = model.materials.add("TestMat_#{rand(10000)}")
mat.color = [255, 0, 0]

# Apply materials
faces = []
comp_def.entities.each { |e| faces << e if e.is_a?(Sketchup::Face) }
faces.sort_by! { |f| -f.area }

faces[0].material = mat  # Main face
faces[-1].material = mat  # One edge
faces[-2].material = mat  # Another edge

# Create instance
model.entities.add_instance(comp_def, Geom::Transformation.new)

puts "New test component created - generate cut list now"