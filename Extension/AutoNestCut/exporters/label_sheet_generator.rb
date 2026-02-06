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

      'custom' => { cols: 3, rows: 4, width: 65, height: 35, spacing_h: 5, spacing_v: 8 }  # Balanced layout: 3x4 with proper spacing

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

      puts "Grid: #{@format[:cols]} cols x #{@format[:rows]} rows"

      puts "Total parts: #{parts_data.length}"

      puts "Preview mode: #{preview_mode}"

      

      Prawn::Document.generate(output_path, 

        page_size: 'A4',

        page_layout: :portrait,

        margin: [50, 50, 50, 50],  # Consistent margins

        info: { Title: 'Part Labels', Creator: 'AutoNestCut' }

      ) do |pdf|

        

        # Set a clean sans-serif font

        pdf.font "Helvetica"

        

        labels_per_page = @format[:cols] * @format[:rows]

        

        # Calculate total width needed for labels

        total_width_needed_mm = (@format[:cols] * @format[:width]) + ((@format[:cols] - 1) * @format[:spacing_h])

        

        # Get available width from PDF bounds and convert to mm

        available_width_pt = pdf.bounds.width

        available_width_mm = available_width_pt / 2.83465

        

        # Calculate left margin to center labels

        margin_left_mm = (available_width_mm - total_width_needed_mm) / 2

        

        # Starting Y position

        start_y_pt = pdf.cursor

        

        parts_data.each_with_index do |part, index|

          # Start new page if needed

          if index > 0 && index % labels_per_page == 0

            pdf.start_new_page

            start_y_pt = pdf.cursor

          end

          

          # Calculate position on current page

          label_on_page = index % labels_per_page

          row = label_on_page / @format[:cols]

          col = label_on_page % @format[:cols]

          

          # Calculate position in mm

          x_mm = margin_left_mm + (col * (@format[:width] + @format[:spacing_h]))

          y_offset_mm = row * (@format[:height] + @format[:spacing_v])

          

          # Convert to points

          x_pos = mm_to_pt(x_mm)

          y_pos = start_y_pt - mm_to_pt(y_offset_mm)

          

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

      # Create COMPACT format for better QR scannability

      # Shorter labels = smaller QR code = easier to scan

      

      id = (part_data[:part_id] || part_data['part_id'] || "N/A").to_s

      name = (part_data[:name] || part_data['name'] || "Unknown").to_s

      w_dim = (part_data[:width] || part_data['width'] || 0).to_f.round(0) # No decimals

      h_dim = (part_data[:height] || part_data['height'] || 0).to_f.round(0)

      thick = (part_data[:thickness] || part_data['thickness'] || 0).to_f.round(0)

      material = (part_data[:material] || part_data['material'] || "").to_s

      board = part_data[:board_number] || part_data['board_number']

      

      # COMPACT format - shorter text for better scanning

      qr_text = "ID:#{id}\n"

      qr_text += "#{name}\n" # Name without label

      qr_text += "#{w_dim}x#{h_dim}x#{thick}mm\n" # Compact dimensions

      qr_text += "#{material}\n" unless material.empty?

      qr_text += "B#{board}" if board # Shorter board label

      

      qr_text

    end

    

    def render_modern_label(pdf, part_data, x, y)

      width_pt = mm_to_pt(@format[:width])

      height_pt = mm_to_pt(@format[:height])

      

      # Data extraction

      name = (part_data[:name] || part_data['name'] || "Unknown Part").to_s

      w_dim = (part_data[:width] || part_data['width'] || 0).to_f.round(1)

      h_dim = (part_data[:height] || part_data['height'] || 0).to_f.round(1)

      thick = (part_data[:thickness] || part_data['thickness'] || 0).to_f.round(1)

      id = (part_data[:part_id] || part_data['part_id'] || "N/A").to_s

      board = part_data[:board_number] || part_data['board_number']

      

      # ========================================

      # EXACT MATCH TO SVG LABEL DESIGN

      # ========================================

      

      # Border width

      bw = mm_to_pt(2.5)

      

      # 1. OUTER BLACK BORDER (2.5mm thick)

      pdf.stroke_color '000000'

      pdf.line_width bw

      pdf.stroke_rectangle [x, y], width_pt, height_pt

      

      # Inner boundaries (after border)

      inner_x = x + bw

      inner_y = y - bw

      inner_w = width_pt - (bw * 2)

      inner_h = height_pt - (bw * 2)

      

      # 2. LAYOUT: Left 31.11% Orange Zone, Right 68.89% White Zone (matching SVG)

      left_col_width = inner_w * 0.3111

      right_col_width = inner_w * 0.6889

      

      # 3. ORANGE ZONE (Left side)

      orange_x = inner_x

      orange_y = inner_y

      orange_w = left_col_width

      orange_h = inner_h

      

      # Fill orange background

      pdf.fill_color 'FF6B00'

      pdf.fill_rectangle [orange_x, orange_y], orange_w, orange_h

      

      # Draw diagonal hatch pattern (black lines from top-left to bottom-right)

      pdf.stroke_color '000000'

      pdf.line_width 1.5

      spacing = mm_to_pt(4) # 4mm spacing

      

      # Diagonal lines going from top-left to bottom-right

      num_lines = ((orange_w + orange_h) / spacing).ceil + 2

      (-num_lines..num_lines).each do |i|

        start_offset = i * spacing

        

        # Line starts from top edge or left edge

        if start_offset <= 0

          line_x1 = orange_x

          line_y1 = orange_y + start_offset

        else

          line_x1 = orange_x + start_offset

          line_y1 = orange_y

        end

        

        # Line ends at bottom edge or right edge

        line_x2 = line_x1 + orange_h

        line_y2 = line_y1 - orange_h

        

        # Clip to orange zone boundaries

        if line_x1 >= orange_x && line_x1 <= orange_x + orange_w &&

           line_y1 <= orange_y && line_y1 >= orange_y - orange_h

          if line_x2 > orange_x + orange_w

            # Clip to right edge

            ratio = (orange_x + orange_w - line_x1) / (line_x2 - line_x1)

            line_x2 = orange_x + orange_w

            line_y2 = line_y1 + ratio * (line_y2 - line_y1)

          end

          

          if line_y2 < orange_y - orange_h

            # Clip to bottom edge

            ratio = (orange_y - orange_h - line_y1) / (line_y2 - line_y1)

            line_y2 = orange_y - orange_h

            line_x2 = line_x1 + ratio * (line_x2 - line_x1)

          end

          

          pdf.line [line_x1, line_y1], [line_x2, line_y2]

          pdf.stroke

        end

      end

      

      # 4. QR CODE (Centered in orange zone with WHITE BOX around it)

      qr_box_size = orange_w * 0.70

      qr_box_x = orange_x + (orange_w - qr_box_size) / 2

      qr_box_y = orange_y - (orange_h - qr_box_size) / 2

      

      # White box for QR

      pdf.fill_color 'FFFFFF'

      pdf.fill_rectangle [qr_box_x, qr_box_y], qr_box_size, qr_box_size

      

      # QR code inside white box (with padding)

      qr_padding = mm_to_pt(2)

      qr_size = qr_box_size - (qr_padding * 2)

      qr_x = qr_box_x + qr_padding

      qr_y = qr_box_y - qr_padding

      

      qr_data = format_qr_data(part_data)

      draw_qr_code(pdf, qr_data, qr_x, qr_y, qr_size)

      

      # 5. WHITE ZONE (Right side)

      white_x = inner_x + left_col_width

      white_y = inner_y

      white_w = right_col_width

      white_h = inner_h

      

      # Fill white background

      pdf.fill_color 'FFFFFF'

      pdf.fill_rectangle [white_x, white_y], white_w, white_h

      

      # 6. METALLIC CORNER (Top-right corner of white zone)

      metal_size = mm_to_pt(20)

      metal_x = white_x + white_w - metal_size

      metal_y = white_y

      

      # Metallic gradient effect

      pdf.fill_color 'B8B8B8' # Dark silver

      pdf.fill_rectangle [metal_x, metal_y], metal_size, metal_size

      

      pdf.fill_color 'D8D8D8' # Medium silver

      pdf.fill_rectangle [metal_x + mm_to_pt(2), metal_y - mm_to_pt(2)], metal_size - mm_to_pt(4), metal_size - mm_to_pt(4)

      

      pdf.fill_color 'F0F0F0' # Light silver

      pdf.fill_rectangle [metal_x + mm_to_pt(4), metal_y - mm_to_pt(4)], metal_size - mm_to_pt(8), metal_size - mm_to_pt(8)

      

      # Part number in metallic corner

      pdf.fill_color '333333'

      pdf.font("Helvetica", style: :bold)

      pdf.font_size 20

      part_num = id.gsub(/[^\d]/, '') # Extract just the number

      pdf.text_box part_num,

        at: [metal_x, metal_y - mm_to_pt(5)],

        width: metal_size,

        height: metal_size,

        align: :center,

        valign: :center

      

      # 7. PART NAME BANNER (Top of white zone, below metallic corner)

      banner_x = white_x + mm_to_pt(3)

      banner_y = white_y - mm_to_pt(2)

      banner_w = white_w - metal_size - mm_to_pt(6)

      

      pdf.fill_color '000000'

      pdf.font("Helvetica", style: :bold)

      pdf.font_size 13

      pdf.text_box name,

        at: [banner_x, banner_y],

        width: banner_w,

        height: mm_to_pt(8),

        overflow: :shrink_to_fit,

        align: :left,

        valign: :top

      

      # 8. DIMENSIONS SECTION

      dim_start_y = white_y - mm_to_pt(12)

      

      # "Dimensions (mm)" header in grey

      pdf.fill_color '888888'

      pdf.font("Helvetica", style: :normal)

      pdf.font_size 8

      pdf.text_box "Dimensions (mm)",

        at: [banner_x, dim_start_y],

        width: white_w - mm_to_pt(6),

        height: mm_to_pt(4)

      

      dim_y = dim_start_y - mm_to_pt(5)

      label_x = banner_x

      value_x = banner_x + mm_to_pt(10)

      

      # Width

      pdf.fill_color '888888'

      pdf.font_size 7

      pdf.text_box "W", at: [label_x, dim_y], width: mm_to_pt(8), height: mm_to_pt(4)

      pdf.fill_color '000000'

      pdf.font_size 11

      pdf.text_box w_dim.to_s, at: [value_x, dim_y], width: white_w - mm_to_pt(16), height: mm_to_pt(5)

      

      dim_y -= mm_to_pt(5.5)

      

      # Height

      pdf.fill_color '888888'

      pdf.font_size 7

      pdf.text_box "H", at: [label_x, dim_y], width: mm_to_pt(8), height: mm_to_pt(4)

      pdf.fill_color '000000'

      pdf.font_size 11

      pdf.text_box h_dim.to_s, at: [value_x, dim_y], width: white_w - mm_to_pt(16), height: mm_to_pt(5)

      

      dim_y -= mm_to_pt(5.5)

      

      # Thickness

      pdf.fill_color '888888'

      pdf.font_size 7

      pdf.text_box "TH", at: [label_x, dim_y], width: mm_to_pt(8), height: mm_to_pt(4)

      pdf.fill_color '000000'

      pdf.font_size 11

      pdf.text_box thick.to_s, at: [value_x, dim_y], width: white_w - mm_to_pt(16), height: mm_to_pt(5)

      

      # 9. FOOTER (Bottom of white zone)

      footer_y = white_y - white_h + mm_to_pt(7)

      

      # Horizontal line

      pdf.stroke_color '000000'

      pdf.line_width 0.8

      pdf.stroke_horizontal_line banner_x, white_x + white_w - mm_to_pt(3), at: footer_y + mm_to_pt(2)

      

      # Footer text

      pdf.fill_color '000000'

      pdf.font("Helvetica", style: :normal)

      pdf.font_size 8

      

      pdf.text_box "ID: #{id}",

        at: [banner_x, footer_y],

        width: white_w * 0.5,

        height: mm_to_pt(5)

      

      if board

        pdf.text_box "B##{board}",

          at: [white_x + (white_w * 0.5), footer_y],

          width: (white_w * 0.5) - mm_to_pt(3),

          height: mm_to_pt(5),

          align: :right

      end

    end

    

    # Custom QR Renderer for Prawn

    # Draws the QR code using rectangles to avoid external image dependencies

    def draw_qr_code(pdf, content, x, y, size)

      # Create QR object using the real rqrcode gem

      # Use LOW error correction for maximum data capacity

      qr = RQRCode::QRCode.new(content.to_s, level: :l)

      

      # QR codes REQUIRE a quiet zone (white border) of at least 4 modules

      quiet_zone_modules = 4

      total_modules = qr.modules.size + (quiet_zone_modules * 2)

      module_size = size / total_modules.to_f

      

      # Draw WHITE background (CRITICAL for scanning!)

      pdf.fill_color 'FFFFFF'

      pdf.fill_rectangle [x, y], size, size

      

      # Calculate QR code position (offset by quiet zone)

      qr_x = x + (quiet_zone_modules * module_size)

      qr_y = y - (quiet_zone_modules * module_size)

      

      # Draw BLACK modules

      pdf.fill_color '000000'

      qr.modules.each_with_index do |row, row_index|

        row.each_with_index do |col, col_index|

          if col # If the module is true (black)

            # Calculate precise coordinates

            rect_x = qr_x + (col_index * module_size)

            rect_y = qr_y - (row_index * module_size)

            

            # Draw square

            pdf.fill_rectangle [rect_x, rect_y], module_size, module_size

          end

        end

      end

      

      # Add thin border for visual reference (optional)

      pdf.stroke_color 'CCCCCC'

      pdf.line_width 0.5

      pdf.stroke_rectangle [x, y], size, size

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
      puts "\n" + "🔍"*40
      puts "DEBUG: SHOW_PREVIEW_DIALOG CALLED"
      puts "🔍"*40
      puts "PDF Path: #{pdf_path}"
      puts "File exists: #{File.exist?(pdf_path)}"
      puts "File size: #{File.size(pdf_path)} bytes" if File.exist?(pdf_path)

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
      
      puts "✓ Dialog created"
      
      # Read PDF and encode to Base64 to bypass Chromium security
      begin
        require 'base64'
        puts "📄 Reading PDF file..."
        pdf_binary = File.binread(pdf_path)
        puts "✓ PDF read: #{pdf_binary.length} bytes"
        
        puts "🔐 Encoding to Base64..."
        base64_pdf = Base64.strict_encode64(pdf_binary)
        puts "✓ Base64 encoded: #{base64_pdf.length} characters"
        
        # Create Data URI
        pdf_data_uri = "data:application/pdf;base64,#{base64_pdf}"
        puts "✓ Data URI created (first 100 chars): #{pdf_data_uri[0...100]}"
        
      rescue => e
        puts "❌ ERROR encoding PDF: #{e.message}"
        puts e.backtrace.first(5).join("\n")
        UI.messagebox("Error encoding PDF: #{e.message}")
        return
      end
      
      puts "🌐 Generating HTML..."
      html_content = generate_preview_html(pdf_data_uri, parts_data.length)
      puts "✓ HTML generated (length: #{html_content.length})"
      
      puts "📝 Setting HTML content..."
      dialog.set_html(html_content)
      puts "✓ HTML set"
      
      # Add callback for export button
      dialog.add_action_callback("export_labels") do |action_context|
        puts "🔘 Export button clicked"
        save_path = UI.savepanel("Save Label Sheet", "", "label_sheet_#{Time.now.strftime('%Y%m%d_%H%M%S')}.pdf")
        if save_path
          begin
            require 'fileutils'
            FileUtils.cp(pdf_path, save_path)
            dialog.close
            File.delete(pdf_path) if File.exist?(pdf_path)
            
            UI.messagebox("Label sheet exported successfully!\n\n#{File.basename(save_path)}")
            puts "✓ Exported to: #{save_path}"
            
            # Ask if user wants to open
            result = UI.messagebox("Would you like to open the exported file?", MB_YESNO)
            if result == IDYES
              UI.openURL("file:///#{save_path.gsub('\\', '/')}")
            end
          rescue => e
            UI.messagebox("Error exporting labels: #{e.message}")
            puts "❌ Export error: #{e.message}"
          end
        else
          puts "⚠ Export cancelled"
        end
      end
      
      # Add callback for cancel button
      dialog.add_action_callback("cancel_export") do |action_context|
        puts "🔘 Cancel button clicked"
        dialog.close
        File.delete(pdf_path) if File.exist?(pdf_path)
      end
      
      puts "🚀 Showing dialog..."
      dialog.show
      puts "✓ Dialog shown"
      puts "🔍"*40 + "\n"
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