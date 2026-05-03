# Test script for Material Database Manager dialog fixes
# This script tests all dialog interactions to ensure they use SketchUp-style dialogs

puts "=" * 60
puts "TESTING MATERIAL DATABASE MANAGER DIALOGS"
puts "=" * 60

# Simple reload using the existing RELOAD_EXTENSION script
load File.join(__dir__, 'RELOAD_EXTENSION.rb')

puts "\n✓ Extension reloaded"

# Wait for extension to fully load
sleep(0.5)

# Open the Material Database Manager using the public method
begin
  AutoNestCut.show_material_database
  puts "\n✓ Material Database Manager opened"
rescue => e
  puts "\n✗ ERROR: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts "\nTEST INSTRUCTIONS:"
puts "1. Click 'Add Material' button"
puts "   → Should show SketchUp inputbox (NOT Chrome prompt)"
puts "   → Enter a material name and click OK"
puts "   → Material should be added to the table"
puts ""
puts "2. Try to add a duplicate material"
puts "   → Should show SketchUp messagebox error (NOT Chrome alert)"
puts ""
puts "3. Click 'Delete' button on any material"
puts "   → Should show SketchUp messagebox confirmation (NOT Chrome confirm)"
puts "   → Click Yes to delete"
puts ""
puts "4. Make changes and click 'Refresh'"
puts "   → Should show SketchUp messagebox warning (NOT Chrome confirm)"
puts "   → Click Yes to refresh"
puts ""
puts "5. All dialogs should work WITHOUT DevTools open"
puts ""
puts "=" * 60
puts "If all dialogs are SketchUp-style, the fix is complete!"
puts "=" * 60
