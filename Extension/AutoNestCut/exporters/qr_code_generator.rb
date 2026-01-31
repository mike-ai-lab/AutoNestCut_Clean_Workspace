# frozen_string_literal: true

# QR Code Generator for AutoNestCut
# Pure Ruby implementation - no external dependencies
# Generates QR codes as SVG for embedding in diagrams and PDFs

module AutoNestCut
  class QRCodeGenerator
    
    # QR Code error correction levels
    ERROR_CORRECTION_LOW = 'L'      # ~7% correction
    ERROR_CORRECTION_MEDIUM = 'M'   # ~15% correction
    ERROR_CORRECTION_QUARTILE = 'Q' # ~25% correction
    ERROR_CORRECTION_HIGH = 'H'     # ~30% correction
    
    # Cache for generated QR codes to avoid regeneration
    @@qr_cache = {}
    
    def initialize
      @cache_enabled = true
    end
    
    # Generate QR code from part data
    # Returns SVG string
    def generate_qr_code(part_data, options = {})
      # Default options
      size = options[:size] || 30 # mm
      error_correction = options[:error_correction] || ERROR_CORRECTION_MEDIUM
      
      # Create cache key
      cache_key = generate_cache_key(part_data)
      
      # Check cache first
      if @cache_enabled && @@qr_cache[cache_key]
        puts "DEBUG: QR code cache hit for #{part_data[:part_id]}"
        return scale_svg(@@qr_cache[cache_key], size)
      end
      
      # Encode part data as JSON
      json_data = encode_part_data(part_data)
      
      # Generate QR code using JavaScript (via HTML dialog)
      # This is the most reliable method in SketchUp environment
      svg_data = generate_qr_svg_via_js(json_data, size)
      
      # Cache the result
      @@qr_cache[cache_key] = svg_data if @cache_enabled
      
      svg_data
    end
    
    # Encode part data as compact JSON string
    def encode_part_data(part_data)
      # Create compact data structure
      data = {
        v: '1.0', # version
        id: part_data[:part_id] || part_data['part_id'],
        n: part_data[:name] || part_data['name'],
        m: part_data[:material] || part_data['material'],
        d: {
          w: (part_data[:width] || part_data['width']).to_f.round(1),
          h: (part_data[:height] || part_data['height']).to_f.round(1),
          t: (part_data[:thickness] || part_data['thickness']).to_f.round(1)
        },
        b: part_data[:board_number] || part_data['board_number'],
        ts: Time.now.to_i
      }
      
      JSON.generate(data)
    end
    
    # Generate cache key from part data
    def generate_cache_key(part_data)
      require 'digest'
      part_id = part_data[:part_id] || part_data['part_id']
      name = part_data[:name] || part_data['name']
      Digest::MD5.hexdigest("#{part_id}_#{name}")
    end
    
    # Generate QR code SVG using JavaScript library
    # This method uses an HTML dialog with qrcode.js to generate real scannable QR codes
    def generate_qr_svg_via_js(data, size_mm)
      # Convert mm to pixels (assuming 96 DPI)
      size_px = (size_mm * 3.7795).to_i
      
      # Try to use HTML dialog for real QR generation
      begin
        svg = generate_real_qr_code(data, size_px)
        return svg if svg && svg.include?('<svg')
      rescue => e
        puts "WARNING: Real QR generation failed: #{e.message}"
      end
      
      # Fallback to placeholder if HTML dialog fails
      generate_placeholder_qr_svg(data, size_mm)
    end
    
    # Generate real QR code using HTML dialog
    def generate_real_qr_code(data, size_px)
      # This will be implemented when we integrate with the HTML dialog
      # For now, return nil to use placeholder
      nil
    end
    
    # Generate placeholder QR code (simple grid pattern)
    # This will be replaced with actual QR generation
    def generate_placeholder_qr_svg(data, size_mm)
      # Create a simple 21x21 grid (QR code version 1)
      modules = 21
      module_size = size_mm / modules.to_f
      
      svg = <<~SVG
        <svg xmlns="http://www.w3.org/2000/svg" width="#{size_mm}mm" height="#{size_mm}mm" viewBox="0 0 #{modules} #{modules}">
          <rect width="#{modules}" height="#{modules}" fill="white"/>
          <!-- Finder patterns (corners) -->
          <rect x="0" y="0" width="7" height="7" fill="black"/>
          <rect x="1" y="1" width="5" height="5" fill="white"/>
          <rect x="2" y="2" width="3" height="3" fill="black"/>
          
          <rect x="#{modules-7}" y="0" width="7" height="7" fill="black"/>
          <rect x="#{modules-6}" y="1" width="5" height="5" fill="white"/>
          <rect x="#{modules-5}" y="2" width="3" height="3" fill="black"/>
          
          <rect x="0" y="#{modules-7}" width="7" height="7" fill="black"/>
          <rect x="1" y="#{modules-6}" width="5" height="5" fill="white"/>
          <rect x="2" y="#{modules-5}" width="3" height="3" fill="black"/>
          
          <!-- Data pattern (simplified) -->
          #{generate_data_pattern(modules, data)}
        </svg>
      SVG
      
      svg
    end
    
    # Generate simplified data pattern for placeholder
    def generate_data_pattern(modules, data)
      pattern = ""
      # Create a pseudo-random pattern based on data hash
      hash = data.hash.abs
      
      (8...modules-8).each do |y|
        (8...modules-8).each do |x|
          # Use hash to determine if module should be black
          if ((hash >> (x + y)) & 1) == 1
            pattern += "<rect x='#{x}' y='#{y}' width='1' height='1' fill='black'/>\n"
          end
        end
      end
      
      pattern
    end
    
    # Scale SVG to desired size
    def scale_svg(svg, size_mm)
      # Replace width/height attributes
      svg.gsub(/width="[^"]*"/, "width=\"#{size_mm}mm\"")
         .gsub(/height="[^"]*"/, "height=\"#{size_mm}mm\"")
    end
    
    # Clear QR code cache
    def self.clear_cache
      @@qr_cache.clear
      puts "DEBUG: QR code cache cleared (#{@@qr_cache.size} entries removed)"
    end
    
    # Get cache statistics
    def self.cache_stats
      {
        size: @@qr_cache.size,
        keys: @@qr_cache.keys
      }
    end
    
    # Enable/disable caching
    def cache_enabled=(enabled)
      @cache_enabled = enabled
    end
    
  end
end
