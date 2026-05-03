# Test: Exact Match Logic (No Fuzzy, No Tolerance)
# This tests the new strict validator behavior

puts "=" * 80
puts "TEST: EXACT MATCH LOGIC (Strict Validator)"
puts "=" * 80
puts ""

# Simulate the exact_material_exists? method
def exact_material_exists?(material_name, thickness, existing_materials)
  return false unless existing_materials.key?(material_name)
  db_thickness = existing_materials[material_name]['thickness'].to_f
  db_thickness == thickness
end

# Create test database
materials_database = {
  'BLUE' => { 'width' => 2440, 'height' => 1220, 'thickness' => 8.0 },
  'GREEN' => { 'width' => 2440, 'height' => 1220, 'thickness' => 18.0 },
  'Blue_Glass_Shelf' => { 'width' => 2440, 'height' => 1220, 'thickness' => 8.0 },
  'MDF_18mm' => { 'width' => 2800, 'height' => 2070, 'thickness' => 18.0 }
}

puts "Database contains:"
materials_database.each do |name, data|
  puts "  - #{name} (#{data['thickness']}mm)"
end
puts ""
puts "=" * 80
puts ""

# Test 1: Exact match (name + thickness)
puts "TEST 1: Component 'BLUE' with 8mm thickness"
puts "-" * 80
result = exact_material_exists?('BLUE', 8.0, materials_database)
puts "Material: BLUE"
puts "Thickness: 8mm"
puts "Exact match exists: #{result}"
if result
  puts "✅ PASS: Exact match found - NO AUTO-CREATE"
else
  puts "❌ FAIL: Should find exact match"
end
puts ""
puts "=" * 80
puts ""

# Test 2: Name exists but thickness different
puts "TEST 2: Component 'BLUE' with 6mm thickness"
puts "-" * 80
result = exact_material_exists?('BLUE', 6.0, materials_database)
puts "Material: BLUE"
puts "Thickness: 6mm"
puts "Database has: BLUE (8mm)"
puts "Exact match exists: #{result}"
if !result
  puts "✅ PASS: No exact match - SHOULD AUTO-CREATE"
else
  puts "❌ FAIL: Should NOT match (thickness different)"
end
puts ""
puts "=" * 80
puts ""

# Test 3: Similar name but not exact
puts "TEST 3: Component 'Blue_Glass_Shelf' with 8mm thickness"
puts "-" * 80
result = exact_material_exists?('Blue_Glass_Shelf', 8.0, materials_database)
puts "Material: Blue_Glass_Shelf"
puts "Thickness: 8mm"
puts "Exact match exists: #{result}"
if result
  puts "✅ PASS: Exact match found - NO AUTO-CREATE"
else
  puts "❌ FAIL: Should find exact match"
end
puts ""
puts "=" * 80
puts ""

# Test 4: Component with material that doesn't exist
puts "TEST 4: Component 'RED' with 12mm thickness"
puts "-" * 80
result = exact_material_exists?('RED', 12.0, materials_database)
puts "Material: RED"
puts "Thickness: 12mm"
puts "Exact match exists: #{result}"
if !result
  puts "✅ PASS: No exact match - SHOULD AUTO-CREATE"
else
  puts "❌ FAIL: Should NOT match (material doesn't exist)"
end
puts ""
puts "=" * 80
puts ""

# Test 5: Thickness tolerance should NOT work
puts "TEST 5: Component 'GREEN' with 18.5mm thickness (tolerance test)"
puts "-" * 80
result = exact_material_exists?('GREEN', 18.5, materials_database)
puts "Material: GREEN"
puts "Thickness: 18.5mm"
puts "Database has: GREEN (18mm)"
puts "Exact match exists: #{result}"
if !result
  puts "✅ PASS: No exact match - SHOULD AUTO-CREATE (no tolerance)"
else
  puts "❌ FAIL: Should NOT match (18.5 ≠ 18.0)"
end
puts ""
puts "=" * 80
puts ""

puts "SUMMARY"
puts "=" * 80
puts ""
puts "The new validator logic:"
puts "  ✓ Exact name match required"
puts "  ✓ Exact thickness match required (no tolerance)"
puts "  ✓ No fuzzy matching"
puts "  ✓ No 'candidates' search"
puts ""
puts "Like a real carpenter:"
puts "  'Do I have THIS material with THIS thickness?'"
puts "  'If YES → use it. If NO → create it.'"
puts ""
