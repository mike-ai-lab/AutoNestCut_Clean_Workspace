# Force load LabelGenerator with explicit error handling
# Run this in SketchUp Ruby Console AFTER loading the extension

puts "\n🔧 FORCE LOADING LabelGenerator"
puts "="*80

workspace = 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace'
label_gen_path = File.join(workspace, 'Extension', 'AutoNestCut', 'processors', 'label_generator.rb')

puts "Path: #{label_gen_path}"
puts "Exists: #{File.exist?(label_gen_path)}"

# Check if AutoNestCut module exists
unless defined?(AutoNestCut)
  puts "❌ AutoNestCut module not loaded!"
  puts "   Load the extension first, then run this script."
  exit
end

puts "✓ AutoNestCut module exists"

# Check if LabelGenerator already loaded
if defined?(AutoNestCut::LabelGenerator)
  puts "✓ LabelGenerator already loaded"
else
  puts "⚠️  LabelGenerator not loaded, loading now..."
  
  begin
    # Force load the file
    load label_gen_path
    
    if defined?(AutoNestCut::LabelGenerator)
      puts "✅ LabelGenerator loaded successfully!"
    else
      puts "❌ File loaded but LabelGenerator class not defined"
      puts "   This means there's an issue with the file content"
    end
  rescue => e
    puts "❌ ERROR loading: #{e.message}"
    puts e.backtrace.first(5).join("\n")
  end
end

# Final check
if defined?(AutoNestCut::LabelGenerator)
  puts "\n✅ FINAL STATUS: LabelGenerator IS available"
  puts "   Methods: #{AutoNestCut::LabelGenerator.singleton_methods.sort.join(', ')}"
  
  # Enable feature
  AutoNestCut::Config.save_global_settings({'enable_part_labels' => true})
  puts "✅ Feature enabled"
  
  # Clear cache
  AutoNestCut::ComponentCache.clear_cache
  puts "✅ Cache cleared"
  
  puts "\n📋 NOW:"
  puts "   1. Close AutoNestCut dialog"
  puts "   2. Select components"
  puts "   3. Run AutoNestCut"
  puts "   4. Click 'Process'"
  puts "   5. Watch for label generation messages"
else
  puts "\n❌ FINAL STATUS: LabelGenerator NOT available"
  puts "   Available constants: #{AutoNestCut.constants.sort.join(', ')}"
end

puts "="*80

