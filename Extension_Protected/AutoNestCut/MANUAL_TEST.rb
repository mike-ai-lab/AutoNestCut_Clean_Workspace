# MANUAL TEST: Apply materials to existing component
model = Sketchup.active_model
selection = model.selection

if selection.empty?
  puts "Please select a component first"
else
  # Get selected component
  comp_instance = selection.first
  if comp_instance.is_a?(Sketchup::ComponentInstance)
    comp_def = comp_instance.definition
    
    # Create test material
    mat = model.materials.add("EdgeBandTest_#{Time.now.to_i}")
    mat.color = [255, 100, 0]
    
    # Find faces
    faces = []
    comp_def.entities.each { |e| faces << e if e.is_a?(Sketchup::Face) }
    faces.sort_by! { |f| -f.area }
    
    puts "Found #{faces.length} faces"
    
    # Apply material to largest face and 2 smallest faces
    if faces.length >= 3
      faces[0].material = mat  # Main face
      faces[-2].material = mat  # Edge 1  
      faces[-1].material = mat  # Edge 2
      puts "Applied materials - now test cut list"
    end
  else
    puts "Please select a component instance"
  end
end