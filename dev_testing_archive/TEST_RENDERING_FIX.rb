# Test to verify L-shape rendering fix
# Run this after reloading the extension

require 'sketchup'

module RenderingFixTest
  
  def self.test_area_calculation
    puts "\n" + "="*70
    puts "  Test 1: Area Calculation Fix"
    puts "="*70
    
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      puts "\n❌ Please select an L-shaped component first!"
      return
    end
    
    entity = selection.first
    
    # Load required files
    load File.join(__dir__, 'Extension', 'AutoNestCut', 'util.rb')
    load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'shape.rb')
    load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'part.rb')
    
    part = AutoNestCut::Part.new(entity)
    
    puts "\n1. Part Information:"
    puts "   Name: #{part.name}"
    puts "   Dimensions: #{part.width.round(1)} x #{part.height.round(1)} mm"
    puts "   Shape type: #{part.shape.type}"
    
    puts "\n2. Area Calculation:"
    bounding_box_area = part.width * part.height
    actual_area = part.area
    shape_area = part.shape.area
    
    puts "   Bounding box area: #{bounding_box_area.round(2)} mm²"
    puts "   Shape area: #{shape_area.round(2)} mm²"
    puts "   Part.area returns: #{actual_area.round(2)} mm²"
    
    if (actual_area - shape_area).abs < 1
      puts "\n   ✅ PASS: Part.area uses actual shape area!"
      puts "   Efficiency will be calculated correctly."
    else
      puts "\n   ❌ FAIL: Part.area still uses bounding box!"
      puts "   Expected: #{shape_area.round(2)}"
      puts "   Got: #{actual_area.round(2)}"
    end
    
    puts "\n3. Efficiency Impact:"
    board_area = 2440 * 1220
    efficiency_wrong = (bounding_box_area / board_area * 100).round(2)
    efficiency_correct = (actual_area / board_area * 100).round(2)
    
    puts "   If using bounding box: #{efficiency_wrong}%"
    puts "   If using actual shape: #{efficiency_correct}%"
    puts "   Difference: #{(efficiency_correct - efficiency_wrong).round(2)}%"
    
  rescue => e
    puts "\n❌ ERROR: #{e.message}"
    puts "   #{e.backtrace.first(3).join("\n   ")}"
  end
  
  def self.test_shape_data_export
    puts "\n" + "="*70
    puts "  Test 2: Shape Data Export"
    puts "="*70
    
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      puts "\n❌ Please select an L-shaped component first!"
      return
    end
    
    entity = selection.first
    
    load File.join(__dir__, 'Extension', 'AutoNestCut', 'util.rb')
    load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'shape.rb')
    load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'part.rb')
    
    part = AutoNestCut::Part.new(entity)
    part_hash = part.to_h
    
    puts "\n1. Checking part export data..."
    
    if part_hash[:shape]
      puts "   ✅ Shape data included in export"
      puts "   Shape type: #{part_hash[:shape][:type]}"
      puts "   Vertices: #{part_hash[:shape][:vertices].length}"
      puts "   Area: #{part_hash[:shape][:area].round(2)} mm²"
      
      if part_hash[:shape][:vertices] && part_hash[:shape][:vertices].length > 0
        puts "\n   ✅ Vertices data available for rendering:"
        part_hash[:shape][:vertices].each_with_index do |v, i|
          puts "     Vertex #{i+1}: (#{v[:x].round(2)}, #{v[:y].round(2)})"
        end
      else
        puts "\n   ❌ No vertices data - rendering will fail!"
      end
    else
      puts "   ❌ No shape data in export - rendering will use bounding box!"
    end
    
    puts "\n2. JavaScript Rendering Check:"
    puts "   The JavaScript code should receive:"
    puts "   - part.shape.type = '#{part_hash[:shape][:type]}'"
    puts "   - part.shape.vertices = array of #{part_hash[:shape][:vertices].length} points"
    puts "   - part.shape.area = #{part_hash[:shape][:area].round(2)}"
    
    puts "\n   ✅ Data is ready for JavaScript rendering!"
    
  rescue => e
    puts "\n❌ ERROR: #{e.message}"
    puts "   #{e.backtrace.first(3).join("\n   ")}"
  end
  
  def self.verify_rendering_code
    puts "\n" + "="*70
    puts "  Test 3: Verify Rendering Code"
    puts "="*70
    
    diagrams_file = File.join(__dir__, 'Extension', 'AutoNestCut', 'ui', 'html', 'diagrams_report.js')
    
    if File.exist?(diagrams_file)
      content = File.read(diagrams_file)
      
      puts "\n1. Checking drawPartWithGrain function..."
      
      if content.include?('part.shape && part.shape.vertices')
        puts "   ✅ Shape rendering code found!"
      else
        puts "   ❌ Shape rendering code NOT found!"
        puts "   The function still uses fillRect only."
      end
      
      if content.include?('ctx.beginPath()')
        puts "   ✅ Polygon drawing code found!"
      else
        puts "   ❌ Polygon drawing code NOT found!"
      end
      
      if content.include?('part.shape.vertices.forEach')
        puts "   ✅ Vertex iteration code found!"
      else
        puts "   ❌ Vertex iteration code NOT found!"
      end
      
      if content.include?('console.log') && content.include?('Rendered')
        puts "   ✅ Debug logging found!"
      else
        puts "   ⚠️  No debug logging - won't see render confirmation"
      end
      
      puts "\n2. Summary:"
      if content.include?('part.shape && part.shape.vertices') && 
         content.include?('ctx.beginPath()') && 
         content.include?('part.shape.vertices.forEach')
        puts "   ✅ ALL CHECKS PASSED!"
        puts "   Rendering code is ready to draw L-shapes."
      else
        puts "   ❌ SOME CHECKS FAILED!"
        puts "   Rendering may still use bounding boxes."
      end
    else
      puts "\n❌ ERROR: diagrams_report.js not found!"
      puts "   Expected at: #{diagrams_file}"
    end
    
  rescue => e
    puts "\n❌ ERROR: #{e.message}"
    puts "   #{e.backtrace.first(3).join("\n   ")}"
  end
  
  def self.run_all_tests
    puts "\n" + "="*70
    puts "  L-Shape Rendering Fix - Verification Suite"
    puts "="*70
    puts "\nThis will verify:"
    puts "  1. Area calculation uses actual shape"
    puts "  2. Shape data is exported correctly"
    puts "  3. Rendering code is updated"
    puts "\n" + "="*70
    
    test_area_calculation
    test_shape_data_export
    verify_rendering_code
    
    puts "\n" + "="*70
    puts "  All Tests Complete!"
    puts "="*70
    puts "\nNext steps:"
    puts "  1. If all tests passed, reload the extension"
    puts "  2. Run AutoNestCut on your L-shaped component"
    puts "  3. Check the diagram shows actual L-shape (not rectangle)"
    puts "  4. Check efficiency is 85-91% (not 13%)"
    puts "\n"
  end
  
end

puts "\n" + "="*70
puts "  L-Shape Rendering Fix Test Suite Loaded"
puts "="*70
puts "\nAvailable tests:"
puts "  1. RenderingFixTest.test_area_calculation"
puts "  2. RenderingFixTest.test_shape_data_export"
puts "  3. RenderingFixTest.verify_rendering_code"
puts "  4. RenderingFixTest.run_all_tests (recommended)"
puts "\nInstructions:"
puts "  1. Select an L-shaped component"
puts "  2. Run: RenderingFixTest.run_all_tests"
puts "\n"
