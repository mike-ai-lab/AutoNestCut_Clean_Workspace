module AutoNestCut
  class FacadeSurface
    attr_reader :face, :area, :normal, :bounds, :material_name
    
    def initialize(face)
      @face = face
      @area = face.area
      @normal = face.normal
      @bounds = face.bounds
      @material_name = face.material ? face.material.name : nil
    end
    
    def area_m2
      # Convert from SketchUp internal units to square meters
      (@area * 0.00064516).round(3) # SketchUp units to m²
    end
    
    def area_ft2
      # Convert from SketchUp internal units to square feet
      (@area * 0.00694444).round(3) # SketchUp units to ft²
    end
    
    def width
      @bounds.width
    end
    
    def height
      @bounds.height
    end
    
    def is_vertical?
      @normal.z.abs < 0.1 # Nearly vertical surface
    end
    
    def is_horizontal?
      @normal.z.abs > 0.9 # Nearly horizontal surface
    end
    
    def orientation
      return 'horizontal' if is_horizontal?
      return 'vertical' if is_vertical?
      'sloped'
    end
    
    def to_h
      {
        area_m2: area_m2,
        area_ft2: area_ft2,
        width: width.round(2),
        height: height.round(2),
        orientation: orientation,
        material: @material_name
      }
    end
  end
end