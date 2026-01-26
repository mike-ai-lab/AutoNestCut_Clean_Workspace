# frozen_string_literal: true

require_relative '../exporters/svg_vector_exporter'

module AutoNestCut
  class SvgExportUI
    
    def self.show_svg_export_dialog(entity)
      return unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      
      dialog = UI::HtmlDialog.new(
        title: "Flatten for CNC - SVG Vector Export",
        preferences_key: "AutoNestCut_SVGExport",
        width: 500,
        height: 400,
        left: 100,
        top: 100
      )
      
      html = generate_svg_export_html(entity)
      dialog.set_html(html)
      
      dialog.add_action_callback("export_svg") do |action_context, params_json|
        params = JSON.parse(params_json) rescue {}
        handle_svg_export(entity, params, dialog)
      end
      
      dialog.add_action_callback("close_dialog") do |action_context|
        dialog.close
      end
      
      dialog.show
    end
    
    private
    
    def self.generate_svg_export_html(entity)
      entity_name = entity.name.empty? ? "Assembly" : entity.name
      
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Flatten for CNC - SVG Vector Export</title>
          <style>
            * {
              margin: 0;
              padding: 0;
              box-sizing: border-box;
            }
            
            body {
              font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
              background: #f5f5f5;
              padding: 20px;
              color: #333;
            }
            
            .container {
              max-width: 450px;
              margin: 0 auto;
              background: white;
              border-radius: 8px;
              box-shadow: 0 2px 8px rgba(0,0,0,0.1);
              padding: 24px;
            }
            
            h1 {
              font-size: 20px;
              margin-bottom: 8px;
              color: #2c3e50;
            }
            
            .subtitle {
              font-size: 13px;
              color: #7f8c8d;
              margin-bottom: 24px;
            }
            
            .section {
              margin-bottom: 24px;
            }
            
            .section-title {
              font-size: 14px;
              font-weight: 600;
              color: #2c3e50;
              margin-bottom: 12px;
              display: flex;
              align-items: center;
              gap: 8px;
            }
            
            .section-title::before {
              content: '';
              display: inline-block;
              width: 4px;
              height: 4px;
              background: #3498db;
              border-radius: 50%;
            }
            
            .face-selector {
              display: grid;
              grid-template-columns: 1fr 1fr;
              gap: 10px;
              margin-bottom: 16px;
            }
            
            .face-option {
              position: relative;
            }
            
            .face-option input[type="radio"] {
              display: none;
            }
            
            .face-option label {
              display: flex;
              align-items: center;
              justify-content: center;
              padding: 12px;
              border: 2px solid #ecf0f1;
              border-radius: 6px;
              cursor: pointer;
              transition: all 0.2s;
              font-size: 13px;
              font-weight: 500;
              background: #f8f9fa;
            }
            
            .face-option input[type="radio"]:checked + label {
              border-color: #3498db;
              background: #ebf5fb;
              color: #2980b9;
            }
            
            .face-option label:hover {
              border-color: #bdc3c7;
              background: #ecf0f1;
            }
            
            .options-group {
              background: #f8f9fa;
              border: 1px solid #ecf0f1;
              border-radius: 6px;
              padding: 12px;
              margin-bottom: 16px;
            }
            
            .option-item {
              display: flex;
              align-items: center;
              gap: 8px;
              margin-bottom: 10px;
              font-size: 13px;
            }
            
            .option-item:last-child {
              margin-bottom: 0;
            }
            
            .option-item input[type="checkbox"] {
              width: 16px;
              height: 16px;
              cursor: pointer;
              accent-color: #3498db;
            }
            
            .option-item label {
              cursor: pointer;
              flex: 1;
            }
            
            .info-box {
              background: #e8f4f8;
              border-left: 4px solid #3498db;
              padding: 12px;
              border-radius: 4px;
              font-size: 12px;
              color: #2c3e50;
              margin-bottom: 16px;
            }
            
            .info-box strong {
              display: block;
              margin-bottom: 4px;
              color: #2980b9;
            }
            
            .buttons {
              display: flex;
              gap: 10px;
              margin-top: 24px;
            }
            
            .btn {
              flex: 1;
              padding: 12px 16px;
              border: none;
              border-radius: 6px;
              font-size: 14px;
              font-weight: 600;
              cursor: pointer;
              transition: all 0.2s;
            }
            
            .btn-primary {
              background: #3498db;
              color: white;
            }
            
            .btn-primary:hover {
              background: #2980b9;
              box-shadow: 0 2px 8px rgba(52, 152, 219, 0.3);
            }
            
            .btn-primary:active {
              transform: translateY(1px);
            }
            
            .btn-secondary {
              background: #ecf0f1;
              color: #2c3e50;
            }
            
            .btn-secondary:hover {
              background: #bdc3c7;
            }
            
            .status-message {
              display: none;
              padding: 12px;
              border-radius: 6px;
              margin-bottom: 16px;
              font-size: 13px;
              font-weight: 500;
            }
            
            .status-message.success {
              background: #d4edda;
              color: #155724;
              border: 1px solid #c3e6cb;
              display: block;
            }
            
            .status-message.error {
              background: #f8d7da;
              color: #721c24;
              border: 1px solid #f5c6cb;
              display: block;
            }
            
            .loading {
              display: none;
              text-align: center;
              padding: 20px;
            }
            
            .spinner {
              border: 3px solid #ecf0f1;
              border-top: 3px solid #3498db;
              border-radius: 50%;
              width: 30px;
              height: 30px;
              animation: spin 1s linear infinite;
              margin: 0 auto 10px;
            }
            
            @keyframes spin {
              0% { transform: rotate(0deg); }
              100% { transform: rotate(360deg); }
            }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>🎯 Flatten for CNC</h1>
            <p class="subtitle">Export #{entity_name} as SVG vector for laser cutting</p>
            
            <div class="section">
              <div class="section-title">Select Face to Export</div>
              <div class="face-selector">
                <div class="face-option">
                  <input type="radio" id="face_front" name="face" value="Front" checked>
                  <label for="face_front">Front</label>
                </div>
                <div class="face-option">
                  <input type="radio" id="face_back" name="face" value="Back">
                  <label for="face_back">Back</label>
                </div>
                <div class="face-option">
                  <input type="radio" id="face_left" name="face" value="Left">
                  <label for="face_left">Left</label>
                </div>
                <div class="face-option">
                  <input type="radio" id="face_right" name="face" value="Right">
                  <label for="face_right">Right</label>
                </div>
                <div class="face-option">
                  <input type="radio" id="face_top" name="face" value="Top">
                  <label for="face_top">Top</label>
                </div>
                <div class="face-option">
                  <input type="radio" id="face_bottom" name="face" value="Bottom">
                  <label for="face_bottom">Bottom</label>
                </div>
              </div>
            </div>
            
            <div class="section">
              <div class="section-title">Export Options</div>
              <div class="options-group">
                <div class="option-item">
                  <input type="checkbox" id="include_dimensions" checked>
                  <label for="include_dimensions">Include dimensions</label>
                </div>
                <div class="option-item">
                  <input type="checkbox" id="include_metadata" checked>
                  <label for="include_metadata">Include metadata</label>
                </div>
              </div>
            </div>
            
            <div class="info-box">
              <strong>💡 Tip:</strong>
              The SVG file can be opened in Illustrator, Inkscape, or sent directly to laser cutters. All dimensions are in millimeters.
            </div>
            
            <div id="statusMessage" class="status-message"></div>
            
            <div id="loading" class="loading">
              <div class="spinner"></div>
              <p>Generating SVG...</p>
            </div>
            
            <div class="buttons">
              <button class="btn btn-secondary" onclick="closeDialog()">Cancel</button>
              <button class="btn btn-primary" onclick="exportSvg()">Export SVG</button>
            </div>
          </div>
          
          <script>
            function getSelectedFace() {
              const selected = document.querySelector('input[name="face"]:checked');
              return selected ? selected.value : 'Front';
            }
            
            function showStatus(message, type = 'success') {
              const statusEl = document.getElementById('statusMessage');
              statusEl.textContent = message;
              statusEl.className = 'status-message ' + type;
              setTimeout(() => {
                statusEl.className = 'status-message';
              }, 5000);
            }
            
            function showLoading(show = true) {
              document.getElementById('loading').style.display = show ? 'block' : 'none';
            }
            
            function exportSvg() {
              const face = getSelectedFace();
              const includeDimensions = document.getElementById('include_dimensions').checked;
              const includeMetadata = document.getElementById('include_metadata').checked;
              
              showLoading(true);
              
              const params = {
                face: face,
                include_dimensions: includeDimensions,
                include_metadata: includeMetadata
              };
              
              // Use sketchup.callback_name() instead of window.location
              if (typeof sketchup !== 'undefined' && sketchup.export_svg) {
                sketchup.export_svg(JSON.stringify(params));
              }
            }
            
            function closeDialog() {
              if (typeof sketchup !== 'undefined' && sketchup.close_dialog) {
                sketchup.close_dialog();
              }
            }
          </script>
        </body>
        </html>
      HTML
    end
    
    def self.handle_svg_export(entity, params, dialog = nil)
      begin
        face_name = params['face'] || 'Front'
        include_dimensions = params['include_dimensions'] != false
        include_metadata = params['include_metadata'] != false
        
        # Export the SVG
        output_path = SvgVectorExporter.export_face_as_svg(entity, face_name)
        
        if output_path && File.exist?(output_path)
          UI.messagebox(
            "SVG exported successfully!\n\nFile: #{File.basename(output_path)}\n\nLocation: #{File.dirname(output_path)}",
            MB_OK,
            "Export Complete"
          )
          
          # Close dialog after successful export
          dialog.close if dialog
          
          # Open the file location
          system("explorer.exe /select,\"#{output_path}\"") if Sketchup.platform == :platform_win
        else
          UI.messagebox("Failed to export SVG file.", MB_OK, "Export Error")
        end
      rescue => e
        UI.messagebox("Error during SVG export: #{e.message}", MB_OK, "Export Error")
        puts "SVG Export Error: #{e.message}"
        puts e.backtrace.join("\n")
      end
    end
  end
end
