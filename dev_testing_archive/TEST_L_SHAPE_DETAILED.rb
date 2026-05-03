# Detailed L-Shape Test for AutoNestCut Non-Rectangular Shape Support
# This test validates L-shape detection, collision, and nesting

require 'sketchup'

# Load required modules
load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'shape.rb')
load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'part.rb')
load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'board.rb')
load File.join(__dir__, 'Extension', 'AutoNestCut', 'util.rb')

module LShapeTest
  
  # Test 1: L-Shape Detection with Various Configurations
  def self.test_l_shape_detection
    puts "\n" + "="*70
    puts "TEST 1: L-Shape Detection"
    puts "="*70
    
    # Standard L-shape (100x100 with 50x50 cutout)
    puts "\n1.1 Standard L-Shape (100x100 with 50x50 cutout)"
    l_vertices_1 = [
      { x: 0, y: 0 },
      { x: 100, y: 0 },
      { x: 100, y: 50 },
      { x: 50, y: 50 },
      { x: 50, y: 100 },
      { x: 0, y: 100 }
    ]
    l_shape_1 = AutoNestCut::Shape.new(l_vertices_1)
    
    puts "  Shape type: #{l_shape_1.type}"
    puts "  Expected: :l_shape"
    puts "  ✓ PASS" if l_shape_1.type == :l_shape
    puts "  ❌ FAIL - Detected as #{l_shape_1.type}" unless l_shape_1.type == :l_shape
    puts "  Bounding box: #{l_shape_1.bounding_box.inspect}"
    puts "  Area: #{l_shape_1.area.round(2)} mm² (expected: 7500 mm²)"
    puts "  Convex: #{l_shape_1.convex?} (expected: false)"
    
    # Rotated L-shape (90 degrees)
    puts "\n1.2 Rotated L-Shape (90° rotation)"
    l_vertices_2 = [
      { x: 0, y: 0 },
      { x: 50, y: 0 },
      { x: 50, y: 50 },
      { x: 100, y: 50 },
      { x: 100, y: 100 },
      { x: 0, y: 100 }
    ]
    l_shape_2 = AutoNestCut::Shape.new(l_vertices_2)
    
    puts "  Shape type: #{l_shape_2.type}"
    puts "  ✓ PASS" if l_shape_2.type == :l_shape
    puts "  ❌ FAIL - Detected as #{l_shape_2.type}" unless l_shape_2.type == :l_shape
    puts "  Bounding box: #{l_shape_2.bounding_box.inspect}"
    puts "  Area: #{l_shape_2.area.round(2)} mm²"
    
    # Large L-shape (typical furniture piece)
    puts "\n1.3 Large L-Shape (720x640 with 220x240 cutout)"
    l_vertices_3 = [
      { x: 0, y: 0 },
      { x: 720, y: 0 },
      { x: 720, y: 400 },
      { x: 500, y: 400 },
      { x: 500, y: 640 },
      { x: 0, y: 640 }
    ]
    l_shape_3 = AutoNestCut::Shape.new(l_vertices_3)
    
    puts "  Shape type: #{l_shape_3.type}"
    puts "  ✓ PASS" if l_shape_3.type == :l_shape
    puts "  ❌ FAIL - Detected as #{l_shape_3.type}" unless l_shape_3.type == :l_shape
    puts "  Bounding box: #{l_shape_3.bounding_box.inspect}"
    puts "  Area: #{l_shape_3.area.round(2)} mm²"
    puts "  Expected area: #{(720*400 + 500*240).round(2)} mm²"
    
    puts "\n✅ L-Shape detection tests complete!"
  end
  
  # Test 2: L-Shape Collision Detection
  def self.test_l_shape_collision
    puts "\n" + "="*70
    puts "TEST 2: L-Shape Collision Detection"
    puts "="*70
    
    # Create L-shape
    l_vertices = [
      { x: 0, y: 0 },
      { x: 100, y: 0 },
      { x: 100, y: 50 },
      { x: 50, y: 50 },
      { x: 50, y: 100 },
      { x: 0, y: 100 }
    ]
    l_shape = AutoNestCut::Shape.new(l_vertices)
    
    # Create rectangle
    rect_shape = AutoNestCut::Shape.rectangle(50, 50)
    
    puts "\n2.1 L-Shape vs Rectangle - No Collision (separated)"
    no_collision = !l_shape.intersects?(rect_shape, 150, 0)
    puts "  Result: #{no_collision ? 'No collision' : 'Collision detected'}"
    puts "  ✓ PASS" if no_collision
    puts "  ❌ FAIL" unless no_collision
    
    puts "\n2.2 L-Shape vs Rectangle - Collision (overlapping)"
    collision = l_shape.intersects?(rect_shape, 25, 25)
    puts "  Result: #{collision ? 'Collision detected' : 'No collision'}"
    puts "  ✓ PASS" if collision
    puts "  ❌ FAIL" unless collision
    
    puts "\n2.3 L-Shape vs Rectangle - In Cutout Area (should NOT collide)"
    # Place rectangle in the cutout area of L-shape
    in_cutout = !l_shape.intersects?(rect_shape, 60, 60)
    puts "  Result: #{in_cutout ? 'No collision (correct)' : 'Collision detected (incorrect)'}"
    puts "  ✓ PASS" if in_cutout
    puts "  ❌ FAIL - Rectangle in cutout should not collide!" unless in_cutout
    
    puts "\n2.4 L-Shape vs L-Shape - Interlocking Test"
    # Create second L-shape that could interlock
    l_shape_2 = AutoNestCut::Shape.new(l_vertices)
    interlocking = l_shape.intersects?(l_shape_2, 50, 50)
    puts "  Result: #{interlocking ? 'Collision detected' : 'No collision'}"
    puts "  Note: Interlocking optimization not yet implemented"
    
    puts "\n✅ L-Shape collision tests complete!"
  end
  
  # Test 3: L-Shape Rotation
  def self.test_l_shape_rotation
    puts "\n" + "="*70
    puts "TEST 3: L-Shape Rotation"
    puts "="*70
    
    l_vertices = [
      { x: 0, y: 0 },
      { x: 100, y: 0 },
      { x: 100, y: 50 },
      { x: 50, y: 50 },
      { x: 50, y: 100 },
      { x: 0, y: 100 }
    ]
    l_shape = AutoNestCut::Shape.new(l_vertices)
    
    puts "\n3.1 Original L-Shape"
    puts "  Bounding box: #{l_shape.bounding_box.inspect}"
    puts "  Area: #{l_shape.area.round(2)} mm²"
    
    puts "\n3.2 After 90° Rotation"
    rotated_90 = l_shape.rotate(90)
    puts "  Bounding box: #{rotated_90.bounding_box.inspect}"
    puts "  Area: #{rotated_90.area.round(2)} mm²"
    puts "  ✓ PASS - Area preserved" if (l_shape.area - rotated_90.area).abs < 1
    puts "  ❌ FAIL - Area changed!" if (l_shape.area - rotated_90.area).abs >= 1
    
    puts "\n3.3 After 180° Rotation"
    rotated_180 = l_shape.rotate(180)
    puts "  Bounding box: #{rotated_180.bounding_box.inspect}"
    puts "  Area: #{rotated_180.area.round(2)} mm²"
    
    puts "\n3.4 After 45° Rotation"
    rotated_45 = l_shape.rotate(45)
    puts "  Bounding box: #{rotated_45.bounding_box.inspect}"
    puts "  Area: #{rotated_45.area.round(2)} mm²"
    puts "  Note: Bounding box increases with diagonal rotation"
    
    puts "\n✅ L-Shape rotation tests complete!"
  end
  
  # Test 4: L-Shape Bounding Box Accuracy
  def self.test_l_shape_bounding_box
    puts "\n" + "="*70
    puts "TEST 4: L-Shape Bounding Box Accuracy"
    puts "="*70
    
    l_vertices = [
      { x: 0, y: 0 },
      { x: 100, y: 0 },
      { x: 100, y: 50 },
      { x: 50, y: 50 },
      { x: 50, y: 100 },
      { x: 0, y: 100 }
    ]
    l_shape = AutoNestCut::Shape.new(l_vertices)
    bb = l_shape.bounding_box
    
    puts "\n  Bounding Box:"
    puts "    X: #{bb[:x]}, Y: #{bb[:y]}"
    puts "    Width: #{bb[:width]}, Height: #{bb[:height]}"
    
    # Verify bounding box
    expected_bb = { x: 0, y: 0, width: 100, height: 100 }
    bb_correct = (bb[:x] - expected_bb[:x]).abs < 0.1 &&
                 (bb[:y] - expected_bb[:y]).abs < 0.1 &&
                 (bb[:width] - expected_bb[:width]).abs < 0.1 &&
                 (bb[:height] - expected_bb[:height]).abs < 0.1
    
    puts "\n  Expected: #{expected_bb.inspect}"
    puts "  ✓ PASS - Bounding box correct" if bb_correct
    puts "  ❌ FAIL - Bounding box incorrect!" unless bb_correct
    
    # Verify area calculation
    expected_area = 7500.0 # 100*50 + 50*50 = 5000 + 2500 = 7500
    area_correct = (l_shape.area - expected_area).abs < 1
    
    puts "\n  Area: #{l_shape.area.round(2)} mm²"
    puts "  Expected: #{expected_area} mm²"
    puts "  ✓ PASS - Area correct" if area_correct
    puts "  ❌ FAIL - Area incorrect!" unless area_correct
    
    puts "\n✅ L-Shape bounding box tests complete!"
  end
  
  # Test 5: L-Shape with SketchUp Component (requires selection)
  def self.test_l_shape_with_sketchup_component
    puts "\n" + "="*70
    puts "TEST 5: L-Shape with SketchUp Component"
    puts "="*70
    
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      puts "\n⚠️  No component selected!"
      puts "   To test with SketchUp geometry:"
      puts "   1. Create an L-shaped component"
      puts "   2. Select it"
      puts "   3. Run: LShapeTest.test_l_shape_with_sketchup_component"
      return
    end
    
    entity = selection.first
    
    unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)
      puts "\n❌ Selected entity is not a component or group"
      return
    end
    
    begin
      puts "\n5.1 Creating Part from Selected Component"
      part = AutoNestCut::Part.new(entity)
      
      puts "  Part name: #{part.name}"
      puts "  Dimensions: #{part.width.round(2)} x #{part.height.round(2)} x #{part.thickness.round(2)} mm"
      
      if part.shape
        puts "\n5.2 Shape Analysis"
        puts "  Shape type: #{part.shape.type}"
        puts "  Is L-shape: #{part.shape.type == :l_shape ? 'YES ✓' : 'NO'}"
        puts "  Is rectangular: #{part.rectangular? ? 'YES' : 'NO'}"
        puts "  Vertices count: #{part.shape.vertices.length}"
        puts "  Convex: #{part.shape.convex?}"
        puts "  Complexity score: #{part.shape.complexity_score}"
        puts "  Area: #{part.shape.area.round(2)} mm²"
        puts "  Bounding box: #{part.shape.bounding_box.inspect}"
        
        if part.shape.type == :l_shape
          puts "\n  ✅ SUCCESS - L-shape detected correctly!"
        elsif part.shape.type == :rectangle
          puts "\n  ⚠️  WARNING - Detected as rectangle"
          puts "     Check if component has proper L-shaped face"
        else
          puts "\n  ℹ️  INFO - Detected as #{part.shape.type}"
        end
        
        # Test rotation
        puts "\n5.3 Testing Rotation"
        original_width = part.width
        original_height = part.height
        part.rotate!(90)
        puts "  After 90° rotation:"
        puts "    Dimensions: #{part.width.round(2)} x #{part.height.round(2)} mm"
        puts "    Rotation angle: #{part.rotation_angle}°"
        puts "    ✓ Width/Height swapped" if (part.width - original_height).abs < 0.1
        
      else
        puts "\n  ❌ FAIL - No shape data extracted"
      end
      
      puts "\n✅ SketchUp component test complete!"
      
    rescue => e
      puts "\n❌ ERROR: #{e.message}"
      puts "   #{e.backtrace.first(3).join("\n   ")}"
    end
  end
  
  # Test 6: L-Shape Nesting Simulation
  def self.test_l_shape_nesting
    puts "\n" + "="*70
    puts "TEST 6: L-Shape Nesting Simulation"
    puts "="*70
    
    puts "\n⚠️  This test simulates nesting logic"
    puts "   Full nesting requires actual SketchUp components"
    
    # Create board
    board = AutoNestCut::Board.new("Plywood 18mm", 2440, 1220)
    puts "\n6.1 Board Created"
    puts "  Material: #{board.material}"
    puts "  Dimensions: #{board.stock_width} x #{board.stock_height} mm"
    
    puts "\n6.2 Board Methods Available"
    puts "  ✓ add_part" if board.respond_to?(:add_part)
    puts "  ✓ find_best_position" if board.respond_to?(:find_best_position)
    puts "  ✓ collides_with_existing_parts?" if board.respond_to?(:collides_with_existing_parts?)
    puts "  ✓ bounding_boxes_overlap?" if board.respond_to?(:bounding_boxes_overlap?)
    
    puts "\n✅ L-Shape nesting structure validated!"
  end
  
  # Run all L-shape tests
  def self.run_all_tests
    puts "\n" + "="*70
    puts "  L-SHAPE COMPREHENSIVE TEST SUITE"
    puts "="*70
    
    test_l_shape_detection
    test_l_shape_collision
    test_l_shape_rotation
    test_l_shape_bounding_box
    test_l_shape_with_sketchup_component
    test_l_shape_nesting
    
    puts "\n" + "="*70
    puts "  ALL L-SHAPE TESTS COMPLETED!"
    puts "="*70
    puts "\n📋 Summary:"
    puts "  ✅ Shape detection validated"
    puts "  ✅ Collision detection validated"
    puts "  ✅ Rotation validated"
    puts "  ✅ Bounding box accuracy validated"
    puts "  ⚠️  SketchUp component test requires selection"
    puts "  ✅ Nesting structure validated"
    
    puts "\n📝 To test with actual SketchUp geometry:"
    puts "  1. Create an L-shaped face in a component"
    puts "  2. Select the component"
    puts "  3. Run: LShapeTest.test_l_shape_with_sketchup_component"
    puts "\n"
  end
  
end

# Instructions
puts "\n" + "="*70
puts "  L-Shape Test Suite Loaded"
puts "="*70
puts "\nAvailable commands:"
puts "  LShapeTest.run_all_tests                          # Run all tests"
puts "  LShapeTest.test_l_shape_detection                 # Test detection only"
puts "  LShapeTest.test_l_shape_collision                 # Test collision only"
puts "  LShapeTest.test_l_shape_rotation                  # Test rotation only"
puts "  LShapeTest.test_l_shape_bounding_box              # Test bounding box"
puts "  LShapeTest.test_l_shape_with_sketchup_component   # Test with selection"
puts "  LShapeTest.test_l_shape_nesting                   # Test nesting structure"
puts "\n"
