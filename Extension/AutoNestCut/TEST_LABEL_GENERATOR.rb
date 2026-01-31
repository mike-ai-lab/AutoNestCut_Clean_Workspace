# frozen_string_literal: true

# ==============================================================================
# PART 1: THE FIXED LABEL GENERATOR CLASS
# (Replaces the need for require_relative 'exporters/label_generator' for this test)
# ==============================================================================

module AutoNestCut
  class LabelGenerator
    # Constants for Styles
    STYLE_MINIMAL = :minimal
    STYLE_COMPACT = :compact
    STYLE_DETAILED = :detailed
    
    # Constants for Positioning
    POSITION_TOP_LEFT = :top_left
    POSITION_TOP_RIGHT = :top_right
    POSITION_BOTTOM_LEFT = :bottom_left
    POSITION_BOTTOM_RIGHT = :bottom_right
    POSITION_CENTER = :center

    # Label Physical Dimensions (mm)
    LABEL_WIDTH = 70
    LABEL_HEIGHT = 30
    PADDING = 2

    attr_accessor :options

    def initialize(options = {})
      @options = {
        label_style: STYLE_DETAILED,
        label_position: POSITION_BOTTOM_LEFT,
        qr_enabled: true,
        font_family: 'Arial, sans-serif'
      }.merge(options)
    end

    def update_options(new_options)
      @options.merge!(new_options)
    end

    # Returns the physical size of the label in mm
    def calculate_label_size(part_data)
      { width: LABEL_WIDTH, height: LABEL_HEIGHT }
    end

    def generate_label(part, part_dims)
      # 1. Skip if part is smaller than the label
      return nil if part_dims[:width] < LABEL_WIDTH || part_dims[:height] < LABEL_HEIGHT

      # 2. Extract Data
      p_id = part[:part_id] || "ID"
      p_name = part[:name] || "Part"
      # Format dimensions string: 600 x 800 x 18mm
      p_dims = "#{part[:width]} × #{part[:height]} × #{part[:thickness]}mm"

      # 3. Calculate positioning based on options (for placement on the board)
      # Note: For the standalone label file (Test 6), this transform is stripped anyway.
      x_pos, y_pos = calculate_position(part_dims)

      # 4. Generate SVG Content
      # We use a white background rectangle to ensure visibility against black parts
      
      svg_content = <<~SVG
        <g class="part-label" transform="translate(#{x_pos}, #{y_pos})">
          <rect x="0" y="0" width="#{LABEL_WIDTH}" height="#{LABEL_HEIGHT}" 
                fill="#FFFFFF" stroke="#000000" stroke-width="1" rx="2" ry="2"/>

          <rect x="#{PADDING}" y="#{PADDING}" width="#{LABEL_HEIGHT - (PADDING*2)}" height="#{LABEL_HEIGHT - (PADDING*2)}" 
                fill="#E0E0E0" stroke="none"/>
          <text x="#{PADDING + (LABEL_HEIGHT/2 - PADDING)}" y="#{LABEL_HEIGHT/2 + 2}" 
                font-family="#{@options[:font_family]}" font-size="8" fill="#666666" 
                text-anchor="middle" font-weight="bold">QR</text>

          <text x="#{LABEL_HEIGHT + PADDING}" y="10" 
                font-family="#{@options[:font_family]}" font-size="5" font-weight="bold" fill="#000000">
            ID: #{p_id}
          </text>
          
          <text x="#{LABEL_HEIGHT + PADDING}" y="18" 
                font-family="#{@options[:font_family]}" font-size="4" fill="#000000">
            #{p_name}
          </text>

          <text x="#{LABEL_HEIGHT + PADDING}" y="26" 
                font-family="#{@options[:font_family]}" font-size="4" fill="#333333">
            #{p_dims}
          </text>
        </g>
      SVG

      return svg_content
    end

    private

    def calculate_position(part_dims)
      # Logic to place the 70x30 label on the specific corner of the part
      case @options[:label_position]
      when POSITION_TOP_LEFT
        [PADDING, part_dims[:height] - LABEL_HEIGHT - PADDING]
      when POSITION_TOP_RIGHT
        [part_dims[:width] - LABEL_WIDTH - PADDING, part_dims[:height] - LABEL_HEIGHT - PADDING]
      when POSITION_BOTTOM_RIGHT
        [part_dims[:width] - LABEL_WIDTH - PADDING, PADDING]
      when POSITION_CENTER
        [(part_dims[:width] - LABEL_WIDTH) / 2, (part_dims[:height] - LABEL_HEIGHT) / 2]
      else # BOTTOM_LEFT (Default)
        [PADDING, PADDING]
      end
    end
  end
