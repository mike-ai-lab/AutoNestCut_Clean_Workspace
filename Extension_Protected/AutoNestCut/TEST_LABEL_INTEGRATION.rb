# TEST_LABEL_INTEGRATION.rb
# Comprehensive test for QR Code & Label Sheet integration

module AutoNestCut
  
  def self.test_label_integration
    puts "\n" + "="*80
    puts "TESTING: QR Code & Label Sheet Integration"
    puts "="*80
    
    # Test 1: Verify label sheet generator exists
    puts "\n[TEST 1] Checking if LabelSheetGenerator exists..."
    begin
      require_relative 'exporters/label_sheet_generator'
      puts "✓ LabelSheetGenerator loaded successfully"
    rescue => e
      puts "✗ FAILED: #{e.message}"
      return false
    end
    
    # Test 2: Create sample parts data
    puts "\n[TEST 2] Creating sample parts data..."
    sample_parts = [
      {
        id: "P1",
        name: "Cabinet Side Panel",
        dimensions: "600×800×18",
        material: "Plywood 18mm",
        board_number: 1
      },
      {
        id: "P2",
        name: "Shelf",
        dimensions: "400×300×18",
        material: "Plywood 18mm",
        board_number: 1
      },
      {
        id: "P3",
        name: "Back Panel",
        dimensions: "800×600×6",
        material: "MDF 6mm",
        board_number: 2
      }
    ]
    puts "✓ Created #{sample_parts.length} sample parts"
    
    # Test 3: Generate label sheet
    puts "\n[TEST 3] Generating label sheet PDF..."
    begin
      generator = LabelSheetGenerator.new
      
      # Get temp directory
      temp_dir = ENV['TEMP'] || ENV['TMP'] || '/tmp'
      output_path = File.join(temp_dir, "AutoNestCut_Test_Labels_#{Time.now.to_i}.pdf")
      
      # Generate with default settings
      settings = {
        'label_settings' => {
          'format' => 'avery_5160'
        }
      }
      
      generator.generate(output_path, sample_parts, settings)
      
      if File.exist?(output_path)
        puts "✓ Label sheet generated successfully!"
        puts "  Location: #{output_path}"
        puts "  File size: #{File.size(output_path)} bytes"
        
        # Open the file
        if Sketchup.platform == :platform_win
          system("start \"\" \"#{output_path}\"")
        else
          system("open \"#{output_path}\"")
        end
        
        return true
      else
        puts "✗ FAILED: PDF file was not created"
        return false
      end
    rescue => e
      puts "✗ FAILED: #{e.message}"
      puts e.backtrace.join("\n")
      return false
    end
  end
  
  def self.test_ui_integration
    puts "\n" + "="*80
    puts "TESTING: UI Integration"
    puts "="*80
    
    puts "\n[INFO] To test UI integration:"
    puts "1. Open the AutoNestCut extension"
    puts "2. Generate a cut list"
    puts "3. Go to the Report tab"
    puts "4. Look for the 'Export Label Sheet (QR Codes)' button"
    puts "5. Click it to generate a label sheet"
    puts "\nThe button should appear alongside other export buttons (CSV, PDF, HTML)"
  end
  
end

# Run tests
puts "\n🏆 STARTING COMPREHENSIVE INTEGRATION TESTS"
puts "="*80

success = AutoNestCut.test_label_integration

if success
  puts "\n" + "="*80
  puts "✓ ALL TESTS PASSED!"
  puts "="*80
  AutoNestCut.test_ui_integration
else
  puts "\n" + "="*80
  puts "✗ SOME TESTS FAILED"
  puts "="*80
end
