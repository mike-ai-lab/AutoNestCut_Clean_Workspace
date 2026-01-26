require_relative '../util' # Ensure Util module is loaded for get_dimensions and get_dominant_material

module AutoNestCut
  class Part
    attr_accessor :name, :width, :height, :thickness, :material, :grain_direction, :edge_banding
    attr_reader :original_definition
    attr_accessor :x, :y, :rotated, :instance_id
    attr_accessor :texture_data # Ensure texture_data is accessible

    # Constructor now expects a component_definition_or_instance and optionally a specific Sketchup::Material object
    # or material_name string. Also handles Sketchup::Group entities.
    def initialize(component_definition_or_instance, specific_material = nil)
      
      # Determine if we're initialized with a ComponentDefinition, ComponentInstance, or Group
      if component_definition_or_instance.is_a?(Sketchup::ComponentDefinition)
        @original_definition = component_definition_or_instance
        definition = component_definition_or_instance
        instance_material = nil
      elsif component_definition_or_instance.is_a?(Sketchup::ComponentInstance)
        @original_definition = component_definition_or_instance.definition
        definition = component_definition_or_instance.definition
        instance_material = component_definition_or_instance.material
      elsif component_definition_or_instance.is_a?(Sketchup::Group)
        # Groups don't have definitions, treat the group itself as the definition
        @original_definition = component_definition_or_instance
        definition = component_definition_or_instance
        instance_material = component_definition_or_instance.material
      else
        raise ArgumentError, "Part must be initialized with a Sketchup::ComponentDefinition, ComponentInstance, or Group"
      end

      @name = definition.respond_to?(:name) ? definition.name : "Group_#{definition.entityID}"

      dimensions_mm = Util.get_dimensions(definition.bounds).sort
      @thickness = dimensions_mm[0]
      @width = dimensions_mm[1]
      @height = dimensions_mm[2]

      detected_material = nil
      if specific_material.is_a?(Sketchup::Material)
        detected_material = specific_material.display_name || specific_material.name
        puts "  Material from specific_material parameter: #{detected_material.inspect}"
      elsif specific_material.is_a?(String)
        detected_material = specific_material
        puts "  Material from specific_material string: #{detected_material.inspect}"
      end

      unless detected_material
        detected_material = instance_material&.display_name || instance_material&.name
      end
      unless detected_material
        if definition.respond_to?(:material)
          detected_material = definition.material&.display_name || definition.material&.name
        end
      end
      
      unless detected_material
        if definition.respond_to?(:entities)
          detected_material = AutoNestCut::Util.get_dominant_material(definition)
        end
      end

      @material = detected_material && detected_material != 'No Material' ? detected_material : nil
      
      # Get grain direction from attribute dictionaries
      @grain_direction = 'Any'
      if component_definition_or_instance.is_a?(Sketchup::ComponentInstance)
        @grain_direction = component_definition_or_instance.get_attribute('AutoNestCut', 'grain_direction') ||
                          component_definition_or_instance.get_attribute('DynamicAttributes', 'grain_direction') ||
                          @grain_direction
      elsif component_definition_or_instance.is_a?(Sketchup::Group)
        @grain_direction = component_definition_or_instance.get_attribute('AutoNestCut', 'grain_direction') || 'Any'
      end
      if @grain_direction == 'Any' && definition.respond_to?(:get_attribute)
        @grain_direction = definition.get_attribute('AutoNestCut', 'grain_direction') ||
                          definition.get_attribute('DynamicAttributes', 'grain_direction') ||
                          'Any'
      end
      
      # Get edge banding from attribute dictionaries
      edge_banding_raw = 'None'
      if component_definition_or_instance.is_a?(Sketchup::ComponentInstance)
        edge_banding_raw = component_definition_or_instance.get_attribute('AutoNestCut', 'edge_banding') ||
                          component_definition_or_instance.get_attribute('DynamicAttributes', 'edge_banding') ||
                          edge_banding_raw
      elsif component_definition_or_instance.is_a?(Sketchup::Group)
        edge_banding_raw = component_definition_or_instance.get_attribute('AutoNestCut', 'edge_banding') || 'None'
      end
      if edge_banding_raw == 'None' && definition.respond_to?(:get_attribute)
        edge_banding_raw = definition.get_attribute('AutoNestCut', 'edge_banding') ||
                          definition.get_attribute('DynamicAttributes', 'edge_banding') ||
                          'None'
      end
      
      # Parse edge banding specification (format: "PVC_White:top,bottom" or "PVC_White" for all edges)
      @edge_banding = parse_edge_banding(edge_banding_raw)
      
      material_obj = nil
      if @material && @material != 'No Material'
        material_obj = Sketchup.active_model.materials[@material]
      end
      @texture_data = material_obj ? material_obj.color.to_a : [200, 200, 200]

      @x = 0.0
      @y = 0.0
      @rotated = false
      @instance_id = nil
    end

    def create_placed_instance
      # When creating a placed instance, copy attributes from the original Part
      placed_part = Part.new(@original_definition) # Initialize with original definition
      placed_part.name = @name
      placed_part.width = @width
      placed_part.height = @height
      placed_part.thickness = @thickness
      placed_part.material = @material
      placed_part.grain_direction = @grain_direction
      placed_part.edge_banding = @edge_banding
      placed_part.texture_data = @texture_data # Copy texture data too

      placed_part.instance_id = nil # This is a new placement
      placed_part.x = 0.0
      placed_part.y = 0.0
      placed_part.rotated = false
      placed_part
    end

    def area
      @width * @height
    end

    def volume_m3
      (@width * @height * @thickness) / 1_000_000_000.0
    end

    def weight_kg(density = 600)
      volume_m3 * density
    end

    def rotate!
      # Check if rotation is allowed based on grain_direction
      return false if @grain_direction && ['fixed', 'vertical', 'horizontal'].include?(@grain_direction.downcase)
      @width, @height = @height, @width
      @rotated = !@rotated
      true
    end

    def can_rotate?
      return false if @grain_direction && ['fixed', 'vertical', 'horizontal'].include?(@grain_direction.downcase)
      true
    end

    def fits_in?(board_width, board_height, kerf_width = 0)
      w_with_kerf = @width + kerf_width
      h_with_kerf = @height + kerf_width

      return true if w_with_kerf <= board_width && h_with_kerf <= board_height
      if can_rotate?
        return true if h_with_kerf <= board_width && w_with_kerf <= board_height
      end
      false
    end

    def get_edge_banding_summary
      return { type: 'None', edges: [], total_length: 0 } if @edge_banding[:type] == 'None'
      
      edges_with_lengths = []
      total_length = 0
      
      @edge_banding[:edges].each do |edge|
        length = case edge
                when 'top', 'bottom' then @width || 0
                when 'left', 'right' then @height || 0
                else 0
                end
        edges_with_lengths << { edge: edge, length: length.round(2) } if length > 0
        total_length += length
      end
      
      {
        type: @edge_banding[:type],
        edges: edges_with_lengths,
        total_length: total_length.round(2)
      }
    end

    def to_h
      {
        name: @name,
        width: @width.round(2),
        height: @height.round(2),
        thickness: @thickness.round(2),
        material: @material,
        grain_direction: @grain_direction,
        edge_banding: @edge_banding,
        edge_banding_summary: get_edge_banding_summary,
        area: area.round(2),
        x: @x.round(2),
        y: @y.round(2),
        rotated: @rotated,
        instance_id: @instance_id,
        texture_data: @texture_data # Include texture_data in hash
      }
    end

    private

    def parse_edge_banding(raw_value)
      return { type: 'None', edges: [] } if raw_value.nil? || raw_value == 'None'
      
      parts = raw_value.split(':')
      type = parts[0] || 'PVC_White'
      
      if parts.length > 1
        edges = parts[1].split(',').map(&:strip)
      else
        edges = ['top', 'bottom', 'left', 'right'] # Default to all edges
      end
      
      { type: type, edges: edges }
    end
  end
end
