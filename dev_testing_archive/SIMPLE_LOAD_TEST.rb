# Simple test to load LabelGenerator
# Run this in SketchUp Ruby Console

puts "\n🧪 SIMPLE LOAD TEST"

# Remove existing module
if defined?(AutoNestCut)
  Object.send(:remove_const, :AutoNestCut)
  puts "✓ Removed existing module"
end

# Load main.rb from workspace
workspace = 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace'
main_path = File.join(workspace, 'Extension', 'AutoNestCut', 'main.rb')

puts "Loading from: #{main_path}"

begin
  load main_path
  puts "✓ Loaded main.rb"
  
  if defined?(AutoNestCut::LabelGenerator)
    puts "✅ LabelGenerator IS LOADED!"
  else
    puts "❌ LabelGenerator NOT LOADED"
    puts "Available constants: #{AutoNestCut.constants.sort.join(', ')}"
  end
rescue => e
  puts "❌ ERROR: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

