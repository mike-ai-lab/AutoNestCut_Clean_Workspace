# SketchUp Script by Muhamad
# Creates panels (600x900x18mm) with unique materials and varying quantities

def create_unique_panels
  model = Sketchup.active_model
  entities = model.active_entities
  materials = model.materials

  # Dimensions in mm (SketchUp uses inches internally)
  width = 600.mm
  height = 900.mm
  thickness = 18.mm
  spacing = 200.mm

  # Varying quantities for each material
  quantities = [3, 4, 6, 2, 8, 9, 5, 7, 1, 10]
  
  output_log = []
  total_panels = 0
  current_x = 0
  current_y = 0
  max_per_row = 5

  model.start_operation('Create Panel Components', true)

  quantities.each_with_index do |qty, i|
    # 1. Create a unique material
    mat_name = "Panel_Material_#{i + 1}"
    mat = materials.add(mat_name)
    mat.color = Sketchup::Color.new(rand(255), rand(255), rand(255))
s
    # 2. Create the component definition (only once per material)
    comp_def = model.definitions.add("Panel_Component_#{i + 1}")
    
    # 3. Draw the geometry in the component definition
    face = comp_def.entities.add_face(
      [0, 0, 0],
      [width, 0, 0],
      [width, height, 0],
      [0, height, 0]
    )
    face.pushpull(-thickness)
    
    # Apply material to all faces
    comp_def.entities.each { |e| e.material = mat if e.is_a?(Sketchup::Face) }

    # 4. Create multiple instances of this component
    qty.times do |instance_num|
      x_offset = current_x * (width + spacing)
      y_offset = current_y * (height + spacing)
      
      transform = Geom::Transformation.new([x_offset, y_offset, 0])
      entities.add_instance(comp_def, transform)
      
      # Update position for next panel
      current_x += 1
      if current_x >= max_per_row
        current_x = 0
        current_y += 1
      end
      
      total_panels += 1
    end

    output_log << "Material #{i + 1}: #{mat_name} - #{qty} panels created"
  end

  model.commit_operation

  # Output results to Ruby console
  puts "\n" + "="*60
  puts "PANEL GENERATION COMPLETE"
  puts "="*60
  output_log.each { |line| puts line }
  puts "-"*60
  puts "Total panels created: #{total_panels}"
  puts "Total unique materials: #{quantities.length}"
  puts "="*60 + "\n"
end

create_unique_panels