# Diagnostic script to find where the slowness is
# Run this in SketchUp Ruby Console BEFORE clicking optimize

require_relative 'processors/model_analyzer'

puts "\n" + "="*80
puts "DIAGNOSTIC: Testing Analysis Speed"
puts "="*80

selection = Sketchup.active_model.selection

if selection.empty?
  puts "ERROR: No components selected!"
  puts "Please select some components first, then run this script."
else
  puts "Selected entities: #{selection.length}"
  
  puts "\nStarting analysis..."
  start_time = Time.now
  
  analyzer = AutoNestCut::ModelAnalyzer.new
  parts_by_material = analyzer.analyze_selection(selection)
  
  elapsed = Time.now - start_time
  
  puts "\n" + "="*80
  puts "RESULTS:"
  puts "="*80
  puts "Analysis time: #{elapsed.round(2)} seconds"
  puts "Materials found: #{parts_by_material.keys.length}"
  parts_by_material.each do |material, parts|
    total_parts = parts.sum { |p| p[:total_quantity] }
    puts "  - #{material}: #{parts.length} types, #{total_parts} total parts"
  end
  puts "="*80
  
  if elapsed > 5
    puts "\n⚠️  WARNING: Analysis took > 5 seconds!"
    puts "This is the bottleneck, not nesting."
    puts "The C++ solver won't help if analysis is slow."
  elsif elapsed > 1
    puts "\n⚠️  Analysis is a bit slow (> 1 second)"
  else
    puts "\n✓ Analysis speed is good!"
  end
end
