# Generate a perfect L-shaped component for testing
# This creates an L-shape exactly as AutoNestCut expects

require 'sketchup'

module LShapeGenerator
  
  def self.create_perfect_l_shape
    model = Sketchup.active_model
    entities = model.active_entities
    
    puts "\n" + "="*70
    puts "  Generating Perfect L-Shape Component"
    puts "="*70
    
    # Start operation
    model.start_operation('Create L-Shape', true)
    
    begin
      # Create component definition
      definition = model.definitions.add("L-Shape Test Component")
      
      # L-shape dimensions (in mm, converted to inches for SketchUp)
      # Total bounding box: 720mm x 560mm
      # L-shape cutout: 408.63mm x 238.13mm (bottom-right)
      
      width_mm = 720.0
      height_mm = 560.0
      thickness_mm = 18.0
      
      # Cutout dimensions (to create the L)
      cutout_width_mm = 408.63
      cutout_height_mm = 238.13
      
      # Convert to inches (SketchUp's internal unit)
      width = width_mm.mm
      height = height_mm.mm
      thickness = thickness_mm.mm
      cutout_width = cutout_width_mm.mm
      cutout_height = cutout_height_mm.mm
      
      puts "\n1. Creating L-shape with dimensions:"
      puts "   Total: #{width_mm} x #{height_mm} x #{thickness_mm} mm"
      puts "   Cutout: #{cutout_width_mm} x #{cutout_height_mm} mm"
      
      # Create the L-shape face
      # Vertices in counter-clockwise order
      points = [
        Geom::Point3d.new(width - cutout_width, 0, 0),           # Bottom-left of cutout
        Geom::Point3d.new(0, 0, 0),                              # Bottom-left corner
        Geom::Point3d.new(0, height, 0),                         # Top-left corner
        Geom::Point3d.new(width, height, 0),                     # Top-right corner
        Geom::Point3d.new(width, height - cutout_height, 0),     # Right side of cutout
        Geom::Point3d.new(width - cutout_width, height - cutout_height, 0)  # Top-left of cutout
      ]
      
      # Create the face
      face = definition.entities.add_face(points)
      
      if face
        puts "   ✓ Face created with #{face.vertices.length} vertices"
        
        # Verify it's an L-shape
        if face.vertices.length == 6
          puts "   ✓ Correct vertex count for L-shape"
        else
          puts "   ⚠️  Warning: Expected 6 vertices, got #{face.vertices.length}"
        end
        
        # Extrude to create thickness
        face.pushpull(-thickness)
        puts "   ✓ Extruded to #{thickness_mm}mm thickness"
        
        # Apply material
        material = model.materials.add("Plywood_Test")
        material.color = Sketchup::Color.new(202, 166, 113)
        face.material = material
        face.back_material = material
        puts "   ✓ Material applied"
        
        # Create instance in model
        transformation = Geom::Transformation.new
        instance = entities.add_instance(definition, transformation)
        
        puts "\n2. Component created successfully!"
        puts "   Name: #{definition.name}"
        puts "   Vertices: #{face.vertices.length}"
        puts "   Bounds: #{definition.bounds.width.to_mm.round(2)} x #{definition.bounds.height.to_mm.round(2)} x #{definition.bounds.depth.to_mm.round(2)} mm"
        
        # Select the instance
        model.selection.clear
        model.selection.add(instance)
        
        puts "\n3. Component selected and ready for testing!"
        puts "   ✓ Run AutoNestCut now to test L-shape rendering"
        
        # Zoom to component
        model.active_view.zoom_extents
        
        model.commit_operation
        
        puts "\n" + "="*70
        puts "  ✅ PERFECT L-SHAPE CREATED!"
        puts "="*70
        puts "\nNext steps:"
        puts "  1. The L-shape component is now selected"
        puts "  2. Run AutoNestCut"
        puts "  3. Check if it renders as L-shape (not rectangle)"
        puts "\n"
        
        return instance
        
      else
        puts "   ❌ ERROR: Failed to create face!"
        model.abort_operation
        return nil
      end
      
    rescue => e
      puts "\n❌ ERROR: #{e.message}"
      puts "   #{e.backtrace.first(5).join("\n   ")}"
      model.abort_operation
      return nil
    end
  end
  
  def self.create_simple_l_shape
    model = Sketchup.active_model
    entities = model.active_entities
    
    puts "\n" + "="*70
    puts "  Generating Simple L-Shape (Alternative)"
    puts "="*70
    
    model.start_operation('Create Simple L-Shape', true)
    
    begin
      definition = model.definitions.add("Simple L-Shape")
      
      # Simpler L-shape: 600mm x 400mm with 300mm x 200mm cutout
      width = 600.mm
      height = 400.mm
      thickness = 18.mm
      cutout_w = 300.mm
      cutout_h = 200.mm
      
      puts "\n1. Creating simple L-shape:"
      puts "   Total: 600 x 400 x 18 mm"
      puts "   Cutout: 300 x 200 mm (bottom-right)"
      
      # L-shape vertices (counter-clockwise)
      points = [
        Geom::Point3d.new(width - cutout_w, 0, 0),      # 1. Bottom-left of cutout
        Geom::Point3d.new(0, 0, 0),                     # 2. Bottom-left corner
        Geom::Point3d.new(0, height, 0),                # 3. Top-left corner
        Geom::Point3d.new(width, height, 0),            # 4. Top-right corner
        Geom::Point3d.new(width, cutout_h, 0),          # 5. Right edge at cutout
        Geom::Point3d.new(width - cutout_w, cutout_h, 0) # 6. Top-left of cutout
      ]
      
      face = definition.entities.add_face(points)
      
      if face && face.vertices.length == 6
        puts "   ✓ L-shape face created (6 vertices)"
        
        face.pushpull(-thickness)
        puts "   ✓ Extruded to 18mm"
        
        # Apply material
        material = model.materials.add("Plywood_Simple")
        material.color = Sketchup::Color.new(210, 180, 140)
        face.material = material
        
        # Create instance
        instance = entities.add_instance(definition, Geom::Transformation.new)
        
        # Select it
        model.selection.clear
        model.selection.add(instance)
        
        model.active_view.zoom_extents
        model.commit_operation
        
        puts "\n✅ Simple L-shape created and selected!"
        puts "   Run AutoNestCut to test"
        
        return instance
      else
        puts "❌ Failed to create L-shape face"
        model.abort_operation
        return nil
      end
      
    rescue => e
      puts "❌ ERROR: #{e.message}"
      model.abort_operation
      return nil
    end
  end
  
  def self.verify_l_shape_component
    model = Sketchup.active_model
    selection = model.selection
    
    puts "\n" + "="*70
    puts "  Verifying Selected Component"
    puts "="*70
    
    if selection.empty?
      puts "\n❌ No component selected!"
      puts "   Please select a component first"
      return false
    end
    
    entity = selection.first
    
    unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
      puts "\n❌ Selected entity is not a component or group!"
      puts "   Type: #{entity.class}"
      return false
    end
    
    puts "\n1. Component Information:"
    if entity.is_a?(Sketchup::ComponentInstance)
      puts "   Type: Component Instance"
      puts "   Name: #{entity.definition.name}"
      definition = entity.definition
    else
      puts "   Type: Group"
      definition = entity
    end
    
    puts "\n2. Analyzing Geometry:"
    
    # Find faces
    entities = definition.respond_to?(:entities) ? definition.entities : definition.definition.entities
    faces = entities.select { |e| e.is_a?(Sketchup::Face) }
    
    puts "   Total faces: #{faces.length}"
    
    if faces.empty?
      puts "   ❌ No faces found! Component is empty."
      return false
    end
    
    # Find largest face (should be the L-shape profile)
    largest_face = faces.max_by { |f| f.area }
    
    puts "\n3. Largest Face Analysis:"
    puts "   Vertices: #{largest_face.vertices.length}"
    puts "   Area: #{(largest_face.area * 645.16).round(2)} mm²"  # Convert to mm²
    
    # Check vertex count
    if largest_face.vertices.length == 6
      puts "   ✅ Correct vertex count for L-shape!"
    elsif largest_face.vertices.length == 4
      puts "   ⚠️  Only 4 vertices - this is a RECTANGLE, not L-shape!"
      return false
    else
      puts "   ⚠️  Unexpected vertex count: #{largest_face.vertices.length}"
      puts "   Expected: 6 for L-shape"
    end
    
    # Check if vertices form 90-degree angles
    puts "\n4. Angle Analysis:"
    vertices = largest_face.outer_loop.vertices
    angles = []
    
    vertices.length.times do |i|
      v1 = vertices[i].position
      v2 = vertices[(i + 1) % vertices.length].position
      v3 = vertices[(i + 2) % vertices.length].position
      
      # Calculate angle
      vec1 = v1 - v2
      vec2 = v3 - v2
      angle = vec1.angle_between(vec2).radians
      angle_degrees = (angle * 180 / Math::PI).round(1)
      angles << angle_degrees
    end
    
    puts "   Angles: #{angles.map { |a| "#{a}°" }.join(', ')}"
    
    # Check for 90-degree angles (L-shape characteristic)
    right_angles = angles.count { |a| (a - 90).abs < 5 || (a - 270).abs < 5 }
    
    if right_angles >= 4
      puts "   ✅ Has #{right_angles} right angles - looks like L-shape!"
    else
      puts "   ⚠️  Only #{right_angles} right angles - may not be L-shape"
    end
    
    puts "\n5. Bounds:"
    bounds = definition.bounds
    puts "   Width: #{bounds.width.to_mm.round(2)} mm"
    puts "   Height: #{bounds.height.to_mm.round(2)} mm"
    puts "   Depth: #{bounds.depth.to_mm.round(2)} mm"
    
    puts "\n" + "="*70
    if largest_face.vertices.length == 6 && right_angles >= 4
      puts "  ✅ VALID L-SHAPE COMPONENT!"
      puts "="*70
      puts "\n  This component should render correctly as L-shape"
      return true
    else
      puts "  ❌ NOT A VALID L-SHAPE!"
      puts "="*70
      puts "\n  Issues found:"
      puts "  - Vertex count: #{largest_face.vertices.length} (expected 6)"
      puts "  - Right angles: #{right_angles} (expected 4+)"
      puts "\n  Recommendation: Use LShapeGenerator.create_perfect_l_shape"
      return false
    end
  end
  
  def self.compare_components
    puts "\n" + "="*70
    puts "  Component Comparison Tool"
    puts "="*70
    puts "\nThis will:"
    puts "  1. Create a perfect L-shape"
    puts "  2. Compare it with your selected component"
    puts "  3. Show differences"
    puts "\n"
    
    # Save current selection
    model = Sketchup.active_model
    old_selection = model.selection.to_a
    
    # Create perfect L-shape
    puts "Creating perfect L-shape..."
    perfect = create_perfect_l_shape
    
    if perfect
      puts "\n✅ Perfect L-shape created!"
      puts "   Now select YOUR L-shape component and run:"
      puts "   LShapeGenerator.verify_l_shape_component"
    end
  end
  
end

puts "\n" + "="*70
puts "  L-Shape Generator Loaded"
puts "="*70
puts "\nAvailable commands:"
puts "\n1. LShapeGenerator.create_perfect_l_shape"
puts "   - Creates a perfect L-shape (720x560mm with cutout)"
puts "   - Automatically selected and ready for testing"
puts "\n2. LShapeGenerator.create_simple_l_shape"
puts "   - Creates a simpler L-shape (600x400mm)"
puts "   - Good for quick testing"
puts "\n3. LShapeGenerator.verify_l_shape_component"
puts "   - Verifies if your selected component is a valid L-shape"
puts "   - Shows vertex count, angles, dimensions"
puts "\n4. LShapeGenerator.compare_components"
puts "   - Creates perfect L-shape and helps compare"
puts "\n" + "="*70
puts "\nRECOMMENDED: Run this first:"
puts "  LShapeGenerator.create_perfect_l_shape"
puts "\nThen run AutoNestCut to test rendering!"
puts "\n"
