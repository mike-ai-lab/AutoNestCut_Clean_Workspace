require 'sketchup.rb'

module ClearMaterials
  def self.clear_recursive(entity)
    entity.material = nil
    entity.back_material = nil if entity.respond_to?(:back_material)
    
    if entity.respond_to?(:entities)
      entity.entities.each { |e| clear_recursive(e) }
    end
  end
  
  def self.clear_selection
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      UI.messagebox("Please select groups or components to clear materials.")
      return
    end
    
    model.start_operation('Clear Materials', true)
    selection.each { |entity| clear_recursive(entity) }
    model.commit_operation
    
    UI.messagebox("Materials cleared from #{selection.length} item(s).")
  end
  
  unless file_loaded?(__FILE__)
    menu = UI.menu('Plugins')
    menu.add_item('Clear Materials') { clear_selection }
    file_loaded(__FILE__)
  end
end
