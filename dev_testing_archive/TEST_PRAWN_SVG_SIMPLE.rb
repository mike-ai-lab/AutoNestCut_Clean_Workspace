# Simple test to verify prawn-svg loads correctly

puts "="*80
puts "Testing prawn-svg loading..."
puts "="*80

begin
  require 'prawn'
  puts "✓ Prawn loaded"
  
  require 'prawn-svg'
  puts "✓ Prawn-SVG loaded successfully!"
  puts "  Version: #{Prawn::Svg::VERSION}" if defined?(Prawn::Svg::VERSION)
  
  # Test creating a simple PDF with SVG
  require 'tmpdir'
  test_pdf = File.join(Dir.tmpdir, "test_svg_#{Time.now.to_i}.pdf")
  
  Prawn::Document.generate(test_pdf) do |pdf|
    pdf.text "Testing SVG Support", size: 20
    pdf.move_down 20
    
    # Simple SVG test
    svg_data = '<svg width="100" height="100"><circle cx="50" cy="50" r="40" fill="blue"/></svg>'
    pdf.svg svg_data, at: [100, 500], width: 100
    
    pdf.text "If you see a blue circle above, SVG works!", size: 12
  end
  
  puts "✓ Test PDF created: #{test_pdf}"
  puts "✓ prawn-svg is working correctly!"
  
rescue LoadError => e
  puts "✗ Error loading: #{e.message}"
  puts "  Backtrace: #{e.backtrace.first(3).join("\n  ")}"
rescue => e
  puts "✗ Error: #{e.message}"
  puts "  Backtrace: #{e.backtrace.first(5).join("\n  ")}"
end

puts "="*80
