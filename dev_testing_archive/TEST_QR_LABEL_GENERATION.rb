# frozen_string_literal: true

# ==============================================================================
# TEST: Real QR Code Generation in Labels
# ==============================================================================
# This test verifies that:
# 1. QR codes are generated using RQRCode gem (not placeholders)
# 2. QR codes contain readable multi-line text format
# 3. Labels can be embedded in SVG diagrams
# 4. Label sheet generator produces scannable QR codes
# ==============================================================================

puts "\n" + "="*80
puts "TEST: Real QR Code Generation in Labels"
puts "="*80

# Test 1: Verify RQRCode gem is available
puts "\n[TEST 1] Checking RQRCode gem availability..."
begin
  require 'rqrcode'
  puts "✓ RQRCode gem is loaded and available"
  puts "  Version: #{RQRCode::VERSION rescue 'unknown'}"
rescue LoadError => e
  puts "✗ FAILED: RQRCode gem not available: #{e.message}"
  puts "  Please ensure Extension/vendor/rqrcode is present"
  exit
end

# Test 2: Test QRCodeGenerator with real data
puts "\n[TEST 2] Testing QRCodeGenerator with real part data..."
begin
  require_relative 'Extension/AutoNestCut/exporters/qr_code_generator'
  
  generator = AutoNestCut::QRCodeGenerator.new
  
  test_part = {
    part_id: 'ANC-001-A',
    name: 'Cabinet Side Panel',
    width: 600.0,
    height: 800.0,
    thickness: 18.0,
    material: 'Plywood 18mm',
    board_number: 1
  }
  
  qr_svg = generator.generate_qr_code(test_part, size: 30)
  
  if qr_svg && qr_svg.include?('<svg') && qr_svg.include?('<rect')
    puts "✓ QR code SVG generated successfully"
    puts "  Size: #{qr_svg.length} characters"
    
    # Check if it's a real QR code (not placeholder)
    if qr_svg.include?('Finder patterns')
      puts "  ⚠️  WARNING: This appears to be a placeholder QR code"
    else
      puts "  ✓ This appears to be a REAL QR code (no placeholder markers)"
    end
    
    # Verify data format
    encoded_data = generator.encode_part_data(test_part)
    puts "\n  Encoded data format:"
    encoded_data.split("\n").each { |line| puts "    #{line}" }
    
  else
    puts "✗ FAILED: QR code generation failed or returned invalid SVG"
  end
  
rescue => e
  puts "✗ FAILED: #{e.message}"
  puts "  #{e.backtrace.first(3).join("\n  ")}"
end

# Test 3: Test LabelGenerator integration
puts "\n[TEST 3] Testing LabelGenerator with QR codes..."
begin
  require_relative 'Extension/AutoNestCut/exporters/label_generator'
  
  label_gen = AutoNestCut::LabelGenerator.new(qr_enabled: true, qr_size: 25)
  
  test_part = {
    part_id: 'ANC-002-B',
    name: 'Shelf Board',
    width: 400.0,
    height: 300.0,
    thickness: 18.0,
    material: 'MDF 18mm',
    board_number: 2
  }
  
  part_dimensions = { width: 400, height: 300 }
  
  label_svg = label_gen.generate_label(test_part, part_dimensions)
  
  if label_svg && label_svg.include?('<g class="part-label"')
    puts "✓ Label SVG generated successfully"
    puts "  Size: #{label_svg.length} characters"
    
    # Check if QR code is embedded
    if label_svg.include?('<svg x=')
      puts "  ✓ QR code is embedded in label"
    else
      puts "  ⚠️  WARNING: QR code might not be properly embedded"
    end
    
    # Check for text content
    if label_svg.include?('ANC-002-B')
      puts "  ✓ Part ID is present in label"
    end
    
  else
    puts "✗ FAILED: Label generation failed"
  end
  
rescue => e
  puts "✗ FAILED: #{e.message}"
  puts "  #{e.backtrace.first(3).join("\n  ")}"
end

# Test 4: Test LabelSheetGenerator (already working)
puts "\n[TEST 4] Testing LabelSheetGenerator (PDF with QR codes)..."
begin
  require_relative 'Extension/AutoNestCut/exporters/label_sheet_generator'
  
  test_parts = [
    {
      part_id: 'ANC-001',
      name: 'Test Part 1',
      width: 600.0,
      height: 800.0,
      thickness: 18.0,
      material: 'Plywood',
      board_number: 1
    },
    {
      part_id: 'ANC-002',
      name: 'Test Part 2',
      width: 400.0,
      height: 300.0,
      thickness: 18.0,
      material: 'MDF',
      board_number: 1
    }
  ]
  
  generator = AutoNestCut::LabelSheetGenerator.new('custom')
  output_path = generator.generate_label_sheet(test_parts, nil, false) # No preview
  
  if File.exist?(output_path)
    file_size = File.size(output_path)
    puts "✓ Label sheet PDF generated successfully"
    puts "  Path: #{output_path}"
    puts "  Size: #{file_size} bytes"
    puts "\n  📱 SCAN TEST: Open this PDF and scan the QR codes with your phone!"
    puts "  Expected data format:"
    puts "    PART: ANC-001"
    puts "    NAME: Test Part 1"
    puts "    SIZE: 600.0 x 800.0 x 18.0mm"
    puts "    MATERIAL: Plywood"
    puts "    BOARD: #1"
  else
    puts "✗ FAILED: PDF file not created"
  end
  
rescue => e
  puts "✗ FAILED: #{e.message}"
  puts "  #{e.backtrace.first(3).join("\n  ")}"
end

puts "\n" + "="*80
puts "TEST COMPLETE"
puts "="*80
puts "\nNext Steps:"
puts "1. Load this test in SketchUp Ruby Console"
puts "2. Check console output for any failures"
puts "3. Open the generated PDF (path shown above)"
puts "4. Scan QR codes with your phone to verify data"
puts "5. Generate a real report and verify QR codes match part data"
puts "="*80
