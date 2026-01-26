# Clear all auto-generated materials from the database to force regeneration with correct dimensions
require_relative 'materials_database'

puts "🧹 Clearing all auto-generated materials from database..."

# Load the database
materials = AutoNestCut::MaterialsDatabase.load_database
puts "📊 Loaded #{materials.length} materials"

# Filter out auto-generated materials
original_count = materials.length
materials.reject! { |name, _| name.start_with?('Auto_user_') }
removed_count = original_count - materials.length

puts "🗑️  Removed #{removed_count} auto-generated materials"
puts "📊 Remaining materials: #{materials.length}"

# Save the cleaned database
AutoNestCut::MaterialsDatabase.save_database(materials)
puts "✓ Database saved successfully"
puts "✓ Auto-materials will be regenerated with correct dimensions on next run"
