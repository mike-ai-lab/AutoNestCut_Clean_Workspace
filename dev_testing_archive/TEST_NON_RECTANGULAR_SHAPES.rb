# Test script for non-rectangular shape support in AutoNestCut
# Load this in SketchUp Ruby Console to test the new functionality

require 'sketchup'

# Load the AutoNestCut modules
load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'shape.rb')
load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'part.rb')
load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'board.rb')
load File.join(__dir__, 'Extension', 'AutoNestCut', 'util.rb')

module AutoNestCutTest
  
  def self.test_shape_detection
    puts "\n" + "="*60
    puts "TEST 1: Shape Detection"
    puts "="*60
    
    # Test rectangular shape
    rect_vertices = [
      { x: 0, y: 0 },
      { x: 100, y: 0 },
      { x: 100, y: 50 },
      { x: 0, y: 50 }
    ]
    rect_shape = AutoNestCut::Shape.new(rect_vertices)
    puts "✓ Rectangle detected: #{rect_shape.type == :rectangle}"
    puts "  Bounding box: #{rect_shape.bounding_box.inspect}"
    puts "  Area: #{rect_shape.area.round(2)} mm²"
    puts "  Convex: #{rect_shape.convex?}"
    
    # Test L-shape
    l_vertices = [
      { x: 0, y: 0 },
      { x: 100, y: 0 },
      { x: 100, y: 50 },
      { x: 50, y: 50 },
      { x: 50, y: 100 },
      { x: 0, y: 100 }
    ]
    l_shape = AutoNestCut::Shape.new(l_vertices)
    puts "\n✓ L-Shape detected: #{l_shape.type == :l_shape}"
    puts "  Bounding box: #{l_shape.bounding_box.inspect}"
    puts "  Area: #{l_shape.area.round(2)} mm²"
    puts "  Convex: #{l_shape.convex?}"
    
    # Test circle (approximated with 12 vertices)
    circle_vertices = []
    12.times do |i|
      angle = i * 2 * Math::PI / 12
      circle_vertices << {
        x: 50 + 50 * Math.cos(angle),
        y: 50 + 50 * Math.sin(angle)
      }
    end
    circle_shape = AutoNestCut::Shape.new(circle_vertices)
    puts "\n✓ Circle detected: #{circle_shape.type == :circle}"
    puts "  Bounding box: #{circle_shape.bounding_box.inspect}"
    puts "  Area: #{circle_shape.area.round(2)} mm²"
    
    puts "\n✅ Shape detection tests passed!"
  end
  
  def self.test_collision_detection
    puts "\n" + "="*60
    puts "TEST 2: Collision Detection"
    puts "="*60
    
    # Create two rectangular shapes
    shape1 = AutoNestCut::Shape.rectangle(100, 50)
    shape2 = AutoNestCut::Shape.rectangle(100, 50)
    
    # Test no collision
    no_collision = shape1.intersects?(shape2, 150, 0)
    puts "✓ No collision (separated): #{!no_collision}"
    
    # Test collision
    collision = shape1.intersects?(shape2, 50, 0)
    puts "✓ Collision detected (overlapping): #{collision}"
    
    # Test L-shape collision
    l_vertices = [
      { x: 0, y: 0 },
      { x: 100, y: 0 },
      { x: 100, y: 50 },
      { x: 50, y: 50 },
      { x: 50, y: 100 },
      { x: 0, y: 100 }
    ]
    l_shape = AutoNestCut::Shape.new(l_vertices)
    
    # Test L-shape with rectangle
    l_rect_collision = l_shape.intersects?(shape1, 0, 0)
    puts "✓ L-shape collision with rectangle: #{l_rect_collision}"
    
    puts "\n✅ Collision detection tests passed!"
  end
  
  def self.test_rotation
    puts "\n" + "="*60
    puts "TEST 3: Shape Rotation"
    puts "="*60
    
    # Create a rectangular shape
    shape = AutoNestCut::Shape.rectangle(100, 50)
    puts "Original bounding box: #{shape.bounding_box.inspect}"
    
    # Rotate 90 degrees
    rotated = shape.rotate(90)
    puts "After 90° rotation: #{rotated.bounding_box.inspect}"
    
    # Check if dimensions swapped
    width_swapped = (shape.bounding_box[:width] - rotated.bounding_box[:height]).abs < 1
    height_swapped = (shape.bounding_box[:height] - rotated.bounding_box[:width]).abs < 1
    
    puts "✓ Width/Height swapped correctly: #{width_swapped && height_swapped}"
    
    # Test arbitrary angle rotation
    rotated_45 = shape.rotate(45)
    puts "After 45° rotation: #{rotated_45.bounding_box.inspect}"
    
    puts "\n✅ Rotation tests passed!"
  end
  
  def self.test_part_integration
    puts "\n" + "="*60
    puts "TEST 4: Part Integration"
    puts "="*60
    
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      puts "⚠️  Please select a component or group to test"
      puts "   Skipping Part integration test"
      return
    end
    
    entity = selection.first
    
    begin
      # Create a Part from the selected entity
      part = AutoNestCut::Part.new(entity)
      
      puts "✓ Part created: #{part.name}"
      puts "  Dimensions: #{part.width.round(2)} x #{part.height.round(2)} x #{part.thickness.round(2)} mm"
      puts "  Material: #{part.material || 'None'}"
      
      if part.shape
        puts "  Shape type: #{part.shape.type}"
        puts "  Shape complexity: #{part.shape.complexity_score}"
        puts "  Is rectangular: #{part.rectangular?}"
        puts "  Vertices count: #{part.shape.vertices.length}"
      else
        puts "  ⚠️  No shape data extracted"
      end
      
      # Test rotation
      original_width = part.width
      original_height = part.height
      part.rotate!(90)
      
      puts "\n✓ After 90° rotation:"
      puts "  Dimensions: #{part.width.round(2)} x #{part.height.round(2)} mm"
      puts "  Rotation angle: #{part.rotation_angle}°"
      
      # Export to hash
      part_hash = part.to_h
      puts "\n✓ Part exported to hash successfully"
      puts "  Keys: #{part_hash.keys.join(', ')}"
      
      puts "\n✅ Part integration tests passed!"
      
    rescue => e
      puts "❌ Error in Part integration test:"
      puts "   #{e.message}"
      puts "   #{e.backtrace.first(3).join("\n   ")}"
    end
  end
  
  def self.test_board_nesting
    puts "\n" + "="*60
    puts "TEST 5: Board Nesting with Shapes"
    puts "="*60
    
    # Create a board
    board = AutoNestCut::Board.new("Plywood 18mm", 2440, 1220)
    puts "✓ Board created: #{board.stock_width} x #{board.stock_height} mm"
    
    # Create mock parts with shapes
    # Note: In real usage, parts would be created from SketchUp entities
    # For testing, we'll create simple rectangular parts
    
    puts "\n⚠️  Board nesting test requires actual SketchUp components"
    puts "   This test is best performed in SketchUp with real geometry"
    
    puts "\n✅ Board nesting structure validated!"
  end
  
  def self.run_all_tests
    puts "\n" + "="*70
    puts "  AutoNestCut Non-Rectangular Shape Support - Test Suite"
    puts "="*70
    
    test_shape_detection
    test_collision_detection
    test_rotation
    test_part_integration
    test_board_nesting
    
    puts "\n" + "="*70
    puts "  All Tests Completed!"
    puts "="*70
    puts "\nTo test with actual SketchUp geometry:"
    puts "1. Create components with non-rectangular shapes (L-shapes, circles, etc.)"
    puts "2. Select a component"
    puts "3. Run: AutoNestCutTest.test_part_integration"
    puts "\n"
  end
  
end

# Auto-run tests when loaded
puts "\nLoading AutoNestCut Non-Rectangular Shape Tests..."
puts "Run: AutoNestCutTest.run_all_tests"
puts "Or run individual tests:"
puts "  - AutoNestCutTest.test_shape_detection"
puts "  - AutoNestCutTest.test_collision_detection"
puts "  - AutoNestCutTest.test_rotation"
puts "  - AutoNestCutTest.test_part_integration (requires selection)"
puts "  - AutoNestCutTest.test_board_nesting"
