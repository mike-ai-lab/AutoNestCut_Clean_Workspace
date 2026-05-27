require 'set'
require_relative '../models/part' # Ensure the Part class is loaded
require_relative '../util' # Ensure Util module is loaded

module AutoNestCut
  class ModelAnalyzer

    def initialize
      @selected_entities = []
      @original_components = []
      @hierarchy_tree = []
      @processed_entities = Set.new
      @progress_callback = nil
    end

    def analyze_selection(selection, progress_callback = nil)
      @selected_entities = selection.to_a
      @original_components = [] # Reset for a fresh analysis
      @hierarchy_tree = [] # Reset for a fresh analysis
      @processed_entities = Set.new # Reset processed entities for a fresh analysis
      @progress_callback = progress_callback
      
      total_entities = @selected_entities.length

      # Initialize definition_counts here so it's accessible throughout this method
      definition_counts = Hash.new(0) # <-- CRITICAL FIX: Initialize here

      # AGGRESSIVE RECURSIVE SEARCH through ALL levels
      @selected_entities.each_with_index do |entity, index|
        if @progress_callback
          progress = 10 + (index.to_f / total_entities * 70).round(1)
          @progress_callback.call("Analyzing components... #{index + 1}/#{total_entities}", progress)
        end
        
        # Pass nil as inherited_material for root entities - they have no parent
        deep_recursive_search(entity, definition_counts, Geom::Transformation.new, false, nil)
      end
      
      # Build hierarchy tree AFTER analysis (faster)
      @hierarchy_tree = @selected_entities.map { |entity| build_simple_tree(entity, 0) }.compact

      # Store original component data before conversion
      original_components_with_entities = @original_components.dup

      # Convert original_components to final format in batch
      @original_components.map! do |comp_data|
        next nil unless comp_data[:entity]
        
        entity = comp_data[:entity]
        
        # Handle both components and groups
        if entity.is_a?(Sketchup::ComponentInstance)
          next nil unless entity.definition
          part_temp = AutoNestCut::Part.new(entity, comp_data[:material])
          {
            name: entity.definition.name,
            entity_id: entity.entityID,
            definition_id: entity.definition.entityID,
            width: part_temp.width.round(2),
            height: part_temp.height.round(2),
            depth: part_temp.thickness.round(2),
            position: {
              x: (comp_data[:transform].origin.x * 25.4).round(2),
              y: (comp_data[:transform].origin.y * 25.4).round(2),
              z: (comp_data[:transform].origin.z * 25.4).round(2)
            },
            material: part_temp.material,
            definition: entity.definition,
            has_face_materials: comp_data[:has_face_materials]
          }
        elsif entity.is_a?(Sketchup::Group)
          part_temp = AutoNestCut::Part.new(entity, comp_data[:material])
          {
            name: entity.name || "Group_#{entity.entityID}",
            entity_id: entity.entityID,
            definition_id: entity.entityID,
            width: part_temp.width.round(2),
            height: part_temp.height.round(2),
            depth: part_temp.thickness.round(2),
            position: {
              x: (comp_data[:transform].origin.x * 25.4).round(2),
              y: (comp_data[:transform].origin.y * 25.4).round(2),
              z: (comp_data[:transform].origin.z * 25.4).round(2)
            },
            material: part_temp.material,
            definition: comp_data[:definition],
            is_group: true,
            has_face_materials: comp_data[:has_face_materials]
          }
        else
          nil
        end
      end.compact

      part_types_by_material = {}
      definition_count = definition_counts.length
      processed_definitions = 0

      # Process only sheet goods and batch create parts
      definition_counts.each do |definition, total_count_for_type|
        # Handle both component definitions and group keys
        is_group = definition.is_a?(String) && definition.start_with?('GROUP_')
        
        if !is_group
          next unless Util.is_sheet_good?(definition.bounds)
        end
        
        processed_definitions += 1
        
        if @progress_callback
          progress = 80 + (processed_definitions.to_f / definition_count * 20).round(1)
          @progress_callback.call("Creating part types... #{processed_definitions}/#{definition_count}", progress)
        end
        
        # Find a representative component with this definition to get material
        representative = if is_group
          original_components_with_entities.find { |comp| comp && comp[:is_group] && comp[:definition] == definition }
        else
          original_components_with_entities.find { |comp| comp && comp[:definition] == definition }
        end
        
        next unless representative
        
        detected_material = representative[:material]
        entity = representative[:entity]
        
        next unless entity
        
        # Create part_type using the actual entity, passing the detected material as override
        part_type = AutoNestCut::Part.new(entity, detected_material)
        material_name = part_type.material
        thickness = part_type.thickness
        grain_direction = part_type.grain_direction || 'Any'
        
        # Group by material + thickness + grain direction.
        # Use a readable fallback key when no material is assigned so the report
        # shows "No Material" instead of a blank/nil prefix like "_18.0mm_grain_Any".
        display_material = material_name.nil? || material_name.strip.empty? ? 'No Material' : material_name
        material_key = "#{display_material}_#{thickness.round(2)}mm_grain_#{grain_direction}"
        
        part_types_by_material[material_key] ||= []
        part_types_by_material[material_key] << { part_type: part_type, total_quantity: total_count_for_type }
      end
      
      # Generate unique names for unnamed parts
      global_part_counter = 1
      part_types_by_material.each do |material_name, parts_array|
        parts_array.each do |part_data|
          part = part_data[:part_type]
          original_name = part.name
          
          # Check if name is nil, empty, "Part", or starts with "Unnamed"
          if original_name.nil? || original_name.empty? || original_name == "Part" || original_name.start_with?("Unnamed")
            new_name = "Part_#{global_part_counter}"
            part.name = new_name
            global_part_counter += 1
          end
        end
      end
      
      # Check for material mismatches and generate warnings
      warnings = []
      @original_components.each do |comp|
        next unless comp
        
        container_material = comp[:material]
        has_face_materials = comp[:has_face_materials]
        comp_name = comp[:name]
        
        if container_material && !has_face_materials
          warnings << {
            name: comp_name,
            container_material: container_material,
            issue: 'Material applied to component container but not to faces'
          }
        end
      end
      
      # Store warnings for later display
      @material_warnings = warnings

      part_types_by_material
    end
    
    def get_material_warnings
      @material_warnings || []
    end

    def get_original_components_data
      @original_components || []
    end
    
    def get_hierarchy_tree
      @hierarchy_tree || []
    end

    private

    # AGGRESSIVE DEEP RECURSIVE SEARCH - Goes through ALL nesting levels
    # Processes BOTH components AND groups as valid sheet goods
    # Only counts LEAF components (no children), never parent containers.
    # inherited_material: the resolved material name from the nearest ancestor that had one,
    # used as a fallback when a leaf has no material of its own.
    def deep_recursive_search(entity, definition_counts, transformation = Geom::Transformation.new, is_root_selection = false, inherited_material = nil)
      # Skip non-geometry entities silently (construction points, edges, guides, text)
      return unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
      
      if entity.is_a?(Sketchup::ComponentInstance)
        definition = entity.definition
        
        # Resolve this instance's own material, then fall back to what was inherited
        own_material = entity.material&.display_name || entity.material&.name
        resolved_material = own_material || inherited_material
        
        # Check if this component has any nested components or groups
        has_nested_components = definition.entities.any? { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
        
        if !has_nested_components && Util.is_sheet_good?(definition.bounds)
          definition_counts[definition] ||= 0
          definition_counts[definition] += 1
          
          combined_transform = transformation * entity.transformation
          
          has_face_materials = definition.entities.any? do |e|
            e.is_a?(Sketchup::Face) && (e.material || e.back_material)
          end
          
          # Use face-dominant material if faces are painted, otherwise use resolved (instance or inherited)
          effective_material = if has_face_materials
            Util.get_dominant_material(definition) || resolved_material
          else
            resolved_material
          end
          
          @original_components << {
            entity: entity,
            transform: combined_transform,
            material: effective_material,
            definition: definition,
            has_face_materials: has_face_materials
          }
        end
        
        # Recurse into children, passing down the resolved material so grandchildren can inherit it
        component_transform = transformation * entity.transformation
        definition.entities.each { |child| deep_recursive_search(child, definition_counts, component_transform, false, resolved_material) }
        
      elsif entity.is_a?(Sketchup::Group)
        own_material = entity.material&.display_name || entity.material&.name
        resolved_material = own_material || inherited_material
        
        has_nested_entities = entity.entities.any? { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }
        
        if !has_nested_entities && Util.is_sheet_good?(entity.bounds)
          group_key = "GROUP_#{entity.entityID}"
          definition_counts[group_key] ||= 0
          definition_counts[group_key] += 1
          
          combined_transform = transformation * entity.transformation
          
          has_face_materials = entity.entities.any? do |e|
            e.is_a?(Sketchup::Face) && (e.material || e.back_material)
          end
          
          effective_material = if has_face_materials
            Util.get_dominant_material(entity) || resolved_material
          else
            resolved_material
          end
          
          @original_components << {
            entity: entity,
            transform: combined_transform,
            material: effective_material,
            definition: group_key,
            has_face_materials: has_face_materials,
            is_group: true
          }
        end
        
        group_transform = transformation * entity.transformation
        entity.entities.each { |child| deep_recursive_search(child, definition_counts, group_transform, false, resolved_material) }
      end
    end
    
    # Simple tree builder that always creates nodes 
    def build_simple_tree(entity, level)
      if entity.is_a?(Sketchup::ComponentInstance)
        # Use Part constructor for consistency in getting material and dimensions
        part_temp = AutoNestCut::Part.new(entity) # Pass the instance for more accurate material detection
        
        {
          type: 'component',
          name: entity.definition.name || 'Unnamed Component',
          level: level,
          material: part_temp.material, # Direct material lookup
          dimensions: "#{part_temp.width.round(1)}x#{part_temp.height.round(1)}x#{part_temp.thickness.round(1)}mm", # Use thickness
          children: []
        }
      elsif entity.is_a?(Sketchup::Group)
        children = []
        entity.entities.each do |child|
          if child.is_a?(Sketchup::ComponentInstance) || child.is_a?(Sketchup::Group)
            child_node = build_simple_tree(child, level + 1)
            children << child_node if child_node
          end
        end
        
        {
          type: 'group',
          name: entity.name || "Group_#{entity.entityID}",
          level: level,
          material: 'Container', # Groups don't typically have "material" like parts
          dimensions: '',
          children: children
        }
      else
        nil
      end
    end
    
    # build_hierarchy_tree is not currently used by analyze_selection, but updated for consistency
    def build_hierarchy_tree(entity, level)
      if entity.is_a?(Sketchup::ComponentInstance)
        children = []
        entity.definition.entities.each do |child|
          child_node = build_hierarchy_tree(child, level + 1)
          children << child_node if child_node
        end
        
        bounds = entity.definition.bounds
        part_temp = AutoNestCut::Part.new(entity) # Pass the instance for more accurate material detection

        if Util.is_sheet_good?(bounds)
          {
            type: 'component',
            name: entity.definition.name || 'Unnamed Component',
            level: level,
            material: part_temp.material,
            dimensions: "#{part_temp.width.round(1)}x#{part_temp.height.round(1)}x#{part_temp.thickness.round(1)}mm", # Use thickness
            children: children
          }
        elsif children.any?
          {
            type: 'component',
            name: entity.definition.name || 'Assembly',
            level: level,
            material: 'Assembly',
            dimensions: '',
            children: children
          }
        else
          nil
        end
      elsif entity.is_a?(Sketchup::Group)
        children = []
        entity.entities.each do |child|
          child_node = build_hierarchy_tree(child, level + 1)
          children << child_node if child_node
        end
        
        {
          type: 'group',
          name: entity.name || "Group_#{entity.entityID}",
          level: level,
          material: 'Container',
          dimensions: '',
          children: children
        }
      else
        nil
      end
    end
  end
end
