# Test script to verify C++ nester integration
# Run this in SketchUp Ruby Console to test

require_relative 'processors/cpp_nester'
require_relative 'processors/nester'
require_relative 'models/board'
require_relative 'models/part'

puts "\n" + "="*80
puts "Testing C++ Nester Integration"
puts "="*80

# Check if C++ solver is available
if AutoNestCut::CppNester.available?
  puts "✓ C++ solver found!"
else
  puts "✗ C++ solver NOT found - will use Ruby fallback"
  puts "  Expected location: #{File.join(__dir__, 'cpp', 'nester.exe')}"
end

puts "="*80
puts "\nIntegration test complete!"
puts "The extension will automatically use C++ solver if available."
puts "="*80
