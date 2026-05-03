# Test Script for 3D Viewer Export
# This creates a simple test model and exports it

require 'sketchup.rb'

# Load the exporter
load File.join(__dir__, 'VIEWS_EXPORTER_EXPLODE.rb')

def create_test_assembly
  model = Sketchup.active_model
  entities = model.entities
  
  # Clear selection
  model.selection.clear
  
  # Create a simple assembly with 3 parts
  group = entities.add_group
  
  # Part 1: Bottom plate (red)
  part1 = group.entities.add_group
  face1 = part1.entities.add_face([0,0,0], [24,0,0], [24,12,0], [0,12,0])
  face1.pushpull(-0.75)
  face1.material = 'red'
  part1.name = "Bottom Plate"
  
  # Part 2: Left side (blue)
  part2 = group.entities.add_group
  face2 = part2.entities.add_face([0,0,0], [0,12,0], [0,12,12], [0,0,12])
  face2.pushpull(0.75)
  face2.material = 'blue'
  part2.name = "Left Side"
  
  # Part 3: Right side (green)
  part3 = group.entities.add_group
  face3 = part3.entities.add_face([24,0,0], [24,12,0], [24,12,12], [24,0,12])
  face3.pushpull(-0.75)
  face3.material = 'green'
  part3.name = "Right Side"
  
  group.name = "Test Assembly"
  
  # Select the group
  model.selection.add(group)
  
  puts "Test assembly created with 3 parts"
  puts "Now run: Plugins > Export Standard Views Pro"
  
  return group
end

# Run the test
unless file_loaded?(__FILE__)
  menu = UI.menu('Plugins')
  menu.add_item('Create Test Assembly for 3D Export') { create_test_assembly }
  file_loaded(__FILE__)
end

puts "Test script loaded. Go to Plugins > Create Test Assembly for 3D Export"
