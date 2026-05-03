# Quick QR Code Test - Run this in SketchUp Ruby Console
# Copy and paste this entire code into the console

puts "\n" + "="*80
puts "QUICK QR CODE TEST"
puts "="*80

# Test 1: Check if RQRCode is available
puts "\n[1] Checking RQRCode gem..."
begin
  require 'rqrcode'
  puts "✓ RQRCode loaded"
  puts "  Version: #{RQRCode::VERSION rescue 'unknown'}"
rescue LoadError => e
  puts "✗ FAILED: #{e.message}"
  puts "\nSOLUTION: The RQRCode gem is not loaded."
  puts "This should be loaded by label_sheet_generator.rb"
  puts "Try reloading the extension first."
  exit
end

# Test 2: Generate a simple QR code
puts "\n[2] Generating test QR code..."
begin
  test_data = "HELLO WORLD"
  qr = RQRCode::QRCode.new(test_data, level: :m)
  puts "✓ QR code generated"
  puts "  Modules: #{qr.modules.size}x#{qr.modules.size}"
  puts "  Data: '#{test_data}'"
rescue => e
  puts "✗ FAILED: #{e.message}"
  puts "  #{e.backtrace.first(3).join("\n  ")}"
  exit
end

# Test 3: Generate QR with part data format
puts "\n[3] Testing with part data format..."
begin
  part_data = "PART: TEST-001\nNAME: Test Part\nSIZE: 600.0 x 800.0 x 18.0mm"
  qr = RQRCode::QRCode.new(part_data, level: :m)
  puts "✓ Part data QR generated"
  puts "  Modules: #{qr.modules.size}x#{qr.modules.size}"
  puts "  Data length: #{part_data.length} characters"
  puts "\n  Data content:"
  part_data.split("\n").each { |line| puts "    #{line}" }
rescue => e
  puts "✗ FAILED: #{e.message}"
  puts "  This might mean the data is too long for QR code"
  exit
end

# Test 4: Generate a minimal test PDF
puts "\n[4] Generating test PDF with QR code..."
begin
  require 'prawn'
  require 'tmpdir'
  
  output_path = File.join(Dir.tmpdir, "qr_test_#{Time.now.to_i}.pdf")
  
  Prawn::Document.generate(output_path, page_size: 'A4') do |pdf|
    pdf.text "QR Code Test", size: 20, style: :bold
    pdf.move_down 20
    
    # Test with simple data first
    simple_data = "TEST123"
    qr = RQRCode::QRCode.new(simple_data, level: :m)
    
    pdf.text "Simple QR (should scan as: #{simple_data})", size: 12
    pdf.move_down 10
    
    # Draw QR code
    x = 50
    y = pdf.cursor
    size = 100 # 100pt square
    module_size = size / qr.modules.size.to_f
    
    pdf.fill_color '000000'
    qr.modules.each_with_index do |row, row_index|
      row.each_with_index do |col, col_index|
        if col
          rect_x = x + (col_index * module_size)
          rect_y = y - (row_index * module_size)
          pdf.fill_rectangle [rect_x, rect_y], module_size, module_size
        end
      end
    end
    
    pdf.move_down 120
    
    # Test with part data
    part_data = "PART: TEST-001\nNAME: Test Part\nSIZE: 600 x 800 x 18mm"
    qr2 = RQRCode::QRCode.new(part_data, level: :m)
    
    pdf.text "Part Data QR (multi-line):", size: 12
    pdf.move_down 10
    
    x2 = 50
    y2 = pdf.cursor
    size2 = 100
    module_size2 = size2 / qr2.modules.size.to_f
    
    pdf.fill_color '000000'
    qr2.modules.each_with_index do |row, row_index|
      row.each_with_index do |col, col_index|
        if col
          rect_x = x2 + (col_index * module_size2)
          rect_y = y2 - (row_index * module_size2)
          pdf.fill_rectangle [rect_x, rect_y], module_size2, module_size2
        end
      end
    end
    
    pdf.move_down 120
    pdf.text "Expected data:", size: 10
    part_data.split("\n").each do |line|
      pdf.text "  #{line}", size: 9
    end
  end
  
  puts "✓ PDF generated successfully"
  puts "\n📄 PDF PATH:"
  puts "  #{output_path}"
  puts "\n📱 SCAN TEST:"
  puts "  1. Open the PDF above"
  puts "  2. Scan the FIRST QR code - should show: TEST123"
  puts "  3. Scan the SECOND QR code - should show part data"
  puts "\n  If first QR works but second doesn't, the data might be too long"
  
rescue => e
  puts "✗ FAILED: #{e.message}"
  puts "  #{e.backtrace.first(5).join("\n  ")}"
end

puts "\n" + "="*80
puts "TEST COMPLETE"
puts "="*80
