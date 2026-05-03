# Diagnose why LabelGenerator is not loading

puts "\n" + "="*80
puts "🔍 DIAGNOSING LABEL GENERATOR LOAD ISSUE"
puts "="*80

# Set the working directory to workspace root
workspace_root = 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace'
Dir.chdir(workspace_root)

puts "✓ Working directory: #{Dir.pwd}"

# Check if files exist
main_rb = File.join(workspace_root, 'Extension', 'AutoNestCut', 'main.rb')
label_gen = File.join(workspace_root, 'Extension', 'AutoNestCut', 'processors', 'label_generator.rb')

puts "\n📁 FILE CHECKS:"
puts "   main.rb exists: #{File.exist?(main_rb)}"
puts "   main.rb path: #{main_rb}"
puts "   label_generator.rb exists: #{File.exist?(label_gen)}"
puts "   label_generator.rb path: #{label_gen}"

# Try to load label_generator directly
puts "\n🧪 DIRECT LOAD TEST:"
begin
  # Remove existing module first
  if defined?(AutoNestCut)
    Object.send(:remove_const, :AutoNestCut)
    puts "   ✓ Removed existing AutoNestCut module"
  end
  
  # Try to load label_generator directly
  puts "   Attempting to load label_generator.rb directly..."
  load label_gen
  
  if defined?(AutoNestCut::LabelGenerator)
    puts "   ✅ SUCCESS! LabelGenerator loaded directly"
  else
    puts "   ❌ FAILED! LabelGenerator not defined after direct load"
  end
rescue => e
  puts "   ❌ ERROR loading label_generator.rb: #{e.message}"
  puts "   #{e.backtrace.first(3).join("\n   ")}"
end

# Now try loading main.rb
puts "\n🧪 MAIN.RB LOAD TEST:"
begin
  # Remove existing module first
  if defined?(AutoNestCut)
    Object.send(:remove_const, :AutoNestCut)
    puts "   ✓ Removed existing AutoNestCut module"
  end
  
  puts "   Attempting to load main.rb..."
  load main_rb
  
  puts "   ✓ main.rb loaded without errors"
  
  # Check what got loaded
  if defined?(AutoNestCut)
    puts "   ✓ AutoNestCut module defined"
    puts "   ✓ AutoNestCut constants: #{AutoNestCut.constants.length} total"
    
    # Check for specific classes
    has_config = defined?(AutoNestCut::Config)
    has_nester = defined?(AutoNestCut::Nester)
    has_label_gen = defined?(AutoNestCut::LabelGenerator)
    
    puts "\n   📦 MODULE CONTENTS:"
    puts "      Config: #{has_config ? '✅' : '❌'}"
    puts "      Nester: #{has_nester ? '✅' : '❌'}"
    puts "      LabelGenerator: #{has_label_gen ? '✅' : '❌'}"
    
    if has_label_gen
      puts "\n   ✅ LabelGenerator IS loaded!"
      puts "      Methods: #{AutoNestCut::LabelGenerator.methods(false).sort.join(', ')}"
    else
      puts "\n   ❌ LabelGenerator NOT loaded!"
      puts "\n   🔍 All loaded constants:"
      AutoNestCut.constants.sort.each do |const|
        puts "      - #{const}"
      end
    end
  else
    puts "   ❌ AutoNestCut module NOT defined"
  end
  
rescue => e
  puts "   ❌ ERROR loading main.rb: #{e.message}"
  puts "   #{e.backtrace.first(10).join("\n   ")}"
end

puts "\n" + "="*80
puts "🔍 DIAGNOSIS COMPLETE"
puts "="*80

