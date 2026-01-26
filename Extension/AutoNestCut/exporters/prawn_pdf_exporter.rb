# frozen_string_literal: true

require 'json'
require 'base64'

module AutoNestCut
  class PrawnPDFExporter
    # Generates professional PDF from HTML content
    # Direct implementation based on proven ViewExportHandler pattern
    def self.generate_pdf_from_html(html_content, settings = {})
      begin
        unless check_prawn_available
          raise "Prawn gem not available. Please install 'prawn' gem."
        end

        require 'prawn'
        require 'prawn/table'

        model_name = Sketchup.active_model.title.empty? ? "Untitled" : Sketchup.active_model.title.gsub(/[^\w]/, '_')
        timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
        filename = "AutoNestCut_Report_#{model_name}_#{timestamp}.pdf"
        
        documents_path = Compatibility.documents_path
        pdf_path = File.join(documents_path, filename)

        # Generate PDF directly
        Prawn::Document.generate(pdf_path, page_size: 'A4', margin: 30) do |pdf|
          pdf.font 'Helvetica'
          
          # Extract and render title
          title = extract_text_between(html_content, '<h1>', '</h1>')
          if title && !title.empty?
            pdf.font_size 24
            pdf.font 'Helvetica', style: :bold
            pdf.text title, align: :center, color: '0066cc'
            pdf.move_down 10
          end
          
          # Extract and render subtitle
          subtitle = extract_text_between(html_content, '<div class="subtitle">', '</div>')
          if subtitle && !subtitle.empty?
            pdf.font_size 10
            pdf.text subtitle, align: :center, color: '666666'
            pdf.move_down 20
          end
          
          # Process all sections
          process_sections(pdf, html_content)
        end

        puts "PDF generated successfully: #{pdf_path}"
        pdf_path
      rescue => e
        puts "ERROR generating PDF: #{e.message}"
        puts e.backtrace.join("\n")
        raise e
      end
    end

    private

    def self.check_prawn_available
      begin
        require 'prawn'
        require 'prawn/table'
        true
      rescue LoadError
        false
      end
    end

    def self.process_sections(pdf, html_content)
      # Find all h2 sections
      section_pattern = /<h2[^>]*>([^<]*)<\/h2>(.*?)(?=<h2|$)/m
      section_count = 0
      
      html_content.scan(section_pattern) do |match|
        section_title = match[0].strip
        section_content = match[1]
        
        # Add page break before section (except first)
        if section_count > 0
          pdf.start_new_page
        end
        
        # Render section title
        if section_title && !section_title.empty?
          pdf.font_size 16
          pdf.font 'Helvetica', style: :bold
          pdf.text section_title, color: '0066cc'
          pdf.move_down 12
        end
        
        # Determine section type and render accordingly
        if section_title.downcase.include?('diagram')
          render_diagrams(pdf, section_content)
        elsif section_title.downcase.include?('assembly')
          render_assembly_views(pdf, section_content)
        else
          render_tables(pdf, section_content)
        end
        
        section_count += 1
      end
    end

    def self.render_diagrams(pdf, section_content)
      # Extract all images from section
      images = []
      img_pattern = /<img[^>]*src="([^"]*)"[^>]*alt="([^"]*)"[^>]*>/m
      
      section_content.scan(img_pattern) do |match|
        images << {
          src: match[0],
          alt: match[1]
        }
      end
      
      # Render each diagram on its own page
      images.each_with_index do |img, idx|
        if idx > 0
          pdf.start_new_page
        end
        
        # Add label
        if img[:alt] && !img[:alt].empty?
          pdf.font_size 12
          pdf.font 'Helvetica', style: :bold
          pdf.text img[:alt], color: '333333'
          pdf.move_down 10
        end
        
        # Render image - fit to full page
        render_image(pdf, img[:src], pdf.bounds.width, pdf.bounds.height - 60)
      end
    end

    def self.render_assembly_views(pdf, section_content)
      # Extract all images from section
      images = []
      img_pattern = /<img[^>]*src="([^"]*)"[^>]*alt="([^"]*)"[^>]*>/m
      
      section_content.scan(img_pattern) do |match|
        images << {
          src: match[0],
          alt: match[1]
        }
      end
      
      # Render 2 images per page vertically
      images.each_with_index do |img, idx|
        # Page break every 2 images
        if idx > 0 && idx % 2 == 0
          pdf.start_new_page
        end
        
        # Spacing between images on same page
        if idx > 0 && idx % 2 == 1
          pdf.move_down 20
        end
        
        # Add label
        if img[:alt] && !img[:alt].empty?
          pdf.font_size 11
          pdf.font 'Helvetica', style: :bold
          pdf.text img[:alt], color: '0066cc'
          pdf.move_down 5
        end
        
        # Render image - half page height
        render_image(pdf, img[:src], pdf.bounds.width, (pdf.bounds.height / 2) - 50)
      end
    end

    def self.render_tables(pdf, section_content)
      # Extract all tables
      table_pattern = /<table[^>]*>(.*?)<\/table>/m
      
      section_content.scan(table_pattern) do |match|
        table_html = match[0]
        table_data = extract_table_data(table_html)
        
        if table_data && !table_data.empty?
          pdf.table(table_data, width: pdf.bounds.width) do |table|
            table.header = true
            table.rows.each_with_index do |row, row_idx|
              row.cells.each do |cell|
                cell.padding = [6, 8]
                cell.font_size = 9
                cell.text_color = '333333'
              end
              
              if row_idx == 0
                row.cells.each do |cell|
                  cell.background_color = 'f0f0f0'
                  cell.text_color = '000000'
                  cell.font_style = :bold
                  cell.border_bottom_width = 2
                  cell.border_bottom_color = '0066cc'
                end
              else
                row.cells.each do |cell|
                  cell.background_color = row_idx.even? ? 'f9f9f9' : 'ffffff'
                  cell.border_bottom_width = 1
                  cell.border_bottom_color = 'dddddd'
                end
              end
            end
          end
          
          pdf.move_down 12
        end
      end
    end

    def self.render_image(pdf, image_src, max_width, max_height)
      begin
        # Handle base64 data URIs
        if image_src.is_a?(String) && image_src.start_with?('data:image')
          # Extract base64 part
          base64_part = image_src.split(',')[1]
          
          if base64_part
            # Decode and write to temp file
            image_bytes = Base64.decode64(base64_part)
            temp_path = File.join(Dir.tmpdir, "pdf_img_#{Time.now.to_i}_#{rand(100000)}.png")
            File.binwrite(temp_path, image_bytes)
            
            # Render with fit
            pdf.image temp_path, fit: [max_width, max_height], position: :center
            
            # Clean up
            File.delete(temp_path) rescue nil
          else
            pdf.text "[Invalid image data]", style: :italic, color: '999999'
          end
        elsif image_src.is_a?(String) && File.exist?(image_src)
          # Handle file path
          pdf.image image_src, fit: [max_width, max_height], position: :center
        else
          pdf.text "[Image not available]", style: :italic, color: '999999'
        end
      rescue => e
        puts "ERROR rendering image: #{e.message}"
        pdf.text "[Error: #{e.message}]", style: :italic, color: '999999'
      end
    end

    def self.extract_table_data(table_html)
      data = []
      
      # Extract header
      thead_pattern = /<thead>(.*?)<\/thead>/m
      thead_match = table_html.match(thead_pattern)
      if thead_match
        header_row = extract_row_data(thead_match[1])
        data << header_row if header_row && !header_row.empty?
      end
      
      # Extract body
      tbody_pattern = /<tbody>(.*?)<\/tbody>/m
      tbody_match = table_html.match(tbody_pattern)
      if tbody_match
        row_pattern = /<tr[^>]*>(.*?)<\/tr>/m
        tbody_match[1].scan(row_pattern) do |row_match|
          row_data = extract_row_data(row_match[0])
          data << row_data if row_data && !row_data.empty?
        end
      end
      
      data
    end

    def self.extract_row_data(row_html)
      cells = []
      cell_pattern = /<(?:th|td)[^>]*>(.*?)<\/(?:th|td)>/m
      
      row_html.scan(cell_pattern) do |match|
        cell_text = match[0].gsub(/<[^>]*>/, '').strip
        cell_text = decode_html_entities(cell_text)
        cells << cell_text
      end
      
      cells
    end

    def self.extract_text_between(html, start_tag, end_tag)
      match = html.match(/#{Regexp.escape(start_tag)}(.*?)#{Regexp.escape(end_tag)}/m)
      match ? match[1].strip.gsub(/<[^>]*>/, '') : ''
    end

    def self.decode_html_entities(text)
      text
        .gsub('&amp;', '&')
        .gsub('&lt;', '<')
        .gsub('&gt;', '>')
        .gsub('&quot;', '"')
        .gsub('&#39;', "'")
        .gsub('&nbsp;', ' ')
    end
  end
end
