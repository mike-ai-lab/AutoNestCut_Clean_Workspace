# frozen_string_literal: true

# Label Generator for AutoNestCut
# Creates labels stylized to match a specific industrial design template.

require_relative 'qr_code_generator'

module AutoNestCut
  class LabelGenerator
    
    # Style constants based on the target image
    STYLE_ORANGE = '#E65100'
    STYLE_BLACK = '#000000'
    STYLE_WHITE = '#FFFFFF'
    STYLE_BORDER_WIDTH = 2.5 # mm, thick borders as seen in image
    
    # Label positions
    POSITION_TOP_LEFT = 'top-left'
    POSITION_TOP_RIGHT = 'top-right'
    POSITION_BOTTOM_LEFT = 'bottom-left'
    POSITION_BOTTOM_RIGHT = 'bottom-right'
    POSITION_CENTER = 'center'
    POSITION_AUTO = 'auto'
    
    def initialize(options = {})
      @qr_generator = QRCodeGenerator.new
      @options = default_options.merge(options)
    end
    
    # Default label options refined for the specific style
    def default_options
      {
        enabled: true,
        qr_enabled: true,
        qr_size: 28,                  # mm, specific size to fit orange zone
        label_position: POSITION_AUTO,
        # Base font size reference, actual sizes are calculated relative to layout
        font_size: 12,                
        background_color: STYLE_WHITE,
        border_color: STYLE_BLACK,
        text_color: STYLE_BLACK,
        border_width: STYLE_BORDER_WIDTH,
        # Fields needed to populate the specific design slots
        include_fields: {
          part_id: true,    # For top banner "Part_XX" and footer "ID: XX"
          dimensions: true, # For main dimensions area
          board_number: true # For footer "B#X"
        }
      }
    end
    
    # Generate label SVG for a part
    def generate_label(part_data, part_dimensions)
      return nil unless @options[:enabled]
      
      # Calculate label dimensions based on a fixed aspect ratio style
      label_size = calculate_label_size(part_data)
      
      # Calculate label position on part
      position = calculate_label_position(part_dimensions, label_size)
      return nil if position[:skip] # Part too small for label
      
      # Generate QR code
      qr_svg = nil
      if @options[:qr_enabled]
        # Generate QR without internal padding as we place it precisely
        qr_svg = @qr_generator.generate_qr_code(part_data, size: @options[:qr_size], padding: 0)
      end
      
      # Generate the complex internal SVG content structure
      label_content = generate_styled_label_content(part_data, qr_svg, label_size)
      
      # Create the outer container and place the content
      create_positioned_label(label_content, position, label_size)
    end
    
    # Calculate label size based on fixed target aspect ratio
    # The target image is roughly square, slightly taller than wide.
    # Let's define a standard size that scales nicely.
    def calculate_label_size(part_data)
      # Standard base size in mm that accommodates the layout nicely
      base_width = 90.0
      base_height = 98.0 # slightly taller ratio
      
      { width: base_width, height: base_height }
    end
    
    # Calculate optimal label position on part (Unchanged logic)
    def calculate_label_position(part_dimensions, label_size)
      part_width = part_dimensions[:width]
      part_height = part_dimensions[:height]
      label_width = label_size[:width]
      label_height = label_size[:height]
      
      # Check if part is large enough for label (needs to be bigger than the label itself)
      if part_width < label_width + 10 || part_height < label_height + 10
        return { skip: true, reason: 'Part too small for standard label style' }
      end
      
      # Calculate position based on preference
      margin = STYLE_BORDER_WIDTH * 2 # mm from edge, accounting for thick borders
      
      position = case @options[:label_position]
      when POSITION_TOP_LEFT
        { x: margin, y: margin }
      when POSITION_TOP_RIGHT
        { x: part_width - label_width - margin, y: margin }
      when POSITION_BOTTOM_LEFT
        { x: margin, y: part_height - label_height - margin }
      when POSITION_BOTTOM_RIGHT
        { x: part_width - label_width - margin, y: part_height - label_height - margin }
      when POSITION_CENTER
        { x: (part_width - label_width) / 2, y: (part_height - label_height) / 2 }
      else # AUTO - Top Right preference
        { x: part_width - label_width - margin, y: margin }
      end
      
      position.merge(skip: false)
    end
    
    # Generate the specific stylized content structure
    def generate_styled_label_content(part_data, qr_svg, label_size)
      w = label_size[:width]
      h = label_size[:height]
      bw = @options[:border_width]
      half_bw = bw / 2.0

      # Layout Ratios based on image analysis
      top_row_height = h * 0.32
      bottom_row_height = h - top_row_height
      left_col_width = w * 0.38
      right_col_width = w - left_col_width
      metal_corner_size = top_row_height
      
      # Font sizes relative to container height (viewBox-native units, not pt)
      font_xl = h * 0.13  # "Part_48" 
      font_lg = h * 0.09  # Dimensions values
      font_md = h * 0.065 # "Dimensions:" label
      font_sm = h * 0.055 # Footer ID/B#

      content = ""

      # --- 1. SVG Definitions (Gradients, Patterns, and Fonts) ---
      content += <<~svg_defs
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
      svg_defs

      # --- 2. Background Structure & Color Zones ---
      # We inset these slightly so the outer thick border defined in create_positioned_label doesn't overlap awkwardly
      inset = half_bw

      # Top Left Banner (White)
      content += "<rect x='#{inset}' y='#{inset}' width='#{w - metal_corner_size - bw}' height='#{top_row_height - bw}' fill='#{STYLE_WHITE}' />"

      # Top Right Metallic Corner
      content += "<rect x='#{w - metal_corner_size + half_bw}' y='#{inset}' width='#{metal_corner_size - bw}' height='#{metal_corner_size - bw}' fill='url(#metalGradient)' />"

      # Bottom Left (Orange Solid Base)
      content += "<rect x='#{inset}' y='#{top_row_height + half_bw}' width='#{left_col_width - bw}' height='#{bottom_row_height - bw}' fill='#{STYLE_ORANGE}' />"

      # Bottom Left (Diagonal Pattern Overlay - top half of orange zone)
      pattern_height = bottom_row_height * 0.45
      content += "<rect x='#{inset}' y='#{top_row_height + half_bw}' width='#{left_col_width - bw}' height='#{pattern_height}' fill='url(#diagonalHatch)' />"

      # Bottom Right (White)
      content += "<rect x='#{left_col_width + half_bw}' y='#{top_row_height + half_bw}' width='#{right_col_width - bw}' height='#{bottom_row_height - bw}' fill='#{STYLE_WHITE}' />"


      # --- 3. Internal Dividing Lines (Thick Black) ---
      # Horizontal divider spanning full width
      content += "<line x1='#{inset}' y1='#{top_row_height}' x2='#{w - inset}' y2='#{top_row_height}' stroke='#{STYLE_BLACK}' stroke-width='#{bw}' stroke-linecap='butt' />"
      
      # Vertical divider (separating orange/white bottom sections)
      content += "<line x1='#{left_col_width}' y1='#{top_row_height + half_bw}' x2='#{left_col_width}' y2='#{h - inset}' stroke='#{STYLE_BLACK}' stroke-width='#{bw}' stroke-linecap='butt' />"
      
      # Vertical divider (separating top banner and metal corner)
      content += "<line x1='#{w - metal_corner_size}' y1='#{inset}' x2='#{w - metal_corner_size}' y2='#{top_row_height - half_bw}' stroke='#{STYLE_BLACK}' stroke-width='#{bw}' stroke-linecap='butt' />"


      # --- 4. Content Placement ---
      
      # Data Extraction
      part_id = escape_xml(part_data[:part_id] || part_data['part_id'] || 'N/A')
      board_num = escape_xml(part_data[:board_number] || part_data['board_number'] || '1')
      dim_w = (part_data[:width] || part_data['width']).to_f.round(1)
      dim_h = (part_data[:height] || part_data['height']).to_f.round(1)
      dim_t = (part_data[:thickness] || part_data['thickness']).to_f.round(1)
      # Ensure consistent formatting X.0mm
      dim_w_str = (dim_w % 1 == 0 ? "#{dim_w.to_i}.0" : dim_w.to_s)
      dim_h_str = (dim_h % 1 == 0 ? "#{dim_h.to_i}.0" : dim_h.to_s)
      dim_t_str = (dim_t % 1 == 0 ? "#{dim_t.to_i}.0" : dim_t.to_s)

      common_font = "font-family=\"'Inter', sans-serif\" fill=\"#{STYLE_BLACK}\""
      label_font = "font-family=\"'Inter', sans-serif\" fill=\"#888888\""  # Grey for W/H/TH labels

      # Top Banner Text "Part_XX" - clipped to avoid overlap, no distortion
      banner_text = "Part_#{part_id}"
      content += "<g clip-path=\"url(#bannerClip)\">"
      content += "<text x='#{bw * 3}' y='#{top_row_height / 2}' #{common_font} font-size='#{font_xl}' font-weight='bold' dominant-baseline='middle'>#{banner_text}</text>"
      content += "</g>"

      # QR Code Placement (in the solid orange section)
      if @options[:qr_enabled] && qr_svg
        qr_pos_x = (left_col_width - @options[:qr_size]) / 2
        # Center vertically in the bottom (solid orange) part of the left column
        qr_available_height = bottom_row_height - pattern_height
        qr_pos_y = top_row_height + pattern_height + (qr_available_height - @options[:qr_size]) / 2
        
        content += "<g transform=\"translate(#{qr_pos_x}, #{qr_pos_y})\">"
        content += qr_svg
        content += "</g>"
      end

      # Right Column Content - with proper padding to avoid edge clipping
      right_col_padding_x = left_col_width + bw * 3  # More padding from left edge
      right_col_top_y = top_row_height + bw * 3
      label_offset_x = font_xs * 2.5  # Space for W/H/TH labels

      content += "<g clip-path=\"url(#dimensionsClip)\">"
      
      # "Dimensions (mm)" Label - unit shown once
      content += "<text x='#{right_col_padding_x}' y='#{right_col_top_y + font_md}' #{common_font} font-size='#{font_md}'>Dimensions</text>"
      content += "<text x='#{right_col_padding_x + font_md * 5.5}' y='#{right_col_top_y + font_md}' #{label_font} font-size='#{font_xs}'>(mm)</text>"

      # Large Dimension Values with W/H/TH labels (no "mm" on each line)
      dim_line1_y = right_col_top_y + font_md + font_lg * 1.5
      dim_line2_y = right_col_top_y + font_md + font_lg * 2.8
      dim_line3_y = right_col_top_y + font_md + font_lg * 4.1
      
      # W label and width value
      content += "<text x='#{right_col_padding_x}' y='#{dim_line1_y}' #{label_font} font-size='#{font_xs}' font-weight='bold'>W</text>"
      content += "<text x='#{right_col_padding_x + label_offset_x}' y='#{dim_line1_y}' #{common_font} font-size='#{font_lg}' font-weight='bold'>#{dim_w_str}</text>"
      
      # H label and height value
      content += "<text x='#{right_col_padding_x}' y='#{dim_line2_y}' #{label_font} font-size='#{font_xs}' font-weight='bold'>H</text>"
      content += "<text x='#{right_col_padding_x + label_offset_x}' y='#{dim_line2_y}' #{common_font} font-size='#{font_lg}' font-weight='bold'>#{dim_h_str}</text>"
      
      # TH label and thickness value
      content += "<text x='#{right_col_padding_x}' y='#{dim_line3_y}' #{label_font} font-size='#{font_xs}' font-weight='bold'>TH</text>"
      content += "<text x='#{right_col_padding_x + label_offset_x}' y='#{dim_line3_y}' #{common_font} font-size='#{font_lg}' font-weight='bold'>#{dim_t_str}</text>"
      
      content += "</g>"

      # Footer Section - line centered between thickness text and footer text
      footer_line_y = h - (font_sm * 2.5)
      # Thin footer line
      content += "<line x1='#{right_col_padding_x}' y1='#{footer_line_y}' x2='#{w - bw * 2}' y2='#{footer_line_y}' stroke='#{STYLE_BLACK}' stroke-width='1' />"
      
      footer_text_y = footer_line_y + font_sm * 1.4
      # ID text left
      content += "<text x='#{right_col_padding_x}' y='#{footer_text_y}' #{common_font} font-size='#{font_sm}'>ID: P#{part_id}</text>"
      # Board number right aligned
      content += "<text x='#{w - bw * 3}' y='#{footer_text_y}' #{common_font} font-size='#{font_sm}' text-anchor='end'>B##{board_num}</text>"

      content
    end
    
    # Create positioned label SVG container (Updated for thick borders)
    def create_positioned_label(content, position, label_size)
      x = position[:x]
      y = position[:y]
      width = label_size[:width]
      height = label_size[:height]
      bw = @options[:border_width]
      
      svg = "<g class=\"part-label\" transform=\"translate(#{x}, #{y})\">"
      
      # Main Outer Border Rectangle
      # We draw the stroke *outside* the defined width/height to avoid crushing content
      svg += "<rect x='#{bw/2.0}' y='#{bw/2.0}' width='#{width - bw}' height='#{height - bw}' "
      svg += "fill='none' " # Fill handled by inner content structures
      svg += "stroke='#{@options[:border_color]}' "
      svg += "stroke-width='#{bw}' "
      # Small border radius for outer corners
      svg += "rx='#{bw}' ry='#{bw}'/>"
      
      # Clip path to ensure inner square corners don't bleed out the rounded outer corners
      svg += "<clipPath id='labelClip'><rect x='#{bw}' y='#{bw}' width='#{width - bw*2}' height='#{height - bw*2}' rx='#{bw/2}' ry='#{bw/2}'/></clipPath>"
      svg += "<g clip-path='url(#labelClip)'>"
      svg += content
      svg += "</g>"
      
      svg += "</g>"
      
      svg
    end
    
    # Utility: Escape XML special characters
    def escape_xml(text)
      return '' unless text
      text.to_s
          .gsub('&', '&amp;')
          .gsub('<', '&lt;')
          .gsub('>', '&gt;')
          .gsub('"', '&quot;')
          .gsub("'", '&apos;')
    end
    
    # Update label options
    def update_options(new_options)
      @options.merge!(new_options)
    end
    
  end
end