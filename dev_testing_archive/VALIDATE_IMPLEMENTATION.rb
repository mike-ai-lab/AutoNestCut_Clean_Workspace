# Validation script for non-rectangular shape implementation
# Run this in SketchUp Ruby Console to validate the implementation

puts "\n" + "="*70
puts "  AutoNestCut Non-Rectangular Shape Implementation Validator"
puts "="*70

validation_results = {
  passed: [],
  failed: [],
  warnings: []
}

def check(description, &block)
  begin
    result = block.call
    if result
      validation_results[:passed] << description
      puts "✅ #{description}"
      true
    else
      validation_results[:failed] << description
      puts "❌ #{description}"
      false
    end
  rescue => e
    validation_results[:failed] << "#{description} (Error: #{e.message})"
    puts "❌ #{description}"
    puts "   Error: #{e.message}"
    false
  end
end

def warn(message)
  validation_results[:warnings] << message
  puts "⚠️  #{message}"
end

# 1. Check file existence
puts "\n📁 Checking Files..."
check("Shape.rb exists") do
  File.exist?(File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'shape.rb'))
end

check("Part.rb exists") do
  File.exist?(File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'part.rb'))
end

check("Board.rb exists") do
  File.exist?(File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'board.rb'))
end

check("Test suite exists") do
  File.exist?(File.join(__dir__, 'TEST_NON_RECTANGULAR_SHAPES.rb'))
end

# 2. Check if files can be loaded
puts "\n📦 Loading Modules..."
begin
  load File.join(__dir__, 'Extension', 'AutoNestCut', 'util.rb')
  check("Util module loaded") { defined?(AutoNestCut::Util) }
rescue => e
  warn("Could not load Util module: #{e.message}")
end

begin
  load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'shape.rb')
  check("Shape class loaded") { defined?(AutoNestCut::Shape) }
rescue => e
  validation_results[:failed] << "Shape class failed to load: #{e.message}"
  puts "❌ Shape class failed to load"
  puts "   Error: #{e.message}"
end

begin
  load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'part.rb')
  check("Part class loaded") { defined?(AutoNestCut::Part) }
rescue => e
  validation_results[:failed] << "Part class failed to load: #{e.message}"
  puts "❌ Part class failed to load"
  puts "   Error: #{e.message}"
end

begin
  load File.join(__dir__, 'Extension', 'AutoNestCut', 'models', 'board.rb')
  check("Board class loaded") { defined?(AutoNestCut::Board) }
rescue => e
  validation_results[:failed] << "Board class failed to load: #{e.message}"
  puts "❌ Board class failed to load"
  puts "   Error: #{e.message}"
end

# 3. Check Shape class API
if defined?(AutoNestCut::Shape)
  puts "\n🔍 Validating Shape Class API..."
  
  check("Shape.new accepts vertices") do
    vertices = [{x: 0, y: 0}, {x: 100, y: 0}, {x: 100, y: 50}, {x: 0, y: 50}]
    shape = AutoNestCut::Shape.new(vertices)
    shape.is_a?(AutoNestCut::Shape)
  end
  
  check("Shape.rectangle class method exists") do
    AutoNestCut::Shape.respond_to?(:rectangle)
  end
  
  check("Shape has type attribute") do
    shape = AutoNestCut::Shape.rectangle(100, 50)
    shape.respond_to?(:type)
  end
  
  check("Shape has vertices attribute") do
    shape = AutoNestCut::Shape.rectangle(100, 50)
    shape.respond_to?(:vertices)
  end
  
  check("Shape has bounding_box attribute") do
    shape = AutoNestCut::Shape.rectangle(100, 50)
    shape.respond_to?(:bounding_box)
  end
  
  check("Shape has intersects? method") do
    shape = AutoNestCut::Shape.rectangle(100, 50)
    shape.respond_to?(:intersects?)
  end
  
  check("Shape has rotate method") do
    shape = AutoNestCut::Shape.rectangle(100, 50)
    shape.respond_to?(:rotate)
  end
  
  check("Shape has convex? method") do
    shape = AutoNestCut::Shape.rectangle(100, 50)
    shape.respond_to?(:convex?)
  end
  
  check("Shape has complexity_score method") do
    shape = AutoNestCut::Shape.rectangle(100, 50)
    shape.respond_to?(:complexity_score)
  end
  
  check("Shape has to_h method") do
    shape = AutoNestCut::Shape.rectangle(100, 50)
    shape.respond_to?(:to_h)
  end
end

# 4. Check Part class integration
if defined?(AutoNestCut::Part)
  puts "\n🔍 Validating Part Class Integration..."
  
  check("Part has shape attribute") do
    # Note: Can't fully test without SketchUp entity
    AutoNestCut::Part.instance_methods.include?(:shape)
  end
  
  check("Part has rotation_angle attribute") do
    AutoNestCut::Part.instance_methods.include?(:rotation_angle)
  end
  
  check("Part has rectangular? method") do
    AutoNestCut::Part.instance_methods.include?(:rectangular?)
  end
  
  check("Part has intersects_with? method") do
    AutoNestCut::Part.instance_methods.include?(:intersects_with?)
  end
  
  check("Part rotate! method exists") do
    AutoNestCut::Part.instance_methods.include?(:rotate!)
  end
