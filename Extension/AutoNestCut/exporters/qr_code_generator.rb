# frozen_string_literal: true

# QR Code Generator for AutoNestCut
# Pure Ruby implementation using RQRCode gem
# Generates QR codes as SVG for embedding in diagrams and PDFs

# Ensure RQRCode gem is loaded (loaded by label_sheet_generator.rb in main.rb)
begin
  require 'rqrcode' unless defined?(RQRCode)
rescue LoadError
  puts "WARNING: RQRCode gem not available. QR codes will use placeholders."
end

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
    
    # Encode part data as COMPACT readable text (optimized for QR scanning)
    def encode_part_data(part_data)
      # Extract data with fallbacks
      id = (part_data[:part_id] || part_data['part_id'] || "N/A").to_s
      name = (part_data[:name] || part_data['name'] || "Unknown").to_s
      w_dim = (part_data[:width] || part_data['width'] || 0).to_f.round(0) # No decimals
      h_dim = (part_data[:height] || part_data['height'] || 0).to_f.round(0)
      thick = (part_data[:thickness] || part_data['thickness'] || 0).to_f.round(0)
      material = (part_data[:material] || part_data['material'] || "").to_s
      board = part_data[:board_number] || part_data['board_number']
      
      # COMPACT format - shorter text = smaller QR = easier to scan
      qr_text = "ID:#{id}\n"
      qr_text += "#{name}\n"
      qr_text += "#{w_dim}x#{h_dim}x#{thick}mm\n"
      qr_text += "#{material}\n" unless material.empty?
      qr_text += "B#{board}" if board
      
      qr_text
    end
    
    # Generate cache key from part data
    def generate_cache_key(part_data)
      require 'digest'
      part_id = part_data[:part_id] || part_data['part_id']
      name = part_data[:name] || part_data['name']
      Digest::MD5.hexdigest("#{part_id}_#{name}")
    end
    
    # Generate QR code SVG using RQRCode gem (same as label_sheet_generator)
    def generate_qr_svg_via_js(data, size_mm)
      # Use real QR generation with RQRCode gem
      generate_real_qr_svg(data, size_mm)
    end
    
    # Generate real scannable QR code as SVG using RQRCode gem
    def generate_real_qr_svg(data, size_mm)
      begin
        # Load RQRCode gem (already vendored and loaded by label_sheet_generator)
        require 'rqrcode' unless defined?(RQRCode)
        
        # Generate QR code with LOW error correction for maximum data capacity
        qr = RQRCode::QRCode.new(data.to_s, level: :l)
        
        # QR codes REQUIRE a quiet zone (white border) of at least 4 modules
        quiet_zone_modules = 4
        total_modules = qr.modules.size + (quiet_zone_modules * 2)
        
        # Build SVG with quiet zone
        svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"#{size_mm}mm\" height=\"#{size_mm}mm\" viewBox=\"0 0 #{total_modules} #{total_modules}\">\n"
        svg += "  <!-- White background (CRITICAL for scanning) -->\n"
        svg += "  <rect width=\"#{total_modules}\" height=\"#{total_modules}\" fill=\"white\"/>\n"
        
        # Draw black modules (offset by quiet zone)
        qr.modules.each_with_index do |row, row_index|
          row.each_with_index do |col, col_index|
            if col # Black module
              # Add quiet zone offset
              x = col_index + quiet_zone_modules
              y = row_index + quiet_zone_modules
              svg += "  <rect x=\"#{x}\" y=\"#{y}\" width=\"1\" height=\"1\" fill=\"black\"/>\n"
            end
          end
        end
        
        svg += "</svg>"
        
        return svg
        
      rescue LoadError => e
        puts "ERROR: RQRCode gem not available: #{e.message}"
        puts "Falling back to placeholder QR code"
        return generate_placeholder_qr_svg(data, size_mm)
      rescue => e
        puts "ERROR: QR generation failed: #{e.message}"
        return generate_placeholder_qr_svg(data, size_mm)
      end
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
