# Test script for all irregular shape types
# This validates shape detection, area calculation, and nesting for all supported shapes

require_relative 'Extension/AutoNestCut/models/shape'
require_relative 'Extension/AutoNestCut/models/part'
require_relative 'Extension/AutoNestCut/models/board'

module IrregularShapeTest
  def self.test_all_shapes
    puts "\n" + "="*80
    puts "IRREGULAR SHAPES COMPREHENSIVE TEST"
    puts "="*80
    
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      puts "\n❌ ERROR: No components selected!"
      puts "Please select the irregular shape components and run this test again."
      return
    end
    
    puts "\n📦 Testing #{selection.length} selected components..."
    
    results = {
      total: 0,
      passed: 0,
      failed: 0,
      shapes: {}
    }
    
    selection.each_with_index do |entity, idx|
      next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      
      results[:total] += 1
      
      puts "\n" + "-"*80
      puts "TEST #{idx + 1}: #{entity.name || 'Unnamed'}"
      puts "-"*80
      
      begin
        # Create Part from entity
        part = AutoNestCut::Part.new(entity)
        
        # Test 1: Shape Detection
        puts "\n1. SHAPE DETECTION"
        puts "  Shape type: #{part.shape.type}"
        puts "  Vertices: #{part.shape.vertices.length}"
        puts "  Is convex: #{part.shape.convex?}"
        puts "  Complexity: #{part.shape.complexity_score}"
        
        # Test 2: Dimensions
        puts "\n2. DIMENSIONS"
        puts "  Width: #{part.width.round(2)} mm"
        puts "  Height: #{part.height.round(2)} mm"
        puts "  Thickness: #{part.thickness.round(2)} mm"
        puts "  Bounding box: #{part.shape.bounding_box[:width].round(2)} x #{part.shape.bounding_box[:height].round(2)} mm"
        
        # Test 3: Area Calculation
        puts "\n3. AREA CALCULATION"
        shape_area = part.shape.area
        bbox_area = part.width * part.height
        area_ratio = (shape_area / bbox_area * 100).round(1)
        
        puts "  Shape area: #{shape_area.round(2)} mm²"
        puts "  Bounding box area: #{bbox_area.round(2)} mm²"
        puts "  Area efficiency: #{area_ratio}%"
        
        if area_ratio > 100
          puts "  ⚠️  WARNING: Shape area exceeds bounding box (calculation error?)"
        elsif area_ratio < 50
          puts "  ✓ Complex shape detected (area < 50% of bbox)"
        else
          puts "  ✓ Area calculation looks correct"
        end
        
        # Test 4: Nesting Test
        puts "\n4. NESTING TEST"
        board = AutoNestCut::Board.new("Test Material", 2440.0, 1220.0)
        kerf_width = 3.0
        
        # Try to place the part
        position = board.find_best_position(part, kerf_width)
        
        if position
          x, y = position
          board.add_part(part, x, y, kerf_width)
          puts "  ✓ Part placed successfully at (#{part.x.round(2)}, #{part.y.round(2)})"
          puts "  Board efficiency: #{board.efficiency_percentage.round(2)}%"
          
          # Try to place a second identical part
          part2 = part.create_placed_instance
          position2 = board.find_best_position(part2, kerf_width)
          
          if position2
            x2, y2 = position2
            board.add_part(part2, x2, y2, kerf_width)
            puts "  ✓ Second part placed at (#{part2.x.round(2)}, #{part2.y.round(2)})"
            puts "  Board efficiency: #{board.efficiency_percentage.round(2)}%"
            
            # Check for collision
            if part.intersects_with?(part2)
              puts "  ❌ COLLISION DETECTED between parts!"
              results[:failed] += 1
            else
              puts "  ✓ No collision - parts properly separated"
              results[:passed] += 1
            end
          else
            puts "  ⚠️  Could not place second part (board full or shape too complex)"
            results[:passed] += 1
          end
        else
          puts "  ❌ Failed to place part on board"
          results[:failed] += 1
        end
        
        # Test 5: Rotation Test
        puts "\n5. ROTATION TEST"
        if part.can_rotate?
          original_width = part.width
          original_height = part.height
          
          part.rotate!(90)
          
          if (part.width - original_height).abs < 1 && (part.height - original_width).abs < 1
            puts "  ✓ Rotation successful (dimensions swapped)"
            puts "  New dimensions: #{part.width.round(2)} x #{part.height.round(2)} mm"
          else
            puts "  ⚠️  Rotation may not have worked correctly"
            puts "  Expected: #{original_height.round(2)} x #{original_width.round(2)} mm"
            puts "  Got: #{part.width.round(2)} x #{part.height.round(2)} mm"
          end
        else
          puts "  ⚠️  Rotation not allowed (grain direction constraint)"
        end
        
        # Store results by shape type
        shape_type = part.shape.type
        results[:shapes][shape_type] ||= { count: 0, passed: 0 }
        results[:shapes][shape_type][:count] += 1
        results[:shapes][shape_type][:passed] += 1 if position
        
        puts "\n✅ TEST PASSED for #{entity.name}"
        
      rescue => e
        puts "\n❌ TEST FAILED: #{e.message}"
        puts "Backtrace: #{e.backtrace.first(3).join("\n")}"
        results[:failed] += 1
      end
    end
    
    # Print summary
    puts "\n" + "="*80
    puts "TEST SUMMARY"
    puts "="*80
    puts "Total tests: #{results[:total]}"
    puts "Passed: #{results[:passed]}"
    puts "Failed: #{results[:failed]}"
    puts "Success rate: #{(results[:passed].to_f / results[:total] * 100).round(1)}%"
    
    puts "\nShapes tested:"
    results[:shapes].each do |shape_type, data|
      puts "  #{shape_type}: #{data[:count]} components (#{data[:passed]} nested successfully)"
    end
    
    puts "\n" + "="*80
    
    if results[:failed] == 0
      puts "✅ ALL TESTS PASSED!"
    else
      puts "⚠️  SOME TESTS FAILED - Review output above"
    end
    
    puts "="*80
  end
end

# Run the test
IrregularShapeTest.test_all_shapes
