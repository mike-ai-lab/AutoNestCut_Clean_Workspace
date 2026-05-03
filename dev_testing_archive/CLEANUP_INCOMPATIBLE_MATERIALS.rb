# Cleanup Script: Remove materials with incompatible thicknesses
# This script removes materials with 8mm and 100mm thickness from the database
# so the validator can auto-create them properly

require 'csv'
require 'fileutils'

# Database file location
database_file = File.join(ENV['APPDATA'] || ENV['HOME'], 'AutoNestCut', 'materials_database.csv')

unless File.exist?(database_file)
  puts "❌ Database file not found: #{database_file}"
  puts "Nothing to clean up."
  exit 0
end

puts "=" * 80
puts "CLEANUP: Remove Incompatible Materials"
puts "=" * 80
puts ""
puts "Database: #{database_file}"
puts ""

# Create backup
backup_file = "#{database_file}.backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}"
FileUtils.cp(database_file, backup_file)
puts "✅ Backup created: #{backup_file}"
puts ""

# Load current database
materials = {}
removed_materials = []

CSV.foreach(database_file, headers: true) do |row|
  name = row['name'].to_s.strip
  next if name.empty?
  
  thickness = row['thickness'].to_f
  
  # Check if this is an incompatible thickness (8mm or 100mm)
  if thickness == 8.0 || thickness == 100.0
    removed_materials << { name: name, thickness: thickness }
    puts "🗑️  Removing: #{name} (#{thickness}mm)"
  else
    materials[name] = {
      'width' => row['width'],
      'height' => row['height'],
      'thickness' => row['thickness'],
      'price' => row['price'],
      'currency' => row['currency'],
      'density' => row['density'],
      'auto_generated' => row['auto_generated'],
      'created_at' => row['created_at'],
      'original_sketchup_material' => row['original_sketchup_material'],
      'is_favorite' => row['is_favorite'],
      'flagged_no_material' => row['flagged_no_material']
    }
  end
end

puts ""
puts "Summary:"
puts "  Materials removed: #{removed_materials.length}"
puts "  Materials remaining: #{materials.length}"
puts ""

if removed_materials.empty?
  puts "✅ No incompatible materials found. Database is clean."
  exit 0
end

# Save cleaned database
CSV.open(database_file, 'w') do |csv|
  csv << ['name', 'width', 'height', 'thickness', 'price', 'currency', 'density', 'auto_generated', 'created_at', 'original_sketchup_material', 'is_favorite', 'flagged_no_material']
  
  materials.each do |name, data|
    csv << [
      name,
      data['width'],
      data['height'],
      data['thickness'],
      data['price'],
      data['currency'],
      data['density'],
      data['auto_generated'],
      data['created_at'],
      data['original_sketchup_material'],
      data['is_favorite'],
      data['flagged_no_material']
    ]
  end
end

puts "✅ Database cleaned successfully!"
puts ""
puts "Removed materials:"
removed_materials.each do |mat|
  puts "  - #{mat[:name]} (#{mat[:thickness]}mm)"
end
puts ""
puts "=" * 80
puts "NEXT STEPS:"
puts "=" * 80
puts ""
puts "1. Restart SketchUp"
puts "2. Open your model with the test components"
puts "3. Run AutoNestCut"
puts "4. The validator should now auto-create materials for:"
puts "   - 8mm glass shelf (no 8mm material in database)"
puts "   - 100mm thick base (no 100mm material in database)"
puts ""
puts "If you need to restore the backup:"
puts "  Copy: #{backup_file}"
puts "  To:   #{database_file}"
puts ""
