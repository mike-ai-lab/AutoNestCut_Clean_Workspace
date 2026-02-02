# frozen_string_literal: true

# QR Code Generator for AutoNestCut
# Uses bundled rqrcode library for real data encoding
# Generates QR codes as SVG for embedding in diagrams and PDFs

module AutoNestCut
  class QRCodeGenerator
    
    # QR Code error correction levels mapping to rqrcode
    ERROR_CORRECTION_LEVELS = {
      'L' => :l, # ~7% correction
      'M' => :m, # ~15% correction
      'Q' => :q, # ~25% correction
      'H' => :h  # ~30% correction
    }
    
    # Cache for generated QR codes to avoid regeneration
    @@qr_cache = {}
    
    def initialize
      @cache_enabled = true
      setup_vendor_paths
    end

    # Ensure vendor libraries are accessible
    def setup_vendor_paths
      return if @paths_setup
      # Get the base directory of the extension
      base_dir = File.expand_path('../..', __dir__)
      vendor_dir = File.join(base_dir, 'vendor')
      
      # Add rqrcode and rqrcode_core to load path if not already there
      [
        File.join(vendor_dir, 'rqrcode'),
        File.join(vendor_dir, 'rqrcode_core')
      ].each do |path|
        $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
      end
      
      begin
        require 'rqrcode'
        @paths_setup = true
      rescue LoadError => e
        puts "ERROR: Failed to load rqrcode library: #{e.message}"
      end
    end
    
    # Generate QR code from part data
    def generate_qr_code(part_data, options = {})
      size = options[:size] || 30 # mm
      ec_level_code = options[:error_correction] || 'M'
      ec_level = ERROR_CORRECTION_LEVELS[ec_level_code] || :m
      
      cache_key = generate_cache_key(part_data)
      
      if @cache_enabled && @@qr_cache[cache_key]
        return scale_svg(@@qr_cache[cache_key], size)
      end
      
      json_data = encode_part_data(part_data)
      
      # Use the real RQRCode library
      begin
        # Ensure library is loaded
        unless defined?(RQRCode::QRCode)
          setup_vendor_paths
        end
        
        qrcode = RQRCode::QRCode.new(json_data, level: ec_level)
        
        # Generate SVG with optimized path for smaller file size
        svg_data = qrcode.as_svg(
          module_size: 1, # Base size, we'll scale via viewBox/CSS
          offset: 0,
          color: "000",
          shape_rendering: "crispEdges",
          standalone: false, # We want to embed it
          use_path: true,
          viewbox: true
        )
        
        # Wrap in a fixed size container or scale the output
        svg_data = finalize_svg(svg_data, size)
        
      rescue => e
        puts "WARNING: QR generation failed: #{e.message}"
        # Fallback to a simple text error if generation fails
        svg_data = generate_error_svg(size)
      end
      
      @@qr_cache[cache_key] = svg_data if @cache_enabled
      svg_data
    end
    
    def encode_part_data(part_data)
      data = {
        v: '1.0',
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
    
    def generate_cache_key(part_data)
      require 'digest'
      part_id = part_data[:part_id] || part_data['part_id']
      name = part_data[:name] || part_data['name']
      Digest::MD5.hexdigest("#{part_id}_#{name}")
    end

    def finalize_svg(svg_body, size_mm)
      # Ensure the SVG has proper dimensions and namespace
      %(<svg xmlns="http://www.w3.org/2000/svg" width="#{size_mm}mm" height="#{size_mm}mm" viewBox="#{extract_viewbox(svg_body)}">#{extract_content(svg_body)}</svg>)
    end

    def extract_viewbox(svg)
      if svg =~ /viewBox="([^"]+)"/
        return $1
      end
      "0 0 100 100" # Fallback
    end

    def extract_content(svg)
      # Remove the outer <svg> tags to embed cleanly if needed, 
      # or return body. RQRCode returns <svg ...><path .../></svg>
      if svg =~ /<svg[^>]*>(.*?)<\/svg>/m
        return $1
      end
      svg
    end
    
    def generate_error_svg(size_mm)
       %(<svg xmlns="http://www.w3.org/2000/svg" width="#{size_mm}mm" height="#{size_mm}mm" viewBox="0 0 100 100"><rect width="100" height="100" fill="#eee"/><text x="50" y="50" text-anchor="middle" font-size="10">QR Error</text></svg>)
    end
    
    def scale_svg(svg, size_mm)
      svg.gsub(/width="[^"]*"/, "width=\"#{size_mm}mm\"")
         .gsub(/height="[^"]*"/, "height=\"#{size_mm}mm\"")
    end
    
    def self.clear_cache
      @@qr_cache.clear
    end
    
    def self.cache_stats
      { size: @@qr_cache.size, keys: @@qr_cache.keys }
    end
    
    def cache_enabled=(enabled)
      @cache_enabled = enabled
    end
  end
end