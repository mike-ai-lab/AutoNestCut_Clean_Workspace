# Recursive Material Applier for SketchUp
# Applies material to the exact face clicked, even if deeply nested

module RecursiveMaterialApplier
  
  def self.activate_tool
    Sketchup.active_model.select_tool(MaterialApplierTool.new)
  end
  
  class MaterialApplierTool
    
    def activate
      Sketchup.status_text = "Click on a face to apply the current material"
    end
    
    def onLButtonDown(flags, x, y, view)
      model = Sketchup.active_model
      material = model.materials.current
      
      unless material
        UI.messagebox("No material selected. Please select a material first.")
        return
      end
      
      ph = view.pick_helper
      ph.do_pick(x, y)
      
      return if ph.count == 0
      
      # Get the picked face and path
      best_face = ph.best_picked
      return unless best_face.is_a?(Sketchup::Face)
      
      path = ph.path_at(0)
      
      model.start_operation("Apply Material to Face", true)
      
      if path.length > 1
        # Face is nested - edit the definition
        container = path[-2]
        if container.is_a?(Sketchup::ComponentInstance) || container.is_a?(Sketchup::Group)
          definition = container.definition
          definition.entities.each do |entity|
            if entity == best_face
              entity.material = material
              break
            end
          end
        end
      else
        # Face is at root level
        best_face.material = material
      end
      
      model.commit_operation
      Sketchup.status_text = "Material applied"
    end
    
    def resume(view)
      Sketchup.status_text = "Click on a face to apply the current material"
    end
    
  end
  
end

# Add menu item
unless file_loaded?(__FILE__)
  menu = UI.menu("Plugins")
  menu.add_item("Recursive Material Applier") {
    RecursiveMaterialApplier.activate_tool
  }
  file_loaded(__FILE__)
end
