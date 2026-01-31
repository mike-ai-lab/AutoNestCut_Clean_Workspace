# frozen_string_literal: true

# ==============================================================================
# DEPENDENCY LOADER
# Loads vendored gems from Extension/vendor directory
# ==============================================================================
module AutoNestCut
  # Add vendor paths to load path
  VENDOR_DIR = File.expand_path('../../../vendor', __FILE__)
  
  def self.load_vendored_gem(gem_name)
    gem_path = File.join(VENDOR_DIR, gem_name)
    if File.directory?(gem_path)
      $LOAD_PATH.unshift(gem_path) unless $LOAD_PATH.include?(gem_path)
      puts "AutoNestCut: Loaded vendored gem '#{gem_name}' from #{gem_path}"
      return true
    else
      puts "AutoNestCut Warning: Vendored gem '#{gem_name}' not found at #{gem_path}"
      return false
    end
  end
  
  def self.ensure_gem_installed(gem_name, lib_name = gem_name)
    begin
      require lib_name
    rescue LoadError
      puts "AutoNestCut: Installing '#{gem_name}' gem for SketchUp... (This may take a moment)"
      begin
        Gem.install(gem_name)
        require lib_name
        puts "AutoNestCut: '#{gem_name}' installed successfully."
      rescue => e
        puts "AutoNestCut Error: Could not install #{gem_name}. Error: #{e.message}"
        UI.messagebox("Error: Could not install required gem '#{gem_name}'. Please check internet connection.")
        raise e
      end
    end
  end
end

# Load vendored gems
AutoNestCut.load_vendored_gem('rqrcode_core')
AutoNestCut.load_vendored_gem('rqrcode')

# Install/Load Prawn (if not already available)
AutoNestCut.ensure_gem_installed('prawn')

# ==============================================================================
# LABEL SHEET GENERATOR
# ==============================================================================

require 'prawn'
require 'rqrcode'
require 'fileutils'
require 'tmpdir'

