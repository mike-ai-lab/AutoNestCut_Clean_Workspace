require 'json'

module AutoNestCut
  class CladdingPreset
    attr_reader :name, :length_values, :height_values, :thickness, :joint_length, :joint_width, :pattern_type, :material_name
    
    def initialize(preset_data, name = nil)
      @name = name || preset_data['name'] || 'Custom Preset'
      @length_values = parse_dimensions(preset_data['length'])
      @height_values = parse_dimensions(preset_data['height'])
      @thickness = preset_data['thickness'].to_f
      @joint_length = preset_data['joint_length'].to_f
      @joint_width = preset_data['joint_width'].to_f
      @pattern_type = preset_data['pattern_type'] || 'stack_bond'
      @material_name = preset_data['color_name'] || 'Cladding Material'
    end
    
    def self.load_from_file(file_path)
      return nil unless File.exist?(file_path)
      
      preset_data = JSON.parse(File.read(file_path))
      preset_name = File.basename(file_path, '.json')
      new(preset_data, preset_name)
    rescue => e
      puts "Error loading preset: #{e.message}"
      nil
    end
    
    def average_piece_length
      @length_values.sum.to_f / @length_values.length
    end
    
    def average_piece_height
      @height_values.sum.to_f / @height_values.length
    end
    
    def effective_piece_area_mm2
      # Area including joints
      (average_piece_length + @joint_length) * (average_piece_height + @joint_width)
    end
    
    def pieces_per_m2
      # Convert mm² to m² and calculate pieces per square meter
      1_000_000.0 / effective_piece_area_mm2
    end
    
    def joint_area_ratio
      # Percentage of area that is joints/mortar
      piece_area = average_piece_length * average_piece_height
      joint_area = effective_piece_area_mm2 - piece_area
      joint_area / effective_piece_area_mm2
    end
    
    def to_h
      {
        name: @name,
        piece_dimensions: "#{average_piece_length.round(1)} x #{average_piece_height.round(1)} x #{@thickness}mm",
        joint_size: "#{@joint_length} x #{@joint_width}mm",
        pattern: @pattern_type,
        material: @material_name,
        pieces_per_m2: pieces_per_m2.round(2),
        joint_ratio: (joint_area_ratio * 100).round(1)
      }
    end
    
    private
    
    def parse_dimensions(dimension_string)
      return [200.0] unless dimension_string
      
      dimension_string.split(';').map(&:to_f).reject(&:zero?)
    end
  end
end