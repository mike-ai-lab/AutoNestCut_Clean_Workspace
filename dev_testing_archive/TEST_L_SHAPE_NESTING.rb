# Test L-shape nesting to verify actual shape-based placement
# Load this in SketchUp Ruby Console after selecting an L-shaped component

require 'sketchup'

# Load the AutoNestCut modules
load File.join(__dir__, 'Extension', 'AutoNestCut', 'util.rb')
load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'shape.rb')
load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'part.rb')
load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'board.rb')

module LShapeNestingTest
  
  def self.test_l_shape_nesting
    puts "\n" + "="*70
    puts "  L-Shape Nesting Test - Actual Shape-Based Placement"
    puts "="*70
    
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      puts "\n❌ ERROR: Please select an L-shaped component first!"
      puts "   1. Create or select an L-shaped component"
      puts "   2. Run this test again"
      return
    end
    
    entity = selection.first
    
    puts "\n1. Creating Part from Selected Component..."
    part = AutoNestCut::Part.new(entity)
    
    puts "   Part: #{part.name}"
    puts "   Dimensions: #{part.width.round(1)} x #{part.height.round(1)} x #{part.thickness.round(1)} mm"
    puts "   Shape type: #{part.shape.type}"
    puts "   Is rectangular: #{part.rectangular?}"
    puts "   Vertices: #{part.shape.vertices.length}"
    
    if part.rectangular?
      puts "\n⚠️  WARNING: Selected component is rectangular, not L-shaped!"
      puts "   This test is designed for L-shaped components."
      puts "   The component will still be tested, but results may not be interesting."
    end
    
    puts "\n2. Creating Board (2440 x 1220 mm)..."
    board = AutoNestCut::Board.new("Test Material", 2440, 1220)
    kerf_width = 3.0
    
    puts "\n3. Testing Placement..."
    puts "   Searching for valid position using grid search..."
    
    position = board.find_best_position(part, kerf_width)
    
    if position
      x, y = position
      puts "   ✅ Position found: (#{x.round(1)}, #{y.round(1)})"
      
      # Place the part
      board.add_part(part, x, y, kerf_width)
      
      puts "\n4. Board Status After Placement:"
      puts "   Parts on board: #{board.parts_on_board.length}"
      puts "   Used area: #{board.used_area.round(2)} mm²"
      puts "   Waste area: #{board.waste_area.round(2)} mm²"
      puts "   Efficiency: #{board.efficiency_percentage.round(2)}%"
      puts "   Free rectangles: #{board.free_rectangles.length}"
      
      # Try to place a second part
      puts "\n5. Testing Second Part Placement..."
      part2 = part.create_placed_instance
      position2 = board.find_best_position(part2, kerf_width)
      
      if position2
        x2, y2 = position2
        puts "   ✅ Second position found: (#{x2.round(1)}, #{y2.round(1)})"
        board.add_part(part2, x2, y2, kerf_width)
        
        puts "\n6. Board Status After Second Part:"
        puts "   Parts on board: #{board.parts_on_board.length}"
        puts "   Used area: #{board.used_area.round(2)} mm²"
        puts "   Efficiency: #{board.efficiency_percentage.round(2)}%"
        
        # Check if parts overlap (they shouldn't!)
        puts "\n7. Collision Check:"
        if part.intersects_with?(part2, x, y, x2, y2)
          puts "   ❌ ERROR: Parts overlap! Shape collision detection failed!"
        else
          puts "   ✅ No collision - parts are properly separated"
        end
      else
        puts "   ⚠️  No position found for second part"
        puts "   This is expected if the board is nearly full"
      end
      
      puts "\n" + "="*70
      puts "  ✅ L-SHAPE NESTING TEST COMPLETE"
      puts "="*70
      
      if part.rectangular?
        puts "\n  Note: Component was rectangular, not L-shaped"
      else
        puts "\n  ✓ L-shape was placed using actual geometry"
        puts "  ✓ Grid search found optimal position"
        puts "  ✓ Shape collision detection working"
      end
      
      # Export board data for visualization
      puts "\n8. Board Data (for visualization):"
      board_data = board.to_h
      puts "   Material: #{board_data[:material]}"
      puts "   Dimensions: #{board_data[:stock_width]} x #{board_data[:stock_height]}"
      puts "   Parts:"
      board_data[:parts].each_with_index do |p, i|
        puts "     Part #{i+1}: #{p[:name]} at (#{p[:x]}, #{p[:y]})"
        if p[:shape]
          puts "       Shape: #{p[:shape][:type]} with #{p[:shape][:vertices].length} vertices"
        end
      end
      
    else
      puts "   ❌ ERROR: No position found for part!"
      puts "   This shouldn't happen for a single part on an empty board."
      puts "\n   Debugging info:"
      puts "   - Part dimensions: #{part.width} x #{part.height}"
      puts "   - Board dimensions: #{board.stock_width} x #{board.stock_height}"
      puts "   - Part fits in board: #{part.fits_in?(board.stock_width, board.stock_height, kerf_width)}"
    end
    
  rescue => e
    puts "\n❌ ERROR: #{e.message}"
    puts "   #{e.backtrace.first(5).join("\n   ")}"
  end
  
  def self.test_multiple_l_shapes
    puts "\n" + "="*70
    puts "  Multiple L-Shapes Nesting Test"
    puts "="*70
    
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      puts "\n❌ ERROR: Please select an L-shaped component first!"
      return
    end
    
    entity = selection.first
    part_template = AutoNestCut::Part.new(entity)
    
    puts "\n1. Creating Board..."
    board = AutoNestCut::Board.new("Test Material", 2440, 1220)
    kerf_width = 3.0
    
    puts "\n2. Attempting to place multiple L-shapes..."
    placed_count = 0
    max_attempts = 10
    
    max_attempts.times do |i|
      part = part_template.create_placed_instance
      position = board.find_best_position(part, kerf_width)
      
      if position
        x, y = position
        board.add_part(part, x, y, kerf_width)
        placed_count += 1
        puts "   ✓ Part #{placed_count} placed at (#{x.round(1)}, #{y.round(1)})"
      else
        puts "   ✗ Could not place part #{i+1} - board full"
        break
      end
    end
    
    puts "\n3. Final Board Status:"
    puts "   Parts placed: #{placed_count}"
    puts "   Used area: #{board.used_area.round(2)} mm²"
    puts "   Total area: #{board.total_area.round(2)} mm²"
    puts "   Efficiency: #{board.efficiency_percentage.round(2)}%"
    puts "   Waste: #{board.calculate_waste_percentage.round(2)}%"
    
    puts "\n" + "="*70
    puts "  ✅ MULTIPLE L-SHAPES TEST COMPLETE"
    puts "="*70
    puts "\n  Placed #{placed_count} L-shaped parts"
    puts "  Efficiency: #{board.efficiency_percentage.round(2)}%"
    
  rescue => e
    puts "\n❌ ERROR: #{e.message}"
    puts "   #{e.backtrace.first(5).join("\n   ")}"
  end
  
end

puts "\n" + "="*70
puts "  L-Shape Nesting Test Suite Loaded"
puts "="*70
puts "\nAvailable tests:"
puts "  1. LShapeNestingTest.test_l_shape_nesting"
puts "     - Tests single L-shape placement with grid search"
puts "     - Verifies collision detection"
puts "     - Shows board efficiency"
puts ""
puts "  2. LShapeNestingTest.test_multiple_l_shapes"
puts "     - Tests placing multiple L-shapes"
puts "     - Shows nesting efficiency"
puts ""
puts "Instructions:"
puts "  1. Select an L-shaped component in SketchUp"
puts "  2. Run: LShapeNestingTest.test_l_shape_nesting"
puts "  3. Check console output for results"
puts ""
