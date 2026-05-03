# Simple test for Material Database Manager
# Run this AFTER the extension is already loaded in SketchUp

puts "=" * 60
puts "TESTING MATERIAL DATABASE MANAGER"
puts "=" * 60

# Just open the dialog using the menu method
AutoNestCut.show_material_database

puts "\n✓ Material Database Manager opened"
puts "\nTEST ALL DIALOGS:"
puts "1. Add Material → SketchUp inputbox"
puts "2. Delete Material → SketchUp confirmation"
puts "3. Refresh with changes → SketchUp warning"
puts "4. All should work WITHOUT DevTools"
puts "=" * 60
