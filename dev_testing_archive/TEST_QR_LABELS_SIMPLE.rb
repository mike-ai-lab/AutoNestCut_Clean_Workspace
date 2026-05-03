# Simple QR Labels Test
# Run this in SketchUp Ruby Console to verify the feature is working

puts "\n" + "="*80
puts "🏷️  QR LABELS SIMPLE TEST"
puts "="*80

# Step 1: Check if LabelGenerator is loaded
if defined?(AutoNestCut::LabelGenerator)
  puts "✅ LabelGenerator is loaded"
else
  puts "❌ LabelGenerator NOT loaded - reloading extension..."
  
  # Reload extension
  if defined?(AutoNestCut)
    Object.send(:remove_const, :AutoNestCut)
  end
  
  extension_path = File.join(__dir__, 'Extension', 'AutoNestCut', 'main.rb')
  load extension_path
  
  if defined?(AutoNestCut::LabelGenerator)
    puts "✅ LabelGenerator loaded after reload"
  else
    puts "❌ FAILED to load LabelGenerator"
    puts "   Check Extension/AutoNestCut/main.rb line 30"
    exit
  end
end

# Step 2: Check feature flag
settings = AutoNestCut::Config.get_cached_settings
if settings['enable_part_labels']
  puts "✅ Feature is enabled"
else
  puts "⚠️  Feature is disabled - enabling now..."
  AutoNestCut::Config.save_global_settings({'enable_part_labels' => true})
  puts "✅ Feature enabled"
end

# Step 3: Clear cache
puts "\n🗑️  Clearing cache..."
AutoNestCut::ComponentCache.clear_cache
puts "✅ Cache cleared"

puts "\n" + "="*80
puts "✅ ALL CHECKS PASSED!"
puts "="*80
puts "\n📋 NEXT STEPS:"
puts "   1. Close AutoNestCut dialog if open"
puts "   2. Select components in SketchUp"
puts "   3. Run AutoNestCut from menu"
puts "   4. Click 'Process' button"
puts "   5. Watch console for these messages:"
puts "      🏷️ LABEL GENERATION CHECK:"
puts "      🏷️ Calling LabelGenerator.generate_labels..."
puts "      ✅ Label generation complete - X parts labeled"
puts "      UID: \"ANC-XXXX-XXX\""
puts "   6. Export PDF and check for Part Code + QR columns"
puts "\n⚠️  CRITICAL: You MUST click 'Process' to run fresh nesting!"
puts "   Do NOT use cached results!"
puts "="*80

