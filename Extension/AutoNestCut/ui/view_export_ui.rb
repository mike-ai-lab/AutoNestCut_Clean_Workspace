# frozen_string_literal: true

module AutoNestCut
  # ViewExportUI - Handles the UI for exporting captured views
  # This module manages the export dialog and user interactions
  # Kept separate from ViewExportHandler for clean separation of concerns
  
  class ViewExportUI
    
    def initialize(assembly_data = nil)
      @assembly_data = assembly_data
      @dialog = nil
    end
    
    # Show export options dialog
    def show_export_dialog
      @dialog = UI::HtmlDialog.new(
        dialog_title: "Export Technical Drawings",
        preferences_key: "AutoNestCut_ViewExport",
        scrollable: true,
        resizable: true,
        width: 500,
        height: 600,
        style: UI::HtmlDialog::STYLE_DIALOG
      )
      
      @dialog.add_action_callback("export_views") do |action_context, params_json|
        begin
          params = JSON.parse(params_json)
          handle_export(params)
        rescue => e
          puts "ERROR in export_views callback: #{e.message}"
          @dialog.execute_script("showError('Export failed: #{e.message.gsub("'", "\\'")}')")
        end
      end
      
      @dialog.add_action_callback("cancel") do |action_context|
        @dialog.close
      end
      
      html = generate_export_dialog_html
      @dialog.set_html(html)
      @dialog.show
    end
    
    private
    
    def generate_export_dialog_html
      render_styles = ViewExportHandler.available_styles
      export_formats = ViewExportHandler.available_formats
      
      styles_html = render_styles.map do |style|
        "<div class='option'>
          <input type='radio' id='style_#{style}' name='render_style' value='#{style}' #{style == 'shaded' ? 'checked' : ''}>
          <label for='style_#{style}'>#{style.upcase.gsub('_', ' ')}</label>
        </div>"
      end.join("\n")
      
      formats_html = export_formats.map do |format|
        "<div class='option'>
          <input type='radio' id='format_#{format}' name='export_format' value='#{format}' #{format == 'pdf' ? 'checked' : ''}>
          <label for='format_#{format}'>#{format.upcase}</label>
        </div>"
      end.join("\n")
      
      <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>Export Technical Drawings</title>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            padding: 20px;
            background: #f5f5f5;
            color: #333;
          }
          .container { max-width: 450px; margin: 0 auto; }
          h1 { font-size: 18px; margin-bottom: 20px; color: #2E7D32; border-bottom: 2px solid #2E7D32; padding-bottom: 10px; }
          .section { margin-bottom: 25px; background: white; padding: 15px; border-radius: 6px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
          .section h2 { font-size: 14px; font-weight: 600; color: #555; margin-bottom: 12px; }
          .option { margin: 10px 0; }
          .option input[type="radio"] { margin-right: 8px; cursor: pointer; }
          .option label { cursor: pointer; font-size: 13px; }
          .info-box { background: #e8f5e9; border-left: 4px solid #2E7D32; padding: 12px; border-radius: 4px; margin-bottom: 20px; font-size: 12px; color: #2E7D32; }
          .buttons { display: flex; gap: 10px; margin-top: 25px; }
          button { flex: 1; padding: 12px; border: none; border-radius: 4px; font-size: 14px; font-weight: 600; cursor: pointer; transition: all 0.2s; }
          .export-btn { background: #2E7D32; color: white; }
          .export-btn:hover { background: #1b5e20; }
          .cancel-btn { background: #999; color: white; }
          .cancel-btn:hover { background: #777; }
          .error { color: #d32f2f; font-size: 12px; margin-top: 10px; display: none; }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>Export Technical Drawings</h1>
          
          <div class="info-box">
            ℹ️ Export captured assembly views in multiple formats for documentation and CAD integration.
          </div>
          
          <div class="section">
            <h2>Rendering Style</h2>
            #{styles_html}
          </div>
          
          <div class="section">
            <h2>Export Format</h2>
            #{formats_html}
          </div>
          
          <div class="section">
            <h2>Options</h2>
            <div class="option">
              <input type="checkbox" id="include_dimensions" name="include_dimensions">
              <label for="include_dimensions">Include Dimensions (if available)</label>
            </div>
          </div>
          
          <div class="error" id="errorMsg"></div>
          
          <div class="buttons">
            <button class="export-btn" onclick="exportViews()">Export</button>
            <button class="cancel-btn" onclick="cancelExport()">Cancel</button>
          </div>
        </div>
        
        <script>
          function exportViews() {
            const renderStyle = document.querySelector('input[name="render_style"]:checked').value;
            const exportFormat = document.querySelector('input[name="export_format"]:checked').value;
            const includeDimensions = document.getElementById('include_dimensions').checked;
            
            const params = {
              render_style: renderStyle,
              export_format: exportFormat,
              include_dimensions: includeDimensions
            };
            
            window.location = 'skp:export_views@' + encodeURIComponent(JSON.stringify(params));
          }
          
          function cancelExport() {
            window.location = 'skp:cancel';
          }
          
          function showError(message) {
            const errorDiv = document.getElementById('errorMsg');
            errorDiv.textContent = message;
            errorDiv.style.display = 'block';
          }
        </script>
      </body>
      </html>
      HTML
    end
    
    def handle_export(params)
      return unless @assembly_data
      
      render_style = params['render_style'] || 'shaded'
      export_format = params['export_format'] || 'pdf'
      include_dimensions = params['include_dimensions'] || false
      
      # Create exporter instance
      exporter = ViewExportHandler.new
      exporter.set_render_style(render_style)
      exporter.set_export_format(export_format)
      
      # Add views from assembly data - COLLECT ALL VIEWS FIRST, THEN ADD ONCE
      if @assembly_data.is_a?(Hash) && @assembly_data[:views]
        puts "DEBUG: handle_export - assembly_data[:views] keys: #{@assembly_data[:views].keys.inspect}"
        
        # Convert base64 data to temporary files
        views_hash = {}
        @assembly_data[:views].each do |view_name, image_data|
          puts "DEBUG: Processing view: #{view_name}"
          
          # If it's base64 data, save to temp file
          if image_data.is_a?(String) && image_data.start_with?('data:image')
            puts "DEBUG: Converting base64 data to file for #{view_name}"
            # Extract base64 from data URI
            base64_str = image_data.split(',')[1]
            if base64_str
              temp_file = File.join(ENV['TEMP'] || '/tmp', "view_#{view_name}_#{Time.now.to_i}.png")
              File.binwrite(temp_file, Base64.decode64(base64_str))
              views_hash[view_name] = temp_file
              puts "DEBUG: Saved #{view_name} to #{temp_file}"
            end
          elsif image_data.is_a?(String) && File.exist?(image_data)
            # Already a file path
            views_hash[view_name] = image_data
            puts "DEBUG: Using existing file path for #{view_name}: #{image_data}"
          else
            puts "DEBUG: WARNING - Unknown data type for #{view_name}: #{image_data.class}"
          end
        end
        
        # Add all views at once
        if views_hash.length > 0
          puts "DEBUG: Adding #{views_hash.length} views to exporter"
          exporter.add_views("Assembly", views_hash)
        else
          puts "ERROR: No valid views found to export"
          @dialog.close if @dialog
          UI.messagebox("Error: No valid views found to export")
          return
        end
      end
      
      # Perform export
      begin
        output_path = exporter.export
        
        @dialog.close if @dialog
        
        # Show success message
        if export_format == 'png'
          UI.messagebox("Technical drawings exported successfully!\n\nLocation: #{output_path}")
        else
          UI.messagebox("Technical drawing exported successfully!\n\nLocation: #{output_path}")
          # Open the file if it's PDF or HTML
          UI.openURL("file:///#{output_path}") if ['pdf', 'html'].include?(export_format)
        end
      rescue => e
        puts "ERROR in export: #{e.message}"
        puts "Backtrace: #{e.backtrace.join("\n")}"
        @dialog.close if @dialog
        UI.messagebox("Export failed: #{e.message}")
      end
    end
  end
end
