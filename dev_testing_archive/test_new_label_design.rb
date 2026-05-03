# Standalone Test for New Label Design
# This generates a sample label SVG to preview the new design

# Mock QRCodeGenerator for testing
class MockQRGenerator
  def generate_qr_code(data, options = {})
    size = options[:size] || 28
    # Generate a simple placeholder QR pattern
    <<~SVG
      <svg width="#{size}" height="#{size}" viewBox="0 0 #{size} #{size}" xmlns="http://www.w3.org/2000/svg">
        <rect width="#{size}" height="#{size}" fill="white"/>
        <rect x="2" y="2" width="6" height="6" fill="black"/>
        <rect x="#{size-8}" y="2" width="6" height="6" fill="black"/>
        <rect x="2" y="#{size-8}" width="6" height="6" fill="black"/>
        <rect x="#{size/2-2}" y="#{size/2-2}" width="4" height="4" fill="black"/>
        <rect x="4" y="10" width="2" height="2" fill="black"/>
        <rect x="8" y="10" width="2" height="2" fill="black"/>
        <rect x="12" y="10" width="2" height="2" fill="black"/>
        <rect x="16" y="10" width="2" height="2" fill="black"/>
        <rect x="20" y="10" width="2" height="2" fill="black"/>
      </svg>
    SVG
  end
end

