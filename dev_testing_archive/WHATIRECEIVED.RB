# frozen_string_literal: true

# ==============================================================================
# DEPENDENCY LOADER
# ==============================================================================
module AutoNestCut
  VENDOR_DIR = File.expand_path('../../../vendor', __FILE__)
  
  def self.load_vendored_gem(gem_name)
    gem_path = File.join(VENDOR_DIR, gem_name)
    if File.directory?(gem_path)
      $LOAD_PATH.unshift(gem_path) unless $LOAD_PATH.include?(gem_path)
      return true
    end
    false
  end
  
  def self.ensure_gem_installed(gem_name, lib_name = gem_name)
    begin
      require lib_name
    rescue LoadError
      begin
        Gem.install(gem_name)
        require lib_name
      rescue => e
        UI.messagebox("Error: Could not install required gem '#{gem_name}'.")
        raise e
      end
    end
  end
end

AutoNestCut.load_vendored_gem('rqrcode_core')
AutoNestCut.load_vendored_gem('rqrcode')
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
    
    # Industrial Design Constants
    COLOR_ORANGE = 'E65100'
    COLOR_BLACK  = '000000'
    COLOR_WHITE  = 'FFFFFF'
    COLOR_METAL  = 'D0D0D0'
    BORDER_WIDTH = 1.5 # pts
    
    FORMATS = {
      'avery_5160' => { cols: 3, rows: 10, width: 66.7, height: 25.4, margin_top: 12.7, margin_left: 4.8, spacing_h: 3.2, spacing_v: 0 },
      'custom'     => { cols: 3, rows: 4, width: 65, height: 65, spacing_h: 5, spacing_v: 8 } # Adjusted for square design
    }
    
    def initialize(format = 'custom')
      @format = FORMATS[format] || FORMATS['custom']
    end
    
    def generate_label_sheet(parts_data, output_path = nil, preview_mode = false)
      output_path ||= File.join(Dir.tmpdir, "label_sheet_#{Time.now.to_i}.pdf")
      
      Prawn::Document.generate(output_path, page_size: 'A4', margin: [40, 40, 40, 40]) do |pdf|
        pdf.font "Helvetica"
        labels_per_page = @format[:cols] * @format[:rows]
        
        # Centering logic
        total_w_mm = (@format[:cols] * @format[:width]) + ((@format[:cols] - 1) * @format[:spacing_h])
        margin_left_mm = ( (pdf.bounds.width / 2.83465) - total_w_mm ) / 2
        start_y_pt = pdf.cursor
        
        parts_data.each_with_index do |part, index|
          if index > 0 && index % labels_per_page == 0
            pdf.start_new_page
            start_y_pt = pdf.cursor
          end
          
          idx = index % labels_per_page
          row, col = idx / @format[:cols], idx % @format[:cols]
          
          x_pos = mm_to_pt(margin_left_mm + (col * (@format[:width] + @format[:spacing_h])))
          y_pos = start_y_pt - mm_to_pt(row * (@format[:height] + @format[:spacing_v]))
          
          render_industrial_label(pdf, part, x_pos, y_pos)
        end
      end
      
      show_preview_dialog(output_path, parts_data) if preview_mode
      output_path
    end

    private

    def render_industrial_label(pdf, part_data, x, y)
      w = mm_to_pt(@format[:width])
      h = mm_to_pt(@format[:height])
      
      # Layout Calculations
      top_h = h * 0.32
      left_w = w * 0.38
      metal_size = top_h
      
      pdf.line_width BORDER_WIDTH
      
      # 1. Background Zones
      pdf.fill_color COLOR_WHITE
      pdf.fill_rectangle [x, y], w, top_h # Top Banner
      
      pdf.fill_color COLOR_ORANGE
      pdf.fill_rectangle [x, y - top_h], left_w, (h - top_h) # Left Column
      
      pdf.fill_color COLOR_WHITE
      pdf.fill_rectangle [x + left_w, y - top_h], (w - left_w), (h - top_h) # Right Column

      # 2. Diagonal Hatching (Top of Orange Section)
      pdf.stroke_color COLOR_BLACK
      pdf.line_width 0.5
      hatch_h = (h - top_h) * 0.45
      pdf.bounding_box([x, y - top_h], width: left_w, height: hatch_h) do
        (0..40).each do |i|
          offset = i * 3
          pdf.stroke_line [0, hatch_h - offset], [offset, hatch_h]
        end
      end

      # 3. Metallic Corner (Radial Gradient)
      pdf.fill_gradient [x + w - (metal_size/2), y - (metal_size/2)], 0, 
                        [x + w - (metal_size/2), y - (metal_size/2)], metal_size/2,
                        COLOR_WHITE, COLOR_METAL
      pdf.fill_rectangle [x + w - metal_size, y], metal_size, metal_size

      # 4. Dividing Lines
      pdf.stroke_color COLOR_BLACK
      pdf.line_width BORDER_WIDTH
      pdf.stroke_horizontal_line x, x + w, at: y - top_h
      pdf.stroke_vertical_line y - top_h, y - h, at: x + left_w
      pdf.stroke_vertical_line y, y - top_h, at: x + w - metal_size
      pdf.stroke_rectangle [x, y], w, h # Outer Border

      # 5. Text Content
      id = (part_data[:part_id] || part_data['part_id'] || "N/A").to_s
      board = part_data[:board_number] || part_data['board_number']
      w_dim = (part_data[:width] || part_data['width'] || 0).to_f.round(1)
      h_dim = (part_data[:height] || part_data['height'] || 0).to_f.round(1)

      # Header
      pdf.fill_color COLOR_BLACK
      pdf.text_box "Part_#{id}", at: [x + 5, y - (top_h/2) + 6], size: top_h * 0.4, style: :bold

      # Dimensions (Right Side)
      dim_x = x + left_w + 5
      dim_y = y - top_h - 10
      pdf.text_box "Dimensions:", at: [dim_x, dim_y], size: 7
      pdf.text_box "#{w_dim} x\n#{h_dim}mm", at: [dim_x, dim_y - 10], size: 11, style: :bold, leading: 2

      # Footer
      footer_y = y - h + 12
      pdf.line_width 0.5
      pdf.stroke_horizontal_line dim_x, x + w - 5, at: footer_y + 2
      pdf.text_box "ID: P#{id}", at: [dim_x, footer_y], size: 7, style: :bold
      pdf.text_box "B##{board}", at: [dim_x, footer_y], size: 7, align: :right, width: (w - left_w - 10)

      # 6. QR Code (Positioned in solid orange area)
      qr_size = left_w * 0.7
      qr_x = x + (left_w - qr_size) / 2
      qr_y = y - h + ((h - top_h - hatch_h - qr_size) / 2) + qr_size
      draw_qr_code(pdf, id, qr_x, qr_y, qr_size)
    end

    def draw_qr_code(pdf, content, x, y, size)
      qr = RQRCode::QRCode.new(content.to_s, level: :l)
      module_size = size / qr.modules.size.to_f
      pdf.fill_color COLOR_BLACK
      qr.modules.each_with_index do |row, r_idx|
        row.each_with_index do |col, c_idx|
          if col
            pdf.fill_rectangle [x + (c_idx * module_size), y - (r_idx * module_size)], module_size, module_size
          end
        end
      end
    end

    def mm_to_pt(mm); mm * 2.83465; end

    def show_preview_dialog(pdf_path, parts_data)
      # Implementation remains same as your original script
      # ...
    end
  end
end