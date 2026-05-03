# Debug module loading to see what's happening
# Run in SketchUp Ruby Console

puts "\n🔍 DEBUG MODULE LOADING"
puts "="*80

# Remove existing
if defined?(AutoNestCut)
  Object.send(:remove_const, :AutoNestCut)
  puts "✓ Removed existing AutoNestCut"
end

workspace = 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace'

# Manually define the module and load files one by one
module AutoNestCut
  puts "  → AutoNestCut module defined"
end

puts "\n📦 Loading files manually..."

base = File.join(workspace, 'Extension', 'AutoNestCut')

# Load label_generator directly
label_gen_path = File.join(base, 'processors', 'label_generator.rb')

puts "\n1️⃣ Loading label_generator.rb..."
puts "   Path: #{label_gen_path}"
puts "   Exists: #{File.exist?(label_gen_path)}"

begin
  load label_gen_path
  puts "   ✓ File loaded without error"
  
  if defined?(AutoNestCut::LabelGenerator)
    puts "   ✅ LabelGenerator class IS defined!"
    puts "   ✅ Class methods: #{AutoNestCut::LabelGenerator.methods(false).join(', ')}"
  else
    puts "   ❌ LabelGenerator class NOT defined"
    puts "   Available in AutoNestCut: #{AutoNestCut.constants.join(', ')}"
  end
rescue => e
  puts "   ❌ ERROR: #{e.message}"
  puts "   #{e.backtrace.first(5).join("\n   ")}"
end

puts "\n" + "="*80

