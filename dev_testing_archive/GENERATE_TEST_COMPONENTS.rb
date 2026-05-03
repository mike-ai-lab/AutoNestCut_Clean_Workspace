# Quick Test Component Generator Loader
# This script can be run from the Open Toolbar to generate test components with edge-banding properties

# Load the test generator if not already loaded
test_generator_path = File.join(File.dirname(__FILE__), 'Extension', 'AutoNestCut', 'test_edge_banding_generator.rb')

if File.exist?(test_generator_path)
  load test_generator_path
  
  # Generate test components immediately
  if defined?(AutoNestCut::TestEdgeBandingGenerator)
    AutoNestCut::TestEdgeBandingGenerator.generate_test_components
    puts "Test components with edge banding properties have been generated!"
    puts "You can now test the AutoNestCut extension with these components."
  else
    puts "Error: TestEdgeBandingGenerator class not found"
  end
else
  puts "Error: Test generator file not found at #{test_generator_path}"
end