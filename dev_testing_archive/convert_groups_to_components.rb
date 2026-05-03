# Convert Groups to Components for SketchUp
# Converts all groups to components recursively

module ConvertGroupsToComponents
  
  def self.convert_all
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      UI.messagebox("Please select groups or components to convert.")
      return
    end
    
    model.start_operation("Convert Groups to Components", true)
    
    count = 0
    selection.to_a.each do |entity|
      count += convert_entity(entity, model)
    end
    
    model.commit_operation
    UI.messagebox("Converted #{count} group(s) to component(s).")
  end
  
  def self.convert_entity(entity, model)
    count = 0
    
    if entity.is_a?(Sketchup::Group)
      # Convert group to component
      definition = entity.definition
      transformation = entity.transformation
      parent = entity.parent
      
      # Recursively convert nested groups first
      definition.entities.to_a.each do |ent|
        if ent.is_a?(Sketchup::Group)
          count += convert_entity(ent, model)
        end
      end
      
      # Create new component definition by copying the group definition
      new_def = model.definitions.add("Component_#{Time.now.to_i}")
      temp_group = new_def.entities.add_group(definition.entities.to_a)
      temp_group.explode
      
      # Replace group with component
      entity.erase!
      parent.entities.add_instance(new_def, transformation)
      
      count += 1
    elsif entity.is_a?(Sketchup::ComponentInstance)
      # Check nested groups inside component
      definition = entity.definition
      definition.entities.to_a.each do |ent|
        if ent.is_a?(Sketchup::Group)
          count += convert_entity(ent, model)
        end
      end
    end
    
    count
  end
  
end

# Add menu item
unless file_loaded?(__FILE__)
  menu = UI.menu("Plugins")
  menu.add_item("Convert Groups to Components") {
    ConvertGroupsToComponents.convert_all
  }
  file_loaded(__FILE__)
end