# Simplified LabelGenerator for testing
class TestLabelGenerator
  STYLE_ORANGE = '#E65100'
  STYLE_BLACK = '#000000'
  STYLE_WHITE = '#FFFFFF'
  STYLE_BORDER_WIDTH = 2.5
  
  def initialize
    @qr_generator = MockQRGenerator.new
    @qr_size = 28
    @border_width = STYLE_BORDER_WIDTH
  end
  
  def generate_test_label
    part_data = {
      part_id: '49',
      board_number: '1',
      width: 2550.0,
      height: 910.0,
      thickness: 18.0
    }
    
    label_size = { width: 90.0, height: 98.0 }
    qr_svg = @qr_generator.generate_qr_code(part_data, size: @qr_size, padding: 0)
    
    content = generate_styled_label_content(part_data, qr_svg, label_size)
    create_full_svg(content, label_size)
  end
  
  def generate_styled_label_content(part_data, qr_svg, label_size)
    w = label_size[:width]
    h = label_size[:height]
    bw = @border_width
    half_bw = bw / 2.0

    # Layout Ratios
    top_row_height = h * 0.32
    bottom_row_height = h - top_row_height
    left_col_width = w * 0.38
    right_col_width = w - left_col_width
    metal_corner_size = top_row_height
    
    # Font sizes (reduced for better fit)
    font_xl = h * 0.13
    font_lg = h * 0.09
    font_md = h * 0.065
    font_sm = h * 0.055
    font_xs = h * 0.045  # W/H/TH labels

    content = ""
    
    inset = half_bw  # Define inset variable

    # Definitions with Google Fonts
    content += <<~SVG_DEFS
      <defs>
        <style type="text/css">
          @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;700&amp;display=swap');
        </style>
        <pattern id="diagonalHatch" patternUnits="userSpaceOnUse" width="4" height="4">
          <path d="M-1,1 l2,-2 M0,4 l4,-4 M3,5 l2,-2" stroke="#{STYLE_BLACK}" stroke-width="0.8"/>
        </pattern>
        <radialGradient id="metalGradient" cx="50%" cy="50%" r="50%" fx="50%" fy="50%">
          <stop offset="0%" style="stop-color:#ffffff;stop-opacity:1" />
          <stop offset="40%" style="stop-color:#d0d0d0;stop-opacity:1" />
          <stop offset="100%" style="stop-color:#a0a0a0;stop-opacity:1" />
        </radialGradient>
        <clipPath id="bannerClip">
          <rect x="#{bw}" y="#{inset}" width="#{w - metal_corner_size - bw * 2}" height="#{top_row_height - bw}"/>
        </clipPath>
        <clipPath id="dimensionsClip">
          <rect x="#{left_col_width + bw}" y="#{top_row_height + bw}" width="#{right_col_width - bw * 2}" height="#{bottom_row_height - bw * 2}"/>
        </clipPath>
      </defs>
    SVG_DEFS

    inset = half_bw

    # Background zones
    content += "<rect x='#{inset}' y='#{inset}' width='#{w - metal_corner_size - bw}' height='#{top_row_height - bw}' fill='#{STYLE_WHITE}' />"
    content += "<rect x='#{w - metal_corner_size + half_bw}' y='#{inset}' width='#{metal_corner_size - bw}' height='#{metal_corner_size - bw}' fill='url(#metalGradient)' />"
    content += "<rect x='#{inset}' y='#{top_row_height + half_bw}' width='#{left_col_width - bw}' height='#{bottom_row_height - bw}' fill='#{STYLE_ORANGE}' />"
    
    pattern_height = bottom_row_height * 0.45
    content += "<rect x='#{inset}' y='#{top_row_height + half_bw}' width='#{left_col_width - bw}' height='#{pattern_height}' fill='url(#diagonalHatch)' />"
    content += "<rect x='#{left_col_width + half_bw}' y='#{top_row_height + half_bw}' width='#{right_col_width - bw}' height='#{bottom_row_height - bw}' fill='#{STYLE_WHITE}' />"

    # Dividing lines
    content += "<line x1='#{inset}' y1='#{top_row_height}' x2='#{w - inset}' y2='#{top_row_height}' stroke='#{STYLE_BLACK}' stroke-width='#{bw}' stroke-linecap='butt' />"
    content += "<line x1='#{left_col_width}' y1='#{top_row_height + half_bw}' x2='#{left_col_width}' y2='#{h - inset}' stroke='#{STYLE_BLACK}' stroke-width='#{bw}' stroke-linecap='butt' />"
    content += "<line x1='#{w - metal_corner_size}' y1='#{inset}' x2='#{w - metal_corner_size}' y2='#{top_row_height - half_bw}' stroke='#{STYLE_BLACK}' stroke-width='#{bw}' stroke-linecap='butt' />"

    # Content
    part_id = part_data[:part_id]
    board_num = part_data[:board_number]
    dim_w = part_data[:width].round(1)
    dim_h = part_data[:height].round(1)
    dim_t = part_data[:thickness].round(1)
    dim_w_str = (dim_w % 1 == 0 ? "#{dim_w.to_i}.0" : dim_w.to_s)
    dim_h_str = (dim_h % 1 == 0 ? "#{dim_h.to_i}.0" : dim_h.to_s)
    dim_t_str = (dim_t % 1 == 0 ? "#{dim_t.to_i}.0" : dim_t.to_s)

    common_font = "font-family=\"'Inter', sans-serif\" fill=\"#{STYLE_BLACK}\""
    label_font = "font-family=\"'Inter', sans-serif\" fill=\"#888888\""  # Grey for W/H/TH labels

    # Top banner - clipped, no distortion, Inter font
    banner_text = "Part_#{part_id}"
    content += "<g clip-path=\"url(#bannerClip)\">"
    content += "<text x='#{bw * 3}' y='#{top_row_height / 2}' #{common_font} font-size='#{font_xl}' font-weight='bold' dominant-baseline='middle'>#{banner_text}</text>"
    content += "</g>"

    # QR code
    qr_pos_x = (left_col_width - @qr_size) / 2
    qr_available_height = bottom_row_height - pattern_height
    qr_pos_y = top_row_height + pattern_height + (qr_available_height - @qr_size) / 2
    
    content += "<g transform=\"translate(#{qr_pos_x}, #{qr_pos_y})\">"
    content += qr_svg
    content += "</g>"

    # Right column - with proper padding, unit shown once
    right_col_padding_x = left_col_width + bw * 3  # More padding
    right_col_top_y = top_row_height + bw * 3
    label_offset_x = font_xs * 2.5  # Space for W/H/TH labels

    content += "<g clip-path=\"url(#dimensionsClip)\">"
    
    # "Dimensions (mm)" - unit shown once
    content += "<text x='#{right_col_padding_x}' y='#{right_col_top_y + font_md}' #{common_font} font-size='#{font_md}'>Dimensions</text>"
    content += "<text x='#{right_col_padding_x + font_md * 5.5}' y='#{right_col_top_y + font_md}' #{label_font} font-size='#{font_xs}'>(mm)</text>"
    
    dim_line1_y = right_col_top_y + font_md + font_lg * 1.5
    dim_line2_y = right_col_top_y + font_md + font_lg * 2.8
    dim_line3_y = right_col_top_y + font_md + font_lg * 4.1
    
    # W label and width value (no "mm")
    content += "<text x='#{right_col_padding_x}' y='#{dim_line1_y}' #{label_font} font-size='#{font_xs}' font-weight='bold'>W</text>"
    content += "<text x='#{right_col_padding_x + label_offset_x}' y='#{dim_line1_y}' #{common_font} font-size='#{font_lg}' font-weight='bold'>#{dim_w_str}</text>"
    
    # H label and height value (no "mm")
    content += "<text x='#{right_col_padding_x}' y='#{dim_line2_y}' #{label_font} font-size='#{font_xs}' font-weight='bold'>H</text>"
    content += "<text x='#{right_col_padding_x + label_offset_x}' y='#{dim_line2_y}' #{common_font} font-size='#{font_lg}' font-weight='bold'>#{dim_h_str}</text>"
    
    # TH label and thickness value (no "mm")
    content += "<text x='#{right_col_padding_x}' y='#{dim_line3_y}' #{label_font} font-size='#{font_xs}' font-weight='bold'>TH</text>"
    content += "<text x='#{right_col_padding_x + label_offset_x}' y='#{dim_line3_y}' #{common_font} font-size='#{font_lg}' font-weight='bold'>#{dim_t_str}</text>"
    
    content += "</g>"

    # Footer - line centered between thickness and footer text
    footer_line_y = h - (font_sm * 2.5)
    content += "<line x1='#{right_col_padding_x}' y1='#{footer_line_y}' x2='#{w - bw * 2}' y2='#{footer_line_y}' stroke='#{STYLE_BLACK}' stroke-width='1' />"
    
    footer_text_y = footer_line_y + font_sm * 1.4
    content += "<text x='#{right_col_padding_x}' y='#{footer_text_y}' #{common_font} font-size='#{font_sm}'>ID: P#{part_id}</text>"
    content += "<text x='#{w - bw * 3}' y='#{footer_text_y}' #{common_font} font-size='#{font_sm}' text-anchor='end'>B##{board_num}</text>"

    content
  end
  
  def create_full_svg(content, label_size)
    w = label_size[:width]
    h = label_size[:height]
    bw = @border_width
    
    svg = <<~SVG_START
      <?xml version="1.0" encoding="UTF-8"?>
      <svg width="#{w}mm" height="#{h}mm" viewBox="0 0 #{w} #{h}" xmlns="http://www.w3.org/2000/svg">
    SVG_START
    
    # Outer border
    svg += "<rect x='#{bw/2.0}' y='#{bw/2.0}' width='#{w - bw}' height='#{h - bw}' "
    svg += "fill='none' stroke='#{STYLE_BLACK}' stroke-width='#{bw}' rx='#{bw}' ry='#{bw}'/>"
    
    svg += content
    svg += "</svg>"
    
    svg
  end
end

# Generate and save
puts "🎨 Generating new label design test..."
generator = TestLabelGenerator.new
svg_content = generator.generate_test_label

output_file = "test_label_new_design.svg"
File.write(output_file, svg_content)

puts "✅ Label generated: #{output_file}"
puts "📂 Opening in default viewer..."

# Auto-open the SVG file in default viewer
full_path = File.expand_path(output_file)
if RUBY_PLATFORM =~ /mswin|mingw|cygwin/
  # Windows
  system("start \"\" \"#{full_path}\"")
elsif RUBY_PLATFORM =~ /darwin/
  # macOS
  system("open \"#{full_path}\"")
else
  # Linux
  system("xdg-open \"#{full_path}\"")
end

puts ""
puts "Design features:"
puts "  • Orange zone with diagonal pattern"
puts "  • Metallic gradient corner"
puts "  • Bold Part_49 header in Inter font"
puts "  • Dimensions (mm) - unit shown once"
puts "  • W/H/TH labels (grey) with values"
puts "  • 2550.0 / 910.0 / 18.0 (no repetitive 'mm')"
puts "  • Proper padding - text never touches edges"
puts "  • Footer with ID and Board number"
puts "  • QR code in orange zone"
puts "  • Google Fonts Inter loaded"
