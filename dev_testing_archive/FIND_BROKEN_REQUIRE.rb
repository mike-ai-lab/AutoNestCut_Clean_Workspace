# Find which require is breaking the load chain
# Run this in SketchUp Ruby Console

puts "\n🔍 FINDING BROKEN REQUIRE"
puts "="*80

# Remove existing module
if defined?(AutoNestCut)
  Object.send(:remove_const, :AutoNestCut)
end

workspace = 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace'
base_path = File.join(workspace, 'Extension', 'AutoNestCut')

# List of files in order they're required in main.rb
files_to_test = [
  'compatibility',
  'materials_database',
  'config',
  'models/part',
  'models/board',
  'models/facade_surface',
  'models/cladding_preset',
  'processors/model_analyzer',
  'processors/nester',
  'processors/facade_analyzer',
  'processors/component_cache',
  'processors/label_generator'
]

puts "Testing each require in order...\n"

module AutoNestCut
  PATH_ROOT = File.dirname(__FILE__).freeze
end

files_to_test.each do |file|
  full_path = File.join(base_path, "#{file}.rb")
  
  begin
    require full_path
    puts "✅ #{file}"
  rescue => e
    puts "❌ #{file}"
    puts "   ERROR: #{e.message}"
    puts "   #{e.backtrace.first(3).join("\n   ")}"
    puts "\n⚠️  THIS IS THE BROKEN FILE! Fix this first."
    break
  end
end

puts "\n" + "="*80
puts "Checking what got loaded..."

if defined?(AutoNestCut::LabelGenerator)
  puts "✅ LabelGenerator is loaded!"
else
  puts "❌ LabelGenerator not loaded"
  puts "Available: #{AutoNestCut.constants.sort.join(', ')}"
end

