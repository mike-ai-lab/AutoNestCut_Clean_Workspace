#!/usr/bin/env ruby
# Test script to verify the validator fix works correctly
# This creates 4 test parts and runs the validator against the default database

require_relative 'Extension/AutoNestCut/processors/component_validator'
require_relative 'Extension/AutoNestCut/materials_database'
require_relative 'Extension/AutoNestCut/config'

# Mock Part class for testing
class MockPart
  attr_accessor :name, :width, :height, :thickness
  
  def initialize(name, width, height, thickness)
    @name = name
    @width = width
    @height = height
    @thickness = thickness
  end
end

puts "=" * 80
puts "VALIDATOR FIX TEST - Physical Containment Check"
puts "=" * 80
puts

# Create 4 test parts with realistic dimensions (all 19mm thick)
test_parts = [
  MockPart.new("Panel_304x762", 304.8, 762.0, 19.0),
  MockPart.new("Panel_304x914", 304.8, 914.4, 19.0),
  MockPart.new("Panel_304x1067", 304.8, 1066.8, 19.0),
  MockPart.new("Panel_304x610", 304.8, 609.6, 19.0)
]

# Group parts by material (simulating SketchUp materials)
parts_by_material = {
  "Maple Wood" => [test_parts[0]],
  "Cherry Wood" => [test_parts[1]],
  "Black Shaker" => [test_parts[2]],
  "White Melamine" => [test_parts[3]]
}

puts "TEST PARTS:"
test_parts.each do |part|
  puts "  - #{part.name}: #{part.width}×#{part.height}×#{part.thickness}mm"
end
puts

# Initialize validator
validator = AutoNestCut::ComponentValidator.new

# Run validation
puts "RUNNING VALIDATION..."
puts
result = validator.validate_and_prepare_materials(parts_by_material)

puts
puts "=" * 80
puts "VALIDATION RESULT"
puts "=" * 80
puts "Success: #{result[:success]}"
puts "Auto-created materials: #{result[:materials_created].length}"
puts "Warnings: #{result[:warnings].length}"
puts "Errors: #{result[:errors].length}"
puts

if result[:materials_created].any?
  puts "AUTO-CREATED MATERIALS:"
  result[:materials_created].each do |mat|
    puts "  ✗ #{mat[:name]}"
    puts "    Dimensions: #{mat[:dimensions]}"
  end
  puts
  puts "❌ TEST FAILED - Materials should NOT have been auto-created!"
  puts "   All test parts have realistic dimensions and should fit on standard sheets."
else
  puts "✅ TEST PASSED - No auto-materials created!"
  puts "   All test parts were validated against existing sheet candidates."
end

puts
puts "WARNINGS:"
result[:warnings].each { |w| puts "  ⚠️  #{w}" }
puts

puts "ERRORS:"
result[:errors].each { |e| puts "  ❌ #{e}" }
puts

puts "=" * 80
