# frozen_string_literal: true

# Label Generator for AutoNestCut
# Creates labels with QR codes and part information for nesting diagrams

require_relative 'qr_code_generator'

module AutoNestCut
  class LabelGenerator
    
    # Label styles
    STYLE_MINIMAL = 'minimal'       # ID only
    STYLE_COMPACT = 'compact'       # ID + dimensions
    STYLE_DETAILED = 'detailed'     # All information
    
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
    
    # Default label options
    def default_options
      {
        enabled: true,
        qr_enabled: true,
        qr_size: 20,              # mm (smaller for now)
        label_position: POSITION_AUTO,
        label_style: STYLE_COMPACT,
        font_size: 10,            # pt (larger for readability)
        padding: 4,               # mm (more padding)
        background_color: '#FFFFFF',
        border_color: '#333333',
        text_color: '#000000',
        border_width: 1,          # mm (thicker border)
        include_fields: {
          part_id: true,
          part_name: true,
          dimensions: true,
          material: false,
          board_number: false
        }
      }
    end
    
    # Generate label SVG for a part
    def generate_label(part_data, part_dimensions)
      return nil unless @options[:enabled]
      
      # Calculate label dimensions
      label_size = calculate_label_size(part_data)
      
      # Calculate label position on part
      position = calculate_label_position(part_dimensions, label_size)
      return nil if position[:skip] # Part too small for label
      
      # Generate QR code
      qr_svg = nil
      if @options[:qr_enabled]
        qr_svg = @qr_generator.generate_qr_code(part_data, size: @options[:qr_size])
      end
      
      # Generate label content
      label_content = generate_label_content(part_data, qr_svg, label_size)
      
      # Create positioned label SVG
      create_positioned_label(label_content, position, label_size)
    end
    
    # Calculate label size based on content
    def calculate_label_size(part_data)
      qr_size = @options[:qr_enabled] ? @options[:qr_size] : 0
      padding = @options[:padding]
      font_size = @options[:font_size]
      
      # Estimate text height based on number of lines
      text_lines = count_text_lines(part_data)
      line_height = font_size * 0.6 # mm per line
      text_height = (text_lines * line_height) + (font_size * 0.5) # Add top margin
      
      # Estimate text width (rough approximation)
      text_width = 50 # mm (enough for most part names)
      
      # Calculate dimensions
      if @options[:qr_enabled]
        width = qr_size + text_width + (padding * 3)
        height = [qr_size, text_height].max + (padding * 2)
      else
        width = text_width + (padding * 2)
        height = text_height + (padding * 2)
      end
      
      { width: width, height: height }
    end
    
    # Count number of text lines based on style
    def count_text_lines(part_data)
      case @options[:label_style]
      when STYLE_MINIMAL
        1 # Just ID
      when STYLE_COMPACT
        2 # ID + dimensions
      when STYLE_DETAILED
        4 # ID + name + dimensions + material
      else
        2
      end
    end
    
    # Calculate optimal label position on part
    def calculate_label_position(part_dimensions, label_size)
      part_width = part_dimensions[:width]
      part_height = part_dimensions[:height]
      label_width = label_size[:width]
      label_height = label_size[:height]
      
      # Check if part is large enough for label
      min_size = 50 # mm
      if part_width < min_size || part_height < min_size
        return { skip: true, reason: 'Part too small' }
      end
      
      # Check if label fits
      if label_width > part_width * 0.8 || label_height > part_height * 0.8
        return { skip: true, reason: 'Label too large for part' }
      end
      
      # Calculate position based on preference
      margin = 5 # mm from edge
      
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
      else # AUTO
        # Choose best position (top-right by default)
        { x: part_width - label_width - margin, y: margin }
      end
      
      position.merge(skip: false)
    end
    
    # Generate label content (QR + text)
    def generate_label_content(part_data, qr_svg, label_size)
      padding = @options[:padding]
      qr_size = @options[:qr_size]
      font_size = @options[:font_size]
      
      content = ""
      
      # TEMPORARILY SKIP QR CODE - will add real implementation later
      # For now, just show a placeholder box
      if @options[:qr_enabled]
        # Draw a simple placeholder box instead of complex QR
        content += "<rect x=\"#{padding}\" y=\"#{padding}\" width=\"#{qr_size}\" height=\"#{qr_size}\" fill=\"#e0e0e0\" stroke=\"#666\" stroke-width=\"0.5\" rx=\"2\"/>"
        content += "<text x=\"#{padding + qr_size/2}\" y=\"#{padding + qr_size/2}\" font-family=\"Arial\" font-size=\"8pt\" fill=\"#666\" text-anchor=\"middle\" dominant-baseline=\"middle\">QR</text>"
      end
      
      # Add text content with proper spacing
      text_x = @options[:qr_enabled] ? (qr_size + padding * 3) : (padding * 2)
      text_y_start = padding + 4 # Start position in mm
      line_height = 4.5 # Spacing between lines in mm
      
      text_content = generate_text_content(part_data)
      text_content.each_with_index do |line, index|
        y_offset = text_y_start + (index * line_height)
        content += "<text x=\"#{text_x}\" y=\"#{y_offset}\" font-family=\"Arial, sans-serif\" font-size=\"#{font_size}pt\" fill=\"#{@options[:text_color]}\" font-weight=\"bold\">#{escape_xml(line)}</text>"
      end
      
      content
    end
    
    # Generate text lines based on style
    def generate_text_content(part_data)
      lines = []
      fields = @options[:include_fields]
      
      # Part ID (always included)
      if fields[:part_id]
        part_id = part_data[:part_id] || part_data['part_id'] || 'N/A'
        lines << "ID: #{part_id}"
      end
      
      # Part name (on separate line)
      if fields[:part_name] && @options[:label_style] != STYLE_MINIMAL
        name = part_data[:name] || part_data['name']
        lines << truncate_text(name, 18) if name
      end
      
      # Dimensions (on separate line)
      if fields[:dimensions]
        width = (part_data[:width] || part_data['width']).to_f.round(0)
        height = (part_data[:height] || part_data['height']).to_f.round(0)
        thickness = (part_data[:thickness] || part_data['thickness']).to_f.round(0)
        lines << "#{width}×#{height}×#{thickness}mm"
      end
      
      # Material (detailed style only)
      if fields[:material] && @options[:label_style] == STYLE_DETAILED
        material = part_data[:material] || part_data['material']
        lines << truncate_text(material, 15) if material
      end
      
      # Board number
      if fields[:board_number]
        board = part_data[:board_number] || part_data['board_number']
        lines << "Board #{board}" if board
      end
      
      lines
    end
    
    # Create positioned label SVG
    def create_positioned_label(content, position, label_size)
      x = position[:x]
      y = position[:y]
      width = label_size[:width]
      height = label_size[:height]
      
      svg = "<g class=\"part-label\" transform=\"translate(#{x}, #{y})\">"
      
      # Background rectangle
      svg += "<rect x=\"0\" y=\"0\" width=\"#{width}\" height=\"#{height}\" "
      svg += "fill=\"#{@options[:background_color]}\" "
      svg += "stroke=\"#{@options[:border_color]}\" "
      svg += "stroke-width=\"#{@options[:border_width]}\" "
      svg += "rx=\"2\" ry=\"2\"/>"
      
      # Content
      svg += content
      
      svg += "</g>"
      
      svg
    end
    
    # Utility: Truncate text to max length
    def truncate_text(text, max_length)
      return text if text.length <= max_length
      text[0...max_length-3] + '...'
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
    
    # Get current options
    def options
      @options
    end
    
  end
end
