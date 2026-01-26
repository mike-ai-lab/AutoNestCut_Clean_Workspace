module AutoNestCut
  class FacadeAnalyzer
    
    def initialize
      @surfaces = []
    end
    
    def analyze_selection(selection)
      @surfaces = []
      
      selection.each do |entity|
        process_entity(entity)
      end
      
      @surfaces
    end
    
    def calculate_quantities(surfaces, preset)
      return {} if surfaces.empty? || !preset
      
      total_area_m2 = surfaces.sum(&:area_m2)
      pieces_per_m2 = preset.pieces_per_m2
      
      # Calculate with waste factor (10% default)
      waste_factor = 0.10
      total_pieces_needed = (total_area_m2 * pieces_per_m2 * (1 + waste_factor)).ceil
      waste_pieces = (total_area_m2 * pieces_per_m2 * waste_factor).ceil
      
      # Joint material calculation (mortar/adhesive)
      joint_volume_m3 = calculate_joint_volume(total_area_m2, preset)
      
      {
        total_area_m2: total_area_m2.round(2),
        pieces_per_m2: pieces_per_m2.round(2),
        total_pieces: total_pieces_needed,
        waste_pieces: waste_pieces,
        waste_factor: (waste_factor * 100).round(1),
        joint_volume_m3: joint_volume_m3.round(3),
        surfaces_count: surfaces.length,
        preset_info: preset.to_h
      }
    end
    
    def generate_surface_breakdown(surfaces)
      breakdown = {
        vertical_surfaces: [],
        horizontal_surfaces: [],
        sloped_surfaces: []
      }
      
      surfaces.each do |surface|
        case surface.orientation
        when 'vertical'
          breakdown[:vertical_surfaces] << surface.to_h
        when 'horizontal'
          breakdown[:horizontal_surfaces] << surface.to_h
        when 'sloped'
          breakdown[:sloped_surfaces] << surface.to_h
        end
      end
      
      breakdown
    end
    
    private
    
    def process_entity(entity)
      case entity
      when Sketchup::Face
        @surfaces << FacadeSurface.new(entity)
      when Sketchup::Group, Sketchup::ComponentInstance
        # Process faces within groups/components
        entity.definition.entities.each do |sub_entity|
          if sub_entity.is_a?(Sketchup::Face)
            # Transform face to world coordinates if needed
            @surfaces << FacadeSurface.new(sub_entity)
          end
        end
      end
    end
    
    def calculate_joint_volume(total_area_m2, preset)
      # Simplified joint volume calculation
      # Joint thickness assumed to be same as cladding thickness
      joint_ratio = preset.joint_area_ratio
      joint_thickness_m = preset.thickness / 1000.0 # Convert mm to m
      
      total_area_m2 * joint_ratio * joint_thickness_m
    end
  end
end