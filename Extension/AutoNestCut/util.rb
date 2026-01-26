# AutoNestCut/util.rb
module AutoNestCut
  module Util
    
    # Unit conversion factors (to mm) - UI's internal is mm, so 1mm = 1mm
    UNIT_FACTORS = {
      'mm' => 1.0,
      'cm' => 10.0,
      'm' => 1000.0,
      'in' => 25.4,
      'ft' => 304.8
    }.freeze
    
    UNIT_LABELS = {
      'mm' => 'mm',
      'cm' => 'cm', 
      'm' => 'm',
      'in' => 'in',
      'ft' => 'ft'
    }.freeze

    # Area conversion factors (divisor to convert from mm² to target unit's square area)
    # e.g., area_mm2 / AREA_FACTORS['m2'] = area_m2
    AREA_FACTORS = {
      'mm2' => 1.0,
      'cm2' => 100.0, # 1 cm² = 100 mm²
      'm2' => 1_000_000.0, # 1 m² = 1,000,000 mm²
      'in2' => 645.16, # 1 in² = 645.16 mm²
      'ft2' => 92903.04 # 1 ft² = 92903.04 mm²
    }.freeze
    
    def self.to_mm(length)
      # This method typically comes from the Sketchup::Length class.
      # If you're calling it on a raw number, it might not exist.
      # Assuming 'length' here is a Sketchup::Length object for this call.
      length.respond_to?(:to_mm) ? length.to_mm : length.to_f
    end
    
    def self.from_mm(mm)
      # This method typically comes from the Sketchup::Length class.
      # If you're building a Length object from mm, you'd do:
      # mm.mm
      # For now, just return the float value.
      mm.to_f
    end
    
    # Converts a value from one linear unit to another.
    def self.convert_units(value_mm, from_units, to_units, precision = nil)
      return value_mm if from_units == to_units
      
      factor_from = UNIT_FACTORS[from_units] || 1.0
      factor_to = UNIT_FACTORS[to_units] || 1.0
      
      # Convert to mm first, then to target unit
      value_in_mm = value_mm * factor_from
      converted_value = value_in_mm / factor_to
      
      precision ? converted_value.round(precision) : converted_value
    end

    # Converts an area value from one square unit to another.
    def self.convert_area_units(area_mm2, from_area_units, to_area_units, precision = nil)
      return area_mm2 if from_area_units == to_area_units
      
      factor_from = AREA_FACTORS[from_area_units] || 1.0
      factor_to = AREA_FACTORS[to_area_units] || 1.0

      # Assuming area_mm2 is already in mm2. If it were in `from_area_units`,
      # you'd do: area_in_mm2 = area_value * factor_from.
      # Since it's named area_mm2, we assume it's the base.
      converted_area = area_mm2 / factor_to
      
      precision ? converted_area.round(precision) : converted_area
    end
    
    # This format_dimension is for Ruby-side usage (e.g., scheduled reports), not for HTML UI rendering.
    def self.format_dimension(value_mm, display_unit = nil, precision = 1)
      display_unit ||= Config.get_cached_settings['units'] || 'mm'
      
      converted_value = convert_units(value_mm, 'mm', display_unit, precision) # Pass precision
      unit_label = UNIT_LABELS[display_unit] || display_unit
      
      "#{converted_value}#{unit_label}"
    end
    
    # This format_area is for Ruby-side usage (e.g., scheduled reports), not for HTML UI rendering.
    def self.format_area(area_mm2, display_area_unit = nil, precision = 3)
      display_area_unit ||= Config.get_cached_settings['area_units'] || 'm2'
      
      converted_area = convert_area_units(area_mm2, 'mm2', display_area_unit, precision) # Pass precision
      area_unit_label = display_area_unit # AREA_FACTORS values are already strings like 'm2'
      
      "#{converted_area} #{area_unit_label}"
    end
    
    def self.get_dimensions(bounds)
      [bounds.width.to_mm, bounds.height.to_mm, bounds.depth.to_mm]
    end
    
    def self.get_dimensions_in_unit(bounds, unit = nil)
      unit ||= Config.get_cached_settings['units'] || 'mm'
      dimensions_mm = get_dimensions(bounds)
      dimensions_mm.map { |dim| convert_units(dim, 'mm', unit) }
    end
    
    def self.is_sheet_good?(bounds, min_thickness = 3, max_thickness = 100, min_area = 1000)
      # Ensure Config module is available or provide a fallback if not
      settings = (defined?(Config) && Config.respond_to?(:get_cached_settings) ? Config.get_cached_settings : {})
      
      min_thickness_setting = settings['min_sheet_thickness'] || min_thickness
      max_thickness_setting = settings['max_sheet_thickness'] || max_thickness
      min_area_setting = settings['min_sheet_area'] || min_area # Assuming in mm2

      dimensions = get_dimensions(bounds).sort # Dimensions are already in mm
      thickness = dimensions[0]
      width = dimensions[1]
      height = dimensions[2]
      
      return false if thickness < min_thickness_setting || thickness > max_thickness_setting
      return false if (width * height) < min_area_setting
      
      true
    end
    
    def self.generate_part_id(name, index)
      clean_name = name.gsub(/[^a-zA-Z0-9]/, '_')
      "#{clean_name}_#{index}"
    end
    
    def self.safe_json(obj)
      begin
        obj.to_json
      rescue
        "{}"
      end
    end

    # Debug helper - controlled by environment variable AUTONESTCUT_DEBUG=1
    def self.debug(msg)
      if ENV['AUTONESTCUT_DEBUG'] == '1'
        begin
          puts "[AutoNestCut] #{msg}"
        rescue
          # best-effort
        end
      end
    end

    # Simple binary PNG signature check. Returns true when path exists and looks like a PNG file.
    def self.png_file?(path)
      return false unless path && File.exist?(path)
      return false unless File.size(path) > 8
      begin
        sig = File.binread(path, 8)
        return sig.start_with?("\x89PNG")
      rescue
        return false
      end
    end

    # Validates image compression and file size
    # Returns hash with :valid (boolean), :file_size_kb (float), :file_size_mb (float)
    def self.validate_image_compression(path, max_size_kb = 500)
      return { valid: false, file_size_kb: 0, file_size_mb: 0, error: 'File does not exist' } unless File.exist?(path)
      
      begin
        file_size_bytes = File.size(path)
        file_size_kb = file_size_bytes / 1024.0
        file_size_mb = file_size_bytes / (1024.0 * 1024.0)
        
        is_valid = file_size_kb <= max_size_kb
        
        {
          valid: is_valid,
          file_size_kb: file_size_kb.round(2),
          file_size_mb: file_size_mb.round(3),
          max_size_kb: max_size_kb,
          file_path: path
        }
      rescue => e
        { valid: false, file_size_kb: 0, file_size_mb: 0, error: e.message }
      end
    end

    # Logs compression validation results for debugging
    def self.log_compression_result(image_name, validation)
      if validation[:valid]
        puts "✓ Assembly image '#{image_name}' optimized: #{validation[:file_size_kb]}KB (limit: #{validation[:max_size_kb]}KB)"
      else
        puts "⚠ Assembly image '#{image_name}' size: #{validation[:file_size_kb]}KB (limit: #{validation[:max_size_kb]}KB)"
      end
    end

    # Detects image format from file signature
    def self.detect_image_format(path)
      return nil unless File.exist?(path) && File.size(path) > 4
      
      begin
        sig = File.binread(path, 4)
        # Check binary signatures directly without regex
        if sig.start_with?("\x89PNG")
          'PNG'
        elsif sig.start_with?("\xFF\xD8\xFF")
          'JPEG'
        elsif sig.start_with?('GIF8')
          'GIF'
        elsif sig.start_with?('RIFF')
          'WEBP'
        else
          'UNKNOWN'
        end
      rescue
        'UNKNOWN'
      end
    end

    # Optimizes image by converting PNG to JPEG if needed
    # Returns the path to the optimized image (may be original or new JPEG)
    def self.optimize_image_to_jpeg(source_path, quality = 0.75, max_size_kb = 500)
      return source_path unless File.exist?(source_path)
      
      format = detect_image_format(source_path)
      current_size_kb = File.size(source_path) / 1024.0
      
      # If already JPEG and within size limit, return as-is
      if format == 'JPEG' && current_size_kb <= max_size_kb
        return source_path
      end
      
      # If PNG or oversized, convert to JPEG
      if format == 'PNG' || current_size_kb > max_size_kb
        begin
          # Create output path with .jpg extension
          output_path = source_path.sub(/\.\w+$/, '.jpg')
          
          # Use ImageMagick if available, otherwise use SketchUp's native export
          if system('convert', source_path, "-quality", (quality * 100).to_i.to_s, output_path)
            # Verify the new file is smaller
            new_size_kb = File.size(output_path) / 1024.0
            if new_size_kb < current_size_kb
              File.delete(source_path) rescue nil
              return output_path
            else
              File.delete(output_path) rescue nil
              return source_path
            end
          end
        rescue => e
          puts "Warning: Could not optimize image #{source_path}: #{e.message}"
        end
      end
      
      source_path
    end

    # Detects the dominant material of a component definition by analyzing its faces.
    # Prioritizes materials directly applied to faces.
    def self.get_dominant_material(definition)
      material_counts = Hash.new(0)
      
      definition.entities.each do |entity|
        if entity.is_a?(Sketchup::Face)
          material = entity.material || entity.back_material
          if material
            material_counts[material.display_name || material.name] += 1
          end
        elsif entity.is_a?(Sketchup::Group)
          entity.entities.each do |nested_entity|
            if nested_entity.is_a?(Sketchup::Face)
              mat = nested_entity.material || nested_entity.back_material
              material_counts[mat.display_name || mat.name] += 1 if mat
            end
          end
        elsif entity.is_a?(Sketchup::ComponentInstance)
          entity.definition.entities.each do |nested_entity|
            if nested_entity.is_a?(Sketchup::Face)
              mat = nested_entity.material || nested_entity.back_material
              if mat
                mat_name = mat.display_name || mat.name
                material_counts[mat_name] += 1 if mat_name
              end
            end
          end
        end
      end
      
      material_counts.max_by { |_, count| count }&.first
    end

    # Formats a price value with currency symbol.
    def self.format_price(price, currency_code)
      # Simplified for demonstration. Your actual MaterialsDatabase method might be more complex.
      # You might want to load currency symbols from a config or locale file.
      case currency_code.upcase
      when 'USD', 'CAD', 'AUD'
        "$#{'%.2f' % price}"
      when 'EUR'
        "€#{'%.2f' % price}"
      when 'GBP'
        "£#{'%.2f' % price}"
      when 'JPY'
        "¥#{'%.0f' % price}" # Yen usually has no decimal places
      when 'SAR' # Added SAR
        "SAR #{'%.2f' % price}"
      else
        "#{currency_code} #{'%.2f' % price}"
      end
    end

  end
end
