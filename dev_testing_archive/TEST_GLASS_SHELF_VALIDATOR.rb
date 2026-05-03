# Test script to verify validator behavior with glass shelves and thick base
# This simulates the user's exact components

require 'json'

# Mock the required modules for standalone testing
module AutoNestCut
  class Config
    def self.get_cached_settings
      { 'default_currency' => 'USD' }
    end
  end
  
  class Util
    def self.debug(msg)
      puts "DEBUG: #{msg}"
    end
  end
  
  class MaterialsDatabase
    def self.load_database
      # Return empty - we'll use defaults only
      {}
    end
    
    def self.save_database(materials)
      puts "MOCK: Would save #{materials.length} materials to database"
    end
    
    def self.get_default_materials
      # Load from JSON file
      json_path = File.join(__dir__, 'Extension/AutoNestCut/default_materials_database.json')
      if File.exist?(json_path)
        JSON.parse(File.read(json_path))
      else
        {}
      end
    end
  end
end

require_relative 'Extension/AutoNestCut/processors/component_validator'

# Mock Part class for testing
class MockPart
  attr_accessor :name, :width, :height, :thickness, :material
  
  def initialize(name, width, height, thickness, material)
    @name = name
    @width = width
    @height = height
    @thickness = thickness
    @material = material
  end
end

puts "=" * 80
puts "GLASS SHELF & THICK BASE VALIDATOR TEST"
puts "=" * 80
puts

# Create test components matching user's data
parts_by_material = {
  'Silver_Metal_Finish' => [
    MockPart.new('Base#1', 250.0, 750.0, 100.0, 'Silver_Metal_Finish'),
    MockPart.new('Side Panel#1', 250.0, 2332.0, 18.0, 'Silver_Metal_Finish'),
    MockPart.new('Top#1', 250.0, 750.0, 18.0, 'Silver_Metal_Finish'),
    MockPart.new('Divider#1', 232.0, 2332.0, 18.0, 'Silver_Metal_Finish'),
    MockPart.new('Side Panel#1', 250.0, 2332.0, 18.0, 'Silver_Metal_Finish'),
    MockPart.new('Back Panel#2', 714.0, 2332.0, 18.0, 'Silver_Metal_Finish')
  ],
  'Blue_Glass_Shelf1' => [
    MockPart.new('Glass Shelf#1', 232.0, 348.0, 8.0, 'Blue_Glass_Shelf1'),
    MockPart.new('Glass Shelf#1', 232.0, 348.0, 8.0, 'Blue_Glass_Shelf1'),
    MockPart.new('Glass Shelf#1', 232.0, 348.0, 8.0, 'Blue_Glass_Shelf1'),
    MockPart.new('Glass Shelf#1', 232.0, 348.0, 8.0, 'Blue_Glass_Shelf1'),
    MockPart.new('Glass Shelf#1', 232.0, 348.0, 8.0, 'Blue_Glass_Shelf1'),
    MockPart.new('Glass Shelf#1', 232.0, 348.0, 8.0, 'Blue_Glass_Shelf1'),
    MockPart.new('Glass Shelf#1', 232.0, 348.0, 8.0, 'Blue_Glass_Shelf1'),
    MockPart.new('Glass Shelf#1', 232.0, 348.0, 8.0, 'Blue_Glass_Shelf1')
  ]
}

puts "TEST COMPONENTS:"
puts "-" * 80
parts_by_material.each do |material, parts|
  puts "Material: #{material}"
  parts.each do |part|
    puts "  - #{part.name}: #{part.width}×#{part.height}×#{part.thickness}mm"
  end
end
puts

puts "EXPECTED BEHAVIOR:"
puts "-" * 80
puts "✓ Base#1 (100mm thick) - SHOULD BE REJECTED (exceeds MAX_THICKNESS 500mm? NO, but no sheet matches)"
puts "✓ Glass Shelf (8mm thick) - SHOULD AUTO-CREATE (no 8mm sheets in database, closest is 6mm or 12mm)"
puts "✓ Other 18mm parts - SHOULD MATCH existing 18mm sheets (no auto-create)"
puts

puts "RUNNING VALIDATOR..."
puts "-" * 80

validator = AutoNestCut::ComponentValidator.new
result = validator.validate_and_prepare_materials(parts_by_material)

puts
puts "=" * 80
puts "VALIDATION RESULTS"
puts "=" * 80
puts "Success: #{result[:success]}"
puts "Errors: #{result[:errors].length}"
puts "Warnings: #{result[:warnings].length}"
puts "Auto-created materials: #{result[:materials_created].length}"
puts

if result[:errors].any?
  puts "ERRORS:"
  result[:errors].each { |e| puts "  ❌ #{e}" }
  puts
end

if result[:warnings].any?
  puts "WARNINGS:"
  result[:warnings].each { |w| puts "  ⚠️  #{w}" }
  puts
end

if result[:materials_created].any?
  puts "AUTO-CREATED MATERIALS:"
  result[:materials_created].each do |mat|
    puts "  ✓ #{mat[:name]}"
    puts "    Dimensions: #{mat[:dimensions]}"
    puts "    Base material: #{mat[:base_material]}"
  end
  puts
else
  puts "❌ NO AUTO-MATERIALS CREATED!"
  puts "This is the BUG - validator should have created materials for:"
  puts "  - Glass Shelf (8mm) - no matching thickness in database"
  puts "  - Base (100mm) - way too thick for any sheet"
  puts
end

puts "=" * 80
puts "TEST COMPLETE"
puts "=" * 80
