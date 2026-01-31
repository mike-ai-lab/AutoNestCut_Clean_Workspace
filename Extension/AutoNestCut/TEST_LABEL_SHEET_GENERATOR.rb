# frozen_string_literal: true

# Test script for Label Sheet Generator
# Load this in SketchUp Ruby Console to test label sheet PDF generation

require_relative 'exporters/label_sheet_generator'

module AutoNestCut
  module LabelSheetTest
    
    def self.run_tests
      puts "\n" + "="*80
      puts "LABEL SHEET GENERATOR - TEST SUITE"
      puts "="*80
      
      # Test 1: Generate label sheet with sample parts
      puts "\n[TEST 1] Generate Label Sheet PDF"
      
      # Sample parts data
      parts = [
        { part_id: 'P1', name: 'Top Panel', width: 800, height: 600, thickness: 18, board_number: 1 },
        { part_id: 'P2', name: 'Side Panel Left', width: 600, height: 800, thickness: 18, board_number: 1 },
        { part_id: 'P3', name: 'Side Panel Right', width: 600, height: 800, thickness: 18, board_number: 1 },
        { part_id: 'P4', name: 'Bottom Panel', width: 800, height: 600, thickness: 18, board_number: 2 },
        { part_id: 'P5', name: 'Back Panel', width: 800, height: 800, thickness: 12, board_number: 2 },
        { part_id: 'P6', name: 'Shelf 1', width: 780, height: 580, thickness: 18, board_number: 2 },
        { part_id: 'P7', name: 'Shelf 2', width: 780, height: 580, thickness: 18, board_number: 3 },
        { part_id: 'P8', name: 'Shelf 3', width: 780, height: 580, thickness: 18, board_number: 3 },
        { part_id: 'P9', name: 'Door Left', width: 400, height: 780, thickness: 18, board_number: 3 },
        { part_id: 'P10', name: 'Door Right', width: 400, height: 780, thickness: 18, board_number: 3 },
        { part_id: 'P11', name: 'Drawer Front 1', width: 780, height: 150, thickness: 18, board_number: 4 },
        { part_id: 'P12', name: 'Drawer Front 2', width: 780, height: 150, thickness: 18, board_number: 4 }
      ]
      
      generator = LabelSheetGenerator.new('custom')
      output_path = generator.generate_label_sheet(parts)
      
      if File.exist?(output_path)
        puts "✓ Label sheet PDF generated successfully"
        puts "  File: #{output_path}"
        puts "  Size: #{File.size(output_path)} bytes"
      else
        puts "✗ Label sheet generation failed"
        return false
      end
      
      # Test 2: Different formats
      puts "\n[TEST 2] Test Different Label Formats"
      formats = ['avery_5160', 'avery_5163', 'avery_5164', 'custom']
      
      formats.each do |format|
        generator = LabelSheetGenerator.new(format)
        output = generator.generate_label_sheet(parts.take(6))  # Just 6 parts for quick test
        
        if File.exist?(output)
          puts "✓ Format '#{format}' generated"
          File.delete(output)  # Clean up test files
        else
          puts "✗ Format '#{format}' failed"
          return false
        end
      end
      
      # Test 3: Large number of parts (multiple pages)
      puts "\n[TEST 3] Multiple Pages Test"
      large_parts_list = []
      30.times do |i|
        large_parts_list << {
          part_id: "P#{i+1}",
          name: "Part #{i+1}",
          width: 500 + (i * 10),
          height: 400 + (i * 5),
          thickness: 18,
          board_number: (i / 10) + 1
        }
      end
      
      generator = LabelSheetGenerator.new('custom')
      output = generator.generate_label_sheet(large_parts_list)
      
      if File.exist?(output)
        puts "✓ Multi-page label sheet generated (30 parts)"
        puts "  File: #{output}"
        File.delete(output)  # Clean up
      else
        puts "✗ Multi-page generation failed"
        return false
      end
      
      puts "\n" + "="*80
      puts "ALL TESTS PASSED ✓"
      puts "="*80
      puts "\nLabel Sheet Generator is ready!"
      puts "Final test file saved at: #{output_path}"
      puts "\nNext steps:"
      puts "1. Open #{output_path} in a PDF viewer"
      puts "2. Verify labels are properly formatted"
      puts "3. Print on label sheets (Avery 5160 or similar)"
      puts "4. Integrate with main extension"
      
      true
    end
    
  end
end

# Auto-run tests when loaded
AutoNestCut::LabelSheetTest.run_tests
