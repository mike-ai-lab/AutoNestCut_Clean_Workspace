# Test script to verify material database HTML path resolution

# Simulate the path resolution
ui_dir = File.expand_path(File.join(__dir__, 'AutoNestCut', 'ui'))
html_path = File.join(ui_dir, 'html', 'material_database.html')

puts "="*80
puts "MATERIAL DATABASE PATH TEST"
puts "="*80
puts "UI Directory: #{ui_dir}"
puts "HTML Path: #{html_path}"
puts "File exists: #{File.exist?(html_path)}"
puts "="*80

if File.exist?(html_path)
  puts "✅ SUCCESS: HTML file found at correct location"
  puts "\nFile size: #{File.size(html_path)} bytes"
  puts "First 100 chars:"
  puts File.read(html_path)[0..100]
else
  puts "❌ ERROR: HTML file not found!"
  puts "\nSearching for material_database.html..."
  
  # Search for the file
  Dir.glob("**/material_database.html").each do |found_path|
    puts "  Found at: #{found_path}"
  end
end