module AutoNestCut
  class LabelSheetGenerator
    
    # Standard label formats (dimensions in mm)
    FORMATS = {
      'avery_5160' => { cols: 3, rows: 10, width: 66.7, height: 25.4, margin_top: 12.7, margin_left: 4.8, spacing_h: 3.2, spacing_v: 0 },
      'avery_5163' => { cols: 2, rows: 5, width: 101.6, height: 50.8, margin_top: 12.7, margin_left: 4.8, spacing_h: 3.2, spacing_v: 0 },
      'avery_5164' => { cols: 2, rows: 3, width: 101.6, height: 84.7, margin_top: 16.9, margin_left: 4.8, spacing_h: 3.2, spacing_v: 0 },
      'custom' => { cols: 3, rows: 8, width: 70, height: 35, margin_top: 10, margin_left: 5, spacing_h: 5, spacing_v: 5 }
    }
    
    def initialize(format = 'custom')
      @format = FORMATS[format] || FORMATS['custom']
    end
    
    # Generate label sheet PDF from parts data
    def generate_label_sheet(parts_data, output_path = nil, preview_mode = false)
      output_path ||= File.join(Dir.tmpdir, "label_sheet_#{Time.now.to_i}.pdf")
      
      puts "\n" + "="*80
      puts "LABEL SHEET GENERATOR"
      puts "="*80
      puts "Format: #{@format[:width]}mm x #{@format[:height]}mm"
      puts "Total parts: #{parts_data.length}"
      puts "Preview mode: #{preview_mode}"
      
      Prawn::Document.generate(output_path, 
        page_size: 'LETTER',
        margin: 0,
        info: { Title: 'Part Labels', Creator: 'AutoNestCut' }
      ) do |pdf|
        
        # Set a clean sans-serif font standard
        pdf.font "Helvetica"
        
        labels_per_page = @format[:cols] * @format[:rows]
        
        parts_data.each_with_index do |part, index|
          # Calculate position logic
          label_on_page = index % labels_per_page
          row = label_on_page / @format[:cols]
          col = label_on_page % @format[:cols]
          
          # Start new page if needed
          pdf.start_new_page if label_on_page == 0 && index > 0
          
          # Calculate coordinates (mm -> pt conversion happens here)
          x_pos = mm_to_pt(@format[:margin_left] + (col * (@format[:width] + @format[:spacing_h])))
          y_pos = pdf.bounds.height - mm_to_pt(@format[:margin_top] + (row * (@format[:height] + @format[:spacing_v])))
          
          # Render the modern label
          render_modern_label(pdf, part, x_pos, y_pos)
        end
      end
      
      puts "✓ Label sheet generated: #{output_path}"
      puts "="*80
      
      # If preview mode, show preview dialog
      if preview_mode
        show_preview_dialog(output_path, parts_data)
      end
      
      output_path
    end
    
    alias generate generate_label_sheet
    
    private
    
    def format_qr_data(part_data)
      # Create a multi-line text format that displays nicely when scanned
      # Most QR scanners will show this as plain text
      
      id = (part_data[:part_id] || part_data['part_id'] || "N/A").to_s
      name = (part_data[:name] || part_data['name'] || "Unknown Part").to_s
      w_dim = (part_data[:width] || part_data['width'] || 0).to_f.round(1)
      h_dim = (part_data[:height] || part_data['height'] || 0).to_f.round(1)
      thick = (part_data[:thickness] || part_data['thickness'] || 0).to_f.round(1)
      material = (part_data[:material] || part_data['material'] || "").to_s
      board = part_data[:board_number] || part_data['board_number']
      
      # Format as readable multi-line text
      qr_text = "PART: #{id}\n"
      qr_text += "NAME: #{name}\n"
      qr_text += "SIZE: #{w_dim} x #{h_dim} x #{thick}mm\n"
      qr_text += "MATERIAL: #{material}\n" unless material.empty?
      qr_text += "BOARD: ##{board}" if board
      
      qr_text
    end
    
    def render_modern_label(pdf, part_data, x, y)
      width_pt = mm_to_pt(@format[:width])
      height_pt = mm_to_pt(@format[:height])
      
      # 1. Outer Cutting Guide (Very light grey, dashed)
      pdf.stroke_color 'E5E5E5'
      pdf.dash(2, space: 2)
      pdf.stroke_rectangle [x, y], width_pt, height_pt
      pdf.undash
      
      # Define content boundaries (Padding 2.5mm)
      padding = mm_to_pt(2.5)
      inner_x = x + padding
      inner_y = y - padding
      inner_w = width_pt - (padding * 2)
      inner_h = height_pt - (padding * 2)
      
      # 2. Layout Calculation
      # Split label: Left 35% for QR, Right 65% for Data
      qr_area_width = inner_w * 0.35
      text_area_x = inner_x + qr_area_width + mm_to_pt(3) # 3mm gap
      text_area_w = inner_w - qr_area_width - mm_to_pt(3)
      
      # 3. Draw Vertical Divider
      pdf.stroke_color '000000'
      pdf.line_width 0.5
      pdf.stroke_vertical_line inner_y, inner_y - inner_h, at: inner_x + qr_area_width + mm_to_pt(1.5)
      
      # 4. Generate and Draw QR Code
      # Encode rich data in a readable format for QR scanners
      # Format: PART:ID|NAME|DIMENSIONS|MATERIAL|BOARD
      qr_data = format_qr_data(part_data)
      draw_qr_code(pdf, qr_data, inner_x, inner_y, qr_area_width)
      
      # 5. Render Text Information (Right Side)
      pdf.fill_color '000000'
      
      # Data extraction
      name = (part_data[:name] || part_data['name'] || "Unknown Part").to_s
      w_dim = (part_data[:width] || part_data['width'] || 0).to_f.round(1)
      h_dim = (part_data[:height] || part_data['height'] || 0).to_f.round(1)
      thick = (part_data[:thickness] || part_data['thickness'] || 0).to_f.round(1)
      id = (part_data[:part_id] || part_data['part_id'] || "N/A").to_s
      board = part_data[:board_number] || part_data['board_number']
      
      current_y = inner_y
      
      # -- HEADER: Part Name --
      pdf.font("Helvetica", style: :bold)
      pdf.font_size 10
      pdf.text_box name,
        at: [text_area_x, current_y],
        width: text_area_w,
        height: mm_to_pt(8),
        overflow: :shrink_to_fit,
        align: :left,
        valign: :top
        
      current_y -= mm_to_pt(9)
      
      # -- BODY: Dimensions --
      pdf.font("Helvetica", style: :normal)
      pdf.font_size 8
      pdf.text_box "Dimensions:", at: [text_area_x, current_y], width: text_area_w, height: 10
      
      pdf.font("Helvetica", style: :bold)
      pdf.font_size 12
      pdf.text_box "#{w_dim} x #{h_dim}",
        at: [text_area_x, current_y - 10],
        width: text_area_w,
        height: 15
        
      # Thickness bubble
      pdf.font_size 8
      pdf.text_box "#{thick}mm", at: [text_area_x + mm_to_pt(25), current_y - 12], width: 30, height: 10, align: :right, style: :italic
      
      # -- FOOTER: Metadata --
      # Draw a thin line above footer
      pdf.stroke_color '666666'
      pdf.line_width 0.25
      footer_y = inner_y - inner_h + mm_to_pt(6)
      pdf.stroke_horizontal_line text_area_x, text_area_x + text_area_w, at: footer_y
      
      pdf.fill_color '333333'
      pdf.font("Courier", style: :bold) # Monospace for IDs looks technical
      pdf.font_size 8
      
      pdf.text_box "ID: #{truncate_text(id, 10)}",
        at: [text_area_x, footer_y - 2],
        width: text_area_w * 0.6,
        height: mm_to_pt(4)
        
      if board
        pdf.text_box "B##{board}",
          at: [text_area_x + (text_area_w * 0.6), footer_y - 2],
          width: text_area_w * 0.4,
          height: mm_to_pt(4),
          align: :right
      end
    end
    
    # Custom QR Renderer for Prawn
    # Draws the QR code using rectangles to avoid external image dependencies
    def draw_qr_code(pdf, content, x, y, size)
      # Create QR object using the real rqrcode gem
      qr = RQRCode::QRCode.new(content.to_s, level: :m)
      
      # Calculate module (pixel) size
      module_size = size / qr.modules.size.to_f
      
      pdf.fill_color '000000'
      
      # Iterate over QR modules and draw black squares
      qr.modules.each_with_index do |row, row_index|
        row.each_with_index do |col, col_index|
          if col # If the module is true (black)
            # Calculate precise coordinates
            rect_x = x + (col_index * module_size)
            rect_y = y - (row_index * module_size)
            
            # Draw square
            pdf.fill_rectangle [rect_x, rect_y], module_size, module_size
          end
        end
      end
      
      # Add text label below QR
      pdf.font("Helvetica", style: :normal)
      pdf.font_size 5
      truncated = truncate_text(content, 15)
      pdf.draw_text truncated, at: [x + (size/2) - (truncated.length * 1.5), y - size - 5]
    end
    
    def mm_to_pt(mm)
      mm * 2.83465
    end
    
    def truncate_text(text, max_length)
      return '' unless text
      text = text.to_s
      return text if text.length <= max_length
      text[0...max_length-1] + '…'
    end
    
    # Show preview dialog with export confirmation
    def show_preview_dialog(pdf_path, parts_data)
      dialog = UI::HtmlDialog.new(
        {
          :dialog_title => "Label Sheet Preview",
          :preferences_key => "com.autonestcut.label_preview",
          :scrollable => false,
          :resizable => true,
          :width => 1400,
          :height => 900,
          :left => 50,
          :top => 50,
          :min_width => 800,
          :min_height => 600,
          :style => UI::HtmlDialog::STYLE_DIALOG
        }
      )
      
      # Convert PDF path to file:// URL for embedding
      pdf_url = "file:///" + pdf_path.gsub("\\", "/")
      
      html_content = generate_preview_html(pdf_url, parts_data.length)
      
      dialog.set_html(html_content)
      
      # Add callback for export button
      dialog.add_action_callback("export_labels") do |action_context|
        # Ask user where to save
        save_path = UI.savepanel("Save Label Sheet", "", "label_sheet.pdf")
        if save_path
          begin
            # Copy temp file to chosen location
            require 'fileutils'
            FileUtils.cp(pdf_path, save_path)
            UI.messagebox("Label sheet exported successfully to:\n#{save_path}")
            dialog.close
          rescue => e
            UI.messagebox("Error exporting labels: #{e.message}")
          end
        end
      end
      
      # Add callback for cancel button
      dialog.add_action_callback("cancel_export") do |action_context|
        dialog.close
      end
      
      dialog.show
    end
    
    def generate_preview_html(pdf_url, label_count)
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Label Sheet Preview</title>
          <style>
            * {
              margin: 0;
              padding: 0;
              box-sizing: border-box;
            }
            
            body {
              background: #2b2b2b;
              overflow: hidden;
              width: 100vw;
              height: 100vh;
            }
            
            .pdf-viewer {
              width: 100%;
              height: 100%;
            }
            
            .pdf-viewer embed {
              width: 100%;
              height: 100%;
              border: none;
            }
            
            .floating-actions {
              position: fixed;
              bottom: 30px;
              right: 30px;
              display: flex;
              gap: 12px;
              z-index: 1000;
            }
            
            .btn {
              padding: 12px 24px;
              font-size: 14px;
              font-weight: 600;
              border: none;
              border-radius: 6px;
              cursor: pointer;
              transition: all 0.2s ease;
              box-shadow: 0 4px 12px rgba(0,0,0,0.3);
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
            }
            
            .btn-export {
              background: #4CAF50;
              color: white;
            }
            
            .btn-export:hover {
              background: #45a049;
              transform: translateY(-2px);
              box-shadow: 0 6px 16px rgba(76, 175, 80, 0.4);
            }
            
            .btn-cancel {
              background: #f44336;
              color: white;
            }
            
            .btn-cancel:hover {
              background: #da190b;
              transform: translateY(-2px);
              box-shadow: 0 6px 16px rgba(244, 67, 54, 0.4);
            }
          </style>
        </head>
        <body>
          <div class="pdf-viewer">
            <embed src="#{pdf_url}" type="application/pdf">
          </div>
          
          <div class="floating-actions">
            <button class="btn btn-cancel" onclick="cancelExport()">Cancel</button>
            <button class="btn btn-export" onclick="exportLabels()">Export</button>
          </div>
          
          <script>
            function exportLabels() {
              window.location = 'skp:export_labels';
            }
            
            function cancelExport() {
              window.location = 'skp:cancel_export';
            }
          </script>
        </body>
        </html>
      HTML
    end
  end
end