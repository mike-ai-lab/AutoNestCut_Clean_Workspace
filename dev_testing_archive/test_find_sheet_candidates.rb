#!/usr/bin/env ruby
# Quick inline test of find_sheet_candidates logic

# Sample database materials (18mm sheets)
existing_materials = {
  "MDF_Standard_18mm_2800x2070" => { "width" => 2800, "height" => 2070, "thickness" => 18 },
  "MDF_Standard_18mm_2440x1220" => { "width" => 2440, "height" => 1220, "thickness" => 18 },
  "Plywood_Birch_18mm_2800x2070" => { "width" => 2800, "height" => 2070, "thickness" => 18 },
  "MFC_Melamine_White_18mm_2800x2070" => { "width" => 2800, "height" => 2070, "thickness" => 18 }
}

# Test parts (19mm thick - should match with 1mm tolerance)
test_parts = [
  { name: "Panel_304x762", width: 304.8, height: 762.0, thickness: 19.0 },
  { name: "Panel_304x914", width: 304.8, height: 914.4, thickness: 19.0 },
  { name: "Panel_304x1067", width: 304.8, height: 1066.8, thickness: 19.0 },
  { name: "Panel_304x610", width: 304.8, height: 609.6, thickness: 19.0 }
]

# Inline implementation of find_sheet_candidates
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
    candidates << { name: db_name, data: db_data } if thickness_ok && fits
  end
  candidates
end

puts "=" * 80
puts "TEST: find_sheet_candidates with 1mm thickness tolerance"
puts "=" * 80
puts

test_parts.each do |part|
  candidates = find_sheet_candidates(part[:width], part[:height], part[:thickness], existing_materials)
  
  puts "Part: #{part[:name]} (#{part[:width]}×#{part[:height]}×#{part[:thickness]}mm)"
  puts "  Thickness check: #{part[:thickness]}mm vs 18mm database = #{(part[:thickness] - 18).abs}mm diff (tolerance: 1mm)"
  puts "  Containment check: #{part[:width]}×#{part[:height]} fits in 2800×2070? #{(part[:width] <= 2800 && part[:height] <= 2070) || (part[:height] <= 2800 && part[:width] <= 2070)}"
  
  if candidates.any?
    puts "  ✅ FOUND #{candidates.length} candidate(s):"
    candidates.each { |c| puts "     - #{c[:name]}" }
  else
    puts "  ❌ NO CANDIDATES FOUND"
  end
  puts
end

puts "=" * 80
puts "RESULT: All parts should find candidates (no auto-create needed)"
puts "=" * 80
