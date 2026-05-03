#!/usr/bin/env ruby
# Standalone validator test - simulates the exact user scenario

require 'json'

puts "=" * 80
puts "VALIDATOR UNIT TEST - Glass Shelf & Thick Base"
puts "=" * 80
puts

# Load default materials from JSON
json_path = 'Extension/AutoNestCut/default_materials_database.json'
unless File.exist?(json_path)
  puts "ERROR: Cannot find #{json_path}"
  exit 1
end

default_materials = JSON.parse(File.read(json_path))
puts "✓ Loaded #{default_materials.length} default materials from JSON"
puts

# Test function: find_sheet_candidates
def find_sheet_candidates(width, height, thickness, existing_materials, thickness_tolerance = 1.0)
  candidates = []
  existing_materials.each do |db_name, db_data|
    next if db_name.start_with?('Auto_user_') || db_name.start_with?('no_material_')
    db_width = db_data['width'].to_f
    db_height = db_data['height'].to_f
    db_thickness = db_data['thickness'].to_f
    next if db_width <= 0 || db_height <= 0
    thickness_ok = (thickness - db_thickness).abs <= thickness_tolerance
    fits = (width <= db_width && height <= db_height) || (height <= db_width && width <= db_height)
    candidates << { name: db_name, data: db_data, thickness: db_thickness } if thickness_ok && fits
  end
  candidates
end

# Test cases matching user's components
test_cases = [
  { name: 'Glass Shelf#1', width: 232.0, height: 348.0, thickness: 8.0, material: 'Blue_Glass_Shelf1', expected_auto_create: true },
  { name: 'Base#1', width: 250.0, height: 750.0, thickness: 100.0, material: 'Silver_Metal_Finish', expected_auto_create: true },
  { name: 'Side Panel#1', width: 250.0, height: 2332.0, thickness: 18.0, material: 'Silver_Metal_Finish', expected_auto_create: false },
  { name: 'Top#1', width: 250.0, height: 750.0, thickness: 18.0, material: 'Silver_Metal_Finish', expected_auto_create: false },
  { name: 'Divider#1', width: 232.0, height: 2332.0, thickness: 18.0, material: 'Silver_Metal_Finish', expected_auto_create: false },
  { name: 'Back Panel#2', width: 714.0, height: 2332.0, thickness: 18.0, material: 'Silver_Metal_Finish', expected_auto_create: false }
]

puts "TEST CASES:"
puts "-" * 80
test_cases.each_with_index do |tc, i|
  puts "#{i+1}. #{tc[:name]}: #{tc[:width]}×#{tc[:height]}×#{tc[:thickness]}mm (#{tc[:material]})"
  puts "   Expected: #{tc[:expected_auto_create] ? 'AUTO-CREATE' : 'MATCH EXISTING SHEET'}"
end
puts

puts "RUNNING TESTS..."
puts "=" * 80
puts

passed = 0
failed = 0

test_cases.each_with_index do |tc, i|
  puts "Test #{i+1}: #{tc[:name]}"
  puts "  Dimensions: W#{tc[:width]} x H#{tc[:height]} x TH#{tc[:thickness]}mm"
  puts "  Material: '#{tc[:material]}'"
  
  # Find sheet candidates
  candidates = find_sheet_candidates(tc[:width], tc[:height], tc[:thickness], default_materials)
  
  puts "  Sheet candidates found: #{candidates.length}"
  
  if candidates.any?
    # Show first few candidates
    sample = candidates.first(3).map { |c| "#{c[:name]} (#{c[:thickness]}mm)" }.join(', ')
    puts "  ✓ CAN FIT on sheets: #{sample}#{candidates.length > 3 ? '...' : ''}"
    should_auto_create = false
  else
    puts "  ✗ CANNOT FIT on any existing sheet (thickness tolerance: 1mm)"
    should_auto_create = true
  end
  
  # Check if result matches expectation
  if should_auto_create == tc[:expected_auto_create]
    puts "  ✅ PASS - Validator decision is correct"
    passed += 1
  else
    puts "  ❌ FAIL - Expected #{tc[:expected_auto_create] ? 'auto-create' : 'match existing'}, got #{should_auto_create ? 'auto-create' : 'match existing'}"
    failed += 1
  end
  
  puts
end

puts "=" * 80
puts "TEST RESULTS"
puts "=" * 80
puts "Total: #{test_cases.length} tests"
puts "Passed: #{passed} ✅"
puts "Failed: #{failed} ❌"
puts

if failed == 0
  puts "🎉 ALL TESTS PASSED!"
  puts
  puts "The validator logic is working correctly:"
  puts "  ✓ 8mm glass shelf will trigger auto-create (no 8mm sheets in database)"
  puts "  ✓ 100mm thick base will trigger auto-create (no 100mm sheets in database)"
  puts "  ✓ 18mm parts will match existing 18mm sheets (no auto-create)"
  puts
  puts "You can now test in SketchUp. The validator should create:"
  puts "  - Auto_user_W232xH348xTH8_(Blue_Glass_Shelf1)"
  puts "  - Auto_user_W250xH750xTH100_(Silver_Metal_Finish)"
  puts
  exit 0
else
  puts "❌ TESTS FAILED!"
  puts "There is a bug in the validator logic that needs fixing."
  puts
  exit 1
end
