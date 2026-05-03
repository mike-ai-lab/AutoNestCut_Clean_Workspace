# Test script to verify material extraction from assembly components
# This will help debug why all parts are showing "Default Material"

model = Sketchup.active_model
selection = model.selection

if selection.empty?
  UI.messagebox("Please select a group or component containing the assembly")
else
  entity = selection.first
  
  puts "\n" + "="*80
  puts "ASSEMBLY MATERIAL EXTRACTION TEST"
  puts "="*80
  
  # Get sub-components
  entities = entity.is_a?(Sketchup::ComponentInstance) ? entity.definition.entities : entity.entities
  sub_parts = entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
  
  puts "\nFound #{sub_parts.length} sub-parts"
  puts "-"*80
  
  sub_parts.each_with_index do |part, idx|
    part_name = if part.is_a?(Sketchup::ComponentInstance)
      part.definition.name
    elsif part.is_a?(Sketchup::Group)
      part.name
    else
      "Part"
    end
    part_name = "Part" if part_name.nil? || part_name.empty?
    
    puts "\n#{idx + 1}. Part: #{part_name}"
    puts "   Type: #{part.class.name}"
    
    # Check component material
    if part.respond_to?(:material) && part.material
      puts "   Component Material: #{part.material.name}"
      puts "   - Has Texture: #{part.material.texture ? 'YES' : 'NO'}"
      puts "   - Color: #{part.material.color}"
      puts "   - Alpha: #{part.material.alpha}"
    else
      puts "   Component Material: NONE"
    end
    
    # Check face materials
    part_entities = part.is_a?(Sketchup::Group) ? part.entities : part.definition.entities
    faces = part_entities.select { |e| e.is_a?(Sketchup::Face) }
    
    puts "   Faces: #{faces.length}"
    
    face_materials = []
    faces.each do |face|
      if face.material
        face_materials << face.material.name
      elsif face.back_material
        face_materials << face.back_material.name
      end
    end
    
    if face_materials.any?
      material_counts = face_materials.each_with_object(Hash.new(0)) { |mat, counts| counts[mat] += 1 }
      puts "   Face Materials:"
      material_counts.each do |mat_name, count|
        mat = model.materials[mat_name]
        has_texture = mat && mat.texture ? "YES" : "NO"
        puts "     - #{mat_name}: #{count} faces (Texture: #{has_texture})"
      end
      
      most_common = material_counts.max_by { |_, count| count }&.first
      puts "   Most Common Face Material: #{most_common}"
    else
      puts "   Face Materials: NONE"
    end
    
    # Determine final material (same logic as report_generator.rb)
    material_name = nil
    
    if part.respond_to?(:material) && part.material
      material_name = part.material.name
    end
    
    if material_name.nil? && face_materials.any?
      material_counts = face_materials.each_with_object(Hash.new(0)) { |mat, counts| counts[mat] += 1 }
      material_name = material_counts.max_by { |_, count| count }&.first
    end
    
    if material_name.nil? || material_name.empty?
      material_name = "Default Material"
    end
    
    puts "   >>> FINAL MATERIAL: #{material_name}"
  end
  
  puts "\n" + "="*80
  puts "TEST COMPLETE"
  puts "="*80
end
