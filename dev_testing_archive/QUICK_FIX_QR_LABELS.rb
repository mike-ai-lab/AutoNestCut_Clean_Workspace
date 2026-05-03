# QUICK FIX: Force Fresh Nesting for QR Labels
# Run this in SketchUp Ruby Console

puts "\n" + "="*80
puts "🏷️  QR LABELS QUICK FIX"
puts "="*80

# Step 1: Reload the extension to load LabelGenerator
puts "\n1️⃣  Reloading extension..."
if defined?(AutoNestCut)
  Object.send(:remove_const, :AutoNestCut)
  puts "   ✓ Removed old module"
end

extension_path = File.join(__dir__, 'Extension', 'AutoNestCut', 'main.rb')
load extension_path
puts "   ✓ Extension reloaded"

# Step 2: Verify LabelGenerator is loaded
if defined?(AutoNestCut::LabelGenerator)
  puts "   ✅ LabelGenerator is now loaded!"
else
  puts "   ❌ LabelGenerator still not loaded - check main.rb"
  exit
end

# Step 3: Clear the cache
puts "\n2️⃣  Clearing component cache..."
if defined?(AutoNestCut::ComponentCache)
  AutoNestCut::ComponentCache.clear_cache
  puts "   ✅ Cache cleared!"
else
  puts "   ⚠️  ComponentCache not found (this is OK)"
end

# Step 4: Enable the feature
puts "\n3️⃣  Enabling QR labels feature..."
AutoNestCut::Config.save_global_settings({'enable_part_labels' => true})
settings = AutoNestCut::Config.get_cached_settings
if settings['enable_part_labels']
  puts "   ✅ Feature enabled!"
else
  puts "   ❌ Feature not enabled - check config"
end

puts "\n" + "="*80
puts "✅ SETUP COMPLETE!"
puts "="*80
puts "\n📋 NEXT STEPS:"
puts "   1. Close the AutoNestCut dialog if it's open"
puts "   2. Select your components in SketchUp"
puts "   3. Run AutoNestCut from the menu"
puts "   4. Click 'Process' to run fresh nesting"
puts "   5. Watch the Ruby Console for label generation messages"
puts "   6. Export PDF and check for QR codes"
puts "\n⚠️  IMPORTANT: Do NOT use cached results!"
puts "   You must run fresh nesting (click Process button)"
puts "="*80

