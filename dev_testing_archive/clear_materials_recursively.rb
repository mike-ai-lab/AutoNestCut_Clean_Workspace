# Clear Materials Recursively for SketchUp
# Removes all materials from selected components/groups and their nested contents

module ClearMaterialsRecursively
  
  def self.clear_materials
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      UI.messagebox("Please select a component or group first.")
      return
    end
    
    model.start_operation("Clear Materials Recursively", true)
    
    selection.each do |entity|
      if entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
        clear_entity_materials(entity)
      elsif entity.is_a?(Sketchup::Face)
        entity.material = nil
        entity.back_material = nil
      end
    end
    
    model.commit_operation
    UI.messagebox("Materials cleared successfully.")
  end
  
  def self.clear_entity_materials(entity)
    # Clear material from the entity itself
    entity.material = nil
    
    # Get the definition and clear materials from all entities inside
    definition = entity.definition
    definition.entities.each do |ent|
      if ent.is_a?(Sketchup::Face)
        ent.material = nil
        ent.back_material = nil
      elsif ent.is_a?(Sketchup::ComponentInstance) || ent.is_a?(Sketchup::Group)
        clear_entity_materials(ent)
      end
    end
  end
  
end

# Add menu item
unless file_loaded?(__FILE__)
  menu = UI.menu("Plugins")
  menu.add_item("Clear Materials Recursively") {
    ClearMaterialsRecursively.clear_materials
  }
  file_loaded(__FILE__)
end
