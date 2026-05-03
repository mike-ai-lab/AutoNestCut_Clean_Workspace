# Clear all auto-created materials from database to force recreation with correct dimensions
require_relative 'materials_database'

puts "\n🦟 CLEANUP: Removing old auto-materials with incorrect dimensions..."

materials = AutoNestCut::MaterialsDatabase.load_database

# Find all auto-materials
auto_materials = materials.select { |name, _| name.start_with?('Auto_user_') }

puts "🦟 Found #{auto_materials.length} auto-materials:"
removed = 0
auto_materials.each do |name, data|
  # Show what's being removed
  puts "  ✗ #{name}: W#{data['width']} x H#{data['height']} x TH#{data['thickness']}"
  materials.delete(name)
  removed += 1
end

# Save cleaned database
AutoNestCut::MaterialsDatabase.save_database(materials)

puts "\n🦟 ✓ Removed #{removed} auto-materials"
puts "🦟 Database now has #{materials.length} materials"
puts "🦟 Auto-materials will be recreated with CORRECT padded dimensions on next run"
puts "🦟 Expected format: Auto_user_W{W+10}xH{H+10}xTH{TH}_(OriginalMaterial)"
puts "\n"