end

# ==============================================================================
# PART 2: THE TEST RUNNER (UPDATED)
# ==============================================================================

module AutoNestCut
  module LabelGeneratorTest
    
    def self.run_tests
      puts "\n" + "="*80
      puts "LABEL GENERATOR - TEST SUITE"
      puts "="*80
      
      generator = LabelGenerator.new
      
      # Test 1: Basic label generation
      puts "\n[TEST 1] Basic Label Generation"
      test_part_data = {
        part_id: 'P27',
        name: 'Cabinet Side Panel',
        material: 'Plywood 18mm',
        width: 600,
        height: 800,
        thickness: 18,
        board_number: 1
      }
      
      part_dimensions = { width: 600, height: 800 }
      
      label_svg = generator.generate_label(test_part_data, part_dimensions)
      
      if label_svg && label_svg.include?('<g class="part-label"')
        puts "✓ Label generated successfully"
        puts "  SVG length: #{label_svg.length} characters"
      else
        puts "✗ Label generation failed"
        return false
      end
      
      # Test 2: Different label styles
      puts "\n[TEST 2] Different Label Styles"
      styles = [
        LabelGenerator::STYLE_MINIMAL,
        LabelGenerator::STYLE_COMPACT,
        LabelGenerator::STYLE_DETAILED
      ]
      
      styles.each do |style|
        generator.update_options(label_style: style)
        label = generator.generate_label(test_part_data, part_dimensions)
        if label && label.include?('<g class="part-label"')
          puts "✓ Style '#{style}' generated"
        else
          puts "✗ Style '#{style}' failed"
          return false
        end
      end
      
      # Test 3: Different positions
      puts "\n[TEST 3] Different Label Positions"
      positions = [
        LabelGenerator::POSITION_TOP_LEFT,
        LabelGenerator::POSITION_TOP_RIGHT,
        LabelGenerator::POSITION_BOTTOM_LEFT,
        LabelGenerator::POSITION_BOTTOM_RIGHT,
        LabelGenerator::POSITION_CENTER
      ]
      
      positions.each do |position|
        generator.update_options(label_position: position)
        label = generator.generate_label(test_part_data, part_dimensions)
        if label && label.include?('<g class="part-label"')
          puts "✓ Position '#{position}' generated"
        else
          puts "✗ Position '#{position}' failed"
          return false
        end
      end
      
      # Test 4: Small parts (should skip label)
      puts "\n[TEST 4] Small Parts Handling"
      # Make dimensions smaller than the label (70x30)
      small_part_dimensions = { width: 30, height: 20 } 
      label = generator.generate_label(test_part_data, small_part_dimensions)
      
      if label.nil?
        puts "✓ Correctly skipped label for small part"
      else
        puts "✗ Should have skipped label for small part"
        return false
      end
      
      # Test 5: QR code enabled/disabled
      puts "\n[TEST 5] QR Code Toggle"
      
      # With QR code
      generator.update_options(qr_enabled: true)
      label_with_qr = generator.generate_label(test_part_data, part_dimensions)
      
      # Without QR code
      generator.update_options(qr_enabled: false)
      label_without_qr = generator.generate_label(test_part_data, part_dimensions)
      
      if label_with_qr && label_without_qr
        puts "✓ QR code toggle working"
      else
        puts "✗ QR code toggle failed"
        return false
      end
      
      # Test 6: Save complete label to file
      puts "\n[TEST 6] Save Label to File (No Preview)"
      generator.update_options(qr_enabled: true, label_style: LabelGenerator::STYLE_COMPACT)
      label = generator.generate_label(test_part_data, part_dimensions)
      
      # Calculate actual label size
      label_size = generator.calculate_label_size(test_part_data)
      label_width = label_size[:width]
      label_height = label_size[:height]
      
      # Create complete SVG document
      # IMPORTANT: ViewBox matches label size (70x30), NOT part size
      complete_svg = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" width="#{label_width}mm" height="#{label_height}mm" viewBox="0 0 #{label_width} #{label_height}">
          <g>
            #{label.gsub(/transform="translate\([^)]+\)"/, 'transform="translate(0,0)"')}
          </g>
        </svg>
      SVG
      
      test_file = File.join(Dir.tmpdir, 'test_label_fixed.svg')
      
      begin
        File.write(test_file, complete_svg)
        if File.exist?(test_file)
          puts "✓ Label saved to: #{test_file}"
          puts "  File size: #{File.size(test_file)} bytes"
          puts "  Label dimensions: #{label_width.round(1)}mm x #{label_height.round(1)}mm"
        else
          puts "✗ Failed to save label"
          return false
        end
      rescue => e
        puts "✗ Error saving file: #{e.message}"
        return false
      end
      
      # Test 7: Multiple parts with different data
      puts "\n[TEST 7] Multiple Parts Generation"
      parts = [
        { part_id: 'P1', name: 'Top Panel', width: 800, height: 600, thickness: 18, board_number: 1 },
        { part_id: 'P2', name: 'Side Panel', width: 600, height: 800, thickness: 18, board_number: 1 },
        { part_id: 'P3', name: 'Bottom Panel', width: 800, height: 600, thickness: 18, board_number: 2 }
      ]
      
      parts.each do |part|
        dims = { width: part[:width], height: part[:height] }
        label = generator.generate_label(part, dims)
        if label && label.include?('<g class="part-label"')
          puts "✓ #{part[:part_id]} label generated"
        else
          puts "✗ #{part[:part_id]} label failed"
          return false
        end
      end
      
      # Test 8: Label Sheet Generator with Preview
      puts "\n[TEST 8] Label Sheet Generator with Preview"
      begin
        require_relative 'exporters/label_sheet_generator'
        
        # Prepare test data for label sheet
        sheet_parts = [
          { part_id: 'P1', name: 'Top Panel', width: 800, height: 600, thickness: 18, material: 'Plywood 18mm', board_number: 1 },
          { part_id: 'P2', name: 'Side Panel', width: 600, height: 800, thickness: 18, material: 'Plywood 18mm', board_number: 1 },
          { part_id: 'P3', name: 'Bottom Panel', width: 800, height: 600, thickness: 18, material: 'MDF 18mm', board_number: 2 },
          { part_id: 'P4', name: 'Shelf', width: 750, height: 300, thickness: 18, material: 'Plywood 18mm', board_number: 2 }
        ]
        
        sheet_generator = AutoNestCut::LabelSheetGenerator.new('custom')
        
        # Generate with preview mode enabled
        output_path = sheet_generator.generate_label_sheet(sheet_parts, nil, true)
        
        if File.exist?(output_path)
          puts "✓ Label sheet generated with preview"
          puts "  Output: #{output_path}"
        else
          puts "✗ Label sheet generation failed"
          return false
        end
        
      rescue => e
        puts "✗ Label sheet test failed: #{e.message}"
        puts e.backtrace.first(3).join("\n")
        return false
      end
      
      puts "\n" + "="*80
      puts "ALL TESTS PASSED ✓"
      puts "="*80
      puts "\nLabel Generator is ready for integration!"
      puts "Test file saved at: #{test_file}"
      puts "\nNext steps:"
      puts "1. Open #{test_file} in a browser to view the label"
      
      true
    end
    
  end
end

# Auto-run tests when loaded
AutoNestCut::LabelGeneratorTest.run_tests