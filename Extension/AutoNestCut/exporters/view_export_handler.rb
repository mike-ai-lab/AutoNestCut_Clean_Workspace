# frozen_string_literal: true

require 'base64'
require 'json'

module AutoNestCut
  class ViewExportHandler
    
    # Rendering style constants
    RENDER_STYLES = {
      'hidden_line' => 1,
      'shaded' => 2,
      'shaded_textured' => 2,
      'wireframe' => 0
    }.freeze
    
    # Export format constants
    EXPORT_FORMATS = ['pdf', 'html', 'dxf', 'png'].freeze
    
    def initialize
      @views_data = {}
      @render_style = 'shaded'
      @export_format = 'pdf'
      @include_dimensions = false
    end
    
    # Set rendering style
    def set_render_style(style)
      raise "Invalid style: #{style}" unless RENDER_STYLES.key?(style)
      @render_style = style
    end
    
    # Set export format
    def set_export_format(format)
      raise "Invalid format: #{format}" unless EXPORT_FORMATS.include?(format)
      @export_format = format
    end
    
    # Store captured views data - EXPECTS FILE PATHS ONLY
    def add_views(entity_name, views_hash)
      puts "DEBUG: add_views called"
      puts "DEBUG:   entity_name: #{entity_name}"
      puts "DEBUG:   views_hash keys: #{views_hash.keys.inspect}"
      puts "DEBUG:   views_hash length: #{views_hash.length}"
      
      # Validate that all values are file paths (strings)
      views_hash.each do |view_name, view_data|
        unless view_data.is_a?(String)
          puts "ERROR: View data must be file paths (strings), got #{view_data.class}"
          return
        end
        
        file_exists = File.exist?(view_data)
        file_size = file_exists ? File.size(view_data) : 0
        puts "DEBUG:   #{view_name}: #{view_data} (exists: #{file_exists}, size: #{file_size} bytes)"
      end
      
      # MERGE views instead of overwriting
      if @views_data[entity_name]
        puts "DEBUG: Entity '#{entity_name}' already exists, MERGING views"
        puts "DEBUG:   Existing views: #{@views_data[entity_name].keys.inspect}"
        @views_data[entity_name].merge!(views_hash)
        puts "DEBUG:   After merge: #{@views_data[entity_name].keys.inspect}"
      else
        puts "DEBUG: Creating new entity '#{entity_name}'"
        @views_data[entity_name] = views_hash
      end
      
      puts "DEBUG: Views data now contains #{@views_data.length} entities"
      puts "DEBUG: Entity '#{entity_name}' now has #{@views_data[entity_name].length} views: #{@views_data[entity_name].keys.inspect}"
    end
    
    # Diagnostic method to check current state
    def diagnose
      puts "\n" + "="*80
      puts "DIAGNOSTIC REPORT"
      puts "="*80
      puts "Export format: #{@export_format}"
      puts "Render style: #{@render_style}"
      puts "Views data count: #{@views_data.length}"
      puts "Views data empty? #{@views_data.empty?}"
      
      if @views_data.empty?
        puts "WARNING: No views data loaded!"
      else
        @views_data.each do |entity_name, views|
          puts "\nEntity: #{entity_name}"
          puts "  Views count: #{views.length}"
          views.each do |view_name, image_path|
            exists = File.exist?(image_path)
            size = exists ? File.size(image_path) : 0
            puts "    - #{view_name}: #{image_path} (exists: #{exists}, size: #{size} bytes)"
          end
        end
      end
      puts "="*80 + "\n"
    end
    
    # Main export method
    def export(output_path = nil)
      puts "\n" + "="*80
      puts "DEBUG: Starting export process"
      puts "DEBUG: Current export format: #{@export_format}"
      puts "DEBUG: Views data count: #{@views_data.length}"
      puts "DEBUG: Views data keys: #{@views_data.keys.inspect}"
      
      # Check if we have any views data
      if @views_data.empty?
        puts "ERROR: No views data available for export!"
        puts "ERROR: Please ensure views are added via add_views() method with file paths."
        raise "No views data available for export"
      end
      
      puts "DEBUG: Proceeding with export. Total entities: #{@views_data.length}"
      @views_data.each do |entity_name, views|
        puts "DEBUG:   - #{entity_name}: #{views.length} views"
      end
      puts "="*80 + "\n"
      
      case @export_format
      when 'pdf'
        export_to_pdf(output_path)
      when 'html'
        export_to_html(output_path)
      when 'dxf'
        export_to_dxf(output_path)
      when 'png'
        export_to_png(output_path)
      else
        raise "Unsupported export format: #{@export_format}"
      end
    end
    
    # ===== PDF EXPORT =====
    def export_to_pdf(output_path = nil)
      begin
        require 'prawn'
        
        output_path ||= generate_default_path('pdf')
        
        puts "DEBUG: PDF export starting"
        puts "DEBUG: Output path: #{output_path}"
        puts "DEBUG: Total entities: #{@views_data.length}"
        
        Prawn::Document.generate(output_path, page_size: 'A4', margin: 30) do |pdf|
          pdf.font_size(20) { pdf.text 'Assembly Technical Documentation', style: :bold, align: :center }
          pdf.move_down 10
          pdf.font_size(10) { pdf.text "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}", align: :center, color: '666666' }
          pdf.move_down 20
          
          @views_data.each_with_index do |(entity_name, views), idx|
            puts "DEBUG: Processing entity #{idx + 1}: #{entity_name} with #{views.length} views"
            
            pdf.start_new_page if idx > 0
            
            # Entity header
            pdf.fill_color '2E7D32'
            pdf.font_size(16) { pdf.text entity_name, style: :bold }
            pdf.fill_color '000000'
            pdf.move_down 10
            
            # Views grid (2 columns)
            views.each_slice(2).with_index do |row_views, row_idx|
              puts "DEBUG:   Row #{row_idx + 1}: #{row_views.length} views"
              
              row_views.each_with_index do |(view_name, image_path), col_idx|
                puts "DEBUG:     View: #{view_name} -> #{image_path}"
                puts "DEBUG:     File exists? #{File.exist?(image_path)}"
                
                next unless File.exist?(image_path)
                
                puts "DEBUG:     Adding to PDF: #{view_name}"
                
                # View label
                pdf.font_size(11) { pdf.text view_name, style: :bold, color: '555555' }
                
                # Image
                begin
                  file_size = File.size(image_path)
                  puts "DEBUG:     Image file size: #{file_size} bytes"
                  pdf.image image_path, fit: [250, 200], position: :center
                  puts "DEBUG:     Image added successfully"
                rescue => e
                  puts "DEBUG:     ERROR adding image: #{e.message}"
                  pdf.text "Error loading image: #{e.message}", color: 'FF0000'
                end
                
                pdf.move_down 5
              end
              
              pdf.move_down 10 if row_idx < (views.length.to_f / 2).ceil - 1
            end
          end
        end
        
        puts "PDF exported successfully: #{output_path}"
        return output_path
        
      rescue LoadError
        raise "Prawn gem required for PDF export. Install with: gem install prawn"
      rescue => e
        puts "ERROR in PDF export: #{e.message}"
        puts "Backtrace: #{e.backtrace.join("\n")}"
        raise "PDF export failed: #{e.message}"
      end
    end
    
    # ===== HTML EXPORT =====
    def export_to_html(output_path = nil)
      begin
        output_path ||= generate_default_path('html')
        
        puts "DEBUG: HTML export starting"
        puts "DEBUG: Output path: #{output_path}"
        
        html_content = generate_html_content
        
        puts "DEBUG: Writing HTML to file..."
        File.write(output_path, html_content, encoding: 'UTF-8')
        
        puts "HTML exported successfully: #{output_path}"
        return output_path
      rescue => e
        puts "ERROR in HTML export: #{e.message}"
        puts "Backtrace: #{e.backtrace.join("\n")}"
        raise "HTML export failed: #{e.message}"
      end
    end
    
    def generate_html_content
      puts "DEBUG: generate_html_content called"
      puts "DEBUG: @views_data.length = #{@views_data.length}"
      puts "DEBUG: @views_data.keys = #{@views_data.keys.inspect}"
      
      groups_html = @views_data.map do |entity_name, views|
        puts "DEBUG:   Processing entity: #{entity_name} with #{views.length} views"
        
        images_html = views.map do |view_name, image_path|
          puts "DEBUG:     Processing view: #{view_name} -> #{image_path}"
          puts "DEBUG:     File exists? #{File.exist?(image_path)}"
          
          if File.exist?(image_path)
            begin
              base64 = Base64.strict_encode64(File.binread(image_path))
              puts "DEBUG:     Base64 encoded, length: #{base64.length}"
              # Use JPEG MIME type for optimized file size in HTML
              "<div class='view-item'>
                <h4>#{view_name}</h4>
                <img src='data:image/jpeg;base64,#{base64}' alt='#{view_name}' />
              </div>"
            rescue => e
              puts "DEBUG:     ERROR encoding image: #{e.message}"
              "<div class='view-item'><h4>#{view_name}</h4><p>Error encoding image</p></div>"
            end
          else
            puts "DEBUG:     WARNING: Image file not found at #{image_path}"
            "<div class='view-item'><h4>#{view_name}</h4><p>Image not found: #{image_path}</p></div>"
          end
        end.join("\n")
        
        "<div class='group-section'>
          <h2>#{entity_name}</h2>
          <div class='group-container'>
            #{images_html}
          </div>
        </div>"
      end.join("\n")
      
      puts "DEBUG: Generated HTML content length: #{groups_html.length} characters"
      
      <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>Assembly Technical Documentation</title>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            background: #f5f5f5; 
            color: #333; 
            padding: 20px;
          }
          .container { max-width: 1200px; margin: 0 auto; }
          h1 { 
            text-align: center; 
            color: #2E7D32; 
            margin-bottom: 10px; 
            font-size: 28px;
          }
          .header-info { 
            text-align: center; 
            color: #666; 
            font-size: 12px; 
            margin-bottom: 30px;
          }
          .group-section { 
            margin-bottom: 40px; 
            background: white; 
            padding: 20px; 
            border-radius: 8px; 
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
          }
          .group-section h2 { 
            color: #2E7D32; 
            border-bottom: 3px solid #2E7D32; 
            padding-bottom: 10px; 
            margin-bottom: 20px;
            font-size: 20px;
          }
          .group-container { 
            display: grid; 
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); 
            gap: 15px;
          }
          .view-item { 
            background: #f9f9f9; 
            padding: 12px; 
            border-radius: 6px; 
            border: 1px solid #ddd;
            text-align: center;
          }
          .view-item h4 { 
            margin: 0 0 10px 0; 
            color: #555; 
            font-size: 14px;
            font-weight: 600;
          }
          .view-item img { 
            width: 100%; 
            height: auto; 
            border: 1px solid #ddd; 
            border-radius: 4px;
            display: block;
          }
          .view-item p { 
            color: #999; 
            font-size: 12px;
          }
          @media print {
            body { background: white; }
            .group-section { box-shadow: none; page-break-inside: avoid; }
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>Assembly Technical Documentation</h1>
          <div class="header-info">
            Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}<br>
            Render Style: #{@render_style.upcase.gsub('_', ' ')}<br>
            Total Components: #{@views_data.length}
          </div>
          #{groups_html}
        </div>
      </body>
      </html>
      HTML
    end
    
    # ===== DXF EXPORT =====
    def export_to_dxf(output_path = nil)
      output_path ||= generate_default_path('dxf')
      
      lines = []
      texts = []
      current_offset = 0
      
      @views_data.each do |entity_name, views|
        spacing = 500
        
        views.each_with_index do |(view_name, _image_path), idx|
          x_offset = current_offset + (idx % 3) * spacing
          y_offset = (idx / 3) * spacing
          
          texts << {
            text: "#{entity_name} - #{view_name}",
            x: x_offset,
            y: y_offset
          }
        end
        
        current_offset += spacing * 4
      end
      
      write_dxf_file(output_path, lines, texts)
      
      puts "DXF exported successfully: #{output_path}"
      return output_path
    end
    
    def write_dxf_file(path, lines, texts)
      File.open(path, 'w') do |f|
        f.puts "  0\nSECTION\n  2\nHEADER"
        f.puts "  9\n$ACADVER\n  1\nAC1009"
        f.puts "  9\n$INSUNITS\n 70\n4"
        f.puts "  0\nENDSEC"
        
        f.puts "  0\nSECTION\n  2\nTABLES"
        f.puts "  0\nTABLE\n  2\nLAYER\n 70\n1"
        f.puts "  0\nLAYER\n  2\n0\n 70\n0\n 62\n7\n  6\nCONTINUOUS"
        f.puts "  0\nENDTAB\n  0\nENDSEC"
        
        f.puts "  0\nSECTION\n  2\nENTITIES"
        
        texts.each do |text_data|
          f.puts "  0\nTEXT"
          f.puts "  8\n0"
          f.puts " 10\n#{text_data[:x]}"
          f.puts " 20\n#{text_data[:y]}"
          f.puts " 30\n0.0"
          f.puts " 40\n50.0"
          f.puts "  1\n#{text_data[:text]}"
          f.puts " 50\n0.0"
          f.puts "  7\nSTANDARD"
        end
        
        f.puts "  0\nENDSEC"
        f.puts "  0\nEOF"
      end
    end
    
    # ===== PNG/JPEG EXPORT =====
    # Exports assembly views as optimized JPEG images (not PNG) to reduce file size
    # JPEG format reduces file size from 14-15MB to ~300-400KB per image while maintaining quality
    def export_to_png(output_path = nil)
      output_dir = output_path || generate_default_directory
      Dir.mkdir(output_dir) unless Dir.exist?(output_dir)
      
      puts "DEBUG: Image export to directory: #{output_dir}"
      puts "DEBUG: @views_data.length = #{@views_data.length}"
      puts "DEBUG: Exporting as JPEG format for optimal file size"
      
      exported_files = []
      total_size_kb = 0
      
      @views_data.each do |entity_name, views|
        puts "DEBUG:   Entity: #{entity_name}, views count: #{views.length}"
        
        views.each do |view_name, image_path|
          puts "DEBUG:     View: #{view_name} -> #{image_path}"
          puts "DEBUG:     File exists? #{File.exist?(image_path)}"
          
          next unless File.exist?(image_path)
          
          safe_name = "#{entity_name}_#{view_name}".gsub(/[^\w\s-]/, '').gsub(/\s+/, '_')
          # Export as JPEG instead of PNG for better compression
          output_file = File.join(output_dir, "#{safe_name}.jpg")
          
          puts "DEBUG:     Copying to: #{output_file}"
          FileUtils.cp(image_path, output_file)
          
          # Validate compression
          file_size_kb = File.size(output_file) / 1024.0
          total_size_kb += file_size_kb
          
          validation = Util.validate_image_compression(output_file, 500)
          Util.log_compression_result("#{entity_name}_#{view_name}", validation)
          
          exported_files << output_file
          puts "DEBUG:     Successfully exported: #{file_size_kb.round(2)}KB"
        end
      end
      
      puts "Image files exported successfully to: #{output_dir}"
      puts "Total files: #{exported_files.length}"
      puts "Total size: #{total_size_kb.round(2)}KB (#{(total_size_kb / 1024.0).round(2)}MB)"
      puts "Average per image: #{(total_size_kb / exported_files.length).round(2)}KB" if exported_files.length > 0
      return output_dir
    end
    
    # ===== HELPER METHODS =====
    
    def generate_default_path(format)
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      documents_path = File.join(ENV['USERPROFILE'] || ENV['HOME'], 'Documents')
      File.join(documents_path, "AutoNestCut_Views_#{timestamp}.#{format}")
    end
    
    def generate_default_directory
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      documents_path = File.join(ENV['USERPROFILE'] || ENV['HOME'], 'Documents')
      File.join(documents_path, "AutoNestCut_Views_#{timestamp}")
    end
    
    # Get available render styles
    def self.available_styles
      RENDER_STYLES.keys
    end
    
    # Get available export formats
    def self.available_formats
      EXPORT_FORMATS
    end
  end
end
