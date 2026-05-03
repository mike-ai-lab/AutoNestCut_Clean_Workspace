# Load ALL AutoNestCut classes
# Run this in SketchUp Ruby Console

puts "\n🚀 LOADING ALL AUTONESTCUT CLASSES"
puts "="*80

workspace = 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace'
base_path = File.join(workspace, 'Extension', 'AutoNestCut')

# Check if AutoNestCut module exists
unless defined?(AutoNestCut)
  puts "❌ AutoNestCut module not loaded!"
  puts "   Run this first:"
  puts "   load '#{File.join(workspace, 'Extension', 'autonestcut.rb')}'"
  exit
end

puts "✓ AutoNestCut module exists"
puts "\n📦 Loading all classes in dependency order..."

# All files in correct dependency order
files = [
  'compatibility.rb',
  'util.rb',
  'materials_database.rb',
  'config.rb',
  'models/part.rb',
  'models/board.rb',
  'models/facade_surface.rb',
  'models/cladding_preset.rb',
  'processors/model_analyzer.rb',
  'processors/nester.rb',
  'processors/facade_analyzer.rb',
  'processors/component_cache.rb',
  'processors/component_validator.rb',
  'processors/label_generator.rb'
]

loaded_count = 0
failed_count = 0

files.each do |file|
  file_path = File.join(base_path, file)
  
  begin
    load file_path
    puts "✅ #{file}"
    loaded_count += 1
  rescue => e
    puts "❌ #{file}"
    puts "   ERROR: #{e.message}"
    failed_count += 1
  end
end

puts "\n" + "="*80
puts "📊 LOADING SUMMARY"
puts "="*80
puts "✅ Loaded: #{loaded_count}"
puts "❌ Failed: #{failed_count}"

# Check critical classes
puts "\n🔍 CRITICAL CLASSES CHECK:"

critical_classes = [
  'Config',
  'MaterialsDatabase',
  'Part',
  'Board',
  'Nester',
  'ComponentCache',
  'ComponentValidator',
  'LabelGenerator'
]

all_ok = true

critical_classes.each do |class_name|
  begin
    const = AutoNestCut.const_get(class_name)
    puts "✅ #{class_name}"
  rescue NameError
    puts "❌ #{class_name} NOT FOUND"
    all_ok = false
  end
end

if all_ok
  puts "\n✅ ALL CRITICAL CLASSES LOADED!"
  
  # Enable QR labels feature
  begin
    AutoNestCut::Config.save_global_settings({'enable_part_labels' => true})
    settings = AutoNestCut::Config.get_cached_settings
    puts "✅ enable_part_labels: #{settings['enable_part_labels']}"
  rescue => e
    puts "⚠️  Could not configure: #{e.message}"
  end
  
  # Clear cache
  begin
    AutoNestCut::ComponentCache.clear_cache
    puts "✅ Cache cleared"
  rescue => e
    puts "⚠️  Could not clear cache: #{e.message}"
  end
  
  puts "\n" + "="*80
  puts "🎉 READY TO USE QR LABELS!"
  puts "="*80
  puts "\n📋 NEXT STEPS:"
  puts "   1. Close AutoNestCut dialog if open"
  puts "   2. Select components"
  puts "   3. Run AutoNestCut"
  puts "   4. Click 'Process' (MUST run fresh nesting!)"
  puts "   5. Watch console for label generation"
  puts "   6. Export PDF"
  puts "   7. Verify Part Code + QR columns appear"
  puts "\n⚠️  CRITICAL: Click 'Process' to run fresh nesting!"
  puts "   Do NOT use cached results!"
  puts "="*80
else
  puts "\n❌ SOME CLASSES MISSING"
  puts "   This will cause errors when using the extension"
  puts "\n   Available constants:"
  AutoNestCut.constants.sort.each do |const|
    puts "      - #{const}"
  end
end

