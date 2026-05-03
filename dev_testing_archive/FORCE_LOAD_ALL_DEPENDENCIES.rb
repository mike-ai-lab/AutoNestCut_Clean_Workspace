# Force load all required classes for QR Labels feature
# Run this in SketchUp Ruby Console AFTER loading the extension

puts "\n🔧 FORCE LOADING ALL DEPENDENCIES"
puts "="*80

workspace = 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace'
base_path = File.join(workspace, 'Extension', 'AutoNestCut')

# Check if AutoNestCut module exists
unless defined?(AutoNestCut)
  puts "❌ AutoNestCut module not loaded!"
  puts "   Load the extension first, then run this script."
  exit
end

puts "✓ AutoNestCut module exists"

# List of files to force load (in dependency order)
files_to_load = [
  { name: 'Config', path: 'config.rb' },
  { name: 'ComponentCache', path: 'processors/component_cache.rb' },
  { name: 'LabelGenerator', path: 'processors/label_generator.rb' }
]

puts "\n📦 Loading required classes..."

files_to_load.each do |file_info|
  class_name = file_info[:name]
  file_path = File.join(base_path, file_info[:path])
  
  # Check if already loaded
  if defined?(AutoNestCut.const_get(class_name))
    puts "✓ #{class_name} already loaded"
  else
    puts "⚠️  #{class_name} not loaded, loading now..."
    
    begin
      load file_path
      
      if defined?(AutoNestCut.const_get(class_name))
        puts "   ✅ #{class_name} loaded successfully!"
      else
        puts "   ❌ File loaded but #{class_name} not defined"
      end
    rescue NameError => e
      puts "   ⚠️  #{class_name} not found (might be a module, not a class)"
    rescue => e
      puts "   ❌ ERROR loading #{class_name}: #{e.message}"
      puts "   #{e.backtrace.first(3).join("\n   ")}"
    end
  end
end

puts "\n" + "="*80
puts "📊 FINAL STATUS"
puts "="*80

# Check each class
checks = [
  'Config',
  'ComponentCache', 
  'LabelGenerator'
]

all_loaded = true

checks.each do |class_name|
  begin
    if defined?(AutoNestCut.const_get(class_name))
      puts "✅ #{class_name} available"
    else
      puts "❌ #{class_name} NOT available"
      all_loaded = false
    end
  rescue NameError
    puts "❌ #{class_name} NOT available"
    all_loaded = false
  end
end

if all_loaded
  puts "\n✅ ALL DEPENDENCIES LOADED!"
  
  # Enable feature
  begin
    AutoNestCut::Config.save_global_settings({'enable_part_labels' => true})
    puts "✅ Feature enabled"
  rescue => e
    puts "⚠️  Could not enable feature: #{e.message}"
  end
  
  # Clear cache
  begin
    AutoNestCut::ComponentCache.clear_cache
    puts "✅ Cache cleared"
  rescue => e
    puts "⚠️  Could not clear cache: #{e.message}"
  end
  
  puts "\n📋 READY TO USE:"
  puts "   1. Close AutoNestCut dialog if open"
  puts "   2. Select components in SketchUp"
  puts "   3. Extensions → Auto Nest Cut → Generate Cut List"
  puts "   4. Click 'Process' button"
  puts "   5. Watch console for:"
  puts "      🏷️ LABEL GENERATION CHECK:"
  puts "      🏷️ Calling LabelGenerator.generate_labels..."
  puts "      ✅ Label generation complete - X parts labeled"
  puts "      UID: \"ANC-XXXX-XXX\""
  puts "   6. Export PDF"
  puts "   7. Check for Part Code + QR columns"
else
  puts "\n❌ SOME DEPENDENCIES MISSING"
  puts "   Available constants: #{AutoNestCut.constants.sort.join(', ')}"
end

puts "="*80

