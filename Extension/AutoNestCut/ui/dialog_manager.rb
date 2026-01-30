require 'json'
require 'thread' # Required for using Ruby's Thread and Queue classes
require 'digest' # Required for generating cache keys (e.g., MD5)
require_relative '../config' # Ensure the Config module is loaded
require_relative '../materials_database' # Ensure MaterialsDatabase is loaded
require_relative '../exporters/report_generator' # Ensure ReportGenerator is loaded
require_relative '../exporters/prawn_pdf_exporter' # Ensure PrawnPDFExporter is loaded
require_relative '../processors/model_analyzer' # Ensure ModelAnalyzer is loaded
require_relative '../processors/component_validator' # Ensure ComponentValidator is loaded
require_relative '../processors/nester' # Ensure Nester is loaded
require_relative '../compatibility' # Ensure Compatibility is loaded for desktop_path etc.
require_relative '../models/part' # Ensure Part class is loaded

module AutoNestCut
  class UIDialogManager

    # Cache for nesting results to avoid recalculating if inputs haven't changed
    # Key: cache_key (MD5 hash of parts and nesting settings)
    # Value: { boards: Array of Board objects, timestamp: Time, access_time: Time }
    @nesting_cache = {}
    
    # Mutex for thread-safe cache access
    @cache_mutex = Mutex.new
    
    # Maximum number of cached nesting results (LRU eviction)
    MAX_CACHE_SIZE = 5

    # Flag to indicate if processing was cancelled by user
    @processing_cancelled = false

    def initialize
      # Ensure cache and cancellation flag are initialized for each new manager instance
      @nesting_cache = {}
      @cache_mutex = Mutex.new
      @processing_cancelled = false
      
      # Initialize all instance variables to nil for proper cleanup
      @dialog = nil
      @parts_by_material = nil
      @original_components = nil
      @hierarchy_tree = nil
      @assembly_entity = nil
      @assembly_data = nil
      @settings = nil
      @boards = nil
      @nesting_queue = nil
      @nesting_thread = nil
      @nesting_watcher_timer = nil
      @nesting_start_time = nil
      @last_progress_update = nil
      @last_processed_cache_key = nil
    end
    
    # Cleanup method to be called when dialog is closed
    def cleanup
      puts "DEBUG: UIDialogManager cleanup started"
      
      # Stop any running timers
      if @nesting_watcher_timer && (defined?(UI.valid_timer?) ? UI.valid_timer?(@nesting_watcher_timer) : true)
        UI.stop_timer(@nesting_watcher_timer)
      end
      @nesting_watcher_timer = nil
      
      # Kill any background threads
      if @nesting_thread && @nesting_thread.alive?
        @nesting_thread.kill
        @nesting_thread.join(1)
      end
      @nesting_thread = nil
      
      # Clear queue
      @nesting_queue.clear if @nesting_queue
      @nesting_queue = nil
      
      # Clear large data structures
      @parts_by_material = nil
      @original_components = nil
      @hierarchy_tree = nil
      @assembly_entity = nil
      @assembly_data = nil
      @settings = nil
      @boards = nil
      
      # Close dialog if still open
      if @dialog
        begin
          @dialog.close if @dialog.respond_to?(:close)
        rescue => e
          puts "DEBUG: Error closing dialog: #{e.message}"
        end
        @dialog = nil
      end
      
      puts "DEBUG: UIDialogManager cleanup completed"
    end
    
    # Destructor to ensure cleanup on garbage collection
    def finalize
      cleanup
    end

    def show_config_dialog(parts_by_material, original_components = [], hierarchy_tree = [], assembly_entity = nil, skip_validation = false)
      puts "=" * 80
      puts "🦟 CONFIG DIALOG: show_config_dialog called"
      puts "=" * 80
      puts "Materials received: #{parts_by_material.keys.inspect}"
      puts "Total parts: #{parts_by_material.values.flatten.length}"
      puts "Skip validation: #{skip_validation}"
      parts_by_material.each do |mat_name, parts|
        puts "  #{mat_name}: #{parts.length} parts"
      end
      puts "=" * 80
      
      @parts_by_material = parts_by_material
      @original_components = original_components
      @hierarchy_tree = hierarchy_tree
      @assembly_entity = assembly_entity
      @assembly_data = nil
      @skip_validation = skip_validation
      
      # Capture assembly data if entity is provided
      if @assembly_entity
        @assembly_data = capture_assembly_data(@assembly_entity)
        puts "DEBUG: Assembly data captured: #{@assembly_data.keys.inspect}"
      end
      
      # Use HtmlDialog for SU2017+ or WebDialog for older versions
      if defined?(UI::HtmlDialog)
        @dialog = UI::HtmlDialog.new(
          dialog_title: "AutoNestCut",
          preferences_key: "AutoNestCut_Main",
          scrollable: true,
          resizable: true,
          width: 620,
          height: 420
        )
      else
        @dialog = UI::WebDialog.new(
          "AutoNestCut",
          true,
          "AutoNestCut_Main",
          1200, # Fallback to a larger size for WebDialog
          750,
          100,
          100,
          true
        )
      end

      html_file = File.join(__dir__, 'html', 'main.html')
      AutoNestCut.set_html_with_cache_busting(@dialog, html_file)

      # Send initial data to dialog when it's ready
      @dialog.add_action_callback("ready") do |action_context|
        puts "DEBUG: Frontend is ready. Sending initial data."
        send_initial_data
      end

      # Handle global settings update from UI (units, precision, currency, area_units)
      @dialog.add_action_callback("update_global_setting") do |action_context, setting_json|
        begin
          setting_data = JSON.parse(setting_json)
          key = setting_data['key']
          value = setting_data['value']
          
          # Use Config module for persistence
          Config.save_global_settings({key => value})
          puts "DEBUG: Global setting updated: #{key} = #{value}"
          
          # After updating a global setting, re-send initial data to ensure UI consistency
          # The JS `receiveInitialData` will then trigger `displayMaterials` and `renderReport` as needed.
          send_initial_data
        rescue => e
          puts "ERROR updating global setting: #{e.message}"
          @dialog.execute_script("showError('Error updating setting: #{e.message.gsub("'", "\\'")}')")
        end
      end

      # Handle materials database save from UI
      @dialog.add_action_callback("save_materials") do |action_context, materials_json|
        begin
          materials = JSON.parse(materials_json)
          MaterialsDatabase.save_database(materials)
          puts "DEBUG: Materials database saved successfully."
        rescue => e
          puts "ERROR saving materials: #{e.message}"
          @dialog.execute_script("showError('Error saving materials: #{e.message.gsub("'", "\\'")}')")
        end
      end

      # Handle processing (nesting and report generation)
      @dialog.add_action_callback("process") do |action_context, settings_json|
        begin
          puts "DEBUG: Process callback started"
          new_settings_from_ui = JSON.parse(settings_json)
          
          # Save global settings from the UI's full settings object
          Config.save_global_settings({
            'kerf_width' => new_settings_from_ui['kerf_width'],
            'allow_rotation' => new_settings_from_ui['allow_rotation'],
            'default_currency' => new_settings_from_ui['default_currency'],
            'units' => new_settings_from_ui['units'],
            'precision' => new_settings_from_ui['precision'],
            'area_units' => new_settings_from_ui['area_units'],
            'auto_create_materials' => new_settings_from_ui['auto_create_materials']
          })
          
          # Save material data (including updates to prices/dimensions if any)
          MaterialsDatabase.save_database(new_settings_from_ui['stock_materials'])

          # Always use async processing for nesting (with caching)
          # Fetch the *latest* settings from Config for processing to ensure consistency
          latest_settings = Config.get_cached_settings
          
          # Combine detected materials with stock materials for Nester input
          # This ensures that Nester has correct dimensions for ALL materials,
          # including those dynamically added from the model if not in stock_materials.
          all_materials_for_nester = MaterialsDatabase.load_database # Start with stock
          
          # Merge in properties from `parts_by_material` for detected but not defined materials
          @parts_by_material.each do |material_name, part_types|
            if !all_materials_for_nester.key?(material_name)
                first_part_type_data = part_types.first
                
                part_obj_from_entry = nil
                if first_part_type_data.is_a?(Hash) && first_part_type_data.key?(:part_type)
                  part_obj_from_entry = first_part_type_data[:part_type]
                elsif first_part_type_data.is_a?(AutoNestCut::Part)
                  part_obj_from_entry = first_part_type_data
                end

                if part_obj_from_entry.is_a?(AutoNestCut::Part) && part_obj_from_entry.respond_to?(:thickness)
                  thickness_val = part_obj_from_entry.thickness
                  
                  all_materials_for_nester[material_name] = {
                    'width' => 2440,
                    'height' => 1220,
                    'thickness' => thickness_val,
                    'price' => 0,
                    'currency' => latest_settings['default_currency'] || 'USD'
                  }
                end
            end
          end
          latest_settings['stock_materials'] = all_materials_for_nester

          # Validate with smart limits
          validation_result = validate_with_smart_limits(@parts_by_material, latest_settings)
          
          if validation_result[:blocked]
            UI.messagebox(validation_result[:message])
            next
          end
          
          if validation_result[:warnings].any?
            @dialog.execute_script("showWarnings(#{validation_result[:warnings].to_json})")
          end

          puts "DEBUG: Validation passed, starting nesting"
          process_with_async_nesting(latest_settings)

        rescue => e
          puts "ERROR in process callback: #{e.message}"
          puts e.backtrace
          error_msg = js_escape(e.message)
          @dialog.execute_script("showError('Error processing: #{error_msg}')")
          @dialog.execute_script("hideProgressOverlay()")
        end
      end

      # Export CSV report
      @dialog.add_action_callback("export_csv") do |action_context, report_data_json|
        begin
          if report_data_json && !report_data_json.empty?
            if report_data_json.is_a?(String)
              report_data = JSON.parse(report_data_json, symbolize_names: true)
            else
              report_data = report_data_json
            end
            export_csv_report(report_data, Config.get_cached_settings)
          else
            UI.messagebox("Error exporting CSV: No report data available")
          end
        rescue => e
          UI.messagebox("Error exporting CSV: #{e.message}")
        end
      end


    @dialog.add_action_callback("export_to_pdf") do |action_context, html_content|
      begin
        puts "DEBUG: Exporting to PDF using Prawn..."
        pdf_path = PrawnPDFExporter.generate_pdf_from_html(html_content, @settings)
        
        if pdf_path && File.exist?(pdf_path)
          puts "DEBUG: PDF generated successfully at: #{pdf_path}"
          UI.messagebox("PDF report exported successfully!\n\nLocation: #{pdf_path}")
          @dialog.execute_script("hideProgressOverlay();")
        else
          raise "PDF file was not created"
        end
      rescue => e
        puts "ERROR: Failed to generate PDF: #{e.message}"
        puts e.backtrace.join("\n")
        @dialog.execute_script("hideProgressOverlay(); showError('Error generating PDF: #{e.message.gsub("'", "\\'")}')")
      end
    end

      @dialog.add_action_callback("export_interactive_html") do |action_context, report_data_json|
        begin
          puts "DEBUG: Interactive HTML export requested"
          puts "DEBUG: @assembly_data available: #{!@assembly_data.nil?}"
          puts "DEBUG: @assembly_data keys: #{@assembly_data.keys.inspect if @assembly_data}"
          report_generator = ReportGenerator.new
          report_generator.export_interactive_html(report_data_json, @assembly_data)
        rescue => e
          puts "ERROR exporting interactive HTML: #{e.message}"
          puts e.backtrace.join("\n")
          UI.messagebox("Error exporting HTML: #{e.message}")
        end
      end
      
      @dialog.add_action_callback("save_html_report") do |action_context, html_content|
        begin
          model_name = Sketchup.active_model.title.empty? ? "Untitled" : Sketchup.active_model.title.gsub(/[^\w]/, '_')
          base_name = "AutoNestCut_Report_#{model_name}"
          counter = 1
          documents_path = Compatibility.documents_path
          
          loop do
            filename = "#{base_name}_#{counter}.html"
            full_path = File.join(documents_path, filename)
            
            unless File.exist?(full_path)
              File.write(full_path, html_content, encoding: 'UTF-8')
              UI.messagebox("Interactive HTML report exported to Documents: #{filename}")
              break
            end
            
            counter += 1
          end
        rescue => e
          UI.messagebox("Error exporting HTML: #{e.message}")
        end
      end
      
      @dialog.add_action_callback("print_pdf") do |action_context, html_or_data|
        begin
          puts "\n" + "="*80
          puts "DEBUG: print_pdf callback STARTED - Using Ruby PDF Exporter"
          puts "="*80
          
          report_data = nil
          assembly_data = nil
          diagram_images = []
          diagrams_data = []
          
          begin
            # Force UTF-8 encoding on incoming data
            utf8_data = html_or_data.force_encoding('UTF-8')
            parsed_data = JSON.parse(utf8_data, symbolize_names: true)
            puts "DEBUG: ✓ JSON parsed successfully!"
            
            # Recursively convert all strings to UTF-8
            report_data = deep_encode_utf8(parsed_data[:report])
            diagrams_data = deep_encode_utf8(parsed_data[:diagrams] || [])
            assembly_data = deep_encode_utf8(parsed_data[:assembly_data])
            diagram_images = deep_encode_utf8(parsed_data[:diagram_images] || [])
            
            puts "DEBUG: Report data keys: #{report_data.keys.inspect if report_data}"
            puts "DEBUG: Diagrams count: #{diagrams_data.length}"
            puts "DEBUG: Diagram images count: #{diagram_images.length}"
            puts "DEBUG: Assembly data present: #{!assembly_data.nil?}"
            
          rescue JSON::ParserError => je
            puts "DEBUG: ✗ JSON parsing failed: #{je.message}"
            raise "Invalid data format for PDF export: #{je.message}"
          end
          
          # Use ReportPdfExporter to generate PDF with vector text
          require_relative '../exporters/report_pdf_exporter'
          
          pdf_exporter = ReportPdfExporter.new
          pdf_exporter.set_report_data(report_data)
          pdf_exporter.set_diagrams_data(diagrams_data)
          pdf_exporter.set_assembly_data(assembly_data) if assembly_data
          
          # Add diagram images
          diagram_images.each_with_index do |img_data, idx|
            pdf_exporter.add_diagram_image(idx, img_data[:image] || img_data['image'])
          end
          
          # Generate PDF file
          pdf_path = pdf_exporter.export_to_pdf
          
          if pdf_path && File.exist?(pdf_path)
            puts "DEBUG: ✓ PDF generated successfully at: #{pdf_path}"
            puts "="*80
            puts "DEBUG: print_pdf callback COMPLETED"
            puts "="*80
            
            # Open the PDF file
            UI.openURL("file:///#{pdf_path}")
            UI.messagebox("PDF exported successfully!\n\nLocation: #{pdf_path}\n\nThe PDF has been opened in your default PDF viewer.")
          else
            raise "PDF file was not created"
          end
          
        rescue => e
          puts "ERROR in print_pdf: #{e.message}"
          puts e.backtrace.join("\n")
          UI.messagebox("Error generating PDF: #{e.message}")
        end
      end
      
      # Helper method to generate complete printable HTML with all report sections and assembly images
      def generate_simple_printable_html(report_data, diagrams_data, assembly_data, diagram_images = [])
        html = <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
              <meta charset="UTF-8">
              <title>AutoNestCut Report</title>
              <style>
                  @page { size: A4 portrait; margin: 15mm; }
                  * { margin: 0; padding: 0; box-sizing: border-box; }
                  body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #e0e0e0; color: #333; font-size: 10pt; line-height: 1.4; padding: 0; margin: 0; }
                  .print-controls { position: fixed; top: 20px; right: 20px; z-index: 1000; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 4px 20px rgba(0,0,0,0.3); display: flex; flex-direction: column; gap: 10px; }
                  .print-controls button { background: #007cba; color: white; border: none; padding: 12px 24px; border-radius: 6px; cursor: pointer; font-size: 15px; font-weight: 600; display: flex; align-items: center; justify-content: center; gap: 8px; min-width: 180px; transition: all 0.3s; }
                  .print-controls button:hover { background: #005a87; transform: translateY(-2px); box-shadow: 0 6px 16px rgba(0,0,0,0.3); }
                  .print-controls button.close { background: #6c757d; }
                  .print-controls button.close:hover { background: #5a6268; }
                  .page { width: 210mm; min-height: 297mm; padding: 15mm; margin: 20px auto; background: white; box-shadow: 0 0 10px rgba(0,0,0,0.2); }
                  h1 { color: #0066cc; border-bottom: 3px solid #0066cc; padding-bottom: 8px; margin: 0 0 10px 0; font-size: 20pt; page-break-after: avoid; }
                  .subtitle { color: #666; font-size: 9pt; margin-bottom: 15px; page-break-after: avoid; }
                  h2 { color: #0066cc; margin: 20px 0 10px 0; border-bottom: 2px solid #0066cc; padding-bottom: 6px; font-size: 13pt; page-break-after: avoid; }
                  h3 { color: #333; margin: 12px 0 8px 0; font-size: 11pt; page-break-after: avoid; }
                  .section { page-break-inside: avoid; margin-bottom: 20px; }
                  .section.new-page { page-break-before: always; }
                  table { width: 100%; border-collapse: collapse; margin: 10px 0 15px 0; font-size: 9pt; page-break-inside: auto; }
                  thead { display: table-header-group; }
                  tbody { display: table-row-group; }
                  tr { page-break-inside: avoid; page-break-after: auto; }
                  th { background: #f0f0f0; padding: 6px 8px; text-align: left; font-weight: 600; border-bottom: 2px solid #0066cc; font-size: 9pt; }
                  td { padding: 5px 8px; border-bottom: 1px solid #ddd; }
                  tr:nth-child(even) { background: #f9f9f9; }
                  .diagram-section { margin: 15px 0; text-align: center; page-break-inside: avoid; }
                  .diagram-image { max-width: 100%; height: auto; border: 1px solid #ddd; margin: 8px 0; }
                  .assembly-section { page-break-before: always; page-break-inside: avoid; margin: 15px 0; }
                  .assembly-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin: 10px 0; page-break-inside: avoid; }
                  .assembly-view { border: 1px solid #ddd; padding: 6px; text-align: center; background: #f9f9f9; page-break-inside: avoid; }
                  .assembly-view img { max-width: 100%; height: auto; margin: 4px 0; }
                  .assembly-view-label { font-weight: 600; margin-top: 4px; color: #0066cc; font-size: 8pt; }
                  .total-highlight { font-weight: 600; background: #ffffcc; }
                  .cut-sequence { margin: 12px 0; page-break-inside: avoid; }
                  .cut-sequence-title { font-weight: 600; margin: 8px 0 4px 0; }
                  @media print {
                      body { background: white; }
                      .print-controls { display: none !important; }
                      .page { margin: 0; box-shadow: none; page-break-after: auto; }
                  }
              </style>
          </head>
          <body>
              <div class="print-controls no-print">
                  <button onclick="window.print()">
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                          <polyline points="6,9 6,2 18,2 18,9"/>
                          <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/>
                          <polyline points="6,14 6,22 18,22 18,14"/>
                      </svg>
                      Print to PDF
                  </button>
                  <button class="close" onclick="window.close()">
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                          <line x1="18" y1="6" x2="6" y2="18"/>
                          <line x1="6" y1="6" x2="18" y2="18"/>
                      </svg>
                      Close
                  </button>
              </div>
              <div class="page">
                  <h1>Cut List & Nesting Report</h1>
                  <p class="subtitle"><strong>Professional Manufacturing Analysis</strong><br><strong>Generated:</strong> #{Time.now.strftime('%m/%d/%Y, %I:%M:%S %p')}</p>
        HTML
        
        # PROJECT SUMMARY
        if report_data && report_data[:summary]
          summary = report_data[:summary]
          html += <<~HTML
            <div class="section">
            <h2>Project Summary</h2>
            <table>
              <thead><tr><th>Project Metric</th><th>Value</th></tr></thead>
              <tbody>
                <tr><td>Total Parts</td><td>#{summary[:total_parts_instances] || 0}</td></tr>
                <tr><td>Unique Components</td><td>#{summary[:total_unique_part_types] || 0}</td></tr>
                <tr><td>Material Sheets</td><td>#{summary[:total_boards] || 0}</td></tr>
                <tr><td>Kerf Width</td><td>#{summary[:kerf_width] || '3.0mm'}</td></tr>
                <tr><td>Material Efficiency</td><td>#{(summary[:overall_efficiency] || 0).round(1)}%</td></tr>
                <tr><td>Total Waste Area</td><td>#{summary[:total_waste_area_absolute] || '0 m²'}</td></tr>
                <tr><td class="total-highlight">Total Cost</td><td class="total-highlight">#{summary[:currency] || 'USD'} #{(summary[:total_project_cost] || 0).round(2)}</td></tr>
              </tbody>
            </table>
            </div>
          HTML
        end
        
        # MATERIALS USED
        if report_data && report_data[:unique_board_types]
          html += <<~HTML
            <div class="section">
            <h2>Materials Used</h2>
            <table>
              <thead><tr><th>Material Type</th><th>Sheets Required</th><th>Unit Cost</th><th>Total Cost</th></tr></thead>
              <tbody>
          HTML
          report_data[:unique_board_types].each do |board_type|
            html += "<tr><td>#{board_type[:material]}</td><td>#{board_type[:count]}</td><td>#{board_type[:currency] || 'USD'} #{(board_type[:price_per_sheet] || 0).round(2)}</td><td class=\"total-highlight\">#{board_type[:currency] || 'USD'} #{(board_type[:total_cost] || 0).round(2)}</td></tr>\n"
          end
          html += "</tbody></table></div>\n"
        end
        
        # UNIQUE PART TYPES
        if report_data && report_data[:unique_part_types]
          html += <<~HTML
            <div class="section">
            <h2>Unique Part Types</h2>
            <table>
              <thead><tr><th>Part Name</th><th>Width (mm)</th><th>Height (mm)</th><th>Thickness (mm)</th><th>Material</th><th>Grain</th><th>Qty</th><th>Area (m²)</th></tr></thead>
              <tbody>
          HTML
          report_data[:unique_part_types].each do |part|
            html += "<tr><td>#{part[:name]}</td><td>#{(part[:width] || 0).round(1)}</td><td>#{(part[:height] || 0).round(1)}</td><td>#{(part[:thickness] || 0).round(1)}</td><td>#{part[:material]}</td><td>#{part[:grain_direction] || 'Any'}</td><td class=\"total-highlight\">#{part[:total_quantity]}</td><td>#{(part[:total_area] / 1000000).round(2)}</td></tr>\n"
          end
          html += "</tbody></table></div>\n"
        end
        
        # SHEET INVENTORY SUMMARY
        if report_data && report_data[:unique_board_types]
          html += <<~HTML
            <div class="section">
            <h2>Sheet Inventory Summary</h2>
            <table>
              <thead><tr><th>Material</th><th>Dimensions (mm)</th><th>Count</th><th>Total Area (m²)</th><th>Price/Sheet</th><th>Total Cost</th></tr></thead>
              <tbody>
          HTML
          report_data[:unique_board_types].each do |board_type|
            width = board_type[:stock_width] || 2440
            height = board_type[:stock_height] || 1220
            html += "<tr><td>#{board_type[:material]}</td><td>#{width.round(1)} x #{height.round(1)}</td><td class=\"total-highlight\">#{board_type[:count]}</td><td>#{(board_type[:total_area] / 1000000).round(2)}</td><td>#{board_type[:currency] || 'USD'} #{(board_type[:price_per_sheet] || 0).round(2)}</td><td class=\"total-highlight\">#{board_type[:currency] || 'USD'} #{(board_type[:total_cost] || 0).round(2)}</td></tr>\n"
          end
          html += "</tbody></table></div>\n"
        end
        
        # CUTTING DIAGRAMS WITH IMAGES
        if diagrams_data && diagrams_data.length > 0
          html += "<div class='section new-page'><h2>Cutting Diagrams</h2>\n"
          diagrams_data.each_with_index do |board, idx|
            html += "<div class=\"diagram-section\">\n"
            html += "<h3>Sheet #{idx + 1}: #{board[:material] || board['material']}</h3>\n"
            html += "<p><strong>Efficiency:</strong> #{(board[:efficiency_percentage] || board['efficiency_percentage'] || 0).round(1)}% | <strong>Waste:</strong> #{(board[:waste_percentage] || board['waste_percentage'] || 0).round(1)}%</p>\n"
            
            # Embed captured diagram image if available
            diagram_img = diagram_images.find { |img| img[:index] == idx || img['index'] == idx }
            if diagram_img && (diagram_img[:image] || diagram_img['image'])
              image_data = diagram_img[:image] || diagram_img['image']
              html += "<img src=\"#{image_data}\" class=\"diagram-image\" alt=\"Cutting diagram for sheet #{idx + 1}\">\n"
            end
            
            html += "</div>\n"
          end
          html += "</div>\n"
        end
        
        # CUT SEQUENCES
        if report_data && report_data[:cut_sequences]
          html += "<div class='section new-page'><h2>Cut Sequences</h2>\n"
          report_data[:cut_sequences].each do |sequence|
            html += "<div class=\"cut-sequence\">\n"
            html += "<div class=\"cut-sequence-title\">#{sequence[:title]}</div>\n"
            if sequence[:stock_size]
              html += "<p style=\"margin: 5px 0; font-size: 9pt;\"><strong>Stock Size:</strong> #{sequence[:stock_size]}</p>\n"
            end
            if sequence[:steps] && sequence[:steps].length > 0
              html += "<table style=\"font-size: 9pt;\">\n"
              html += "<thead><tr><th>Step</th><th>Operation</th><th>Description</th><th>Measurement</th></tr></thead>\n"
              html += "<tbody>\n"
              sequence[:steps].each do |step|
                html += "<tr><td>#{step[:step]}</td><td>#{step[:operation]}</td><td>#{step[:description]}</td><td>#{step[:measurement]}</td></tr>\n"
              end
              html += "</tbody></table>\n"
            end
            html += "</div>\n"
          end
          html += "</div>\n"
        end
        
        # USABLE OFFCUTS
        if report_data && report_data[:usable_offcuts]
          html += <<~HTML
            <div class="section">
            <h2>Usable Offcuts</h2>
            <table>
              <thead><tr><th>Sheet #</th><th>Material</th><th>Estimated Size</th><th>Area (m²)</th></tr></thead>
              <tbody>
          HTML
          report_data[:usable_offcuts].each do |offcut|
            html += "<tr><td>#{offcut[:board_number]}</td><td>#{offcut[:material]}</td><td>#{offcut[:estimated_dimensions]}</td><td>#{offcut[:area_m2]}</td></tr>\n"
          end
          html += "</tbody></table></div>\n"
        end
        
        # ASSEMBLY VIEWS
        if assembly_data && assembly_data[:views]
          html += "<div class='section assembly-section new-page'>\n"
          html += "<h2>Assembly Views</h2>\n"
          html += "<div class=\"assembly-grid\">\n"
          
          assembly_data[:views].each do |view_name, view_image|
            html += "<div class=\"assembly-view\">\n"
            if view_image.is_a?(String) && view_image.start_with?('data:image')
              html += "<img src=\"#{view_image}\" alt=\"#{view_name} view\">\n"
            end
            html += "<div class=\"assembly-view-label\">#{view_name}</div>\n"
            html += "</div>\n"
          end
          
          html += "</div>\n"
          html += "</div>\n"
        end
        
        # CUT LIST & PART DETAILS
        if report_data && report_data[:parts_placed]
          html += <<~HTML
            <div class="section new-page">
            <h2>Cut List & Part Details</h2>
            <table style="font-size: 9pt;">
              <thead><tr><th>Part ID</th><th>Name</th><th>Dimensions (mm)</th><th>Material</th><th>Sheet #</th><th>Grain</th><th>Edge Banding</th></tr></thead>
              <tbody>
          HTML
          report_data[:parts_placed].each_with_index do |part, idx|
            part_id = part[:part_unique_id] || part[:instance_id] || "P#{idx + 1}"
            width = (part[:width] || 0).round(1)
            height = (part[:height] || 0).round(1)
            edge_banding = part[:edge_banding].is_a?(Hash) ? (part[:edge_banding][:type] || 'None') : (part[:edge_banding] || 'None')
            html += "<tr><td>#{part_id}</td><td>#{part[:name]}</td><td>#{width} x #{height}</td><td>#{part[:material]}</td><td>#{part[:board_number]}</td><td>#{part[:grain_direction] || 'Any'}</td><td>#{edge_banding}</td></tr>\n"
          end
          html += "</tbody></table></div>\n"
        end
        
        # FOOTER
        html += <<~HTML
          <div style="margin-top: 30px; padding-top: 15px; border-top: 1px solid #ddd; text-align: center; font-size: 9pt; color: #666;">
            <p>AutoNestCut Professional</p>
            <p>Developed by Int. Arch. M.Shkeir</p>
          </div>
              </div>
          </body>
          </html>
        HTML
        
        html
      end

      @dialog.add_action_callback("back_to_config") do |action_context|
        @dialog.execute_script("showConfigTab()")
      end

      @dialog.add_action_callback("load_default_materials") do |action_context|
        puts "DEBUG: Loading default materials."
        begin
          defaults = MaterialsDatabase.get_default_materials
          existing = MaterialsDatabase.load_database
          
          # CRITICAL: Merge defaults with existing (defaults don't override user materials)
          # Only add defaults that don't already exist
          merged = existing.merge(defaults)
          
          MaterialsDatabase.save_database(merged)
          puts "✅ Default materials loaded: #{defaults.length} defaults merged with #{existing.length} existing materials"
          
          send_initial_data # Refresh UI with merged materials
        rescue => e
          puts "ERROR loading defaults: #{e.message}"
          @dialog.execute_script("showError('Error loading defaults: #{e.message.gsub("'", "\\'")}')")
        end
      end

      @dialog.add_action_callback("refresh_materials_safe") do |action_context|
        puts "DEBUG: Safe refresh of materials requested."
        begin
          # Load current database state WITHOUT any modifications or auto-creation
          loaded_materials = MaterialsDatabase.load_database
          
          # Send to UI without any auto-creation or modification
          @dialog.execute_script("receiveMaterialsData(#{loaded_materials.to_json})")
          puts "✅ Materials refreshed from database (#{loaded_materials.length} materials)"
        rescue => e
          puts "ERROR refreshing materials: #{e.message}"
          @dialog.execute_script("showError('Error refreshing: #{e.message.gsub("'", "\\'")}')")
        end
      end

      @dialog.add_action_callback("import_materials_csv") do |action_context|
        puts "DEBUG: Importing materials CSV."
        file_path = UI.openpanel("Select Materials CSV File", "", "CSV Files|*.csv||")
        if file_path
          imported = MaterialsDatabase.import_csv(file_path)
          unless imported.empty?
            existing = MaterialsDatabase.load_database
            merged = existing.merge(imported)
            MaterialsDatabase.save_database(merged)
            send_initial_data # Refresh UI
            UI.messagebox("Imported #{imported.keys.length} materials successfully!")
          else
            UI.messagebox("No valid materials found in CSV file.")
          end
        end
      end

      @dialog.add_action_callback("export_materials_database") do |action_context|
        documents_path = Compatibility.documents_path
        filename = "AutoNestCut_Materials_Database_#{Time.now.strftime('%Y%m%d')}.csv"
        file_path = File.join(documents_path, filename)

        materials = MaterialsDatabase.load_database
        MaterialsDatabase.save_database(materials)

        require 'fileutils'
        FileUtils.cp(MaterialsDatabase.database_file, file_path)
        UI.messagebox("Materials database exported to Documents: #{filename}")
      end

      @dialog.add_action_callback("highlight_material") do |action_context, material_name|
        highlight_components_by_material(material_name)
      end

      @dialog.add_action_callback("clear_highlight") do |action_context|
        clear_component_highlight
      end

      @dialog.add_action_callback("purge_old_auto_materials") do |action_context|
        purge_old_auto_materials
      end

      @dialog.add_action_callback("refresh_config") do |action_context|
        puts "DEBUG: Frontend requested config refresh."
        # Invalidate cache when input components are refreshed, as parts_by_material will change
        @nesting_cache = {}
        @last_processed_cache_key = nil # Clear the last key too
        refresh_configuration_data
      end

      @dialog.add_action_callback("refresh_report") do |action_context|
        puts "DEBUG: Frontend requested report refresh."
        # This means recalculate report data with current settings, not re-nest the parts
        # Pass current settings to ensure the report reflects them (e.g., unit/currency changes)
        refresh_report_display_with_current_settings
      end
      
      @dialog.add_action_callback("cancel_processing") do |action_context|
        @processing_cancelled = true
        @dialog.execute_script("updateProgressOverlay('Cancelling process...', 0)")
      end
      
      @dialog.add_action_callback("clear_nesting_cache") do |action_context|
        @nesting_cache = {}
        @last_processed_cache_key = nil
        puts "Nesting cache cleared manually"
      end
      
      @dialog.add_action_callback("get_material_texture") do |action_context, material_name|
        begin
          puts "DEBUG: Texture requested for material: #{material_name}"
          
          # Handle "Default Material" case - skip texture loading
          if material_name == "Default Material" || material_name.nil? || material_name.empty?
            puts "DEBUG: Skipping texture for Default Material (no material assigned)"
            @dialog.execute_script("console.log('No material assigned to component - skipping texture');")
            next
          end
          
          model = Sketchup.active_model
          material = model.materials[material_name]
          
          if material
            puts "DEBUG: Material found: #{material.name}"
            puts "DEBUG: Material has texture: #{material.texture ? 'YES' : 'NO'}"
            puts "DEBUG: Material color: #{material.color}"
            puts "DEBUG: Material alpha: #{material.alpha}"
            
            # Prepare material properties
            material_props = {
              name: material.name,
              color: material.color.to_i & 0xFFFFFF,
              alpha: material.alpha,
              has_texture: material.texture ? true : false
            }
            
            if material.texture
              puts "DEBUG: Texture width: #{material.texture.width}"
              puts "DEBUG: Texture height: #{material.texture.height}"
              puts "DEBUG: Texture filename: #{material.texture.filename}"
              
              # Try to write texture to temp file
              temp_dir = File.join(ENV['TEMP'] || ENV['TMP'] || '/tmp', 'autonestcut_textures')
              Dir.mkdir(temp_dir) unless Dir.exist?(temp_dir)
              temp_file = File.join(temp_dir, "#{material.name.gsub(/[^\w]/, '_')}.png")
              
              success = material.texture.write(temp_file)
              puts "DEBUG: Texture write success: #{success}"
              
              if success && File.exist?(temp_file)
                require 'base64'
                image_data = File.binread(temp_file)
                base64_data = Base64.strict_encode64(image_data)
                
                data_uri = "data:image/png;base64,#{base64_data}"
                puts "DEBUG: Texture data URI length: #{data_uri.length}"
                
                material_props[:texture] = data_uri
                
                json_data = material_props.to_json
                @dialog.execute_script("if(window.applyMaterialToMesh){applyMaterialToMesh(#{json_data});}else{console.error('applyMaterialToMesh not defined');}")
                
                File.delete(temp_file) if File.exist?(temp_file)
              else
                puts "DEBUG: Failed to write texture to temp file"
                # Still send material properties without texture
                json_data = material_props.to_json
                @dialog.execute_script("if(window.applyMaterialToMesh){applyMaterialToMesh(#{json_data});}else{console.error('applyMaterialToMesh not defined');}")
              end
            else
              puts "DEBUG: Material has no texture, sending color/opacity only"
              # Send material properties without texture
              json_data = material_props.to_json
              @dialog.execute_script("if(window.applyMaterialToMesh){applyMaterialToMesh(#{json_data});}else{console.error('applyMaterialToMesh not defined');}")
            end
          else
            puts "DEBUG: Material not found: #{material_name}"
            @dialog.execute_script("console.log('Material not found: #{material_name}');")
          end
        rescue => e
          puts "ERROR loading material texture: #{e.message}"
          puts e.backtrace.join("\n")
          @dialog.execute_script("console.error('Texture load error: #{js_escape(e.message)}');")
        end
      end
      
      @dialog.add_action_callback("save_3d_snapshot") do |action_context, data_json|
        begin
          data = JSON.parse(data_json)
          image_data = data['image_data']
          filename = data['filename']
          
          # Remove data:image/png;base64, prefix
          image_data = image_data.sub(/^data:image\/png;base64,/, '')
          
          # Decode base64
          require 'base64'
          decoded_image = Base64.decode64(image_data)
          
          # Save to Documents folder
          documents_path = Compatibility.documents_path
          full_path = File.join(documents_path, filename)
          
          File.binwrite(full_path, decoded_image)
          puts "3D snapshot saved: #{full_path}"
          
          # Send success feedback to frontend
          @dialog.execute_script("showSnapshotSuccess('#{full_path.gsub('\\', '/')}')")
        rescue => e
          puts "ERROR saving 3D snapshot: #{e.message}"
          puts e.backtrace.join("\n")
        end
      end
      
      # Export technical drawings (views)
      @dialog.add_action_callback("export_technical_drawings") do |action_context|
        begin
          puts "DEBUG: Export technical drawings requested"
          
          # Show export UI with assembly data
          export_ui = ViewExportUI.new(@assembly_data)
          export_ui.show_export_dialog
        rescue => e
          puts "ERROR in export_technical_drawings: #{e.message}"
          puts e.backtrace.join("\n")
          UI.messagebox("Error opening export dialog: #{e.message}")
        end
      end
      
      # Handle export from ViewExportUI dialog
      @dialog.add_action_callback("export_views") do |action_context, params_json|
        begin
          params = JSON.parse(params_json)
          puts "DEBUG: Processing export with params: #{params.inspect}"
          
          # This callback is handled by ViewExportUI
          # Just log for debugging
        rescue => e
          puts "ERROR in export_views callback: #{e.message}"
        end
      end

      # Add callback for when dialog closes to trigger cleanup
      @dialog.add_action_callback("dialog_closing") do |action_context|
        puts "DEBUG: Dialog closing callback triggered"
        cleanup
      end
      
      # Also set up a timer to detect if dialog was closed without callback
      UI.start_timer(5, true) do
        if @dialog && !@dialog.respond_to?(:visible?) 
          cleanup
        elsif @dialog && @dialog.respond_to?(:visible?) && !@dialog.visible?
          cleanup
        end
      end

      @dialog.show
    end

    private

    # Helper method to recursively convert all strings in a data structure to UTF-8
    def deep_encode_utf8(obj)
      case obj
      when String
        # Force encoding to UTF-8, replacing invalid characters
        obj.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      when Hash
        obj.transform_keys { |k| deep_encode_utf8(k) }
           .transform_values { |v| deep_encode_utf8(v) }
      when Array
        obj.map { |item| deep_encode_utf8(item) }
      else
        obj
      end
    end

    # CRITICAL: Remap components to auto-created materials if they exceed standard material dimensions
    # DETERMINISTIC AUTO-MATERIAL BINDING SYSTEM
    # Binds components to auto-created materials based on exact dimension matching
    # Formula: Auto_user_W{componentWidth+10}xH{componentHeight+10}xTH{componentThickness}_(SketchUpMaterialName)
    def bind_components_to_auto_materials(parts_by_material, loaded_materials)
      # Deterministic binding of components to auto-materials
      auto_materials = loaded_materials.select { |name, _| name.start_with?('Auto_user_') || name.start_with?('no_material_') }
      
      remapped = {}
      
      parts_by_material.each do |original_material_name, part_entries|
        part_entries.each do |part_entry|
          # Extract Part object
          part_obj = if part_entry.is_a?(Hash) && part_entry.key?(:part_type)
                       part_entry[:part_type]
                     else
                       part_entry
                     end
          
          next unless part_obj.respond_to?(:width) && part_obj.respond_to?(:height) && part_obj.respond_to?(:thickness)
          
          part_width = part_obj.width.to_f
          part_height = part_obj.height.to_f
          part_thickness = part_obj.thickness.to_f
          
          # Check if an auto-material was created for this exact component
          target_material = nil
          auto_materials.each do |auto_mat_name, auto_mat_data|
            auto_width = auto_mat_data['width'].to_f
            auto_height = auto_mat_data['height'].to_f
            auto_thickness = auto_mat_data['thickness'].to_f
            
            # Check if this auto-material matches this component's dimensions
            if (part_width - auto_width).abs < 0.1 && (part_height - auto_height).abs < 0.1 && (part_thickness - auto_thickness).abs < 0.1
              target_material = auto_mat_name
              break
            end
          end
          
          # If no auto-material found, keep original material
          if target_material.nil?
            target_material = original_material_name
          end
          
          remapped[target_material] ||= []
          remapped[target_material] << part_entry
        end
      end
      
      remapped
    end
    
    # Generate auto-material name using deterministic formula
    def generate_auto_material_name(width, height, thickness, sketchup_material_name)
      # Formula: Auto_user_W{componentWidth+10}xH{componentHeight+10}xTH{componentThickness}_(SketchUpMaterialName)
      width_padded = (width + 10).round(0)
      height_padded = (height + 10).round(0)
      thickness_rounded = thickness.round(0)
      
      sanitized_material = sketchup_material_name.to_s.strip
      sanitized_material = 'unknown' if sanitized_material.empty?
      
      "Auto_user_W#{width_padded}xH#{height_padded}xTH#{thickness_rounded}_(#{sanitized_material})"
    end

    # This ensures nesting uses the correct material dimensions for oversized components
    def remap_components_to_auto_materials(parts_by_material, loaded_materials)
      # Delegate to the new deterministic binding system
      bind_components_to_auto_materials(parts_by_material, loaded_materials)
    end

    # Capture assembly data from the assembly entity using ReportGenerator
    def capture_assembly_data(assembly_entity)
      return nil unless assembly_entity
      
      begin
        report_generator = ReportGenerator.new
        assembly_data = report_generator.capture_assembly_data(assembly_entity)
        return assembly_data
      rescue => e
        puts "DEBUG: Error capturing assembly data: #{e.message}"
        puts e.backtrace.join("\n")
        return nil
      end
    end

    # Helper method to escape strings for safe JavaScript execution
    def js_escape(str)
      return '' if str.nil?
      str.to_s
         .gsub('\\', '\\\\')
         .gsub("\n", '\\n')
         .gsub("\r", '')
         .gsub("'", "\\'")  
         .gsub('"', '\\"')
    end

    def validate_with_smart_limits(parts_by_material, settings)
      blocked_parts = []
      warnings = []
      auto_create = settings['auto_create_materials'] != false
      
      parts_by_material.each do |material_name, part_types|
        part_types.each do |part_entry|
          part_obj = part_entry.is_a?(Hash) ? part_entry[:part_type] : part_entry
          next unless part_obj.respond_to?(:width) && part_obj.respond_to?(:height) && part_obj.respond_to?(:thickness)
          
          width = part_obj.width.to_f
          height = part_obj.height.to_f
          thickness = part_obj.thickness.to_f
          
          # Extreme limits - block unrealistic cases
          if width > 10000 || height > 10000
            blocked_parts << "#{part_obj.name}: #{width.round(0)}x#{height.round(0)}mm is too large (max 10,000mm)"
          elsif width < 1 || height < 1
            blocked_parts << "#{part_obj.name}: #{width.round(1)}x#{height.round(1)}mm is too small (min 1mm)"
          elsif thickness > 500
            blocked_parts << "#{part_obj.name}: #{thickness.round(0)}mm thick - not a sheet material (max 500mm)"
          elsif thickness < 0.1
            blocked_parts << "#{part_obj.name}: #{thickness.round(2)}mm thick - too thin (min 0.1mm)"
          end
        end
        
        # Check material availability if auto-create is disabled
        unless auto_create
          unless settings['stock_materials'].key?(material_name)
            warnings << "Material '#{material_name}' not in database. Enable 'Auto-create materials' or add to materials list."
          end
        end
      end
      
      if blocked_parts.any?
        msg = "Cannot process the following components:\n\n"
        blocked_parts.each { |p| msg += "• #{p}\n" }
        msg += "\nThese dimensions are outside realistic sheet cutting limits."
        return { blocked: true, message: msg, warnings: [] }
      end
      
      { blocked: false, warnings: warnings }
    end

    # Sends all initial data (settings, parts, materials, etc.) to the frontend
    def send_initial_data
      # STAGE 1: VALIDATE AND AUTO-CREATE MATERIALS AT LAUNCH (unless already validated)
      if @skip_validation
        puts "\n=== STAGE 1: SKIPPING VALIDATION (materials already resolved) ==="
      else
        puts "\n=== STAGE 1: COMPONENT VALIDATION & AUTO-MATERIAL CREATION ==="
        validator = ComponentValidator.new
        validation_result = validator.validate_and_prepare_materials(@parts_by_material)
        
        if !validation_result[:success]
          # Show validation errors to user
          error_msg = "Component Validation Errors:\n\n"
          validation_result[:errors].each { |err| error_msg += "• #{err}\n" }
          UI.messagebox(error_msg)
          puts "ERROR: Validation failed - #{validation_result[:errors].inspect}"
          return
        end
        
        # Show warnings if any
        if validation_result[:warnings].any?
          warning_msg = "Component Validation Warnings:\n\n"
          validation_result[:warnings].each { |warn| warning_msg += "• #{warn}\n" }
          puts "WARNINGS: #{warning_msg}"
        end
        
        # Show info about auto-created materials
        if validation_result[:materials_created].any?
          created_msg = "Auto-Created Materials:\n\n"
          validation_result[:materials_created].each do |mat|
            created_msg += "✓ #{mat[:name]}\n  Dimensions: #{mat[:dimensions]}\n\n"
          end
          created_msg += "These materials are flagged as auto-generated.\nYou can rename them in the configuration window."
          puts "INFO: #{created_msg}"
        end
        
        puts "=== STAGE 1 COMPLETE ===\n"
      end
      
      # STAGE 2: LOAD MATERIALS AND PREPARE UI
      # CRITICAL: Reload materials from database to get the newly created ones
      # This ensures the UI and nesting engine use the correct material dimensions
      puts "DEBUG: Reloading materials database to include auto-created materials..."
      loaded_materials = MaterialsDatabase.load_database
      puts "DEBUG: Loaded #{loaded_materials.length} materials from database"
      puts "DEBUG: Auto-created materials in database: #{loaded_materials.select { |k, _| k.start_with?('Auto_user_') }.keys.inspect}"
      
      # CRITICAL: BIND COMPONENTS TO AUTO-MATERIALS IMMEDIATELY
      # This ensures parts_by_material references the correct auto-materials before serialization
      @parts_by_material = bind_components_to_auto_materials(@parts_by_material, loaded_materials)
      
      # Get current global settings from a configuration manager (e.g., Config.rb)
      current_settings = Config.get_cached_settings

      # CRITICAL: Flatten materials array format for frontend compatibility
      # Frontend expects: { "Material_Name": { width, height, thickness, ... } }
      # Backend stores: { "Material_Name": [{ width, height, thickness, ... }, ...] }
      # Solution: Create unique keys for each thickness variation
      flattened_materials = {}
      loaded_materials.each do |name, data|
        # Handle both array (new format) and hash (legacy format)
        thickness_variations = data.is_a?(Array) ? data : [data]
        
        if thickness_variations.length == 1
          # Single thickness - use original name
          flattened_materials[name] = thickness_variations[0]
        else
          # Multiple thicknesses - create unique keys with thickness suffix
          thickness_variations.each do |variation|
            thickness_mm = variation['thickness'].to_f.round(0)
            unique_key = "#{name}_#{thickness_mm}mm"
            flattened_materials[unique_key] = variation.merge('original_name' => name)
          end
        end
      end
      
      current_settings['stock_materials'] = flattened_materials

      # Auto-load detected materials into stock_materials for UI display if they don't exist
      # Group by material+thickness and use smart naming
      @parts_by_material.each do |material_name, part_types|
        first_part_entry = part_types.first
        
        part_obj_from_entry = nil
        if first_part_entry.is_a?(Hash) && first_part_entry.key?(:part_type)
          part_obj_from_entry = first_part_entry[:part_type]
        else
          part_obj_from_entry = first_part_entry
        end

        next unless part_obj_from_entry.respond_to?(:thickness)
        next unless part_obj_from_entry.respond_to?(:width)
        next unless part_obj_from_entry.respond_to?(:height)
        
        thickness_val = part_obj_from_entry.thickness
        width_val = part_obj_from_entry.width.to_f
        height_val = part_obj_from_entry.height.to_f
        
        # Smart material naming - never use "No Material"
        display_name = if material_name.nil? || material_name.empty? || material_name.downcase == 'no material'
          if thickness_val < 0.8
            "Thin Sheet (#{thickness_val.round(1)}mm)"
          elsif thickness_val <= 1.2
            "Standard Sheet (#{thickness_val.round(1)}mm)"
          else
            "Sheet Material (#{thickness_val.round(1)}mm)"
          end
        else
          # Group by material+thickness: "Oak (18mm)", "Glass (6mm)"
          "#{material_name} (#{thickness_val.round(1)}mm)"
        end
        
        # CRITICAL: Only add if NOT already in stock_materials (to preserve auto-created materials with custom dimensions)
        unless current_settings['stock_materials'].key?(display_name)
          # Check if this material has an auto-created variant with SAME base material AND SAME thickness
          # Extract base material name from display_name (e.g., "Metal_Corrogated_Shiny" from "Metal_Corrogated_Shiny (18.0mm)")
          base_material_match = display_name.match(/^(.+?)\s*\([\d.]+mm\)$/)
          base_material_name = base_material_match ? base_material_match[1] : material_name
          
          # Look for auto-materials that match this specific base material + thickness combination
          # Format: Auto_user_W{W}xH{H}xTH{TH}_(BaseMaterialName)
          matching_auto_variant = current_settings['stock_materials'].select do |k, v|
            next unless k.start_with?('Auto_user_') || k.start_with?('no_material_')
            
            # Extract the base material name from the auto-material name
            # Format: Auto_user_W232xH348xTH8_(Blue_Glass_Shelf)
            auto_base_match = k.match(/\(([^)]+)\)$/)
            auto_base_name = auto_base_match ? auto_base_match[1] : nil
            
            # Extract thickness from auto-material name
            # Format: Auto_user_W232xH348xTH8_(...)
            auto_thickness_match = k.match(/TH([\d.]+)_/)
            auto_thickness = auto_thickness_match ? auto_thickness_match[1].to_f : nil
            
            # Only skip if BOTH base material AND thickness match
            auto_base_name == base_material_name && auto_thickness && (auto_thickness - thickness_val).abs <= 1.0
          end.first
          
          if matching_auto_variant
            # Auto-created material exists for THIS specific material+thickness - don't override it
            puts "DEBUG: Skipping default material creation for '#{display_name}' - matching auto-variant exists: #{matching_auto_variant[0]}"
            next
          end
          
          # No matching auto-variant exists - create with standard dimensions
          current_settings['stock_materials'][display_name] = {
            'width' => 2440,
            'height' => 1220,
            'thickness' => thickness_val,
            'price' => 0,
            'currency' => current_settings['default_currency'] || 'USD',
            'auto_generated' => true
          }
        end
      end
      # Save these potentially new materials to the database so they persist
      MaterialsDatabase.save_database(current_settings['stock_materials'])

      # Combine initial data for frontend
      initial_data = {
        settings: current_settings, # Contains global settings (units, currency, etc.) and stock_materials
        parts_by_material: serialize_parts_by_material(@parts_by_material),
        original_components: @original_components,
        model_materials: get_model_materials, # Materials from SketchUp model
        hierarchy_tree: @hierarchy_tree,
        assembly_data: @assembly_data # Add assembly data for 3D viewer
      }
      
      script = "receiveInitialData(#{initial_data.to_json}); if(window.assemblyData) { console.log('Assembly data set:', window.assemblyData); }"
      @dialog.execute_script(script)
    rescue => e
      puts "ERROR in send_initial_data: #{e.message}"
      puts e.backtrace
      @dialog.execute_script("showError('Error loading initial data: #{e.message.gsub("'", "\\'")}')")
    end

    # ======================================================================================
    # CACHE MANAGEMENT HELPERS
    # ======================================================================================
    
    # Validates cached boards data
    def validate_cached_boards(boards)
      return false if boards.nil?
      return false unless boards.is_a?(Array)
      return false if boards.empty?
      
      # Verify each board is valid
      boards.all? { |board| board.respond_to?(:material) && board.respond_to?(:parts) }
    end
    
    # Gets cached boards with thread safety and validation
    def get_cached_boards(cache_key)
      cache_start = Time.now
      puts "DEBUG: [get_cached_boards] Checking cache for key: #{cache_key[0..8]}..."
      
      result = @cache_mutex.synchronize do
        cache_entry = @nesting_cache[cache_key]
        
        if cache_entry.nil?
          puts "DEBUG: [get_cached_boards] Cache miss, took #{((Time.now - cache_start) * 1000).round(1)}ms"
          return nil
        end
        
        boards = cache_entry[:boards]
        
        # Validate cached data
        validate_start = Time.now
        unless validate_cached_boards(boards)
          puts "WARNING: Invalid cached data for key #{cache_key}, removing from cache"
          @nesting_cache.delete(cache_key)
          puts "DEBUG: [get_cached_boards] Validation failed, took #{((Time.now - cache_start) * 1000).round(1)}ms"
          return nil
        end
        validate_time = ((Time.now - validate_start) * 1000).round(1)
        puts "DEBUG: [get_cached_boards] Validation took #{validate_time}ms"
        
        # Update access time for LRU
        cache_entry[:access_time] = Time.now
        
        total_time = ((Time.now - cache_start) * 1000).round(1)
        puts "✓ Cache hit for key: #{cache_key[0..8]}... (#{boards.length} boards) - took #{total_time}ms"
        boards
      end
      
      result
    end
    
    # Stores boards in cache with thread safety and LRU eviction
    def store_cached_boards(cache_key, boards)
      @cache_mutex.synchronize do
        # Validate before storing
        unless validate_cached_boards(boards)
          puts "WARNING: Attempted to cache invalid boards data, skipping"
          return
        end
        
        # Store with metadata
        @nesting_cache[cache_key] = {
          boards: boards,
          timestamp: Time.now,
          access_time: Time.now
        }
        
        puts "✓ Nesting results cached for key: #{cache_key[0..8]}... (#{boards.length} boards)"
        
        # Enforce cache size limit with LRU eviction
        if @nesting_cache.size > MAX_CACHE_SIZE
          # Find least recently accessed entry
          lru_key = @nesting_cache.min_by { |k, v| v[:access_time] }[0]
          @nesting_cache.delete(lru_key)
          puts "⚠ Cache size limit reached, evicted LRU entry: #{lru_key[0..8]}..."
        end
        
        puts "📊 Cache stats: #{@nesting_cache.size}/#{MAX_CACHE_SIZE} entries"
      end
    end
    
    # Clears the nesting cache with thread safety
    def clear_nesting_cache
      @cache_mutex.synchronize do
        cache_size = @nesting_cache.size
        @nesting_cache.clear
        @last_processed_cache_key = nil
        puts "🗑 Nesting cache cleared (#{cache_size} entries removed)"
      end
    end

    # ======================================================================================
    # ASYNCHRONOUS NESTING PROCESSING WITH CACHING
    # ======================================================================================

    # Queue for communication between background thread and UI thread
    @nesting_queue = nil
    # Reference to the background thread
    @nesting_thread = nil
    # Reference to the UI timer for watching the queue
    @nesting_watcher_timer = nil

    # Store the cache key of the last successfully processed nesting
    @last_processed_cache_key = nil

    # Generates a unique, stable hash key for the given parts and settings
    def generate_cache_key(parts_by_material_hash, settings)
      key_start = Time.now
      puts "DEBUG: [generate_cache_key] Starting cache key generation..."
      
      # Return a distinct key for empty parts to avoid accidental cache hits
      if parts_by_material_hash.nil? || parts_by_material_hash.empty?
        result = Digest::MD5.hexdigest("EMPTY_PARTS_#{Time.now.to_i}")
        puts "DEBUG: [generate_cache_key] Empty parts, took #{((Time.now - key_start) * 1000).round(1)}ms"
        return result
      end

      # Create a canonical representation of parts_by_material
      serialize_start = Time.now
      serialized_parts = parts_by_material_hash.map do |material, parts_array|
        [material.to_s, parts_array.map do |part_entry|
          part_type = part_entry.is_a?(Hash) && part_entry.key?(:part_type) ? part_entry[:part_type] : part_entry
          {
            name: part_type.name.to_s,
            width: part_type.width.to_f,
            height: part_type.height.to_f,
            thickness: part_type.thickness.to_f, # Include thickness in cache key
            total_quantity: (part_entry[:total_quantity] || 1).to_i
          }
        end.sort_by { |p| [p[:name], p[:width], p[:height], p[:thickness], p[:total_quantity]] }]
      end.sort_by(&:first).to_json
      serialize_time = ((Time.now - serialize_start) * 1000).round(1)
      puts "DEBUG: [generate_cache_key] Serialization took #{serialize_time}ms"

      # Extract only nesting-relevant settings that affect the *nesting pattern* or *outcome*
      settings_start = Time.now
      nesting_stock_materials = if settings['stock_materials']
                                  settings['stock_materials'].transform_values do |material_data|
                                    material_data.reject { |k, _v| k == 'price' || k == 'currency' } # Remove price and currency from cache key
                                  end
                                else
                                  {}
                                end

      nesting_settings = {
        'stock_materials' => nesting_stock_materials,
        'kerf_width' => settings['kerf_width'],
        'allow_rotation' => settings['allow_rotation']
        # Add any other settings from Config that directly influence the nesting result
      }.to_json
      settings_time = ((Time.now - settings_start) * 1000).round(1)
      puts "DEBUG: [generate_cache_key] Settings processing took #{settings_time}ms"

      # Combine and hash
      hash_start = Time.now
      result = Digest::MD5.hexdigest(serialized_parts + nesting_settings)
      hash_time = ((Time.now - hash_start) * 1000).round(1)
      
      total_time = ((Time.now - key_start) * 1000).round(1)
      puts "DEBUG: [generate_cache_key] Hash generation took #{hash_time}ms"
      puts "DEBUG: [generate_cache_key] TOTAL TIME: #{total_time}ms"
      
      result
    end

    def process_with_async_nesting(settings)
      @processing_cancelled = false # Reset cancellation flag at the start of a new process

      @dialog.execute_script("showProgressOverlay('Preparing optimization...', 0)")

      @settings = settings # Store current settings for report generation later
      @boards = [] # Clear previous boards data

      # Initialize communication queue and thread references
      @nesting_queue = Queue.new
      @nesting_thread = nil
      @nesting_watcher_timer = nil

      current_cache_key = generate_cache_key(@parts_by_material, settings)
      cache_start_time = Time.now

      # Try to get cached boards with thread safety and validation
      cached_boards = get_cached_boards(current_cache_key)

      if cached_boards
        # --- CACHE HIT ---
        cache_elapsed = ((Time.now - cache_start_time) * 1000).round(1)
        puts "⚡ Cache retrieval took #{cache_elapsed}ms"
        
        @dialog.execute_script("updateProgressOverlay('Using cached results...', 10)")
        @last_processed_cache_key = current_cache_key

        # Simulate quick completion with a very short timer to allow UI update
        UI.start_timer(0.01, false) do
          generate_report_and_show_tab(cached_boards)
          @dialog.execute_script("hideProgressOverlay()")
        end
      else
        # --- CACHE MISS ---
        puts "✗ Cache miss for key: #{current_cache_key[0..8]}..."
        puts "="*80
        puts "DEBUG: RUNNING NESTING ON MAIN THREAD (NO THREADING)"
        puts "="*80
        
        # Run nesting synchronously on main thread for debugging
        run_nesting_synchronously(current_cache_key)
      end
    end
    
    # Run nesting synchronously on main thread (for debugging)
    def run_nesting_synchronously(cache_key)
      begin
        puts "DEBUG: Starting synchronous nesting..."
        
        # FORCE USE RUBY NESTER - C++ integration has bugs with part duplication
        puts "="*80
        puts "✓ USING RUBY NESTER (Reliable & Accurate)"
        puts "="*80
        nester = Nester.new
        
        progress_callback = lambda do |message, percentage|
          @dialog.execute_script("updateProgressOverlay('#{message}', #{percentage})")
        end
        
        @dialog.execute_script("updateProgressOverlay('Starting optimization...', 5)")
        
        boards_result = nester.optimize_boards(@parts_by_material, @settings, progress_callback)
        
        puts "DEBUG: Nesting complete, #{boards_result.length} boards"
        
        # Store in cache
        store_cached_boards(cache_key, boards_result)
        @last_processed_cache_key = cache_key
        
        # Generate report
        generate_report_and_show_tab(boards_result)
        @dialog.execute_script("hideProgressOverlay()")
        
      rescue => e
        puts "ERROR: Synchronous nesting failed: #{e.message}"
        puts e.backtrace.join("\n")
        @dialog.execute_script("hideProgressOverlay()")
        @dialog.execute_script("alert('Nesting failed: #{e.message}')")
      end
    end

    # Starts the heavy nesting computation in a separate background thread
    def start_nesting_background_thread(cache_key)
      puts "DEBUG: [start_nesting_background_thread] Preparing thread data..."
      thread_prep_start = Time.now
      
      # CRITICAL: Serialize ALL data BEFORE creating the thread
      # SketchUp objects cannot be accessed from background threads!
      puts "DEBUG: Serializing parts_by_material for thread safety..."
      serialize_start = Time.now
      
      parts_by_material_for_thread = {}
      @parts_by_material.each do |material, types_and_quantities|
        parts_by_material_for_thread[material] = types_and_quantities.map do |entry|
          part_type = entry[:part_type]
          {
            part_type: part_type, # Keep the Part object reference (it's already serialized)
            total_quantity: entry[:total_quantity]
          }
        end
      end
      
      serialize_time = ((Time.now - serialize_start) * 1000).round(1)
      puts "DEBUG: Serialization took #{serialize_time}ms"
      
      settings_for_thread = @settings.dup
      
      thread_prep_time = ((Time.now - thread_prep_start) * 1000).round(1)
      puts "DEBUG: [start_nesting_background_thread] Thread data prep took #{thread_prep_time}ms"
      puts "DEBUG: [start_nesting_background_thread] Creating thread NOW..."

      @nesting_thread = Thread.new do
        begin
          thread_start = Time.now
          puts "\n" + "="*80
          puts "DEBUG: NESTING THREAD STARTED AT #{Time.now}"
          puts "="*80
          
          # Try to use C++ nester if available, fallback to Ruby
          puts "DEBUG: Attempting to load cpp_nester..."
          load_start = Time.now
          begin
            require_relative '../processors/cpp_nester'
            load_time = ((Time.now - load_start) * 1000).round(1)
            puts "DEBUG: cpp_nester loaded in #{load_time}ms"
            
            check_start = Time.now
            use_cpp = CppNester.available?
            check_time = ((Time.now - check_start) * 1000).round(1)
            puts "DEBUG: C++ availability check took #{check_time}ms"
          rescue LoadError => e
            puts "DEBUG: Failed to load cpp_nester: #{e.message}"
            use_cpp = false
          rescue => e
            puts "DEBUG: Error checking C++ availability: #{e.message}"
            puts "DEBUG: Backtrace: #{e.backtrace.first(3).join("\n")}"
            use_cpp = false
          end
          
          puts "DEBUG: C++ solver available? #{use_cpp}"
          
          nester_create_start = Time.now
          if use_cpp
            puts "="*80
            puts "DEBUG: ✓✓✓ USING C++ NESTER (HIGH-PERFORMANCE MODE) ✓✓✓"
            puts "="*80
            nester = CppNester.new
          else
            puts "="*80
            puts "DEBUG: ✗✗✗ USING RUBY NESTER (SLOW MODE) ✗✗✗"
            puts "="*80
            nester = Nester.new
          end
          nester_create_time = ((Time.now - nester_create_start) * 1000).round(1)
          puts "DEBUG: Nester object created in #{nester_create_time}ms"
          
          boards_result = []
          
          nester_progress_callback = lambda do |message, percentage|
            unless @processing_cancelled
              @nesting_queue.push({ type: :progress, message: message, percentage: percentage })
            end
          end

          @nesting_queue.push({ type: :progress, message: "Starting optimization...", percentage: 5 })
          
          puts "DEBUG: Calling nester.optimize_boards NOW..."
          optimize_start = Time.now
          boards_result = nester.optimize_boards(parts_by_material_for_thread, settings_for_thread, nester_progress_callback)
          optimize_time = ((Time.now - optimize_start) * 1000).round(1)
          puts "DEBUG: optimize_boards completed in #{optimize_time}ms"
          
          if @processing_cancelled
            @nesting_queue.push({ type: :cancelled })
          else
            @nesting_queue.push({ type: :complete, boards: boards_result, cache_key: cache_key })
          end
          
          total_thread_time = ((Time.now - thread_start) * 1000).round(1)
          puts "DEBUG: Total thread execution time: #{total_thread_time}ms"

        rescue StandardError => e
          puts "Background nesting thread error: #{e.message}\n#{e.backtrace.join("\n")}"
          @nesting_queue.push({ type: :error, message: "Nesting calculation failed: #{e.message}" })
        end
      end
      
      puts "DEBUG: [start_nesting_background_thread] Thread created and started"
    end

    # Starts a UI timer to periodically check the queue for messages from the background thread
    def start_nesting_progress_watcher
      @nesting_start_time = Time.now
      @nesting_timeout = 600 # 10 minutes timeout
      @last_progress_update = Time.now
      
      puts "DEBUG: Starting nesting progress watcher at #{@nesting_start_time}"
      
      @nesting_watcher_timer = UI.start_timer(0.25, true) do
        # Check for timeout
        elapsed = Time.now - @nesting_start_time
        if elapsed > @nesting_timeout
          puts "ERROR: Nesting process timeout after #{elapsed.round(1)} seconds"
          finalize_nesting_process
          @dialog.execute_script("hideProgressOverlay()")
          @dialog.execute_script("showError('Nesting process timed out after 10 minutes. Please try with fewer components or simpler settings.')")
          return
        end
        
        process_queue_message # Process one message at a time to prevent blocking
      end
    end

    # Processes a single message from the queue on the main UI thread
    def process_queue_message
      return unless @nesting_queue
      return if @nesting_queue.empty?

      begin
        message = @nesting_queue.pop(true)
        
        puts "DEBUG: Queue message received - Type: #{message[:type]}, Time: #{Time.now.strftime('%H:%M:%S.%3N')}"

        case message[:type]
        when :progress
          pct = message[:percentage].clamp(0, 100)
          elapsed = Time.now - @nesting_start_time
          puts "DEBUG: Progress update - #{pct}% (#{message[:message]}) - Elapsed: #{elapsed.round(1)}s"
          @dialog.execute_script("updateProgressOverlay('#{message[:message].gsub("'", "\\'")}', #{pct})")
          @last_progress_update = Time.now
          
        when :error
          elapsed = Time.now - @nesting_start_time
          puts "ERROR: Nesting error after #{elapsed.round(1)}s - #{message[:message]}"
          finalize_nesting_process
          @dialog.execute_script("hideProgressOverlay()")
          @dialog.execute_script("showError('#{message[:message].gsub("'", "\\'")}')")
          
        when :cancelled
          elapsed = Time.now - @nesting_start_time
          puts "DEBUG: Nesting cancelled after #{elapsed.round(1)}s"
          finalize_nesting_process
          @dialog.execute_script("hideProgressOverlay()")
          @dialog.execute_script("showError('Nesting process cancelled by user.')") # Changed to showError for explicit feedback
          
        when :complete
          elapsed = Time.now - @nesting_start_time
          puts "DEBUG: Nesting complete after #{elapsed.round(1)}s"
          @dialog.execute_script("updateProgressOverlay('All nesting calculations complete. Preparing reports...', 90)")
          
          finalize_nesting_process 

          @boards = message[:boards]
          @last_processed_cache_key = message[:cache_key]

          # Store in cache with thread safety, validation, and LRU eviction
          if message[:cache_key] && @boards && !@boards.empty?
            store_cached_boards(message[:cache_key], @boards)
          end
          
          UI.start_timer(0.01, false) do
            generate_report_and_show_tab(@boards)
          end
        end
      rescue ThreadError => e
        # Ignore, just means no message was available this tick.
        puts "DEBUG: ThreadError (expected if queue empty): #{e.message}"
      rescue => e
        puts "ERROR in process_queue_message: #{e.message}"
        puts e.backtrace.join("\n")
      end
    end

    # Cleans up the background thread and UI timer
    def finalize_nesting_process
      if @nesting_watcher_timer && (defined?(UI.valid_timer?) ? UI.valid_timer?(@nesting_watcher_timer) : true)
        UI.stop_timer(@nesting_watcher_timer)
      end
      @nesting_watcher_timer = nil

      if @nesting_thread && @nesting_thread.alive?
        @nesting_thread.kill
        @nesting_thread.join
      end
      @nesting_thread = nil

      @nesting_queue.clear if @nesting_queue
      @nesting_queue = nil

      @processing_cancelled = false
    end

    # Generates the report data and displays the report tab in the dialog
    def generate_report_and_show_tab(boards)
      @dialog.execute_script("updateProgressOverlay('Generating reports...', 95)")

      if boards.empty?
        @dialog.execute_script("hideProgressOverlay()")
        @dialog.execute_script("showError('General failure: No boards could be generated. Check material settings and part dimensions. Ensure all components fit within sheet width, height, and thickness.')")
        return
      end

      # Perform actual report data generation (passing the current @settings)
      report_generator = ReportGenerator.new
      report_data = report_generator.generate_report_data(boards, @settings)

      # Capture assembly data if entity is available
      assembly_data = nil
      if @assembly_entity
        begin
          assembly_data = report_generator.capture_assembly_data(@assembly_entity)
          puts "DEBUG: Assembly data captured for display: #{assembly_data.keys.inspect if assembly_data}"
        rescue => e
          puts "WARNING: Failed to capture assembly data for display: #{e.message}"
        end
      end

      # Prepare data for dialog - include assembly_data in the JSON
      data = {
        diagrams: boards.map(&:to_h), # Assuming Board objects have a to_h method
        report: report_data,
        original_components: @original_components,
        hierarchy_tree: @hierarchy_tree,
        assembly_data: assembly_data  # Include assembly data for export
      }

      @dialog.execute_script("updateProgressOverlay('Finalizing...', 100)")
      @dialog.execute_script("hideProgressOverlay()")
      @dialog.execute_script("showReportTab(#{data.to_json})")
    rescue StandardError => e
      puts "ERROR in generate_report_and_show_tab: #{e.message}"
      puts e.backtrace
      @dialog.execute_script("hideProgressOverlay()")
      @dialog.execute_script("showError('Error generating report: #{e.message.gsub("'", "\\'")}')")
    end

    # ======================================================================================
    # END ASYNCHRONOUS NESTING PROCESSING
    # ======================================================================================

    def serialize_parts_by_material(parts_by_material_hash)
      result = {}
      parts_by_material_hash.each do |material, parts|
        result[material] = parts.map do |part_entry|
          # Robustly extract Part object
          part_type_obj = nil
          total_quantity = 1
          
          if part_entry.is_a?(Hash) && part_entry.key?(:part_type)
            part_type_obj = part_entry[:part_type]
            total_quantity = part_entry[:total_quantity] || 1
          elsif part_entry.is_a?(AutoNestCut::Part)
            part_type_obj = part_entry
            total_quantity = 1
          end

          if part_type_obj.is_a?(AutoNestCut::Part)
            serialized = {
              name: part_type_obj.name || 'Unnamed Part',
              width: part_type_obj.width || 0,
              height: part_type_obj.height || 0,
              thickness: part_type_obj.thickness || 0,
              material: material,  # CRITICAL: Include the bound material name
              total_quantity: total_quantity
            }
            serialized
          else
            nil # Return nil to filter out invalid entries
          end
        end.compact # Remove nil entries
      end
      result
    end

    def get_model_materials
      materials = []
      Sketchup.active_model.materials.each do |material|
        materials << {
          name: material.display_name || material.name,
          color: material.color ? material.color.to_a[0..2] : [200, 200, 200]
        }
      end
      materials
    end

    def highlight_components_by_material(material_name)
      model = Sketchup.active_model
      selection = model.selection
      selection.clear

      matching_entities = []

      if @original_components && !@original_components.empty?
        @original_components.each do |comp_data|
          # Use string comparison for material names
          if comp_data[:material].to_s.strip.downcase == material_name.to_s.strip.downcase
            found_entity = find_entity_by_id(model, comp_data[:entity_id])
            if found_entity
              matching_entities << found_entity
            end
          end
        end
      end
      
      model.selection.add(matching_entities)

      if matching_entities.any?
        view = model.active_view
        view.zoom(matching_entities)
      else
        puts "DEBUG: No components found with material: #{material_name}"
        UI.messagebox("No components found with material: #{material_name}")
      end
    end

    # Helper method to find an entity by its ID recursively in the model
    def find_entity_by_id(model, entity_id)
      return nil unless entity_id

      # First, check model.find_entities_by_id (if available and entity_id is a valid ID from SketchUp::Entity)
      # Note: model.find_entities_by_id expects an array of IDs and returns entities.
      # For a single ID, iterating is generally safer or using specific methods.
      # If entity_id is not an integer (e.g., from an attribute), this won't work.
      # Assuming entity_id is from Sketchup::Entity#entityID, which is an integer.
      
      # Simpler direct iteration approach:
      model.entities.each do |entity|
        return entity if entity.entityID == entity_id
        if entity.is_a?(Sketchup::Group)
          found = find_entity_in_container(entity, entity_id)
          return found if found
        elsif entity.is_a?(Sketchup::ComponentInstance)
          # Search inside the component's definition entities
          found = find_entity_in_container(entity.definition, entity_id)
          return found if found
        end
      end
      nil
    end

    # Recursive helper for find_entity_by_id
    def find_entity_in_container(container, entity_id)
      return nil unless container.respond_to?(:entities)

      container.entities.each do |entity|
        return entity if entity.entityID == entity_id
        if entity.is_a?(Sketchup::Group)
          found = find_entity_in_container(entity, entity_id)
          return found if found
        elsif entity.is_a?(Sketchup::ComponentInstance)
          found = find_entity_in_container(entity.definition, entity_id)
          return found if found
        end
      end
      nil
    end

    def clear_component_highlight
      Sketchup.active_model.selection.clear
    end

    def purge_old_auto_materials
      puts "🧹 [Ruby] purge_old_auto_materials callback triggered"
      
      # Load current materials database
      materials = MaterialsDatabase.load_database
      puts "📊 [Ruby] Loaded #{materials.length} materials from database"
      puts "📊 [Ruby] Database file: #{MaterialsDatabase.database_file}"
      
      # Get currently active materials (those used by components)
      active_materials = @parts_by_material.keys if @parts_by_material
      active_materials ||= []
      puts "📊 [Ruby] Active materials: #{active_materials.length}"
      
      # Identify materials to purge
      materials_to_purge = []
      materials.each do |name, data|
        # Only purge if: 1) Name starts with "Auto_user_" 2) NOT in active materials
        if name.start_with?('Auto_user_') && !active_materials.include?(name)
          materials_to_purge << name
        end
      end
      
      puts "🎯 [Ruby] Materials to purge: #{materials_to_purge.length}"
      materials_to_purge.each { |m| puts "  - #{m}" }
      
      if materials_to_purge.empty?
        puts "ℹ️ [Ruby] No materials to purge"
        @dialog.execute_script("showMessage('No old auto-created materials to purge.');")
        return
      end
      
      # Remove purged materials
      materials_to_purge.each { |name| materials.delete(name) }
      puts "🗑️ [Ruby] Deleted #{materials_to_purge.length} materials from hash"
      puts "📊 [Ruby] Materials remaining in hash: #{materials.length}"
      
      # Save updated database
      puts "💾 [Ruby] Saving updated database..."
      MaterialsDatabase.save_database(materials)
      puts "✓ [Ruby] Database saved successfully"
      
      # Verify the database was saved correctly
      reloaded_materials = MaterialsDatabase.load_database
      puts "✓ [Ruby] Verification: Database now contains #{reloaded_materials.length} materials"
      
      puts "🦟 Purge: Removed #{materials_to_purge.length} old auto-materials"
      
      # Refresh the UI - also update JavaScript side with purged materials list
      puts "🔄 [Ruby] Refreshing UI..."
      purged_list_json = materials_to_purge.to_json
      # Properly escape the JSON for JavaScript by using single quotes for the outer string
      # and escaping single quotes inside the message
      escaped_message = "✓ Purged #{materials_to_purge.length} old auto-created materials.".gsub("'", "\\'")
      @dialog.execute_script("removePurgedMaterials(#{purged_list_json}); displayMaterials(); showMessage('#{escaped_message}');")
      puts "✓ [Ruby] UI refresh script executed"
    end

    def refresh_configuration_data
      model = Sketchup.active_model
      selection = model.selection

      if selection.empty?
        @dialog.execute_script("showError('Please select components or groups to analyze for refresh.')")
        return
      end

      begin
        analyzer = ModelAnalyzer.new
        @parts_by_material = analyzer.analyze_selection(selection) # Use the more comprehensive analyze_selection
        @original_components = analyzer.get_original_components_data
        @hierarchy_tree = analyzer.get_hierarchy_tree

        if @parts_by_material.empty?
          @dialog.execute_script("showError('No valid sheet good parts found in your selection.')")
          return
        end

        # Send refreshed data to the dialog. `send_initial_data` already handles populating settings
        # and stock materials from detected parts.
        send_initial_data
      rescue => e
        puts "ERROR refreshing data: #{e.message}"
        puts e.backtrace
        @dialog.execute_script("showError('Error refreshing data: #{e.message.gsub("'", "\\'")}')")
      end
    end

    # Refreshes only the report display using the last computed boards and current settings
    def refresh_report_display_with_current_settings
      return unless @boards && !@boards.empty? # Ensure boards are available from a previous run

      # Load current settings, as display-only settings might have changed since last nesting
      @settings = Config.get_cached_settings # Update @settings to ensure report generation uses latest config

      begin
        generate_report_and_show_tab(@boards)
      rescue => e
        puts "ERROR refreshing report display: #{e.message}"
        puts e.backtrace
        @dialog.execute_script("showError('Error refreshing report display: #{e.message.gsub("'", "\\'")}')")
      end
    end

    def export_csv_report(report_data, global_settings)
      model_name = Sketchup.active_model.title.empty? ? "Untitled" : Sketchup.active_model.title.gsub(/[^\w]/, '_')
      base_name = "AutoNestCut_Report_#{model_name}"
      counter = 1
      documents_path = Compatibility.documents_path

      loop do
        filename = "#{base_name}_#{counter}.csv"
        full_path = File.join(documents_path, filename)

        unless File.exist?(full_path)
          begin
            reporter = ReportGenerator.new
            reporter.export_csv(full_path, report_data)
            UI.messagebox("CSV report exported to Documents: #{filename}")
            return
          rescue => e
            UI.messagebox("Error exporting CSV: #{e.message}")
            return
          end
        end
        counter += 1
      end
    end

    def export_csv_new(report_data)
      require 'csv'
      
      model_name = Sketchup.active_model.title.empty? ? "Untitled" : Sketchup.active_model.title.gsub(/[^\w]/, '_')
      filename = "Cutting_List_#{model_name}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.csv"
      desktop_path = File.join(ENV['USERPROFILE'] || ENV['HOME'], 'Desktop')
      full_path = File.join(desktop_path, filename)
      
      CSV.open(full_path, 'w') do |csv|
        csv << ["Part Types"]
        csv << ["Name", "Width", "Height", "Material", "Quantity"]
        
        if report_data[:unique_part_types]
          report_data[:unique_part_types].each do |part|
            csv << [
              part[:name] || '',
              part[:width] || 0,
              part[:height] || 0,
              part[:material] || '',
              part[:total_quantity] || 0
            ]
          end
        end
        
        csv << []
        csv << ["Summary"]
        if report_data[:summary]
          csv << ["Total Parts", report_data[:summary][:total_parts_instances] || 0]
          csv << ["Total Boards", report_data[:summary][:total_boards] || 0]
          csv << ["Total Cost", report_data[:summary][:total_project_cost] || 0]
        end
      end
      
      UI.messagebox("CSV exported to Desktop: #{filename}")
    rescue => e
      UI.messagebox("CSV export failed: #{e.message}")
    end

    def export_interactive_html_report(report_data)
      model_name = Sketchup.active_model.title.empty? ? "Untitled" : Sketchup.active_model.title.gsub(/[^\w]/, '_')
      base_name = "AutoNestCut_Report_#{model_name}"
      counter = 1
      documents_path = Compatibility.documents_path

      loop do
        filename = "#{base_name}_#{counter}.html"
        full_path = File.join(documents_path, filename)

        unless File.exist?(full_path)
          html_content = generate_standalone_html(report_data)
          File.write(full_path, html_content, encoding: 'UTF-8')
          UI.messagebox("Interactive HTML report exported to Documents: #{filename}")
          return
        end

        counter += 1
      end
    end

    def generate_standalone_html(report_data)
      css_file = File.join(__dir__, 'html', 'style.css')
      diagrams_css_file = File.join(__dir__, 'html', 'diagrams_style.css')
      js_file = File.join(__dir__, 'html', 'diagrams_report.js')
      
      css_content = File.exist?(css_file) ? File.read(css_file) : ''
      diagrams_css_content = File.exist?(diagrams_css_file) ? File.read(diagrams_css_file) : ''
      js_content = File.exist?(js_file) ? File.read(js_file) : ''
      
      # Add current interface styling overrides for consistency
      current_styling = <<~CSS
        /* Updated styling to match current interface */
        .materials-header {
          display: grid;
          grid-template-columns: 300px 120px 120px 120px 120px 80px 80px;
          gap: 12px;
          padding: 12px 16px;
          background: linear-gradient(135deg, #f8fafc, #f1f5f9);
          border: 1px solid #e1e5e9;
          border-radius: 8px;
          font-size: 14px;
          font-weight: 700;
          color: #1a1a1a;
          margin-bottom: 12px;
          font-family: 'Inter', sans-serif !important;
          box-shadow: 0 1px 3px rgba(0,0,0,0.05);
          width: fit-content;
        }
        
        .material-item {
          display: grid;
          grid-template-columns: 300px 120px 120px 120px 120px 80px 80px;
          gap: 12px;
          padding: 12px 16px;
          border-radius: 8px;
          align-items: center;
          margin-bottom: 8px;
          border: 1px solid #e1e5e9;
          transition: all 0.2s ease;
          background: #ffffff;
        }
        
        .parts-card table {
          width: 100%;
          border-collapse: collapse;
        }
        
        /* Enhanced table styling for exports */
        th, td {
          text-align: left !important;
          padding: 8px 12px;
          border-bottom: 1px solid #d0d7de;
          font-family: 'Inter', sans-serif !important;
          vertical-align: middle;
        }
        
        th {
          background: #f5f5f5 !important;
          font-weight: 700;
          position: sticky;
          top: 0;
          z-index: 10;
        }
        
        tbody tr:hover {
          background: #f6f8fa !important;
        }
        
        /* Right-align numeric columns */
        th:nth-child(n+2):not(th:nth-child(5)):not(th:nth-child(1)),
        td:nth-child(n+2):not(td:nth-child(5)):not(td:nth-child(1)) {
          text-align: right !important;
        }
        
        /* Keep text columns left-aligned */
        th:nth-child(1), td:nth-child(1),
        th:nth-child(5), td:nth-child(5) {
          text-align: left !important;
        }
        
        .total-highlight {
          font-weight: 600;
          color: #1a1a1a;
          background: #f0f9ff !important;
        }
        
        /* Cut sequence styling */
        .cut-sequence-board {
          margin-bottom: 24px;
          padding: 16px;
          border: 1px solid #d0d7de;
          border-radius: 6px;
          background: #f8fafc;
        }
        
        .cut-sequence-board h4 {
          margin: 0 0 8px 0;
          font-size: 16px;
          font-weight: 600;
          color: #1a1a1a;
          font-family: 'Inter', sans-serif !important;
        }
        
        .cut-sequence-table {
          width: 100%;
          margin-top: 12px;
        }
        
        .cut-sequence-table th {
          background: #ffffff !important;
          font-weight: 600;
        }
        
        .cut-sequence-table td:first-child {
          font-weight: 600;
          color: #007cba;
        }
      CSS

      <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>AutoNestCut Interactive Report</title>
        <style>
        #{css_content}
        #{diagrams_css_content}
        #{current_styling}
        body { margin: 0; padding: 0; height: 100vh; display: flex; flex-direction: column; }
        .floating-print { position: fixed; top: 20px; right: 20px; z-index: 1000; background: #007cba; color: white; border: none; padding: 12px; border-radius: 50%; cursor: pointer; box-shadow: 0 2px 8px rgba(0,0,0,0.2); }
        .floating-print:hover { background: #005a87; }
        </style>
      </head>
      <body>
        <button class="floating-print" onclick="window.print()" title="Print Report">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="6,9 6,2 18,2 18,9"/>
            <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/>
            <polyline points="6,14 6,22 18,22 18,14"/>
          </svg>
        </button>
        
        <div class="container">
          <div id="diagramsContainer" class="diagrams-container">
            <h2>Cutting Diagrams</h2>
          </div>
          <div class="resizer" id="resizer"></div>
          <div id="reportContainer" class="report-container">
            <h2>Materials Used</h2>
            <div class="table-with-controls">
              <table id="materialsUsedTable"></table>
            </div>
            
            <h2>Overall Summary</h2>
            <div class="table-with-controls">
              <table id="summaryTable"></table>
            </div>
            
            <h2>Unique Part Types</h2>
            <div class="table-with-controls">
              <table id="uniquePartTypesTable"></table>
            </div>
            
            <h2>Material Requirements</h2>
            <div class="table-with-controls">
              <table id="materialRequirementsTable"></table>
            </div>
            
            <h2>Sheet Inventory Summary</h2>
            <div class="table-with-controls">
              <table id="sheetInventoryTable"></table>
            </div>
            
            <h2>Cut Sequences</h2>
            <div id="cutSequenceContainer"></div>
            
            <h2>Usable Offcuts</h2>
            <div class="table-with-controls">
              <table id="offcutsTable"></table>
            </div>
            
            <h2>Cut List & Part Details</h2>
            <div class="tree-controls">
              <button type="button" id="treeToggle" onclick="toggleTreeView()">Show Tree Structure</button>
              <div class="tree-search" id="treeSearchContainer" style="display: none;">
                <input type="text" id="treeSearch" placeholder="Search components..." oninput="filterTree()">
                <button type="button" onclick="clearTreeSearch()">Clear</button>
                <button type="button" onclick="expandAll()">Expand All</button>
                <button type="button" onclick="collapseAll()">Collapse All</button>
              </div>
            </div>
            <div id="treeStructure" class="tree-structure" style="display: none;"></div>
            <div class="table-with-controls">
              <table id="partsTable"></table>
            </div>
          </div>
        </div>
        
        <div id="partModal" class="modal">
          <div class="modal-content">
            <span class="close">&times;</span>
            <div class="modal-controls"><button id="projectionToggle">Orthographic</button></div>
            <canvas id="modalCanvas" width="500" height="400"></canvas>
            <div id="modalInfo"></div>
          </div>
        </div>
        
        <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
        <script>#{js_content}</script>
        <script>
          const reportData = #{report_data.to_json};
          document.addEventListener('DOMContentLoaded', () => {
            receiveData(reportData);
            
            // Add Material Requirements table
            const materialReqTable = document.getElementById('materialRequirementsTable');
            if (materialReqTable && reportData.diagrams) {
              materialReqTable.innerHTML = generateBoardsSummaryTableHTML(reportData.diagrams);
            }
            
            // Add Cut Sequences
            if (typeof renderCutSequences === 'function' && reportData.report.cut_sequences) {
              renderCutSequences(reportData.report);
            }
            
            // Add Offcuts table
            const offcutsTable = document.getElementById('offcutsTable');
            if (offcutsTable && reportData.report.usable_offcuts) {
              if (reportData.report.usable_offcuts.length === 0) {
                offcutsTable.innerHTML = '<thead><tr><th>Sheet #</th><th>Material</th><th>Estimated Size</th><th>Area (m2)</th></tr></thead><tbody><tr><td colspan="4">No significant offcuts</td></tr></tbody>';
              } else {
                let html = '<thead><tr><th>Sheet #</th><th>Material</th><th>Estimated Size</th><th>Area (m2)</th></tr></thead><tbody>';
                reportData.report.usable_offcuts.forEach(offcut => {
                  html += `<tr><td>${offcut.board_number}</td><td>${offcut.material}</td><td>${offcut.estimated_dimensions}</td><td>${offcut.area_m2}</td></tr>`;
                });
                html += '</tbody>';
                offcutsTable.innerHTML = html;
              }
            }
            
            initResizer();
            const modal = document.getElementById('partModal');
            const closeBtns = document.querySelectorAll('#partModal .close');
            closeBtns.forEach(btn => btn.addEventListener('click', () => modal.style.display = 'none'));
            window.addEventListener('click', (e) => { if (e.target === modal) modal.style.display = 'none'; });
          });
          
          function generateBoardsSummaryTableHTML(boardsData) {
            if (!boardsData || boardsData.length === 0) return '<thead><tr><th>Sheet</th><th>Material</th><th>Dimensions</th><th>Parts</th><th>Efficiency</th><th>Waste</th></tr></thead><tbody><tr><td colspan="6">No material requirements available</td></tr></tbody>';
            
            const reportUnits = window.currentUnits || 'mm';
            const reportPrecision = window.currentPrecision ?? 1;
            
            let html = `<thead><tr><th>Sheet</th><th>Material</th><th>Dimensions (${reportUnits})</th><th>Parts Count</th><th>Efficiency</th><th>Waste</th></tr></thead><tbody>`;
            
            boardsData.forEach((board, index) => {
              const width = (board.stock_width || 0) / (window.unitFactors[reportUnits] || 1);
              const height = (board.stock_height || 0) / (window.unitFactors[reportUnits] || 1);
              
              html += `<tr>
                <td>Sheet ${index + 1}</td>
                <td>${board.material}</td>
                <td>${formatNumber(width, reportPrecision)} x ${formatNumber(height, reportPrecision)}</td>
                <td>${board.parts ? board.parts.length : 0}</td>
                <td>${formatNumber(board.efficiency_percentage, 1)}%</td>
                <td>${formatNumber(board.waste_percentage, 1)}%</td>
              </tr>`;
            });
            
            html += `</tbody>`;
            return html;
          }
        </script>
      </body>
      </html>
      HTML
    end
  end
end