end

# 5. Check Board class integration
if defined?(AutoNestCut::Board)
  puts "\n🔍 Validating Board Class Integration..."
  
  check("Board has collides_with_existing_parts? method") do
    AutoNestCut::Board.instance_methods(false).include?(:collides_with_existing_parts?)
  end
  
  check("Board has bounding_boxes_overlap? method") do
    AutoNestCut::Board.instance_methods(false).include?(:bounding_boxes_overlap?)
  end
  
  check("Board has update_free_rectangles_with_shape method") do
    AutoNestCut::Board.instance_methods(false).include?(:update_free_rectangles_with_shape)
  end
end

# 6. Functional tests
if defined?(AutoNestCut::Shape)
  puts "\n🧪 Running Functional Tests..."
  
  check("Can create rectangular shape") do
    shape = AutoNestCut::Shape.rectangle(100, 50)
    shape.type == :rectangle
  end
  
  check("Rectangle has correct dimensions") do
    shape = AutoNestCut::Shape.rectangle(100, 50)
    bb = shape.bounding_box
    (bb[:width] - 100).abs < 0.1 && (bb[:height] - 50).abs < 0.1
  end
  
  check("Can detect L-shape") do
    vertices = [
      {x: 0, y: 0}, {x: 100, y: 0}, {x: 100, y: 50},
      {x: 50, y: 50}, {x: 50, y: 100}, {x: 0, y: 100}
    ]
    shape = AutoNestCut::Shape.new(vertices)
    shape.type == :l_shape
  end
  
  check("Collision detection works") do
    shape1 = AutoNestCut::Shape.rectangle(100, 50)
    shape2 = AutoNestCut::Shape.rectangle(100, 50)
    # Overlapping
    collision = shape1.intersects?(shape2, 50, 0)
    # Not overlapping
    no_collision = !shape1.intersects?(shape2, 150, 0)
    collision && no_collision
  end
  
  check("Rotation works") do
    shape = AutoNestCut::Shape.rectangle(100, 50)
    rotated = shape.rotate(90)
    bb = rotated.bounding_box
    # After 90° rotation, width and height should swap (approximately)
    (bb[:width] - 50).abs < 5 && (bb[:height] - 100).abs < 5
  end
  
  check("Shape exports to hash") do
    shape = AutoNestCut::Shape.rectangle(100, 50)
    hash = shape.to_h
    hash.is_a?(Hash) && hash.key?(:type) && hash.key?(:vertices)
  end
end

# 7. Documentation check
puts "\n📚 Checking Documentation..."
check("Implementation documentation exists") do
  File.exist?(File.join(__dir__, 'NON_RECTANGULAR_SHAPES_IMPLEMENTATION.md'))
end

check("Quick start guide exists") do
  File.exist?(File.join(__dir__, 'NON_RECTANGULAR_SHAPES_QUICK_START.md'))
end

check("Summary document exists") do
  File.exist?(File.join(__dir__, 'NON_RECTANGULAR_SHAPES_SUMMARY.md'))
end

# 8. Print summary
puts "\n" + "="*70
puts "  Validation Summary"
puts "="*70

puts "\n✅ Passed: #{validation_results[:passed].length}"
validation_results[:passed].each { |item| puts "   - #{item}" }

if validation_results[:failed].length > 0
  puts "\n❌ Failed: #{validation_results[:failed].length}"
  validation_results[:failed].each { |item| puts "   - #{item}" }
end

if validation_results[:warnings].length > 0
  puts "\n⚠️  Warnings: #{validation_results[:warnings].length}"
  validation_results[:warnings].each { |item| puts "   - #{item}" }
end

# Final verdict
puts "\n" + "="*70
total_checks = validation_results[:passed].length + validation_results[:failed].length
pass_rate = (validation_results[:passed].length.to_f / total_checks * 100).round(1)

if validation_results[:failed].length == 0
  puts "  ✅ ALL VALIDATIONS PASSED! (#{pass_rate}%)"
  puts "  Implementation is ready for testing in SketchUp"
elsif pass_rate >= 80
  puts "  ⚠️  MOSTLY PASSED (#{pass_rate}%)"
  puts "  Review failed checks before proceeding"
else
  puts "  ❌ VALIDATION FAILED (#{pass_rate}%)"
  puts "  Fix critical issues before proceeding"
end
puts "="*70

puts "\n📋 Next Steps:"
puts "1. Fix any failed validations"
puts "2. Load test suite: load 'TEST_NON_RECTANGULAR_SHAPES.rb'"
puts "3. Run tests: AutoNestCutTest.run_all_tests"
puts "4. Test with real SketchUp geometry"
puts "5. Proceed to Phase 3 (rendering updates)"

puts "\n"
