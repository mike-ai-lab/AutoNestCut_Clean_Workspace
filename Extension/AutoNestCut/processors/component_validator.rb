require_relative '../materials_database'
require_relative '../config'
require_relative '../util'

module AutoNestCut
  class ComponentValidator
    
    # Soft limits - materials will be auto-created if exceeded
    SOFT_LIMIT_HEIGHT = 5000  # 5 meters in mm
    SOFT_LIMIT_WIDTH = 4000   # 4 meters in mm
    
    # Hard limits - components will be rejected if exceeded
    HARD_LIMIT_HEIGHT = 5500  # 5.5 meters in mm
    HARD_LIMIT_WIDTH = 4500   # 4.5 meters in mm
    
    # Minimum realistic dimensions
    MIN_DIMENSION = 1          # 1mm minimum
    MIN_THICKNESS = 0.1        # 0.1mm minimum
    
    # Maximum realistic thickness for sheet materials
    MAX_THICKNESS = 500        # 500mm maximum
    
    def initialize
      @auto_created_materials = []
      @validation_warnings = []
      @validation_errors = []
    end
    
    # Main validation method called at extension launch
    # Returns: { success: boolean, materials_created: array, warnings: array, errors: array, missing_materials: array }
    def validate_and_prepare_materials(parts_by_material)
      @auto_created_materials = []
      @validation_warnings = []
      @validation_errors = []
      @missing_materials = []
      
      return { success: false, materials_created: [], warnings: [], errors: ['No components to validate'], missing_materials: [] } if parts_by_material.empty?
      
      # Load existing materials database
      existing_materials = MaterialsDatabase.load_database
      
      # Merge default materials so fuzzy matching has more options
      default_materials = MaterialsDatabase.get_default_materials
      existing_materials = default_materials.merge(existing_materials)
      
      # Remove all old auto-materials to prevent dimension mismatches
      existing_materials.reject! { |name, _| name.start_with?('Auto_user_') }
      
      default_currency = Config.get_cached_settings['default_currency'] || 'USD'
      
      # Validate each material and its components
      parts_by_material.each do |material_name, part_entries|
        validate_material_and_components(material_name, part_entries, existing_materials, default_currency)
      end
      
      # Save any newly created materials to database
      if @auto_created_materials.any?
        updated_materials = existing_materials.merge(
          @auto_created_materials.each_with_object({}) { |mat, hash| hash[mat[:name]] = mat[:data] }
        )
        MaterialsDatabase.save_database(updated_materials)
      end
      
      {
        success: @validation_errors.empty?,
        materials_created: @auto_created_materials,
        warnings: @validation_warnings,
        errors: @validation_errors,
        missing_materials: @missing_materials,
        material_remappings: @material_remappings || {}
      }
    end
    
    def get_material_remappings
      @material_remappings || {}
    end
    
    private
    
    # Check if EXACT material exists (name + thickness)
    # Returns: [exists?, actual_material_data]
    def exact_material_exists?(material_name, thickness, existing_materials)
      return [false, nil] unless existing_materials.key?(material_name)
      
      # Materials are stored as arrays of thickness variations
      thickness_variations = existing_materials[material_name]
      
      # Handle both array and single hash formats (for backward compatibility)
      thickness_variations = [thickness_variations] unless thickness_variations.is_a?(Array)
      
      # Search for matching thickness (with 0.01mm tolerance)
      matching = thickness_variations.find { |mat| (mat['thickness'].to_f - thickness).abs < 0.01 }
      
      [!matching.nil?, matching]
    end
    
    # Get the actual material name from database (handles thickness suffixes)
    def get_actual_material_name(material_name, thickness, existing_materials)
      exists, actual_name = exact_material_exists?(material_name, thickness, existing_materials)
      exists ? actual_name : nil
    end
    
    # Collect missing material for user decision
    def collect_missing_material(material_name, thickness, part_obj, width, height)
      # Check if we already collected this material
      existing = @missing_materials.find { |m| m[:name] == material_name && m[:thickness] == thickness }
      
      if existing
        # Add component to existing missing material
        existing[:component_count] += 1
        existing[:components] << {
          name: part_obj.name,
          width: width.round(1),
          height: height.round(1)
        }
      else
        # New missing material
        @missing_materials << {
          name: material_name,
          thickness: thickness.round(2),
          component_count: 1,
          components: [{
            name: part_obj.name,
            width: width.round(1),
            height: height.round(1)
          }]
        }
      end
    end
    
    def validate_material_and_components(material_name, part_entries, existing_materials, default_currency)
      part_entries.each do |part_entry|
        part_obj = if part_entry.is_a?(Hash) && part_entry.key?(:part_type)
                     part_entry[:part_type]
                   else
                     part_entry
                   end
        
        next unless part_obj.respond_to?(:width) && part_obj.respond_to?(:height) && part_obj.respond_to?(:thickness)
        
        width = part_obj.width.to_f
        height = part_obj.height.to_f
        thickness = part_obj.thickness.to_f
        
        # Hard constraints
        if width > HARD_LIMIT_WIDTH || height > HARD_LIMIT_HEIGHT
          @validation_errors << "Component '#{part_obj.name}': #{width.round(0)}x#{height.round(0)}mm exceeds maximum limits (#{HARD_LIMIT_WIDTH}x#{HARD_LIMIT_HEIGHT}mm). This component is too large to fit on any standard sheet material."
          next
        end
        
        if width < MIN_DIMENSION || height < MIN_DIMENSION
          @validation_errors << "Component '#{part_obj.name}': #{width.round(1)}x#{height.round(1)}mm is too small (minimum #{MIN_DIMENSION}mm)"
          next
        end
        
        if thickness > MAX_THICKNESS
          @validation_errors << "Component '#{part_obj.name}': #{thickness.round(0)}mm thick - not a sheet material (maximum #{MAX_THICKNESS}mm)"
          next
        end
        
        if thickness < MIN_THICKNESS
          @validation_errors << "Component '#{part_obj.name}': #{thickness.round(2)}mm thick - too thin (minimum #{MIN_THICKNESS}mm)"
          next
        end
        
        # Warn if it exceeds the common standard sheet
        can_fit_on_standard_sheet = false
        if (width <= 2440 && height <= 1220) || (height <= 2440 && width <= 1220)
          can_fit_on_standard_sheet = true
        end
        
        unless can_fit_on_standard_sheet
          @validation_warnings << "Component '#{part_obj.name}': #{width.round(1)}x#{height.round(1)}mm exceeds standard sheet size (2440x1220mm). This may require custom material sizing."
        end
        
        # If no material name assigned -> flagged temporary material
        if material_name.nil? || material_name.to_s.strip.empty?
          auto_create_flagged_material(part_obj.name, width, height, thickness, default_currency, existing_materials)
          next
        end
        
        # If material is already an auto-created placeholder, skip
        if material_name.to_s.start_with?('Auto_user_') || material_name.to_s.start_with?('no_material_')
          next
        end
        
        # Exact match only - no fuzzy matching
        exact_match, material_data = exact_material_exists?(material_name, thickness, existing_materials)
        
        unless exact_match
          # Material doesn't exist exactly as specified. Collect as missing.
          collect_missing_material(material_name, thickness, part_obj, width, height)
        end
      end
    end
    
    def auto_create_oversized_material(base_material_name, width, height, thickness, default_currency, existing_materials)
      # Handle nil material names - convert to string first, then check
      base_material_name = base_material_name.to_s.strip
      base_material_name = 'unknown' if base_material_name.empty?
      
      # CRITICAL FIX: Prevent nested auto-material wrapping
      # If this is already an auto-material, extract the ORIGINAL material name
      original_sketchup_material = base_material_name
      
      if base_material_name.start_with?('Auto_user_')
        # This is already an auto-material - extract the original SketchUp material
        # Format: Auto_user_W{W}xH{H}xTH{TH}_(OriginalMaterial)
        match = base_material_name.match(/\(([^)]+)\)$/)
        if match
          extracted = match[1]
          # If the extracted material is ALSO an auto-material, keep extracting
          while extracted.start_with?('Auto_user_')
            inner_match = extracted.match(/\(([^)]+)\)$/)
            break unless inner_match
            extracted = inner_match[1]
          end
          original_sketchup_material = extracted
        end
      elsif base_material_name.start_with?('no_material_')
        # This is a flagged material - extract the component name
        match = base_material_name.match(/\(([^)]+)\)$/)
        original_sketchup_material = match ? match[1] : base_material_name
      end
      
      # Generate unique material name with new formula: Auto_user_W{W}xH{H}xTH{TH}_(SketchUpMaterialName)
      # Note: No padding in the name - it reflects actual component dimensions
      material_name = generate_user_material_name(width, height, thickness, original_sketchup_material)
      
      # Skip if already created in this session
      return if @auto_created_materials.any? { |m| m[:name] == material_name }
      
      # Calculate pricing based on area ratio vs. closest standard material
      price = calculate_material_price(width, height, thickness, existing_materials, default_currency)
      
      # Create material data with auto_generated flag
      # CRITICAL: Material dimensions should be exactly the component dimensions
      # The nester will add kerf during placement, so we don't add it here
      material_data = {
        'width' => width.round(1),
        'height' => height.round(1),
        'thickness' => thickness.round(2),
        'price' => price,
        'currency' => default_currency,
        'density' => 600,  # Default density for sheet materials
        'auto_generated' => true,
        'created_at' => Time.now.to_s,
        'original_sketchup_material' => original_sketchup_material
      }
      
      @auto_created_materials << {
        name: material_name,
        data: material_data,
        base_material: base_material_name,
        dimensions: "#{width.round(1)}x#{height.round(1)}mm"
      }
      
      @validation_warnings << "Auto-created material '#{material_name}' for component (#{width.round(1)}x#{height.round(1)}mm). Rename in configuration as needed."
    end
    
    def auto_create_flagged_material(component_name, width, height, thickness, default_currency, existing_materials)
      # Create a flagged material for components with no material assigned
      # Format: no_material_W{W}xH{H}xTH{TH}_(component_name)
      # This flags the issue for user attention while allowing processing to continue
      
      width_rounded = width.round(0)
      height_rounded = height.round(0)
      thickness_rounded = thickness.round(0)
      
      # Sanitize component name
      sanitized_name = component_name.to_s.strip
      sanitized_name = 'unnamed' if sanitized_name.empty?
      
      material_name = "no_material_W#{width_rounded}xH#{height_rounded}xTH#{thickness_rounded}_(#{sanitized_name})"
      
      # Skip if already created in this session
      return if @auto_created_materials.any? { |m| m[:name] == material_name }
      
      # Calculate pricing
      price = calculate_material_price(width, height, thickness, existing_materials, default_currency)
      
      # Create material data with flagged indicator
      material_data = {
        'width' => width.round(1),
        'height' => height.round(1),
        'thickness' => thickness.round(2),
        'price' => price,
        'currency' => default_currency,
        'density' => 600,
        'auto_generated' => true,
        'flagged_no_material' => true,  # Flag indicating no material was assigned
        'created_at' => Time.now.to_s,
        'original_sketchup_material' => 'NO_MATERIAL'
      }
      
      @auto_created_materials << {
        name: material_name,
        data: material_data,
        base_material: 'NO_MATERIAL',
        dimensions: "#{width.round(1)}x#{height.round(1)}mm"
      }
      
      @validation_warnings << "⚠️  FLAGGED: Component '#{component_name}' has no material assigned. Created temporary material '#{material_name}'. Please assign a proper material to this component."
    end
    
    def generate_user_material_name(width, height, thickness, sketchup_material_name)
      # Deterministic formula: Auto_user_W{componentWidth}xH{componentHeight}xTH{componentThickness}_(SketchUpMaterialName)
      # No padding - dimensions reflect actual component size
      # The nester will add kerf during placement
      # Example: Component 250x750x18, material 'silver_metal_finish' → Auto_user_W250xH750xTH18_(silver_metal_finish)
      
      width_rounded = width.round(0)
      height_rounded = height.round(0)
      thickness_rounded = thickness.round(0)
      
      # Sanitize the SketchUp material name for use in the auto-material name
      sanitized_material = sketchup_material_name.to_s.strip
      sanitized_material = 'unknown' if sanitized_material.empty?
      
      "Auto_user_W#{width_rounded}xH#{height_rounded}xTH#{thickness_rounded}_(#{sanitized_material})"
    end
    
    def calculate_material_price(width, height, thickness, existing_materials, default_currency)
      # CRITICAL FIX: Default price for auto-generated materials is now 300
      # This ensures materials have a reasonable default price instead of 0
      
      # Calculate area of the new material
      new_area = (width * height) / 1_000_000.0  # Convert to m²
      
      # Find closest standard material by area with non-zero price
      closest_material = nil
      closest_ratio = nil
      
      existing_materials.each do |name, data|
        next if name.start_with?('user_')  # Skip other user-created materials
        next if data['price'].to_f == 0  # Skip materials with 0 price
        
        std_width = data['width'].to_f
        std_height = data['height'].to_f
        std_area = (std_width * std_height) / 1_000_000.0
        
        ratio = new_area / std_area
        
        if closest_ratio.nil? || (ratio - 1.0).abs < (closest_ratio - 1.0).abs
          closest_material = data
          closest_ratio = ratio
        end
      end
      
      # If no standard material found with non-zero price, use default pricing of 300
      if closest_material.nil?
        # Default: 300 for auto-generated materials
        return 300
      end
      
      # Calculate price based on area ratio
      base_price = closest_material['price'].to_f
      base_area = (closest_material['width'].to_f * closest_material['height'].to_f) / 1_000_000.0
      
      # Price per m² of base material
      price_per_m2 = base_price / base_area
      
      # Apply 10% premium for custom/oversized materials
      custom_price_per_m2 = price_per_m2 * 1.1
      
      # Calculate final price
      (new_area * custom_price_per_m2).round(2)
    end
    
    def get_auto_created_materials
      @auto_created_materials
    end
    
    def get_validation_warnings
      @validation_warnings
    end
    
    def get_validation_errors
      @validation_errors
    end
  end
end
