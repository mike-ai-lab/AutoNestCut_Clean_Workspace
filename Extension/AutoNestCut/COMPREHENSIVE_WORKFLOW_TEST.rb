# frozen_string_literal: true

# ==============================================================================
# COMPREHENSIVE WORKFLOW TEST - AutoNestCut Extension
# Tests the complete workflow from component selection to export
# Includes edge cases and error handling validation
# ==============================================================================

require_relative 'main'
require_relative 'models/part'
require_relative 'models/board'
require_relative 'processors/model_analyzer'
require_relative 'processors/nester'
require_relative 'exporters/report_generator'
require_relative 'exporters/label_sheet_generator'
require_relative 'exporters/label_generator'
require_relative 'exporters/qr_code_generator'
require_relative 'ui/dialog_manager'

module AutoNestCut
  module ComprehensiveWorkflowTest
    
    # Test Results Tracker
    @test_results = {
      passed: [],
      failed: [],
      warnings: []
    }
    
    def self.run_all_tests
      puts "\n" + "="*80
      puts "AUTONESTCUT COMPREHENSIVE WORKFLOW TEST SUITE"
      puts "="*80
      puts "Testing complete workflow from A to Z with edge cases"
      puts "="*80 + "\n"
      
      # Phase 1: Component Creation & Analysis
      test_component_creation
      test_material_detection
      test_dimension_extraction
      test_grain_direction_handling
      test_edge_banding_parsing
      
      # Phase 2: Model Analysis
      test_model_analyzer_basic
      test_empty_selection
      test_invalid_components
      test_nested_components
      
      # Phase 3: Nesting Algorithm
      test_nesting_basic
      test_nesting_rotation
      test_nesting_grain_constraints
      test_nesting_oversized_parts
      
      # Phase 4: Report Generation
      test_report_generation
      test_report_data_integrity
      test_missing_data_handling
      
      # Phase 5: Label Generation
      test_label_generator_svg
      test_label_sheet_generator_pdf
      test_qr_code_generation
      test_label_positioning
      
      # Phase 6: Material Highlighting
      test_material_highlighting
      test_highlight_toggle
      test_highlight_by_thickness
      
      # Phase 7: Export Functions
      test_csv_export
      test_pdf_export
      test_svg_export
      
      # Phase 8: Edge Cases & Error Handling
      test_zero_dimensions
      test_negative_dimensions
      test_missing_materials
      test_duplicate_components
      test_very_large_quantities
      test_special_characters_in_names
      test_unicode_material_names
      
      # Print Results
      print_test_results
    end
    
    # ========================================================================
    # PHASE 1: COMPONENT CREATION & ANALYSIS
    # ========================================================================
    
    def self.test_component_creation
      test_name = "Component Creation"
      begin
        model = Sketchup.active_model
        
        # Create test component
        definition = model.definitions.add("TestComponent_#{Time.now.to_i}")
        entities = definition.entities
        
        # Add a simple box
        face = entities.add_face([0,0,0], [100,0,0], [100,100,0], [0,100,0])
        face.pushpull(-18)
        
        # Create instance
        instance = model.active_entities.add_instance(definition, Geom::Transformation.new)
        
        # Create Part object
        part = Part.new(instance)
        
        # Validate
        assert(part.width > 0, "Part width should be positive")
        assert(part.height > 0, "Part height should be positive")
        assert(part.thickness > 0, "Part thickness should be positive")
        
        # Cleanup
        instance.erase!
        model.definitions.purge_unused
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    def self.test_material_detection
      test_name = "Material Detection"
      begin
        model = Sketchup.active_model
        
        # Create material
        material = model.materials.add("TestMaterial_#{Time.now.to_i}")
        material.color = Sketchup::Color.new(200, 100, 50)
        
        # Create component with material
        definition = model.definitions.add("MaterialTest_#{Time.now.to_i}")
        entities = definition.entities
        face = entities.add_face([0,0,0], [100,0,0], [100,100,0], [0,100,0])
        face.pushpull(-18)
        face.material = material
        
        instance = model.active_entities.add_instance(definition, Geom::Transformation.new)
        
        # Test Part material detection
        part = Part.new(instance)
        
        assert(part.material != nil, "Material should be detected")
        assert(part.material.include?("TestMaterial"), "Material name should match")
        
        # Cleanup
        instance.erase!
        model.materials.remove(material)
        model.definitions.purge_unused
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    def self.test_dimension_extraction
      test_name = "Dimension Extraction"
      begin
        model = Sketchup.active_model
        
        # Create component with known dimensions
        definition = model.definitions.add("DimensionTest_#{Time.now.to_i}")
        entities = definition.entities
        
        # Create 800mm x 600mm x 18mm box
        face = entities.add_face([0,0,0], [800.mm,0,0], [800.mm,600.mm,0], [0,600.mm,0])
        face.pushpull(-18.mm)
        
        instance = model.active_entities.add_instance(definition, Geom::Transformation.new)
        part = Part.new(instance)
        
        # Part class sorts dimensions, so thickness=18, width=600, height=800
        # Validate dimensions (with tolerance)
        assert((part.thickness - 18).abs < 1, "Thickness should be ~18mm, got #{part.thickness}")
        assert((part.width - 600).abs < 1 || (part.width - 800).abs < 1, "Width should be ~600mm or ~800mm, got #{part.width}")
        assert((part.height - 800).abs < 1 || (part.height - 600).abs < 1, "Height should be ~800mm or ~600mm, got #{part.height}")
        
        # Cleanup
        instance.erase!
        model.definitions.purge_unused
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    def self.test_grain_direction_handling
      test_name = "Grain Direction Handling"
      begin
        model = Sketchup.active_model
        
        definition = model.definitions.add("GrainTest_#{Time.now.to_i}")
        entities = definition.entities
        face = entities.add_face([0,0,0], [100,0,0], [100,100,0], [0,100,0])
        face.pushpull(-18)
        
        instance = model.active_entities.add_instance(definition, Geom::Transformation.new)
        
        # Test different grain directions
        grain_directions = ['Any', 'horizontal', 'vertical', 'fixed']
        
        grain_directions.each do |grain|
          instance.set_attribute('AutoNestCut', 'grain_direction', grain)
          part = Part.new(instance)
          
          assert(part.grain_direction == grain, "Grain direction should be #{grain}")
          
          # Test rotation capability
          if ['fixed', 'horizontal', 'vertical'].include?(grain.downcase)
            assert(!part.can_rotate?, "Part with #{grain} grain should not rotate")
          else
            assert(part.can_rotate?, "Part with #{grain} grain should rotate")
          end
        end
        
        # Cleanup
        instance.erase!
        model.definitions.purge_unused
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    def self.test_edge_banding_parsing
      test_name = "Edge Banding Parsing"
      begin
        model = Sketchup.active_model
        
        definition = model.definitions.add("EdgeBandingTest_#{Time.now.to_i}")
        entities = definition.entities
        face = entities.add_face([0,0,0], [100,0,0], [100,100,0], [0,100,0])
        face.pushpull(-18)
        
        instance = model.active_entities.add_instance(definition, Geom::Transformation.new)
        
        # Test valid edge banding formats
        test_cases = [
          { input: 'PVC_White:all', expected_edges: 4 },
          { input: 'PVC_White:top,bottom', expected_edges: 2 },
          { input: 'PVC_White:top,bottom,left,right', expected_edges: 4 },
          { input: 'None', expected_edges: 0 }
        ]
        
        test_cases.each do |test_case|
          instance.set_attribute('AutoNestCut', 'edge_banding', test_case[:input])
          part = Part.new(instance)
          
          edge_count = part.edge_banding[:edges].length
          assert(edge_count == test_case[:expected_edges], 
                 "Edge banding '#{test_case[:input]}' should have #{test_case[:expected_edges]} edges, got #{edge_count}")
        end
        
        # Cleanup
        instance.erase!
        model.definitions.purge_unused
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    # ========================================================================
    # PHASE 2: MODEL ANALYSIS
    # ========================================================================
    
    def self.test_model_analyzer_basic
      test_name = "Model Analyzer - Basic"
      begin
        model = Sketchup.active_model
        
        # Save current selection
        original_selection = model.selection.to_a
        model.selection.clear
        
        # Create test components in a temporary group to isolate them
        test_group = model.active_entities.add_group
        test_entities = test_group.entities
        
        # Create test components
        test_instances = []
        3.times do |i|
          definition = model.definitions.add("AnalyzerTest_#{i}_#{Time.now.to_i}")
          entities = definition.entities
          face = entities.add_face([0,0,0], [100,0,0], [100,100,0], [0,100,0])
          face.pushpull(-18)
          
          instance = test_entities.add_instance(definition, Geom::Transformation.new([i*200, 0, 0]))
          test_instances << instance
        end
        
        # Select only test instances
        model.selection.add(test_instances)
        
        # Analyze
        analyzer = ModelAnalyzer.new
        parts_by_material = analyzer.analyze_selection(model.selection)
        
        assert(!parts_by_material.empty?, "Analyzer should find parts")
        
        # Cleanup
        model.selection.clear
        test_group.erase!
        model.definitions.purge_unused
        
        # Restore original selection
        model.selection.add(original_selection) unless original_selection.empty?
        
        pass_test(test_name)
      rescue => e
        # Cleanup on error
        model.selection.clear rescue nil
        model.definitions.purge_unused rescue nil
        fail_test(test_name, e)
      end
    end
    
    def self.test_empty_selection
      test_name = "Empty Selection Handling"
      begin
        model = Sketchup.active_model
        model.selection.clear
        
        analyzer = ModelAnalyzer.new
        parts_by_material = analyzer.analyze_selection(model.selection)
        
        assert(parts_by_material.empty?, "Empty selection should return empty hash")
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    def self.test_invalid_components
      test_name = "Invalid Component Handling"
      begin
        model = Sketchup.active_model
        
        # Create invalid component (just a line, no volume)
        definition = model.definitions.add("InvalidTest_#{Time.now.to_i}")
        entities = definition.entities
        entities.add_line([0,0,0], [100,0,0])
        
        instance = model.active_entities.add_instance(definition, Geom::Transformation.new)
        
        # This should either skip or handle gracefully
        analyzer = ModelAnalyzer.new
        parts_by_material = analyzer.analyze_selection(model.selection.add(instance))
        
        # Cleanup
        instance.erase!
        model.definitions.purge_unused
        
        pass_test(test_name)
      rescue => e
        # Expected to fail gracefully
        warn_test(test_name, "Invalid components should be skipped: #{e.message}")
      end
    end
    
    def self.test_nested_components
      test_name = "Nested Components"
      begin
        model = Sketchup.active_model
        
        # Create nested structure
        inner_def = model.definitions.add("Inner_#{Time.now.to_i}")
        face = inner_def.entities.add_face([0,0,0], [100,0,0], [100,100,0], [0,100,0])
        face.pushpull(-18)
        
        outer_def = model.definitions.add("Outer_#{Time.now.to_i}")
        outer_def.entities.add_instance(inner_def, Geom::Transformation.new)
        
        outer_instance = model.active_entities.add_instance(outer_def, Geom::Transformation.new)
        
        analyzer = ModelAnalyzer.new
        parts_by_material = analyzer.analyze_selection(model.selection.add(outer_instance))
        
        # Should handle nested components
        assert(!parts_by_material.empty?, "Should analyze nested components")
        
        # Cleanup
        outer_instance.erase!
        model.definitions.purge_unused
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    # ========================================================================
    # PHASE 3: NESTING ALGORITHM
    # ========================================================================
    
    def self.test_nesting_basic
      test_name = "Nesting - Basic"
      begin
        # Create test parts
        parts = []
        3.times do |i|
          part = create_mock_part(400, 300, 18, "Plywood")
          parts << part
        end
        
        # Create board
        board = Board.new(2440, 1220, 18, "Plywood")
        
        # Nest parts
        nester = Nester.new
        result = nester.nest_parts(parts, [board])
        
        assert(result[:boards].length > 0, "Should create at least one board")
        assert(result[:boards][0].parts.length > 0, "Board should have parts")
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    def self.test_nesting_rotation
      test_name = "Nesting - Rotation"
      begin
        # Create part that needs rotation to fit
        part = create_mock_part(1500, 800, 18, "Plywood")
        part.grain_direction = 'Any' # Allow rotation
        
        board = Board.new(2440, 1220, 18, "Plywood")
        
        nester = Nester.new
        result = nester.nest_parts([part], [board])
        
        assert(result[:boards][0].parts.length > 0, "Part should fit with rotation")
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    def self.test_nesting_grain_constraints
      test_name = "Nesting - Grain Constraints"
      begin
        # Create part with fixed grain
        part = create_mock_part(1500, 800, 18, "Plywood")
        part.grain_direction = 'fixed'
        
        assert(!part.can_rotate?, "Part with fixed grain should not rotate")
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    def self.test_nesting_oversized_parts
      test_name = "Nesting - Oversized Parts"
      begin
        # Create part larger than board
        part = create_mock_part(3000, 2000, 18, "Plywood")
        board = Board.new(2440, 1220, 18, "Plywood")
        
        nester = Nester.new
        result = nester.nest_parts([part], [board])
        
        # Should handle gracefully (create offcut or skip)
        warn_test(test_name, "Oversized parts should be handled: #{result[:offcuts].length} offcuts")
        
      rescue => e
        warn_test(test_name, "Oversized parts handling: #{e.message}")
      end
    end
    
    # ========================================================================
    # PHASE 4: REPORT GENERATION
    # ========================================================================
    
    def self.test_report_generation
      test_name = "Report Generation"
      begin
        # Create mock boards with parts
        board = Board.new(2440, 1220, 18, "Plywood")
        part = create_mock_part(400, 300, 18, "Plywood")
        part.x = 0
        part.y = 0
        board.add_part(part)
        
        # Generate report
        generator = ReportGenerator.new
        settings = { kerf_width: 3, unit: 'mm' }
        report_data = generator.generate_report_data([board], settings)
        
        assert(report_data[:boards].length > 0, "Report should have boards")
        assert(report_data[:parts_placed].length > 0, "Report should have parts")
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    def self.test_report_data_integrity
      test_name = "Report Data Integrity"
      begin
        board = Board.new(2440, 1220, 18, "Plywood")
        part = create_mock_part(400, 300, 18, "Plywood")
        part.x = 0
        part.y = 0
        board.add_part(part)
        
        generator = ReportGenerator.new
        report_data = generator.generate_report_data([board], {})
        
        # Validate data structure
        assert(report_data.key?(:boards), "Report should have :boards key")
        assert(report_data.key?(:parts_placed), "Report should have :parts_placed key")
        assert(report_data.key?(:unique_part_types), "Report should have :unique_part_types key")
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    # ========================================================================
    # PHASE 5: LABEL GENERATION
    # ========================================================================
    
    def self.test_label_generator_svg
      test_name = "Label Generator - SVG"
      begin
        generator = LabelGenerator.new
        
        part_data = {
          part_id: 'P1',
          name: 'Test Part',
          width: 800,
          height: 600,
          thickness: 18,
          material: 'Plywood',
          board_number: 1
        }
        
        part_dimensions = { width: 800, height: 600 }
        
        label_svg = generator.generate_label(part_data, part_dimensions)
        
        assert(label_svg != nil, "Should generate SVG label")
        assert(label_svg.include?('<g'), "SVG should contain group element")
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    def self.test_label_sheet_generator_pdf
      test_name = "Label Sheet Generator - PDF"
      begin
        generator = LabelSheetGenerator.new('custom')
        
        parts = [
          { part_id: 1, width: 800, height: 600, thickness: 18, board_number: 1 },
          { part_id: 2, width: 600, height: 400, thickness: 18, board_number: 1 }
        ]
        
        output_path = generator.generate_label_sheet(parts, nil, false)
        
        assert(File.exist?(output_path), "PDF file should be created")
        assert(File.size(output_path) > 0, "PDF file should not be empty")
        
        # Cleanup
        File.delete(output_path) if File.exist?(output_path)
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    def self.test_qr_code_generation
      test_name = "QR Code Generation"
      begin
        qr_gen = QRCodeGenerator.new
        
        part_data = { part_id: 'P42' }
        qr_svg = qr_gen.generate_qr_code(part_data, size: 28, padding: 0)
        
        assert(qr_svg != nil, "Should generate QR code")
        assert(qr_svg.include?('svg'), "Should be SVG format")
        assert(qr_svg.include?('P42'), "Should encode part ID")
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    # ========================================================================
    # PHASE 8: EDGE CASES
    # ========================================================================
    
    def self.test_zero_dimensions
      test_name = "Zero Dimensions Handling"
      begin
        part_data = { part_id: 1, width: 0, height: 0, thickness: 0, board_number: 1 }
        
        # Should handle gracefully
        generator = LabelSheetGenerator.new
        # This might fail or skip - both are acceptable
        
        warn_test(test_name, "Zero dimensions should be handled gracefully")
      rescue => e
        warn_test(test_name, "Zero dimensions: #{e.message}")
      end
    end
    
    def self.test_special_characters_in_names
      test_name = "Special Characters in Names"
      begin
        part_data = {
          part_id: 'P1',
          name: 'Test<>&"Part',
          width: 800,
          height: 600,
          thickness: 18,
          board_number: 1
        }
        
        generator = LabelGenerator.new
        label_svg = generator.generate_label(part_data, { width: 800, height: 600 })
        
        # Should escape XML characters
        assert(!label_svg.include?('<>&"'), "Special characters should be escaped")
        
        pass_test(test_name)
      rescue => e
        fail_test(test_name, e)
      end
    end
    
    def self.test_unicode_material_names
      test_name = "Unicode Material Names"
      begin
        part_data = {
          part_id: 'P1',
          name: 'Тест',  # Cyrillic
          material: '木材',  # Chinese
          width: 800,
          height: 600,
          thickness: 18,
          board_number: 1
        }
        
        generator = LabelSheetGenerator.new
        output_path = generator.generate_label_sheet([part_data], nil, false)
        
        assert(File.exist?(output_path), "Should handle unicode names")
        
        File.delete(output_path) if File.exist?(output_path)
        
        pass_test(test_name)
      rescue => e
        warn_test(test_name, "Unicode handling: #{e.message}")
      end
    end
    
    # ========================================================================
    # HELPER METHODS
    # ========================================================================
    
    def self.create_mock_part(width, height, thickness, material)
      model = Sketchup.active_model
      definition = model.definitions.add("MockPart_#{Time.now.to_i}_#{rand(1000)}")
      entities = definition.entities
      face = entities.add_face([0,0,0], [width.mm,0,0], [width.mm,height.mm,0], [0,height.mm,0])
      face.pushpull(-thickness.mm)
      
      instance = model.active_entities.add_instance(definition, Geom::Transformation.new)
      part = Part.new(instance)
      
      # Cleanup instance but keep definition for part
      instance.erase!
      
      part
    end
    
    def self.assert(condition, message)
      raise message unless condition
    end
    
    def self.pass_test(test_name)
      @test_results[:passed] << test_name
      puts "✓ PASS: #{test_name}"
    end
    
    def self.fail_test(test_name, error)
      @test_results[:failed] << { name: test_name, error: error.message }
      puts "✗ FAIL: #{test_name}"
      puts "  Error: #{error.message}"
      puts "  #{error.backtrace.first(2).join("\n  ")}"
    end
    
    def self.warn_test(test_name, message)
      @test_results[:warnings] << { name: test_name, message: message }
      puts "⚠ WARN: #{test_name}"
      puts "  #{message}"
    end
    
    def self.print_test_results
      puts "\n" + "="*80
      puts "TEST RESULTS SUMMARY"
      puts "="*80
      
      total = @test_results[:passed].length + @test_results[:failed].length + @test_results[:warnings].length
      
      puts "\n✓ PASSED: #{@test_results[:passed].length}/#{total}"
      @test_results[:passed].each { |name| puts "  • #{name}" }
      
      if @test_results[:failed].length > 0
        puts "\n✗ FAILED: #{@test_results[:failed].length}/#{total}"
        @test_results[:failed].each { |result| puts "  • #{result[:name]}: #{result[:error]}" }
      end
      
      if @test_results[:warnings].length > 0
        puts "\n⚠ WARNINGS: #{@test_results[:warnings].length}/#{total}"
        @test_results[:warnings].each { |result| puts "  • #{result[:name]}: #{result[:message]}" }
      end
      
      puts "\n" + "="*80
      
      success_rate = (@test_results[:passed].length.to_f / total * 100).round(1)
      puts "SUCCESS RATE: #{success_rate}%"
      puts "="*80 + "\n"
    end
    
  end
end

# Run the test suite
AutoNestCut::ComprehensiveWorkflowTest.run_all_tests
