# frozen_string_literal: true

# Test script for QR Code Generator
# Load this in SketchUp Ruby Console to test QR code generation

require_relative 'exporters/qr_code_generator'

module AutoNestCut
  module QRCodeTest
    
    def self.run_tests
      puts "\n" + "="*80
      puts "QR CODE GENERATOR - TEST SUITE"
      puts "="*80
      
      generator = QRCodeGenerator.new
      
      # Test 1: Basic QR code generation
      puts "\n[TEST 1] Basic QR Code Generation"
      test_part_data = {
        part_id: 'P27',
        name: 'Cabinet Side Panel',
        material: 'Plywood 18mm',
        width: 600,
        height: 800,
        thickness: 18,
        board_number: 1
      }
      
      svg = generator.generate_qr_code(test_part_data, size: 30)
      
      if svg && svg.include?('<svg')
        puts "✓ QR code generated successfully"
        puts "  SVG length: #{svg.length} characters"
      else
        puts "✗ QR code generation failed"
        return false
      end
      
      # Test 2: Data encoding
      puts "\n[TEST 2] Part Data Encoding"
      json_data = generator.encode_part_data(test_part_data)
      parsed = JSON.parse(json_data)
      
      if parsed['id'] == 'P27' && parsed['n'] == 'Cabinet Side Panel'
        puts "✓ Data encoding successful"
        puts "  JSON: #{json_data}"
      else
        puts "✗ Data encoding failed"
        return false
      end
      
      # Test 3: Cache functionality
      puts "\n[TEST 3] Cache Functionality"
      QRCodeGenerator.clear_cache
      
      # Generate same QR code twice
      svg1 = generator.generate_qr_code(test_part_data, size: 30)
      svg2 = generator.generate_qr_code(test_part_data, size: 30)
      
      stats = QRCodeGenerator.cache_stats
      if stats[:size] == 1
        puts "✓ Cache working correctly"
        puts "  Cache size: #{stats[:size]}"
      else
        puts "✗ Cache not working"
        return false
      end
      
      # Test 4: Different sizes
      puts "\n[TEST 4] Different QR Code Sizes"
      sizes = [20, 30, 40, 50]
      sizes.each do |size|
        svg = generator.generate_qr_code(test_part_data, size: size)
        if svg.include?("width=\"#{size}mm\"")
          puts "✓ Size #{size}mm generated correctly"
        else
          puts "✗ Size #{size}mm failed"
          return false
        end
      end
      
      # Test 5: Multiple parts
      puts "\n[TEST 5] Multiple Parts Generation"
      parts = [
        { part_id: 'P1', name: 'Part 1', material: 'MDF', width: 500, height: 600, thickness: 18, board_number: 1 },
        { part_id: 'P2', name: 'Part 2', material: 'Plywood', width: 700, height: 800, thickness: 18, board_number: 1 },
        { part_id: 'P3', name: 'Part 3', material: 'Melamine', width: 400, height: 500, thickness: 16, board_number: 2 }
      ]
      
      parts.each do |part|
        svg = generator.generate_qr_code(part, size: 30)
        if svg && svg.include?('<svg')
          puts "✓ #{part[:part_id]} generated"
        else
          puts "✗ #{part[:part_id]} failed"
          return false
        end
      end
      
      stats = QRCodeGenerator.cache_stats
      puts "  Total cached: #{stats[:size]} QR codes"
      
      # Test 6: Save QR code to file
      puts "\n[TEST 6] Save QR Code to File"
      svg = generator.generate_qr_code(test_part_data, size: 50)
      test_file = File.join(Dir.tmpdir, 'test_qr_code.svg')
      
      begin
        File.write(test_file, svg)
        if File.exist?(test_file)
          puts "✓ QR code saved to: #{test_file}"
          puts "  File size: #{File.size(test_file)} bytes"
        else
          puts "✗ Failed to save QR code"
          return false
        end
      rescue => e
        puts "✗ Error saving file: #{e.message}"
        return false
      end
      
      puts "\n" + "="*80
      puts "ALL TESTS PASSED ✓"
      puts "="*80
      puts "\nQR Code Generator is ready for integration!"
      puts "Test file saved at: #{test_file}"
      puts "\nNext steps:"
      puts "1. Open #{test_file} in a browser to view the QR code"
      puts "2. Scan with a QR scanner app to verify data"
      puts "3. Proceed to label generator implementation"
      
      true
    end
    
  end
end

# Auto-run tests when loaded
AutoNestCut::QRCodeTest.run_tests
