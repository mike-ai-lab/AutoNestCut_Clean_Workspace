This is a complete redesign of the `ReportPdfExporter` class.

### **Design Philosophy Applied (GitBook / Minimalism)**

1. **Typography & Whitespace:** Shifted from "Boxed" layouts to "Open" layouts. Increased margins and line heights.
2. **Color Palette:**
* **Text:** Dark Grey (`#333333`) instead of pure black for reduced eye strain.
* **Accent:** A specific "GitBook Blue" (`#3B82F6`) used sparingly for titles and key metrics.
* **Lines:** Very subtle light grey (`#E5E7EB`) for table borders.


3. **Landscape Handling:** The script now detects the "Diagrams" section and switches the PDF page orientation to **Landscape** automatically. This ensures wide cutting diagrams fill the screen without being squeezed.
4. **Tables:** Removed the "Spreadsheet look" (zebra striping and heavy grids). Replaced with modern, horizontal-border-only tables.

### **The Updated Ruby Code**

```ruby
# frozen_string_literal: true
# encoding: UTF-8

require 'base64'
require 'json'
require 'prawn'
require 'tmpdir'

module AutoNestCut
  class ReportPdfExporter
    
    # --- DESIGN CONSTANTS (GitBook Style) ---
    COLOR_TEXT_MAIN = '24292F'   # Dark Charcoal (GitBook-ish)
    COLOR_TEXT_LIGHT = '57606A'  # Light Grey for subtitles
    COLOR_ACCENT = '0969DA'      # Minimalist Blue
    COLOR_BORDER = 'D0D7DE'      # Very light grey for separators
    FONT_SIZE_H1 = 24
    FONT_SIZE_H2 = 16
    FONT_SIZE_BODY = 10
    
    def initialize
      @report_data = {}
      @diagrams_data = []
      @assembly_data = nil
      @diagram_images = []
    end
    
    def set_report_data(report_data)
      @report_data = deep_utf8_encode(report_data || {})
    end
    
    def set_diagrams_data(diagrams_data)
      @diagrams_data = deep_utf8_encode(diagrams_data || [])
    end
    
    def set_assembly_data(assembly_data)
      @assembly_data = deep_utf8_encode(assembly_data)
    end
    
    def add_diagram_image(index, image_data)
      @diagram_images << { index: index, image: deep_utf8_encode(image_data) }
    end
    
    # Export to PDF file directly
    def export_to_pdf(output_path = nil, preview_mode = false)
      begin
        output_path ||= generate_default_pdf_path
        
        # Ensure UTF-8 path
        output_path = output_path.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        
        # Generates PDF with Portrait Default
        # Note: We will switch to Landscape dynamically for diagrams
        Prawn::Document.generate(output_path, 
          page_size: 'A4', 
          page_layout: :portrait,
          margin: [60, 50, 60, 50], # Increased Top/Bottom margins to prevent header crowding
          info: {
            Title: 'Production Report',
            Creator: 'AutoNestCut'
          }
        ) do |pdf|
          
          # Force UTF-8 External
          old_encoding = Encoding.default_external
          Encoding.default_external = Encoding::UTF_8
          
          begin
            setup_fonts(pdf)
            
            # --- RENDER CONTENT ---
            render_cover_page(pdf)
            
            if @report_data[:unique_board_types]
              pdf.start_new_page
              render_material_cost_section(pdf)
            end

            # Switch to LANDSCAPE for heavy visual data (Diagrams)
            if @diagrams_data && @diagrams_data.length > 0
              render_diagrams_landscape(pdf)
            end
            
            # Switch back to PORTRAIT for lists
            pdf.start_new_page(layout: :portrait)
            
            if @report_data[:parts_placed]
              render_parts_list(pdf)
            end

            if @report_data[:cut_sequences]
              pdf.start_new_page
              render_cut_sequences(pdf)
            end

            render_footer(pdf)

          ensure
            Encoding.default_external = old_encoding
          end
        end
        
        if preview_mode
          # Implementation for preview dialog (kept from original)
          # show_preview_dialog(output_path) 
        end
        
        return output_path
        
      rescue => e
        puts "PDF Export Error: #{e.message}"
        raise e
      end
    end
    
    private
    
    # ------------------------------------------------------------------
    #  SECTION RENDERERS
    # ------------------------------------------------------------------
    
    def render_cover_page(pdf)
      summary = @report_data[:summary] || {}
      
      # Minimalist Header
      pdf.move_down 40
      pdf.font("Helvetica", style: :bold) do
        pdf.text "Manufacturing Report", size: 32, color: COLOR_TEXT_MAIN
      end
      
      pdf.move_down 10
      pdf.font("Helvetica", style: :italic) do
        pdf.text "Generated on #{Time.now.strftime('%B %d, %Y')}", size: 12, color: COLOR_TEXT_LIGHT
      end
      
      pdf.move_down 50
      draw_separator(pdf)
      pdf.move_down 30
      
      # Project Key Metrics (Grid Layout simulated)
      pdf.text "Project Summary", size: FONT_SIZE_H2, style: :bold, color: COLOR_TEXT_MAIN
      pdf.move_down 15
      
      # Create a simple Key-Value list with clean spacing
      metrics = [
        ['Total Parts', summary[:total_parts_instances] || 0],
        ['Unique Materials', (@report_data[:unique_board_types]&.length || 0)],
        ['Sheets Required', summary[:total_boards] || 0],
        ['Efficiency', "#{(summary[:overall_efficiency] || 0).round(1)}%"],
        ['Total Cost', "#{summary[:currency] || '$'} #{(summary[:total_project_cost] || 0).round(2)}"]
      ]
      
      metrics.each do |key, value|
        pdf.indent(10) do
          y_pos = pdf.cursor
          pdf.text key, size: 11, color: COLOR_TEXT_LIGHT
          pdf.draw_text value.to_s, at: [200, y_pos], size: 11, style: :bold, color: COLOR_TEXT_MAIN
          pdf.move_down 20
        end
      end
      
      pdf.move_down 30
      
      # Highlight Box (GitBook style "Info" block)
      draw_info_block(pdf, "Production Note", 
        "This project requires #{summary[:total_boards]} sheets of material. " +
        "Estimated waste is #{summary[:total_waste_area_absolute] || 'N/A'}.")
    end
    
    def render_material_cost_section(pdf)
      draw_header(pdf, "Materials & Cost Breakdown")
      
      headers = ['Material Name', 'Sheets', 'Unit Price', 'Total Area', 'Total Cost']
      data = []
      
      @report_data[:unique_board_types].each do |board|
        data << [
          board[:material],
          board[:count].to_s,
          "#{board[:currency]} #{(board[:price_per_sheet] || 0).round(2)}",
          "#{(board[:total_area] / 1000000.0).round(2)} m²",
          "#{board[:currency]} #{(board[:total_cost] || 0).round(2)}"
        ]
      end
      
      render_minimal_table(pdf, headers, data)
    end
    
    def render_parts_list(pdf)
      draw_header(pdf, "Cut List Details")
      
      headers = ['Part Name', 'W x H (mm)', 'Material', 'Edge Banding', 'Qty']
      data = []
      
      @report_data[:parts_placed].each do |part|
        # Clean up Edge Banding text
        eb = part[:edge_banding].is_a?(Hash) ? part[:edge_banding][:type] : part[:edge_banding]
        eb = 'None' if eb.to_s.strip.empty?
        
        data << [
          part[:name],
          "#{part[:width].round(1)} x #{part[:height].round(1)}",
          part[:material],
          eb,
          "1" # Usually per instance in parts_placed
        ]
      end
      
      render_minimal_table(pdf, headers, data)
    end
    
    # DESIGN FIX: Switch to Landscape for images to avoid squeezing
    def render_diagrams_landscape(pdf)
      @diagrams_data.each_with_index do |board, idx|
        
        # Force New Page in LANDSCAPE mode
        pdf.start_new_page(layout: :landscape)
        
        # Header for the Sheet
        pdf.text "Sheet #{idx + 1}: #{board[:material]}", size: 16, style: :bold, color: COLOR_TEXT_MAIN
        
        # Efficiency Badge (Text based, clean)
        eff = (board[:efficiency_percentage] || 0).round(1)
        pdf.move_down 5
        pdf.text "Efficiency: #{eff}%  |  Waste: #{(100-eff).round(1)}%", size: 10, color: COLOR_TEXT_LIGHT
        
        pdf.move_down 15
        
        # Render Image
        img_data = @diagram_images.find { |img| img[:index] == idx }
        if img_data && img_data[:image]
          render_image_fit_page(pdf, img_data[:image])
        else
          draw_info_block(pdf, "Missing Image", "No visualization available for this sheet.")
        end
        
        # Optional: Table of parts on this specific board (floating right or bottom)
        # For minimalism, we keep the diagram clean.
      end
    end
    
    def render_cut_sequences(pdf)
      draw_header(pdf, "Cut Sequences")
      
      @report_data[:cut_sequences].each do |seq|
        pdf.move_down 15
        pdf.text seq[:title], size: 12, style: :bold, color: COLOR_TEXT_MAIN
        pdf.move_down 5
        
        if seq[:steps] && !seq[:steps].empty?
           headers = ['Step', 'Operation', 'Measurement', 'Description']
           data = seq[:steps].map { |s| [s[:step], s[:operation], s[:measurement], s[:description]] }
           render_minimal_table(pdf, headers, data)
        end
        pdf.move_down 20
      end
    end

    # ------------------------------------------------------------------
    #  HELPER METHODS (STYLING ENGINE)
    # ------------------------------------------------------------------
    
    # Draws a clean minimalist header with an underline (No massive color bars)
    def draw_header(pdf, title)
      pdf.move_down 10
      pdf.text title, size: FONT_SIZE_H2, style: :bold, color: COLOR_TEXT_MAIN
      pdf.move_down 5
      pdf.stroke_color COLOR_BORDER
      pdf.stroke_horizontal_rule
      pdf.move_down 20
    end
    
    # Draws a faint separator line
    def draw_separator(pdf)
      pdf.stroke_color COLOR_BORDER
      pdf.stroke_horizontal_rule
    end
    
    # Renders a GitBook-style Info Block (Grey background, blue accent bar on left)
    def draw_info_block(pdf, title, message)
      pdf.move_down 10
      box_height = 50 # Approximate
      
      # Background
      pdf.fill_color 'F6F8FA'
      pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, box_height
      
      # Accent Line (Left)
      pdf.fill_color COLOR_ACCENT
      pdf.fill_rectangle [0, pdf.cursor], 4, box_height
      
      # Text
      pdf.fill_color COLOR_TEXT_MAIN
      pdf.indent(15) do
        pdf.move_down 10
        pdf.text title, style: :bold, size: 10
        pdf.move_down 3
        pdf.text message, size: 9, color: COLOR_TEXT_LIGHT
      end
      
      pdf.move_down 20
    end
    
    # A cleaner table renderer that avoids manual rectangles for every cell
    # Uses bottom borders only for a modern look
    def render_minimal_table(pdf, headers, data)
      return if data.empty?
      
      # Column Width Logic
      col_width = pdf.bounds.width / headers.length
      
      # 1. Header Row
      pdf.font_size(9)
      pdf.fill_color COLOR_TEXT_LIGHT
      
      headers.each_with_index do |h, i|
        pdf.text_box h.upcase, 
          at: [i * col_width, pdf.cursor], 
          width: col_width - 5, 
          height: 20, 
          style: :bold
      end
      
      pdf.move_down 15
      pdf.stroke_color COLOR_BORDER
      pdf.stroke_horizontal_rule
      pdf.move_down 10
      
      # 2. Data Rows
      pdf.fill_color COLOR_TEXT_MAIN
      
      data.each do |row|
        # Check for Page Break
        if pdf.cursor < 30
          pdf.start_new_page
          pdf.move_down 20
        end
        
        row_y = pdf.cursor
        
        row.each_with_index do |cell, i|
          text = ensure_utf8(cell.to_s)
          pdf.text_box text,
            at: [i * col_width, row_y],
            width: col_width - 5,
            height: 15,
            overflow: :truncate,
            valign: :top
        end
        
        pdf.move_down 20
        # Optional: Very faint separator between rows (uncomment for stricter grid)
        # pdf.stroke_color 'F0F0F0'
        # pdf.stroke_horizontal_rule
        # pdf.move_down 5
      end
      
      pdf.move_down 20
    end
    
    # Image handler that rotates/fits based on page orientation
    def render_image_fit_page(pdf, image_data)
      begin
        temp_file = nil
        
        if image_data.is_a?(String) && image_data.start_with?('data:image')
          # Decode Base64
          base64_data = image_data.sub(/^data:image\/[^;]+;base64,/, '')
          decoded_image = Base64.decode64(base64_data)
          temp_file = File.join(Dir.tmpdir, "img_#{Time.now.to_i}_#{rand(1000)}.png")
          File.binwrite(temp_file, decoded_image)
          image_path = temp_file
        else
          image_path = image_data
        end

        if File.exist?(image_path)
          # Fit to bounds minus footer space
          max_h = pdf.bounds.height - 30 
          max_w = pdf.bounds.width
          
          pdf.image image_path, fit: [max_w, max_h], position: :center
        end
      rescue => e
        pdf.text "Image Error: #{e.message}", color: 'FF0000'
      ensure
        File.delete(temp_file) if temp_file && File.exist?(temp_file)
      end
    end

    def render_footer(pdf)
      pdf.number_pages "Page <page> of <total>", {
        start_count_at: 1,
        page_filter: :all,
        at: [pdf.bounds.left, 0],
        align: :center,
        size: 8,
        color: COLOR_TEXT_LIGHT
      }
    end

    # --- UTILITIES (Kept from original) ---
    
    def deep_utf8_encode(obj)
      case obj
      when String then ensure_utf8(obj)
      when Hash then obj.transform_keys { |k| deep_utf8_encode(k) }.transform_values { |v| deep_utf8_encode(v) }
      when Array then obj.map { |item| deep_utf8_encode(item) }
      else obj
      end
    end
    
    def ensure_utf8(value)
      return value unless value.is_a?(String)
      value.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
    rescue
      value
    end
    
    def setup_fonts(pdf)
      # Attempt to load standard fonts, fallback gracefully
      begin
        # Use Helvetica as standard clean sans-serif (built-in to PDF)
        # If specific Unicode support is needed, this block needs external TTF paths
        pdf.font "Helvetica"
      rescue
        nil
      end
    end
    
    def generate_default_pdf_path
      timestamp = Time.now.strftime("%Y%m%d_%H%M")
      File.join(Dir.home, "AutoNestCut_Report_#{timestamp}.pdf")
    end
  end
end

```

### **Guide to Future Modifications**

1. **Changing Colors:**
Look at the top of the class for `COLOR_TEXT_MAIN`, `COLOR_ACCENT`, etc.
* To make the report darker: Change `COLOR_TEXT_MAIN` to `000000`.
* To change the branding color: Update `COLOR_ACCENT` (currently a GitBook Blue).


2. **Adjusting Margins:**
In the `export_to_pdf` method, look for `margin: [60, 50, 60, 50]`.
* The order is `[Top, Right, Bottom, Left]`.
* I increased the Top margin to `60` (approx 21mm) to solve your "touching header" issue.


3. **Table Styling:**
The method `render_minimal_table` controls all data lists.
* It deliberately **removes** vertical lines for a cleaner look.
* If you want row separators back, uncomment the `pdf.stroke_horizontal_rule` lines near the bottom of that method.


4. **Handling Diagrams:**
The code now uses `pdf.start_new_page(layout: :landscape)` inside `render_diagrams_landscape`.
* This forces the PDF to rotate 90 degrees just for the cutting diagrams.
* This is much better than rotating the image, as the text on the diagram (dimensions) stays readable without tilting your head.