# frozen_string_literal: true

# ==============================================================================
# LABEL SHEET PREVIEW TEST
# Quick test to demonstrate the preview feature
# ==============================================================================

require_relative 'exporters/label_sheet_generator'

module AutoNestCut
  module LabelSheetPreviewTest
    
    def self.run_preview_test
      puts "\n" + "="*80
      puts "LABEL SHEET PREVIEW TEST"
      puts "="*80
      
      # Sample parts data
      parts_data = [
        { 
          part_id: 'P1', 
          name: 'Cabinet Top Panel', 
          width: 800, 
          height: 600, 
          thickness: 18, 
          material: 'Plywood 18mm', 
          board_number: 1 
        },
        { 
          part_id: 'P2', 
          name: 'Cabinet Side Panel', 
          width: 600, 
          height: 800, 
          thickness: 18, 
          material: 'Plywood 18mm', 
          board_number: 1 
        },
        { 
          part_id: 'P3', 
          name: 'Cabinet Bottom Panel', 
          width: 800, 
          height: 600, 
          thickness: 18, 
          material: 'MDF 18mm', 
          board_number: 2 
        },
        { 
          part_id: 'P4', 
          name: 'Shelf', 
          width: 750, 
          height: 300, 
          thickness: 18, 
          material: 'Plywood 18mm', 
          board_number: 2 
        },
        { 
          part_id: 'P5', 
          name: 'Back Panel', 
          width: 800, 
          height: 900, 
          thickness: 6, 
          material: 'Plywood 6mm', 
          board_number: 3 
        },
        { 
          part_id: 'P6', 
          name: 'Door Panel', 
          width: 400, 
          height: 700, 
          thickness: 18, 
          material: 'MDF 18mm', 
          board_number: 3 
        }
      ]
      
      puts "Generating label sheet for #{parts_data.length} parts..."
      
      # Create label sheet generator
      generator = LabelSheetGenerator.new('custom')
      
      # Generate with preview mode enabled (true)
      output_path = generator.generate_label_sheet(parts_data, nil, true)
      
      puts "\n✓ Preview window opened!"
      puts "  Temporary file: #{output_path}"
      puts "\nInstructions:"
      puts "  1. Review the label sheet in the preview window"
      puts "  2. Click 'Export Label Sheet' to save to your desired location"
      puts "  3. Click 'Cancel' to close without saving"
      puts "="*80
      
      true
    end
    
  end
end

# Run the test
AutoNestCut::LabelSheetPreviewTest.run_preview_test
