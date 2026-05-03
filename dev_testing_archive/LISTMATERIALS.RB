module MaterialInspector
  def self.list_materials_in_selection
    model = Sketchup.active_model
    selection = model.selection

    if selection.length != 1 || 
       !(selection.first.is_a?(Sketchup::ComponentInstance) || selection.first.is_a?(Sketchup::Group))
      UI.messagebox("Select exactly one Component or Group.")
      return
    end

    root = selection.first
    materials = {}

    traverse_entities(root.definition.entities, materials)

    # Include material applied directly to the component/group
    if root.material
      materials[root.material.display_name] = root.material
    end

    if materials.empty?
      UI.messagebox("No materials found in the selected component.")
      return
    end

    report = "Materials used in '#{root.name}':\n\n"
    materials.keys.sort.each do |name|
      report << "• #{name}\n"
    end

    puts report
    UI.messagebox(report)
  end

  def self.traverse_entities(entities, materials)
    entities.each do |entity|
      case entity
      when Sketchup::Face
        if entity.material
          materials[entity.material.display_name] = entity.material
        end
        if entity.back_material
          materials[entity.back_material.display_name] = entity.back_material
        end

      when Sketchup::Group, Sketchup::ComponentInstance
        if entity.material
          materials[entity.material.display_name] = entity.material
        end
        traverse_entities(entity.definition.entities, materials)
      end
    end
  end
end

MaterialInspector.list_materials_in_selection
