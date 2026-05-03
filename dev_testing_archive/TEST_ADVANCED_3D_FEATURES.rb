# Advanced Test Script for 3D Viewer Export
# Tests: Openings, L-Shapes, Textures, Complex Geometry

require 'sketchup.rb'

# Load the exporter
load File.join(__dir__, 'VIEWS_EXPORTER_EXPLODE.rb')

def create_advanced_test_assembly
  model = Sketchup.active_model
  entities = model.entities
  
  # Clear selection
  model.selection.clear
  
  # Create main assembly group
  assembly = entities.add_group
  assembly.name = "Advanced Test Assembly"
  
  # ===== PART 1: L-SHAPED PANEL WITH OPENING =====
  part1 = assembly.entities.add_group
  part1.name = "L-Shape with Opening"
  
  # Create L-shape
  pts = [
    [0, 0, 0],
    [24, 0, 0],
    [24, 12, 0],
    [12, 12, 0],
    [12, 24, 0],
    [0, 24, 0]
  ]
  face1 = part1.entities.add_face(pts)
  face1.pushpull(-0.75)
  
  # Add opening (hole)
  hole_pts = [
    [2, 2, -0.75],
    [6, 2, -0.75],
    [6, 6, -0.75],
    [2, 6, -0.75]
  ]
  hole_face = part1.entities.add_face(hole_pts)
  hole_face.erase! # This creates the opening
  
  # Apply red color
  part1.entities.grep(Sketchup::Face).each { |f| f.material = 'red' }
  
  # ===== PART 2: PANEL WITH TEXTURE =====
  part2 = assembly.entities.add_group
  part2.name = "Textured Panel"
  
  face2 = part2.entities.add_face([30, 0, 0], [42, 0, 0], [42, 18, 0], [30, 18, 0])
  face2.pushpull(-0.75)
  
  # Create a material with texture
  mat = model.materials.add("Wood Texture Test")
  mat.color = [139, 90, 43] # Brown color as fallback
  
  # Try to find and apply a texture from SketchUp's default materials
  # If this fails, it will just use the brown color
  begin
    # Try to use a SketchUp default texture if available
    # Users can also manually apply textures in SketchUp before exporting
    default_mat = model.materials["Wood_Floor_Light"] || model.materials["Wood"]
    if default_mat && default_mat.texture
      mat.texture = default_mat.texture.filename
      puts "Applied texture from: #{default_mat.name}"
    else
      puts "No default texture found - using solid color"
      puts "TIP: Apply a textured material in SketchUp to test texture export"
    end
  rescue => e
    puts "Could not apply texture: #{e.message}"
    puts "Using solid color instead"
  end
  
  part2.entities.grep(Sketchup::Face).each { |f| f.material = mat }
  
  # ===== PART 3: COMPLEX POLYGON (PENTAGON) =====
  part3 = assembly.entities.add_group
  part3.name = "Pentagon Panel"
  
  # Create pentagon
  center = Geom::Point3d.new(50, 12, 0)
  radius = 8
  pentagon_pts = []
  5.times do |i|
    angle = (i * 72 - 90).degrees
    x = center.x + radius * Math.cos(angle)
    y = center.y + radius * Math.sin(angle)
    pentagon_pts << [x, y, 0]
  end
  
  face3 = part3.entities.add_face(pentagon_pts)
  face3.pushpull(-0.75)
  face3.material = 'blue'
  
  # ===== PART 4: CIRCULAR OPENING =====
  part4 = assembly.entities.add_group
  part4.name = "Panel with Round Hole"
  
  face4 = part4.entities.add_face([0, 30, 0], [20, 30, 0], [20, 45, 0], [0, 45, 0])
  face4.pushpull(-0.75)
  
  # Add circular opening
  circle_center = Geom::Point3d.new(10, 37.5, -0.75)
  circle = part4.entities.add_circle(circle_center, [0, 0, 1], 3, 24)
  circle_face = part4.entities.add_face(circle)
  circle_face.erase! # Creates the hole
  
  part4.entities.grep(Sketchup::Face).each { |f| f.material = 'green' }
  
  # ===== PART 5: NESTED COMPONENTS =====
  part5 = assembly.entities.add_group
  part5.name = "Nested Assembly"
  
  # Outer box
  outer = part5.entities.add_group
  outer.name = "Outer Box"
  face5a = outer.entities.add_face([25, 30, 0], [40, 30, 0], [40, 45, 0], [25, 45, 0])
  face5a.pushpull(-2)
  face5a.material = 'yellow'
  
  # Inner box (nested)
  inner = part5.entities.add_group
  inner.name = "Inner Box"
  face5b = inner.entities.add_face([28, 33, -0.5], [37, 33, -0.5], [37, 42, -0.5], [28, 42, -0.5])
  face5b.pushpull(-1)
  face5b.material = 'orange'
  
  # Select the assembly
  model.selection.add(assembly)
  
  puts "=" * 60
  puts "ADVANCED TEST ASSEMBLY CREATED"
  puts "=" * 60
  puts "Features included:"
  puts "  ✓ L-shaped panel with rectangular opening"
  puts "  ✓ Textured panel (or solid color fallback)"
  puts "  ✓ Pentagon (complex polygon)"
  puts "  ✓ Panel with circular opening"
  puts "  ✓ Nested components"
  puts ""
  puts "Now run: Plugins > Export Standard Views Pro"
  puts "Make sure to check 'Include Interactive 3D Viewer'"
  puts "=" * 60
  
  return assembly
end

# Run the test
unless file_loaded?(__FILE__)
  menu = UI.menu('Plugins')
  menu.add_item('Create Advanced Test Assembly') { create_advanced_test_assembly }
  file_loaded(__FILE__)
end

puts "Advanced test script loaded."
puts "Go to: Plugins > Create Advanced Test Assembly"
