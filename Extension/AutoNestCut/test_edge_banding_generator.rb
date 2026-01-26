# Test Edge Banding Component Generator (fixed)
# Replaces destructive model.entities.clear! with a safe grouped workflow
# - Creates / reuses a Tag (layer) named "AutoNestCut_Test"
# - Removes only prior AutoNestCut test groups & definitions
# - Places new instances inside a parent Group "AutoNestCut Test Components"
# - Fixes bottom-face detection and groups tag assignment
#
# Usage: Place this file in your plugin folder and run from Extensions -> AutoNestCut Test Tools

module AutoNestCut
  class TestEdgeBandingGenerator

    def self.generate_test_components
      model = Sketchup.active_model
      return unless model

      # Start undoable operation
      model.start_operation('Generate Test Edge Banding Components', true)

      begin
        # --- Cleanup previous runs (non-destructive to other user geometry) ---
        # Remove any prior parent groups that were created by this tool
        model.entities.grep(Sketchup::Group).each do |gr|
          if gr.get_attribute('AutoNestCut', 'test_group')
            gr.erase!
          end
        end

        # Remove definitions created by prior runs if they exist and have no remaining instances
        # (this prevents name collisions and stale definitions)
        prior_names = [
          'Cabinet_Door_1', 'Cabinet_Door_2', 'Shelf_Panel', 'Back_Panel', 'Drawer_Front'
        ]
        prior_names.each do |dname|
          defn = model.definitions[dname]
          if defn
            # erase only if there are no remaining instances (safe)
            if defn.count_instances == 0
              defn.erase!
            end
          end
        end

        # --- Create / reuse parent group and Tag (layer) ---
        parent_group = model.entities.add_group
        parent_group.name = 'AutoNestCut Test Components'
        parent_group.set_attribute('AutoNestCut', 'test_group', true)

        # Create or reuse a Tag (layer) - use model.layers for compatibility
        layers = model.layers
        tag_name = 'AutoNestCut_Test'
        tag = layers[tag_name] || layers.add(tag_name)
        parent_group.layer = tag

        # --- Define test components ---
        test_components = [
          {
            name: 'Cabinet_Door_1',
            width: 400,
            height: 600,
            thickness: 18,
            material: 'White_Melamine',
            edge_banding: 'PVC_White_2mm',
            grain_direction: 'L'
          },
          {
            name: 'Cabinet_Door_2',
            width: 350,
            height: 550,
            thickness: 18,
            material: 'Oak_Veneer',
            edge_banding: 'Wood_Edge_1mm',
            grain_direction: 'L'
          },
          {
            name: 'Shelf_Panel',
            width: 800,
            height: 300,
            thickness: 18,
            material: 'White_Melamine',
            edge_banding: 'PVC_White_2mm',
            grain_direction: 'W'
          },
          {
            name: 'Back_Panel',
            width: 1200,
            height: 800,
            thickness: 6,
            material: 'Plywood',
            edge_banding: 'None',
            grain_direction: 'Any'
          },
          {
            name: 'Drawer_Front',
            width: 450,
            height: 150,
            thickness: 18,
            material: 'Oak_Veneer',
            edge_banding: 'Wood_Edge_1mm',
            grain_direction: 'W'
          }
        ]

        x_offset = 0
        y_offset = 0

        test_components.each_with_index do |comp_data, index|
          # Remove any existing definition with same name if safe (no instances)
          existing_def = model.definitions[comp_data[:name]]
          if existing_def && existing_def.count_instances == 0
            existing_def.erase!
          end

          # Create component definition
          definition = model.definitions.add(comp_data[:name])

          # Create the geometry (a simple box) within the definition
          width_mm = comp_data[:width]
          height_mm = comp_data[:height]
          thickness_mm = comp_data[:thickness]

          width = width_mm.mm
          height = height_mm.mm
          thickness = thickness_mm.mm

          pts = [
            [0, 0, 0],
            [width, 0, 0],
            [width, height, 0],
            [0, height, 0]
          ]

          face = definition.entities.add_face(pts)
          # Ensure face was created before pushpull
          if face && face.valid?
            face.pushpull(thickness)
          end

          # Set material on the model and apply to all entities in the definition
          material = model.materials.add(comp_data[:material])

          case comp_data[:material]
          when 'White_Melamine'
            material.color = Sketchup::Color.new(245, 245, 245)
          when 'Oak_Veneer'
            material.color = Sketchup::Color.new(160, 120, 80)
          when 'Plywood'
            material.color = Sketchup::Color.new(200, 180, 140)
          else
            material.color = Sketchup::Color.new(200, 200, 200)
          end

          # Apply material to faces in definition
          definition.entities.grep(Sketchup::Face).each do |f|
            f.material = material
            f.back_material = material
          end

          # Create instance inside the parent group so model's main entities remain untouched
          transformation = Geom::Transformation.new([x_offset.mm, y_offset.mm, 0])
          instance = parent_group.entities.add_instance(definition, transformation)

          # Ensure the instance and parent are on the test Tag
          instance.layer = tag
          parent_group.layer = tag

          # Add text label (placed inside parent group)
          label_text = "#{comp_data[:name]}\n#{width_mm}x#{height_mm}x#{thickness_mm}mm\nMaterial: #{comp_data[:material]}\nEdge: #{comp_data[:edge_banding]}\nGrain: #{comp_data[:grain_direction]}"
          text_position = [x_offset.mm, (y_offset + height_mm + 20).mm, 0]
          text_entity = parent_group.entities.add_text(label_text, text_position)
          # orient text normal up
          if text_entity.respond_to?(:vector=)
            text_entity.vector = [0, 0, 1]
          end

          # Add edge banding visual indicators (construction lines on edges in the definition)
          if comp_data[:edge_banding] != 'None'
            # Find the top or bottom face by checking Z normal magnitude (near +/-1)
            target_face = nil
            definition.entities.grep(Sketchup::Face).each do |ent_face|
              # Use abs(normal.z) > 0.9 to reliably detect horizontal faces
              if ent_face.normal && ent_face.normal.z.abs > 0.9
                # choose the face whose area is approximately width*height
                target_face = ent_face
                break
              end
            end

            if target_face
              # Choose color name (not directly assigned to clines—SketchUp construction lines use layer visibility)
              # Add construction lines along edges to indicate banding
              target_face.edges.each do |edge|
                # create a construction line inside the definition
                p1 = edge.start.position
                p2 = edge.end.position
                cline = definition.entities.add_cline(p1, p2)
                # Optional: set a short attribute so we can style / identify it later
                cline.set_attribute('AutoNestCut', 'edge_banding_indicator', true)
              end
            end
          end

          # Set custom attributes for edge banding on both instance and definition
          instance.set_attribute('AutoNestCut', 'edge_banding', comp_data[:edge_banding])
          instance.set_attribute('AutoNestCut', 'grain_direction', comp_data[:grain_direction])
          instance.set_attribute('AutoNestCut', 'material_override', comp_data[:material])

          definition.set_attribute('AutoNestCut', 'edge_banding', comp_data[:edge_banding])
          definition.set_attribute('AutoNestCut', 'grain_direction', comp_data[:grain_direction])
          definition.set_attribute('AutoNestCut', 'material_override', comp_data[:material])

          # Additional edge-banding meta
          if comp_data[:edge_banding] != 'None'
            perimeter = 2 * (width_mm + height_mm)
            instance.set_attribute('AutoNestCut', 'edge_banding_length', perimeter)
            instance.set_attribute('AutoNestCut', 'edge_banding_type', comp_data[:edge_banding])
            definition.set_attribute('AutoNestCut', 'edge_banding_length', perimeter)
            definition.set_attribute('AutoNestCut', 'edge_banding_type', comp_data[:edge_banding])

            case comp_data[:edge_banding]
            when 'PVC_White_2mm'
              instance.set_attribute('AutoNestCut', 'edge_banding_edges', 'All_4_edges')
              definition.set_attribute('AutoNestCut', 'edge_banding_edges', 'All_4_edges')
            when 'Wood_Edge_1mm'
              instance.set_attribute('AutoNestCut', 'edge_banding_edges', '2_long_edges')
              definition.set_attribute('AutoNestCut', 'edge_banding_edges', '2_long_edges')
            end
          end

          # Advance offsets for next component
          x_offset += width_mm + 100
          if x_offset > 2000
            x_offset = 0
            y_offset += height_mm + 150
          end
        end

        # Zoom to fit the new group content only (safer - zooms the model view)
        model.active_view.zoom_extents

        model.commit_operation
        puts "Generated #{test_components.length} test components with edge banding properties inside group '#{parent_group.name}' (Tag: #{tag_name})"
      rescue => e
        model.abort_operation
        UI.messagebox("Error generating test components: #{e.message}")
        puts e.backtrace
      end
    end

    # ... remaining methods unchanged except they should respect tags/groups if needed ...
    # For the rest of the class (add_edge_banding_to_selection, show_component_info, clear_edge_banding_from_selection)
    # you can reuse the original implementations; they will work normally because instances are normal component instances.

    def self.add_edge_banding_to_selection
      model = Sketchup.active_model
      selection = model.selection
      return if selection.empty?
      model.start_operation('Add Edge Banding Properties', true)
      begin
        edge_banding_types = ['PVC_White_2mm', 'Wood_Edge_1mm', 'ABS_Black_1mm', 'Veneer_Edge_0.5mm']
        selection.each_with_index do |entity, index|
          next unless entity.is_a?(Sketchup::ComponentInstance)
          edge_banding = edge_banding_types[index % edge_banding_types.length]
          entity.set_attribute('AutoNestCut', 'edge_banding', edge_banding)
          entity.set_attribute('AutoNestCut', 'edge_banding_type', edge_banding)
          bounds = entity.bounds
          width = bounds.width.to_mm
          height = bounds.height.to_mm
          perimeter = 2 * (width + height)
          entity.set_attribute('AutoNestCut', 'edge_banding_length', perimeter)
          case edge_banding
          when 'PVC_White_2mm', 'ABS_Black_1mm'
            entity.set_attribute('AutoNestCut', 'edge_banding_edges', 'All_4_edges')
          when 'Wood_Edge_1mm', 'Veneer_Edge_0.5mm'
            entity.set_attribute('AutoNestCut', 'edge_banding_edges', '2_long_edges')
          end
          grain_directions = ['L', 'W', 'Any']
          grain = grain_directions[index % grain_directions.length]
          entity.set_attribute('AutoNestCut', 'grain_direction', grain)
        end
        model.commit_operation
        puts "Added edge banding properties to #{selection.length} selected components"
      rescue => e
        model.abort_operation
        UI.messagebox("Error adding edge banding properties: #{e.message}")
      end
    end

    def self.show_component_info
      model = Sketchup.active_model
      selection = model.selection
      if selection.empty?
        UI.messagebox("Please select one or more components to view their properties.")
        return
      end
      info_text = "Component Information:\n\n"
      selection.each_with_index do |entity, index|
        next unless entity.is_a?(Sketchup::ComponentInstance)
        info_text += "Component #{index + 1}: #{entity.definition.name}\n"
        bounds = entity.bounds
        width = bounds.width.to_mm.round(1)
        height = bounds.height.to_mm.round(1)
        depth = bounds.depth.to_mm.round(1)
        info_text += "  Dimensions: #{width} x #{height} x #{depth} mm\n"
        edge_banding = entity.get_attribute('AutoNestCut', 'edge_banding') || 'None'
        grain_direction = entity.get_attribute('AutoNestCut', 'grain_direction') || 'Not set'
        material_override = entity.get_attribute('AutoNestCut', 'material_override') || 'Default'
        info_text += "  Edge Banding: #{edge_banding}\n"
        info_text += "  Grain Direction: #{grain_direction}\n"
        info_text += "  Material: #{material_override}\n"
        if edge_banding != 'None'
          edge_length = entity.get_attribute('AutoNestCut', 'edge_banding_length')
          edge_config = entity.get_attribute('AutoNestCut', 'edge_banding_edges')
          info_text += "  Edge Length: #{edge_length.round(1)} mm\n" if edge_length
          info_text += "  Edge Config: #{edge_config}\n" if edge_config
        end
        info_text += "\n"
      end
      UI.messagebox(info_text)
    end

    def self.clear_edge_banding_from_selection
      model = Sketchup.active_model
      selection = model.selection
      return if selection.empty?
      model.start_operation('Clear Edge Banding Properties', true)
      begin
        selection.each do |entity|
          next unless entity.is_a?(Sketchup::ComponentInstance)
          entity.delete_attribute('AutoNestCut', 'edge_banding')
          entity.delete_attribute('AutoNestCut', 'edge_banding_type')
          entity.delete_attribute('AutoNestCut', 'edge_banding_length')
          entity.delete_attribute('AutoNestCut', 'edge_banding_edges')
        end
        model.commit_operation
        puts "Cleared edge banding properties from #{selection.length} selected components"
      rescue => e
        model.abort_operation
        UI.messagebox("Error clearing edge banding properties: #{e.message}")
      end
    end
  end
end

# Add menu items to the Extensions menu for easy access (as before)
unless file_loaded?(__FILE__)
  if defined?(AutoNestCut::TestEdgeBandingGenerator)
    extensions_menu = UI.menu('Extensions')
    autonest_menu = extensions_menu.add_submenu('AutoNestCut Test Tools')

    autonest_menu.add_item('Generate Test Components with Edge Banding') {
      AutoNestCut::TestEdgeBandingGenerator.generate_test_components
    }

    autonest_menu.add_item('Add Edge Banding to Selected Components') {
      AutoNestCut::TestEdgeBandingGenerator.add_edge_banding_to_selection
    }

    autonest_menu.add_item('Clear Edge Banding from Selected Components') {
      AutoNestCut::TestEdgeBandingGenerator.clear_edge_banding_from_selection
    }

    autonest_menu.add_item('Show Component Information') {
      AutoNestCut::TestEdgeBandingGenerator.show_component_info
    }

    file_loaded(__FILE__)
  end
end
