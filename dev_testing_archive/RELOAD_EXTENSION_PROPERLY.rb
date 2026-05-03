# Proper Extension Reload for Development
# This reloads the extension from your workspace directory

puts "\n" + "="*80
puts "🔄 RELOADING AutoNestCut Extension"
puts "="*80

# Step 1: Remove existing module
if defined?(AutoNestCut)
  puts "✓ Removing existing AutoNestCut module..."
  Object.send(:remove_const, :AutoNestCut)
end

# Step 2: Find the correct path to main.rb
workspace_root = __dir__
main_rb_path = File.join(workspace_root, 'Extension', 'AutoNestCut', 'main.rb')

puts "✓ Workspace root: #{workspace_root}"
puts "✓ Loading from: #{main_rb_path}"

# Step 3: Verify file exists
unless File.exist?(main_rb_path)
  puts "❌ ERROR: main.rb not found at: #{main_rb_path}"
  puts "   Current directory: #{Dir.pwd}"
  exit
end

# Step 4: Verify label_generator.rb exists
label_gen_path = File.join(workspace_root, 'Extension', 'AutoNestCut', 'processors', 'label_generator.rb')
unless File.exist?(label_gen_path)
  puts "❌ ERROR: label_generator.rb not found at: #{label_gen_path}"
  exit
end
puts "✓ label_generator.rb found at: #{label_gen_path}"

# Step 5: Load the extension
begin
  load main_rb_path
  puts "✓ Extension loaded successfully"
rescue => e
  puts "❌ ERROR loading extension: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit
end

# Step 6: Verify LabelGenerator is loaded
if defined?(AutoNestCut::LabelGenerator)
  puts "✅ LabelGenerator class is loaded!"
  
  # Test that it has the expected methods
  if AutoNestCut::LabelGenerator.respond_to?(:generate_labels)
    puts "✅ generate_labels method exists"
  else
    puts "⚠️  generate_labels method not found"
  end
else
  puts "❌ LabelGenerator class NOT loaded!"
  puts "\n🔍 Debugging info:"
  puts "   AutoNestCut module defined: #{defined?(AutoNestCut)}"
  
  if defined?(AutoNestCut)
    puts "   AutoNestCut constants: #{AutoNestCut.constants.sort.join(', ')}"
  end
  
  exit
end

# Step 7: Check config
begin
  settings = AutoNestCut::Config.get_cached_settings
  puts "✓ Config loaded"
  puts "   enable_part_labels: #{settings['enable_part_labels']}"
  
  unless settings['enable_part_labels']
    puts "⚠️  Feature is disabled - enabling now..."
    AutoNestCut::Config.save_global_settings({'enable_part_labels' => true})
    puts "✅ Feature enabled"
  end
rescue => e
  puts "⚠️  Could not check config: #{e.message}"
end

# Step 8: Clear cache
begin
  if defined?(AutoNestCut::ComponentCache)
    AutoNestCut::ComponentCache.clear_cache
    puts "✅ Component cache cleared"
  else
    puts "⚠️  ComponentCache not found (this is OK)"
  end
rescue => e
  puts "⚠️  Could not clear cache: #{e.message}"
end

puts "\n" + "="*80
puts "✅ RELOAD COMPLETE!"
puts "="*80
puts "\n📋 NEXT STEPS:"
puts "   1. Close AutoNestCut dialog if open"
puts "   2. Select components in SketchUp"
puts "   3. Extensions → Auto Nest Cut → Generate Cut List"
puts "   4. Click 'Process' button (CRITICAL!)"
puts "   5. Watch console for:"
puts "      🏷️ LABEL GENERATION CHECK:"
puts "      🏷️ Calling LabelGenerator.generate_labels..."
puts "      ✅ Label generation complete - X parts labeled"
puts "      UID: \"ANC-XXXX-XXX\""
puts "   6. Export PDF"
puts "   7. Check for Part Code + QR columns"
puts "\n⚠️  IMPORTANT: You MUST click 'Process' to run fresh nesting!"
puts "="*80

