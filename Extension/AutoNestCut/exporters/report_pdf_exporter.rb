# frozen_string_literal: true
# encoding: UTF-8

require 'base64'
require 'json'
require 'prawn'
require 'tmpdir'

module AutoNestCut
  class ReportPdfExporter
    
    def initialize
      @report_data = {}
      @diagrams_data = []
      @assembly_data = nil
      @diagram_images = []
    end
    
    # Set report data
    def set_report_data(report_data)
      @report_data = deep_utf8_encode(report_data || {})
    end
    
    # Set diagrams data
    def set_diagrams_data(diagrams_data)
      @diagrams_data = deep_utf8_encode(diagrams_data || [])
    end
    
    # Set assembly data with views
    def set_assembly_data(assembly_data)
      @assembly_data = deep_utf8_encode(assembly_data)
    end
    
    # Add diagram image (base64 or file path)
    def add_diagram_image(index, image_data)
      @diagram_images << { index: index, image: deep_utf8_encode(image_data) }
    end
    
    # Generate preview HTML for the report
    def generate_preview_html
      begin
        html = generate_printable_html
        return html
      rescue => e
        puts "ERROR generating preview HTML: #{e.message}"
        raise "Failed to generate preview: #{e.message}"
      end
    end
    
    # Export to PDF file directly
    def export_to_pdf(output_path = nil)
      begin
        output_path ||= generate_default_pdf_path
        
        puts "\n" + "="*80
        puts "DEBUG: PDF EXPORT STARTING"
        puts "="*80
        puts "DEBUG: Output path: #{output_path}"
        
        # Debug: Check what data we have
        puts "\nDEBUG: DATA AVAILABILITY CHECK:"
        puts "  @report_data present: #{!@report_data.nil?}"
        puts "  @report_data keys: #{@report_data.keys.inspect if @report_data}"
        puts "  @diagrams_data present: #{!@diagrams_data.nil?}"
        puts "  @diagrams_data count: #{@diagrams_data.length if @diagrams_data}"
        puts "  @assembly_data present: #{!@assembly_data.nil?}"
        puts "  @assembly_data keys: #{@assembly_data.keys.inspect if @assembly_data}"
        puts "  @diagram_images count: #{@diagram_images.length}"
        
        if @report_data
          puts "\nDEBUG: REPORT DATA DETAILS:"
          puts "  summary: #{!@report_data[:summary].nil?}"
          puts "  unique_board_types: #{@report_data[:unique_board_types]&.length || 0}"
          puts "  unique_part_types: #{@report_data[:unique_part_types]&.length || 0}"
          puts "  parts_placed: #{@report_data[:parts_placed]&.length || 0}"
          puts "  cut_sequences: #{@report_data[:cut_sequences]&.length || 0}"
          puts "  usable_offcuts: #{@report_data[:usable_offcuts]&.length || 0}"
        end
        
        # Force UTF-8 encoding on output path
        output_path = output_path.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        
        # Generate PDF using Prawn with UTF-8 support and professional margins
        Prawn::Document.generate(output_path, 
          page_size: 'A4', 
          margin: [40, 50, 40, 50],  # Top, Right, Bottom, Left - professional margins
          info: {
            Title: 'AutoNestCut Manufacturing Report',
            Author: 'Int. Arch. M.Shkeir',
            Subject: 'Cut List & Nesting Analysis',
            Creator: 'AutoNestCut Professional',
            Producer: 'AutoNestCut',
            CreationDate: Time.now
          }
        ) do |pdf|
          # Set default external encoding to UTF-8 for this block
          old_encoding = Encoding.default_external
          Encoding.default_external = Encoding::UTF_8
          
          begin
            # Set up Unicode font support
            setup_pdf_fonts(pdf)
            render_pdf_content(pdf)
          ensure
            # Restore original encoding
            Encoding.default_external = old_encoding
          end
        end
        
        puts "\n" + "="*80
        puts "DEBUG: PDF EXPORT COMPLETED SUCCESSFULLY"
        puts "="*80
        return output_path
        
      rescue LoadError
        raise "Prawn gem required for PDF export. Install with: gem install prawn"
      rescue => e
        puts "\nERROR in PDF export: #{e.message}"
        puts "Backtrace: #{e.backtrace.join("\n")}"
        raise "PDF export failed: #{e.message}"
      end
    end
    
    private
    
    # Deep UTF-8 encoding for nested data structures
    def deep_utf8_encode(obj)
      case obj
      when String
        ensure_utf8(obj)
      when Symbol
        obj
      when Hash
        obj.transform_keys { |k| deep_utf8_encode(k) }
           .transform_values { |v| deep_utf8_encode(v) }
      when Array
        obj.map { |item| deep_utf8_encode(item) }
      else
        obj
      end
    end
    
    # Helper method to ensure strings are UTF-8 encoded for Prawn
    def ensure_utf8(value)
      case value
      when String
        # Force UTF-8 encoding with aggressive replacement
        if value.encoding == Encoding::UTF_8
          # Already UTF-8, but check if valid
          value.valid_encoding? ? value : value.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        else
          # Convert from other encoding to UTF-8
          value.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        end
      when Symbol
        ensure_utf8(value.to_s)
      when Numeric, TrueClass, FalseClass, NilClass
        value
      else
        ensure_utf8(value.to_s)
      end
    end
    
    # Setup PDF fonts with UTF-8 support
    def setup_pdf_fonts(pdf)
      begin
        # Try to use system fonts for better Unicode support
        if File.exist?('C:/Windows/Fonts/DejaVuSans.ttf')
          pdf.font_families.update('DejaVu' => {
            normal: 'C:/Windows/Fonts/DejaVuSans.ttf',
            bold: 'C:/Windows/Fonts/DejaVuSans-Bold.ttf',
            italic: 'C:/Windows/Fonts/DejaVuSans-Oblique.ttf',
            bold_italic: 'C:/Windows/Fonts/DejaVuSans-BoldOblique.ttf'
          })
          pdf.font 'DejaVu'
        elsif File.exist?('C:/Windows/Fonts/Arial.ttf')
          pdf.font_families.update('Arial' => {
            normal: 'C:/Windows/Fonts/Arial.ttf',
            bold: 'C:/Windows/Fonts/Arialbd.ttf',
            italic: 'C:/Windows/Fonts/Ariali.ttf',
            bold_italic: 'C:/Windows/Fonts/Arialbi.ttf'
          })
          pdf.font 'Arial'
        else
          # Fallback: use Helvetica
          pdf.font 'Helvetica'
        end
      rescue => e
        puts "WARNING: Could not load Unicode font: #{e.message}"
        pdf.font 'Helvetica'
      end
    end
    
    # Render all PDF content
    def render_pdf_content(pdf)
      puts "\nDEBUG: RENDERING PDF CONTENT..."
      
      # Title page
      puts "  → Rendering title page..."
      render_title_page(pdf)
      
      # Overall Summary (Enhanced)
      if @report_data[:summary]
        puts "  → Rendering overall summary (NEW PAGE)..."
        pdf.start_new_page
        render_overall_summary_section(pdf)
      else
        puts "  ✗ Skipping overall summary (no data)"
      end
      
      # Materials Used
      if @report_data[:unique_board_types] && @report_data[:unique_board_types].length > 0
        puts "  → Rendering materials section (#{@report_data[:unique_board_types].length} materials)..."
        render_materials_section(pdf)
      else
        puts "  ✗ Skipping materials section (no data)"
      end
      
      # Unique Part Types
      if @report_data[:unique_part_types] && @report_data[:unique_part_types].length > 0
        puts "  → Rendering unique parts section (#{@report_data[:unique_part_types].length} parts)..."
        render_unique_parts_section(pdf)
      else
        puts "  ✗ Skipping unique parts section (no data)"
      end
      
      # Sheet Inventory Summary
      if @report_data[:unique_board_types] && @report_data[:unique_board_types].length > 0
        puts "  → Rendering sheet inventory section..."
        render_sheet_inventory_section(pdf)
      else
        puts "  ✗ Skipping sheet inventory section (no data)"
      end
      
      # Boards Summary (NEW - Detailed per-board breakdown)
      if @diagrams_data && @diagrams_data.length > 0
        puts "  → Rendering boards summary section (NEW PAGE) (#{@diagrams_data.length} boards)..."
        pdf.start_new_page
        render_boards_summary_section(pdf)
      else
        puts "  ✗ Skipping boards summary section (no diagrams data)"
      end
      
      # Cutting Diagrams
      if @diagrams_data && @diagrams_data.length > 0
        puts "  → Rendering cutting diagrams section (NEW PAGE) (#{@diagrams_data.length} diagrams)..."
        pdf.start_new_page
        render_diagrams_section(pdf)
      else
        puts "  ✗ Skipping cutting diagrams section (no data)"
      end
      
      # Cut Sequences
      if @report_data[:cut_sequences] && @report_data[:cut_sequences].length > 0
        puts "  → Rendering cut sequences section (NEW PAGE) (#{@report_data[:cut_sequences].length} sequences)..."
        pdf.start_new_page
        render_cut_sequences_section(pdf)
      else
        puts "  ✗ Skipping cut sequences section (no data)"
      end
      
      # Usable Offcuts
      if @report_data[:usable_offcuts] && @report_data[:usable_offcuts].length > 0
        puts "  → Rendering offcuts section (#{@report_data[:usable_offcuts].length} offcuts)..."
        render_offcuts_section(pdf)
      else
        puts "  ✗ Skipping offcuts section (no data)"
      end
      
      # Assembly Views
      if @assembly_data && @assembly_data[:views]
        puts "  → Rendering assembly section (NEW PAGE) (#{@assembly_data[:views].length} views)..."
        pdf.start_new_page
        render_assembly_section(pdf)
      else
        puts "  ✗ Skipping assembly section (no data)"
      end
      
      # Cut List & Part Details
      if @report_data[:parts_placed] && @report_data[:parts_placed].length > 0
        puts "  → Rendering parts list section (NEW PAGE) (#{@report_data[:parts_placed].length} parts)..."
        pdf.start_new_page
        render_parts_list_section(pdf)
      else
        puts "  ✗ Skipping parts list section (no data)"
      end
      
      # Cost Breakdown (NEW)
      if @report_data[:unique_board_types] && @report_data[:unique_board_types].length > 0
        puts "  → Rendering cost breakdown section (#{@report_data[:unique_board_types].length} materials)..."
        render_cost_breakdown_section(pdf)
      else
        puts "  ✗ Skipping cost breakdown section (no data)"
      end
      
      # Footer
      puts "  → Rendering footer..."
      render_footer(pdf)
      
      puts "DEBUG: PDF CONTENT RENDERING COMPLETE"
    end
    
    def render_title_page(pdf)
      # Professional header with branding
      pdf.fill_color '0066cc'
      pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 80
      pdf.fill_color '000000'
      
      pdf.move_down 20
      pdf.font_size(32) { pdf.text 'Cut List & Nesting Report', style: :bold, align: :center, color: 'FFFFFF' }
      pdf.move_down 8
      pdf.font_size(13) { pdf.text 'Professional Manufacturing Analysis', align: :center, color: 'E6F2FF' }
      pdf.move_down 30
      
      summary = @report_data[:summary] || {}
      
      # Project Information Section with visual separator
      pdf.stroke_color 'CCCCCC'
      pdf.stroke_horizontal_rule
      pdf.move_down 15
      
      pdf.font_size(14) { pdf.text 'Project Information', style: :bold, color: '0066cc' }
      pdf.move_down 10
      
      project_info = [
        ['Project Name:', summary[:project_name] || 'Untitled Project'],
        ['Client Name:', summary[:client_name] || 'N/A'],
        ['Generated:', Time.now.strftime('%B %d, %Y at %I:%M %p')],
        ['Units:', summary[:units] || 'mm'],
        ['Currency:', summary[:currency] || 'USD']
      ]
      
      render_enhanced_table(pdf, project_info, header: false)
      
      pdf.move_down 25
      pdf.stroke_horizontal_rule
      pdf.move_down 15
      
      # Key Metrics Section with visual emphasis
      pdf.font_size(14) { pdf.text 'Key Metrics', style: :bold, color: '0066cc' }
      pdf.move_down 10
      
      metrics = [
        ['Total Parts:', summary[:total_parts_instances] || 0],
        ['Unique Components:', summary[:total_unique_part_types] || 0],
        ['Material Sheets:', summary[:total_boards] || 0],
        ['Material Efficiency:', "#{(summary[:overall_efficiency] || 0).round(1)}%"],
        ['Total Waste Area:', summary[:total_waste_area_absolute] || '0 m²'],
        ['Total Project Cost:', "#{summary[:currency] || 'USD'} #{(summary[:total_project_cost] || 0).round(2)}"],
        ['Total Weight:', "#{(summary[:total_project_weight_kg] || 0).round(2)} kg"]
      ]
      
      render_enhanced_table(pdf, metrics, header: false, highlight_last: true)
    end
    
    def render_overall_summary_section(pdf)
      pdf.font_size(18) { pdf.text 'Overall Summary', style: :bold, color: '0066cc' }
      pdf.stroke_color 'CCCCCC'
      pdf.stroke_horizontal_rule
      pdf.move_down 15
      
      summary = @report_data[:summary]
      
      table_data = [
        ['Metric', 'Value'],
        ['Total Parts Instances', summary[:total_parts_instances] || 0],
        ['Total Unique Part Types', summary[:total_unique_part_types] || 0],
        ['Total Boards', summary[:total_boards] || 0],
        ['Overall Efficiency', "#{(summary[:overall_efficiency] || 0).round(1)}%"],
        ['Total Project Weight', "#{(summary[:total_project_weight_kg] || 0).round(2)} kg"],
        ['Total Project Cost', "#{summary[:currency] || 'USD'} #{(summary[:total_project_cost] || 0).round(2)}"]
      ]
      
      render_enhanced_table(pdf, table_data, highlight_last: true)
      pdf.move_down 10
    end
    
    def render_summary_section(pdf)
      pdf.font_size(16) { pdf.text 'Project Summary', style: :bold, color: '0066cc' }
      pdf.move_down 12
      
      summary = @report_data[:summary]
      
      table_data = [
        ['Project Metric', 'Value'],
        ['Total Parts', summary[:total_parts_instances] || 0],
        ['Unique Components', summary[:total_unique_part_types] || 0],
        ['Material Sheets', summary[:total_boards] || 0],
        ['Kerf Width', summary[:kerf_width] || '3.0mm'],
        ['Material Efficiency', "#{(summary[:overall_efficiency] || 0).round(1)}%"],
        ['Total Waste Area', summary[:total_waste_area_absolute] || '0 m²'],
        ['Total Cost', "#{summary[:currency] || 'USD'} #{(summary[:total_project_cost] || 0).round(2)}"],
        ['Total Weight', "#{(summary[:total_project_weight_kg] || 0).round(2)} kg"]
      ]
      
      render_text_table(pdf, table_data)
    end
    
    def render_materials_section(pdf)
      pdf.font_size(18) { pdf.text 'Materials Used', style: :bold, color: '0066cc' }
      pdf.stroke_color 'CCCCCC'
      pdf.stroke_horizontal_rule
      pdf.move_down 15
      
      table_data = [['Material', 'Price per Sheet']]
      
      @report_data[:unique_board_types].each do |board_type|
        table_data << [
          board_type[:material] || board_type['material'],
          "#{board_type[:currency] || board_type['currency'] || 'USD'} #{(board_type[:price_per_sheet] || board_type['price_per_sheet'] || 0).round(2)}"
        ]
      end
      
      render_enhanced_table(pdf, table_data)
      pdf.move_down 10
    end
    
    def render_unique_parts_section(pdf)
      pdf.font_size(18) { pdf.text 'Unique Part Types', style: :bold, color: '0066cc' }
      pdf.stroke_color 'CCCCCC'
      pdf.stroke_horizontal_rule
      pdf.move_down 15
      
      table_data = [['Name', 'Width (mm)', 'Height (mm)', 'Thickness (mm)', 'Material', 'Grain', 'Edge Banding', 'Qty', 'Total Area (m²)', 'Weight (kg)']]
      
      @report_data[:unique_part_types].each do |part|
        # Properly format edge banding
        edge_banding_value = part[:edge_banding] || part['edge_banding']
        if edge_banding_value.is_a?(Hash)
          edge_banding_text = edge_banding_value[:type] || edge_banding_value['type'] || 'None'
        else
          edge_banding_text = edge_banding_value || 'None'
        end
        
        table_data << [
          part[:name] || part['name'] || '',
          (part[:width] || part['width'] || 0).round(1).to_s,
          (part[:height] || part['height'] || 0).round(1).to_s,
          (part[:thickness] || part['thickness'] || 0).round(1).to_s,
          part[:material] || part['material'] || '',
          part[:grain_direction] || part['grain_direction'] || 'Any',
          edge_banding_text,
          (part[:total_quantity] || part['total_quantity']).to_s,
          ((part[:total_area] || part['total_area'] || 0) / 1000000).round(2).to_s,
          (part[:total_weight_kg] || part['total_weight_kg'] || 0).round(2).to_s
        ]
      end
      
      render_enhanced_table(pdf, table_data)
      pdf.move_down 10
    end
    
    def render_sheet_inventory_section(pdf)
      pdf.font_size(18) { pdf.text 'Sheet Inventory Summary', style: :bold, color: '0066cc' }
      pdf.stroke_color 'CCCCCC'
      pdf.stroke_horizontal_rule
      pdf.move_down 15
      
      table_data = [['Material', 'Dimensions (mm)', 'Count', 'Total Area (m²)', 'Price/Sheet', 'Total Cost']]
      
      @report_data[:unique_board_types].each do |board_type|
        width = board_type[:stock_width] || 2440
        height = board_type[:stock_height] || 1220
        table_data << [
          board_type[:material],
          "#{width.round(1)} x #{height.round(1)}",
          board_type[:count].to_s,
          ((board_type[:total_area] || 0) / 1000000).round(2).to_s,
          "#{board_type[:currency] || 'USD'} #{(board_type[:price_per_sheet] || 0).round(2)}",
          "#{board_type[:currency] || 'USD'} #{(board_type[:total_cost] || 0).round(2)}"
        ]
      end
      
      render_enhanced_table(pdf, table_data)
    end
    
    def render_boards_summary_section(pdf)
      pdf.font_size(18) { pdf.text 'Boards Summary', style: :bold, color: '0066cc' }
      pdf.move_down 15
      
      @diagrams_data.each_with_index do |board, idx|
        # Check if we need a new page - ensure enough space
        if pdf.cursor < 250
          pdf.start_new_page
        end
        
        material = board[:material] || board['material'] || 'Unknown'
        width = board[:stock_width] || board['stock_width'] || 2440
        height = board[:stock_height] || board['stock_height'] || 1220
        parts_count = board[:parts_count] || board['parts_count'] || 0
        efficiency = (board[:efficiency_percentage] || board['efficiency_percentage'] || 0).round(1)
        waste = (board[:waste_percentage] || board['waste_percentage'] || 0).round(1)
        
        # Board header with colored background based on efficiency
        bg_color = efficiency >= 80 ? 'E8F5E9' : (efficiency >= 60 ? 'FFF8E1' : 'FFEBEE')
        pdf.fill_color bg_color
        pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 35
        pdf.fill_color '000000'
        
        pdf.move_down 10
        pdf.font_size(14) { pdf.text "Board #{idx + 1}: #{material}", style: :bold, indent_paragraphs: 10 }
        pdf.move_down 12
        
        # Board info in enhanced format
        board_info = [
          ['Size:', "#{width.round(1)} × #{height.round(1)} mm"],
          ['Parts:', parts_count.to_s],
          ['Efficiency:', "#{efficiency}%"],
          ['Waste:', "#{waste}%"]
        ]
        
        render_enhanced_table(pdf, board_info, header: false)
        
        # Parts on this board
        if @report_data[:parts_placed]
          parts_on_board = @report_data[:parts_placed].select { |p| (p[:board_number] || p['board_number']) == (idx + 1) }
          
          if parts_on_board.length > 0
            pdf.move_down 12
            pdf.font_size(11) { pdf.text 'Parts on this board:', style: :bold, color: '0066cc' }
            pdf.move_down 6
            
            parts_table = [['Part ID', 'Name', 'Dimensions (mm)', 'Material', 'Grain', 'Edge Banding']]
            
            parts_on_board.each_with_index do |part, part_idx|
              part_id = part[:part_unique_id] || part['part_unique_id'] || part[:instance_id] || part['instance_id'] || "P#{part_idx + 1}"
              name = part[:name] || part['name'] || ''
              width_p = (part[:width] || part['width'] || 0).round(1)
              height_p = (part[:height] || part['height'] || 0).round(1)
              material_p = part[:material] || part['material'] || ''
              grain = part[:grain_direction] || part['grain_direction'] || 'Any'
              
              # Properly format edge banding
              edge_banding_value = part[:edge_banding] || part['edge_banding']
              if edge_banding_value.is_a?(Hash)
                edge_banding = edge_banding_value[:type] || edge_banding_value['type'] || 'None'
              else
                edge_banding = edge_banding_value.to_s == '' ? 'None' : (edge_banding_value || 'None')
              end
              
              parts_table << [part_id, name, "#{width_p} × #{height_p}", material_p, grain, edge_banding]
            end
            
            render_enhanced_table(pdf, parts_table)
          end
        end
        
        pdf.move_down 20
        
        # Add separator line between boards
        if idx < @diagrams_data.length - 1
          pdf.stroke_color 'DDDDDD'
          pdf.stroke_horizontal_rule
          pdf.move_down 15
        end
      end
    end
    
    def render_diagrams_section(pdf)
      pdf.font_size(18) { pdf.text 'Cutting Diagrams', style: :bold, color: '0066cc' }
      pdf.move_down 15
      
      @diagrams_data.each_with_index do |board, idx|
        # Each diagram gets its own page (except first)
        if idx > 0
          pdf.start_new_page
        end
        
        # Board header with background
        pdf.fill_color 'F0F8FF'
        pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 30
        pdf.fill_color '000000'
        
        pdf.move_down 8
        pdf.font_size(13) { pdf.text "Sheet #{idx + 1}: #{board[:material] || board['material']}", style: :bold, indent_paragraphs: 10 }
        pdf.move_down 8
        
        efficiency = (board[:efficiency_percentage] || board['efficiency_percentage'] || 0).round(1)
        waste = (board[:waste_percentage] || board['waste_percentage'] || 0).round(1)
        
        # Efficiency badge
        efficiency_color = efficiency >= 80 ? '28A745' : (efficiency >= 60 ? 'FFC107' : 'DC3545')
        pdf.font_size(10) { 
          pdf.formatted_text [
            { text: "Efficiency: ", color: '666666' },
            { text: "#{efficiency}%", color: efficiency_color, styles: [:bold] },
            { text: " | Waste: #{waste}%", color: '666666' }
          ], indent_paragraphs: 10
        }
        pdf.move_down 20
        
        # Try to embed diagram image - MAXIMIZED TO FULL PAGE
        diagram_img = @diagram_images.find { |img| img[:index] == idx || img['index'] == idx }
        if diagram_img && (diagram_img[:image] || diagram_img['image'])
          image_data = diagram_img[:image] || diagram_img['image']
          
          begin
            if image_data.is_a?(String) && image_data.start_with?('data:image')
              base64_data = image_data.sub(/^data:image\/[^;]+;base64,/, '')
              decoded_image = Base64.decode64(base64_data)
              
              temp_file = File.join(Dir.tmpdir, "diagram_#{idx}_#{Time.now.to_i}.png")
              File.binwrite(temp_file, decoded_image)
              
              # MAXIMIZED: Use full page width and maximum available height
              available_height = pdf.cursor - 60  # Leave space for footer
              pdf.image temp_file, fit: [pdf.bounds.width, available_height], position: :center
              
              File.delete(temp_file) if File.exist?(temp_file)
            elsif File.exist?(image_data)
              available_height = pdf.cursor - 60
              pdf.image image_data, fit: [pdf.bounds.width, available_height], position: :center
            end
          rescue => e
            puts "WARNING: Could not embed diagram image: #{e.message}"
            pdf.fill_color 'FFE6E6'
            pdf.fill_rectangle [pdf.bounds.left, pdf.cursor], pdf.bounds.width, 40
            pdf.fill_color '000000'
            pdf.move_down 15
            pdf.text "⚠ Diagram image unavailable", color: 'DC3545', align: :center
            pdf.move_down 15
          end
        end
      end
    end
    
    def render_cut_sequences_section(pdf)
      pdf.font_size(18) { pdf.text 'Cut Sequences', style: :bold, color: '0066cc' }
      pdf.stroke_color 'CCCCCC'
      pdf.stroke_horizontal_rule
      pdf.move_down 15
      
      @report_data[:cut_sequences].each_with_index do |sequence, seq_idx|
        # Check for page break - ensure enough space for sequence
        if pdf.cursor < 200
          pdf.start_new_page
          pdf.font_size(18) { pdf.text 'Cut Sequences (continued)', style: :bold, color: '0066cc' }
          pdf.stroke_horizontal_rule
          pdf.move_down 15
        end
        
        # Sequence header with background
        pdf.fill_color 'F0F8FF'
        pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 28
        pdf.fill_color '000000'
        pdf.move_down 8
        pdf.font_size(12) { pdf.text sequence[:title], style: :bold, indent_paragraphs: 10 }
        pdf.move_down 8
        
        if sequence[:stock_size]
          pdf.font_size(9) { pdf.text "Stock Size: #{sequence[:stock_size]}", color: '666666', indent_paragraphs: 10 }
          pdf.move_down 8
        end
        
        if sequence[:steps] && sequence[:steps].length > 0
          table_data = [['Step', 'Operation', 'Description', 'Measurement']]
          sequence[:steps].each do |step|
            table_data << [
              step[:step].to_s,
              step[:operation].to_s,
              step[:description].to_s,
              step[:measurement].to_s
            ]
          end
          
          render_enhanced_table(pdf, table_data)
        end
        
        pdf.move_down 15
      end
    end
    
    def render_offcuts_section(pdf)
      pdf.font_size(18) { pdf.text 'Usable Offcuts', style: :bold, color: '0066cc' }
      pdf.stroke_color 'CCCCCC'
      pdf.stroke_horizontal_rule
      pdf.move_down 15
      
      table_data = [['Sheet #', 'Material', 'Estimated Size', 'Area (m²)']]
      
      @report_data[:usable_offcuts].each do |offcut|
        table_data << [
          offcut[:board_number].to_s,
          offcut[:material],
          offcut[:estimated_dimensions],
          offcut[:area_m2].to_s
        ]
      end
      
      render_enhanced_table(pdf, table_data)
    end
    
    def render_assembly_section(pdf)
      pdf.font_size(18) { pdf.text 'Assembly Views', style: :bold, color: '0066cc' }
      pdf.move_down 15
      
      views = @assembly_data[:views] || {}
      
      views.each_with_index do |(view_name, view_image), idx|
        # Each assembly view gets its own page (except first)
        if idx > 0
          pdf.start_new_page
        end
        
        # Force UTF-8 encoding on view name
        view_name_utf8 = ensure_utf8(view_name.to_s)
        
        # View header with background
        pdf.fill_color 'F8F9FA'
        pdf.fill_rectangle [0, pdf.cursor], pdf.bounds.width, 25
        pdf.fill_color '000000'
        pdf.move_down 7
        pdf.font_size(12) { pdf.text view_name_utf8, style: :bold, indent_paragraphs: 10, color: '0066cc' }
        pdf.move_down 15
        
        begin
          if view_image.is_a?(String) && view_image.start_with?('data:image')
            base64_data = view_image.sub(/^data:image\/[^;]+;base64,/, '')
            decoded_image = Base64.decode64(base64_data)
            
            safe_view_name = view_name_utf8.gsub(/[^a-zA-Z0-9_-]/, '_')
            temp_file = File.join(Dir.tmpdir, "assembly_#{safe_view_name}_#{Time.now.to_i}.png")
            File.binwrite(temp_file, decoded_image)
            
            # MAXIMIZED: Use full page width and maximum available height
            available_height = pdf.cursor - 60  # Leave space for footer
            pdf.image temp_file, fit: [pdf.bounds.width, available_height], position: :center
            
            File.delete(temp_file) if File.exist?(temp_file)
          elsif File.exist?(view_image)
            available_height = pdf.cursor - 60
            pdf.image view_image, fit: [pdf.bounds.width, available_height], position: :center
          end
        rescue => e
          puts "WARNING: Could not embed assembly view: #{e.message}"
          pdf.fill_color 'FFE6E6'
          pdf.fill_rectangle [pdf.bounds.left, pdf.cursor], pdf.bounds.width, 40
          pdf.fill_color '000000'
          pdf.move_down 15
          pdf.text "⚠ Assembly view unavailable", color: 'DC3545', align: :center
          pdf.move_down 15
        end
      end
    end
    
    def render_parts_list_section(pdf)
      pdf.font_size(18) { pdf.text 'Cut List & Part Details', style: :bold, color: '0066cc' }
      pdf.stroke_color 'CCCCCC'
      pdf.stroke_horizontal_rule
      pdf.move_down 15
      
      table_data = [['Part ID', 'Name', 'Dimensions (mm)', 'Material', 'Sheet #', 'Grain', 'Edge Banding']]
      
      @report_data[:parts_placed].each_with_index do |part, idx|
        part_id = part[:part_unique_id] || part[:instance_id] || "P#{idx + 1}"
        width = (part[:width] || 0).round(1)
        height = (part[:height] || 0).round(1)
        
        # Properly format edge banding
        edge_banding_value = part[:edge_banding]
        if edge_banding_value.is_a?(Hash)
          edge_banding = edge_banding_value[:type] || edge_banding_value['type'] || 'None'
        else
          edge_banding = edge_banding_value.to_s == '' ? 'None' : (edge_banding_value || 'None')
        end
        
        table_data << [
          part_id,
          part[:name],
          "#{width} x #{height}",
          part[:material],
          part[:board_number].to_s,
          part[:grain_direction] || 'Any',
          edge_banding
        ]
      end
      
      render_enhanced_table(pdf, table_data)
    end
    
    def render_cost_breakdown_section(pdf)
      pdf.move_down 20
      pdf.font_size(18) { pdf.text 'Cost Breakdown', style: :bold, color: '0066cc' }
      pdf.stroke_color 'CCCCCC'
      pdf.stroke_horizontal_rule
      pdf.move_down 15
      
      table_data = [['Material', 'Sheets Required', 'Unit Cost', 'Total Cost']]
      
      @report_data[:unique_board_types].each do |board_type|
        table_data << [
          board_type[:material] || board_type['material'],
          (board_type[:count] || board_type['count']).to_s,
          "#{board_type[:currency] || board_type['currency'] || 'USD'} #{(board_type[:price_per_sheet] || board_type['price_per_sheet'] || 0).round(2)}",
          "#{board_type[:currency] || board_type['currency'] || 'USD'} #{(board_type[:total_cost] || board_type['total_cost'] || 0).round(2)}"
        ]
      end
      
      render_enhanced_table(pdf, table_data, highlight_last: true)
      pdf.move_down 15
    end
    
    def render_footer(pdf)
      # Add page numbers on all pages at the bottom
      pdf.number_pages '<page> of <total>', 
        at: [pdf.bounds.left, -10], 
        align: :center, 
        size: 9,
        color: '999999'
      
      # Add professional footer ONLY at the absolute bottom of the last page
      # We need to position it at the bottom margin, not at current cursor
      pdf.go_to_page(pdf.page_count)
      
      # Calculate position for footer at bottom of page
      # Bottom margin is 40pt, so we position footer elements from bottom up
      footer_y_position = 30  # 30pt from bottom of page
      
      # Move to bottom of page for footer
      pdf.bounding_box([pdf.bounds.left, footer_y_position], width: pdf.bounds.width, height: 30) do
        # Footer separator line at top of bounding box
        pdf.stroke_color 'CCCCCC'
        pdf.stroke_horizontal_rule
        pdf.move_down 5
        
        # Footer content with branding
        pdf.font_size(10) { 
          pdf.text 'AutoNestCut Professional', 
            align: :center, 
            color: '0066cc',
            style: :bold
        }
        pdf.move_down 3
        pdf.font_size(8) { 
          pdf.text 'Developed by Int. Arch. M.Shkeir', 
            align: :center, 
            color: '999999'
        }
        pdf.move_down 2
        pdf.font_size(8) { 
          pdf.text "Generated on #{Time.now.strftime('%B %d, %Y at %I:%M %p')}", 
            align: :center, 
            color: 'CCCCCC'
        }
      end
    end
    
    
    # Enhanced table rendering with better styling and page break handling
    def render_enhanced_table(pdf, table_data, options = {})
      return if table_data.empty?
      
      has_header = options.fetch(:header, true)
      highlight_last = options.fetch(:highlight_last, false)
      
      pdf.font_size(9)
      
      # Calculate column widths
      num_cols = table_data[0].length
      col_width = (pdf.bounds.width - 20) / num_cols
      
      # Store current font
      current_font = pdf.font.family
      
      # Render header row if present
      if has_header
        header = table_data[0]
        
        # Header background with gradient effect
        pdf.fill_color '0066cc'
        pdf.fill_rectangle [pdf.bounds.left, pdf.cursor], pdf.bounds.width, 24
        pdf.fill_color 'FFFFFF'
        
        pdf.font current_font, style: :bold
        header.each_with_index do |cell, idx|
          x = pdf.bounds.left + (idx * col_width)
          cell_text = ensure_utf8(cell).to_s
          pdf.text_box cell_text, at: [x + 5, pdf.cursor - 6], width: col_width - 10, height: 20, overflow: :truncate, valign: :center
        end
        pdf.font current_font
        pdf.fill_color '000000'
        pdf.move_down 24
        
        data_rows = table_data[1..-1]
      else
        data_rows = table_data
      end
      
      # Render data rows with alternating colors
      data_rows.each_with_index do |row, row_idx|
        # Check if we need a page break
        if pdf.cursor < 50
          pdf.start_new_page
          
          # Re-render header on new page if applicable
          if has_header
            header = table_data[0]
            pdf.fill_color '0066cc'
            pdf.fill_rectangle [pdf.bounds.left, pdf.cursor], pdf.bounds.width, 24
            pdf.fill_color 'FFFFFF'
            pdf.font current_font, style: :bold
            header.each_with_index do |cell, idx|
              x = pdf.bounds.left + (idx * col_width)
              cell_text = ensure_utf8(cell).to_s
              pdf.text_box cell_text, at: [x + 5, pdf.cursor - 6], width: col_width - 10, height: 20, overflow: :truncate, valign: :center
            end
            pdf.font current_font
            pdf.fill_color '000000'
            pdf.move_down 24
          end
        end
        
        # Alternating row colors
        row_color = row_idx.even? ? 'FFFFFF' : 'F8F9FA'
        
        # Highlight last row if requested
        if highlight_last && row_idx == data_rows.length - 1
          row_color = 'FFFACD'
          pdf.font current_font, style: :bold
        end
        
        pdf.fill_color row_color
        pdf.fill_rectangle [pdf.bounds.left, pdf.cursor], pdf.bounds.width, 20
        pdf.fill_color '000000'
        
        row.each_with_index do |cell, idx|
          x = pdf.bounds.left + (idx * col_width)
          cell_text = ensure_utf8(cell).to_s
          pdf.text_box cell_text, at: [x + 5, pdf.cursor - 5], width: col_width - 10, height: 18, overflow: :truncate
        end
        
        pdf.font current_font if highlight_last && row_idx == data_rows.length - 1
        pdf.move_down 20
      end
      
      pdf.move_down 5
    end
    
    # Helper method to render text-based tables without using pdf.table
    # Fixes: Font consistency (Issue #2), Color format (Issue #3), Page breaks (Issue #4), Encoding (Issue #10)
    def render_text_table(pdf, table_data)
      return if table_data.empty?
      
      pdf.font_size(9)
      
      # Calculate column widths
      num_cols = table_data[0].length
      col_width = (pdf.bounds.width - 10) / num_cols
      
      # Store current font to maintain Unicode support (Fix #2)
      current_font = pdf.font.family
      
      # Render header row
      header = table_data[0]
      pdf.fill_color 'F0F0F0'  # Fix #3: Proper hex format (uppercase, no #)
      pdf.fill_rectangle [pdf.bounds.left, pdf.cursor], pdf.bounds.width, 20
      pdf.fill_color '000000'
      
      pdf.font current_font, style: :bold  # Fix #2: Use current font instead of forcing Helvetica
      header.each_with_index do |cell, idx|
        x = pdf.bounds.left + (idx * col_width)
        # Fix #10: Ensure UTF-8 encoding for all text
        cell_text = ensure_utf8(cell).to_s
        # FIX: Changed 'pdf.cursor + 15' to 'pdf.cursor - 5' to position text INSIDE the rectangle
        pdf.text_box cell_text, at: [x + 2, pdf.cursor - 5], width: col_width - 4, height: 18, overflow: :truncate
      end
      pdf.font current_font  # Fix #2: Reset to current font
      pdf.move_down 20
      
      # Render data rows with page break checks (Fix #4)
      table_data[1..-1].each do |row|
        # Check if we need a page break before rendering row (Fix #4)
        if pdf.cursor < 40
          pdf.start_new_page
          # Re-render header on new page
          pdf.fill_color 'F0F0F0'
          pdf.fill_rectangle [pdf.bounds.left, pdf.cursor], pdf.bounds.width, 20
          pdf.fill_color '000000'
          pdf.font current_font, style: :bold
          header.each_with_index do |cell, idx|
            x = pdf.bounds.left + (idx * col_width)
            cell_text = ensure_utf8(cell).to_s
            # FIX: Corrected cursor position here as well
            pdf.text_box cell_text, at: [x + 2, pdf.cursor - 5], width: col_width - 4, height: 18, overflow: :truncate
          end
          pdf.font current_font
          pdf.move_down 20
        end
        
        row.each_with_index do |cell, idx|
          x = pdf.bounds.left + (idx * col_width)
          # Fix #10: Ensure UTF-8 encoding for all text
          cell_text = ensure_utf8(cell).to_s
          # FIX: Adjusted row text position
          pdf.text_box cell_text, at: [x + 2, pdf.cursor - 2], width: col_width - 4, height: 16, overflow: :truncate
        end
        pdf.move_down 16
      end
      
      pdf.move_down 5
    end
    
    def generate_printable_html
      summary = @report_data[:summary] || {}
      
      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>AutoNestCut Report Preview</title>
            <style>
                @page { size: A4 portrait; margin: 15mm; }
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { 
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
                    background: #e0e0e0; 
                    color: #333; 
                    font-size: 10pt; 
                    line-height: 1.4; 
                    padding: 0; 
                    margin: 0; 
                }
                .print-controls { 
                    position: fixed; 
                    top: 20px; 
                    right: 20px; 
                    z-index: 1000; 
                    background: white; 
                    padding: 20px; 
                    border-radius: 8px; 
                    box-shadow: 0 4px 20px rgba(0,0,0,0.3); 
                    display: flex; 
                    flex-direction: column; 
                    gap: 10px; 
                }
                .print-controls button { 
                    background: #007cba; 
                    color: white; 
                    border: none; 
                    padding: 12px 24px; 
                    border-radius: 6px; 
                    cursor: pointer; 
                    font-size: 15px; 
                    font-weight: 600; 
                    display: flex; 
                    align-items: center; 
                    justify-content: center; 
                    gap: 8px; 
                    min-width: 180px; 
                    transition: all 0.3s; 
                }
                .print-controls button:hover { 
                    background: #005a87; 
                    transform: translateY(-2px); 
                    box-shadow: 0 6px 16px rgba(0,0,0,0.3); 
                }
                .print-controls button.close { 
                    background: #6c757d; 
                }
                .print-controls button.close:hover { 
                    background: #5a6268; 
                }
                .page { 
                    width: 210mm; 
                    min-height: 297mm; 
                    padding: 15mm; 
                    margin: 20px auto; 
                    background: white; 
                    box-shadow: 0 0 10px rgba(0,0,0,0.2); 
                }
                h1 { 
                    color: #0066cc; 
                    border-bottom: 3px solid #0066cc; 
                    padding-bottom: 8px; 
                    margin: 0 0 10px 0; 
                    font-size: 20pt; 
                    page-break-after: avoid; 
                }
                .subtitle { 
                    color: #666; 
                    font-size: 9pt; 
                    margin-bottom: 15px; 
                    page-break-after: avoid; 
                }
                h2 { 
                    color: #0066cc; 
                    margin: 20px 0 10px 0; 
                    border-bottom: 2px solid #0066cc; 
                    padding-bottom: 6px; 
                    font-size: 13pt; 
                    page-break-after: avoid; 
                }
                h3 { 
                    color: #333; 
                    margin: 12px 0 8px 0; 
                    font-size: 11pt; 
                    page-break-after: avoid; 
                }
                .section { 
                    page-break-inside: avoid; 
                    margin-bottom: 20px; 
                }
                .section.new-page { 
                    page-break-before: always; 
                }
                table { 
                    width: 100%; 
                    border-collapse: collapse; 
                    margin: 10px 0 15px 0; 
                    font-size: 9pt; 
                    page-break-inside: auto; 
                }
                thead { 
                    display: table-header-group; 
                }
                tbody { 
                    display: table-row-group; 
                }
                tr { 
                    page-break-inside: avoid; 
                    page-break-after: auto; 
                }
                th { 
                    background: #f0f0f0; 
                    padding: 6px 8px; 
                    text-align: left; 
                    font-weight: 600; 
                    border-bottom: 2px solid #0066cc; 
                    font-size: 9pt; 
                }
                td { 
                    padding: 5px 8px; 
                    border-bottom: 1px solid #ddd; 
                }
                tr:nth-child(even) { 
                    background: #f9f9f9; 
                }
                .diagram-section { 
                    margin: 15px 0; 
                    text-align: center; 
                    page-break-inside: avoid; 
                }
                .diagram-image { 
                    max-width: 100%; 
                    height: auto; 
                    border: 1px solid #ddd; 
                    margin: 8px 0; 
                }
                .assembly-section { 
                    page-break-before: always; 
                    page-break-inside: avoid; 
                    margin: 15px 0; 
                }
                .assembly-grid { 
                    display: grid; 
                    grid-template-columns: repeat(3, 1fr); 
                    gap: 10px; 
                    margin: 10px 0; 
                    page-break-inside: avoid; 
                }
                .assembly-view { 
                    border: 1px solid #ddd; 
                    padding: 6px; 
                    text-align: center; 
                    background: #f9f9f9; 
                    page-break-inside: avoid; 
                }
                .assembly-view img { 
                    max-width: 100%; 
                    height: auto; 
                    margin: 4px 0; 
                }
                .assembly-view-label { 
                    font-weight: 600; 
                    margin-top: 4px; 
                    color: #0066cc; 
                    font-size: 8pt; 
                }
                .total-highlight { 
                    font-weight: 600; 
                    background: #ffffcc; 
                }
                .cut-sequence { 
                    margin: 12px 0; 
                    page-break-inside: avoid; 
                }
                .cut-sequence-title { 
                    font-weight: 600; 
                    margin: 8px 0 4px 0; 
                }
                @media print {
                    body { background: white; }
                    .print-controls { display: none !important; }
                    .page { margin: 0; box-shadow: none; page-break-after: auto; }
                }
            </style>
        </head>
        <body>
            <div class="print-controls no-print">
                <button onclick="window.print()">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="6,9 6,2 18,2 18,9"/>
                        <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/>
                        <polyline points="6,14 6,22 18,22 18,14"/>
                    </svg>
                    Print to PDF
                </button>
                <button class="close" onclick="window.close()">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <line x1="18" y1="6" x2="6" y2="18"/>
                        <line x1="6" y1="6" x2="18" y2="18"/>
                    </svg>
                    Close
                </button>
            </div>
            <div class="page">
                <h1>Cut List & Nesting Report</h1>
                <p class="subtitle"><strong>Professional Manufacturing Analysis</strong><br><strong>Generated:</strong> #{Time.now.strftime('%m/%d/%Y, %I:%M:%S %p')}</p>
      HTML
      
      # PROJECT SUMMARY
      if summary
        html += <<~HTML
          <div class="section">
          <h2>Project Summary</h2>
          <table>
            <thead><tr><th>Project Metric</th><th>Value</th></tr></thead>
            <tbody>
              <tr><td>Total Parts</td><td>#{summary[:total_parts_instances] || 0}</td></tr>
              <tr><td>Unique Components</td><td>#{summary[:total_unique_part_types] || 0}</td></tr>
              <tr><td>Material Sheets</td><td>#{summary[:total_boards] || 0}</td></tr>
              <tr><td>Kerf Width</td><td>#{summary[:kerf_width] || '3.0mm'}</td></tr>
              <tr><td>Material Efficiency</td><td>#{(summary[:overall_efficiency] || 0).round(1)}%</td></tr>
              <tr><td>Total Waste Area</td><td>#{summary[:total_waste_area_absolute] || '0 m²'}</td></tr>
              <tr><td class="total-highlight">Total Cost</td><td class="total-highlight">#{summary[:currency] || 'USD'} #{(summary[:total_project_cost] || 0).round(2)}</td></tr>
            </tbody>
          </table>
          </div>
        HTML
      end
      
      # MATERIALS USED
      if @report_data[:unique_board_types]
        html += <<~HTML
          <div class="section">
          <h2>Materials Used</h2>
          <table>
            <thead><tr><th>Material Type</th><th>Sheets Required</th><th>Unit Cost</th><th>Total Cost</th></tr></thead>
            <tbody>
        HTML
        @report_data[:unique_board_types].each do |board_type|
          html += "<tr><td>#{board_type[:material]}</td><td>#{board_type[:count]}</td><td>#{board_type[:currency] || 'USD'} #{(board_type[:price_per_sheet] || 0).round(2)}</td><td class=\"total-highlight\">#{board_type[:currency] || 'USD'} #{(board_type[:total_cost] || 0).round(2)}</td></tr>\n"
        end
        html += "</tbody></table></div>\n"
      end
      
      # UNIQUE PART TYPES
      if @report_data[:unique_part_types]
        html += <<~HTML
          <div class="section">
          <h2>Unique Part Types</h2>
          <table>
            <thead><tr><th>Part Name</th><th>Width (mm)</th><th>Height (mm)</th><th>Thickness (mm)</th><th>Material</th><th>Grain</th><th>Qty</th><th>Area (m²)</th></tr></thead>
            <tbody>
        HTML
        @report_data[:unique_part_types].each do |part|
          html += "<tr><td>#{part[:name]}</td><td>#{(part[:width] || 0).round(1)}</td><td>#{(part[:height] || 0).round(1)}</td><td>#{(part[:thickness] || 0).round(1)}</td><td>#{part[:material]}</td><td>#{part[:grain_direction] || 'Any'}</td><td class=\"total-highlight\">#{part[:total_quantity]}</td><td>#{(part[:total_area] / 1000000).round(2)}</td></tr>\n"
        end
        html += "</tbody></table></div>\n"
      end
      
      # SHEET INVENTORY SUMMARY
      if @report_data[:unique_board_types]
        html += <<~HTML
          <div class="section">
          <h2>Sheet Inventory Summary</h2>
          <table>
            <thead><tr><th>Material</th><th>Dimensions (mm)</th><th>Count</th><th>Total Area (m²)</th><th>Price/Sheet</th><th>Total Cost</th></tr></thead>
            <tbody>
        HTML
        @report_data[:unique_board_types].each do |board_type|
          width = board_type[:stock_width] || 2440
          height = board_type[:stock_height] || 1220
          html += "<tr><td>#{board_type[:material]}</td><td>#{width.round(1)} x #{height.round(1)}</td><td class=\"total-highlight\">#{board_type[:count]}</td><td>#{(board_type[:total_area] / 1000000).round(2)}</td><td>#{board_type[:currency] || 'USD'} #{(board_type[:price_per_sheet] || 0).round(2)}</td><td class=\"total-highlight\">#{board_type[:currency] || 'USD'} #{(board_type[:total_cost] || 0).round(2)}</td></tr>\n"
        end
        html += "</tbody></table></div>\n"
      end
      
      # CUTTING DIAGRAMS WITH IMAGES
      if @diagrams_data && @diagrams_data.length > 0
        html += "<div class='section new-page'><h2>Cutting Diagrams</h2>\n"
        @diagrams_data.each_with_index do |board, idx|
          html += "<div class=\"diagram-section\">\n"
          html += "<h3>Sheet #{idx + 1}: #{board[:material] || board['material']}</h3>\n"
          html += "<p><strong>Efficiency:</strong> #{(board[:efficiency_percentage] || board['efficiency_percentage'] || 0).round(1)}% | <strong>Waste:</strong> #{(board[:waste_percentage] || board['waste_percentage'] || 0).round(1)}%</p>\n"
          
          # Embed captured diagram image if available
          diagram_img = @diagram_images.find { |img| img[:index] == idx || img['index'] == idx }
          if diagram_img && (diagram_img[:image] || diagram_img['image'])
            image_data = diagram_img[:image] || diagram_img['image']
            html += "<img src=\"#{image_data}\" class=\"diagram-image\" alt=\"Cutting diagram for sheet #{idx + 1}\">\n"
          end
          
          html += "</div>\n"
        end
        html += "</div>\n"
      end
      
      # CUT SEQUENCES
      if @report_data[:cut_sequences]
        html += "<div class='section new-page'><h2>Cut Sequences</h2>\n"
        @report_data[:cut_sequences].each do |sequence|
          html += "<div class=\"cut-sequence\">\n"
          html += "<div class=\"cut-sequence-title\">#{sequence[:title]}</div>\n"
          if sequence[:stock_size]
            html += "<p style=\"margin: 5px 0; font-size: 9pt;\"><strong>Stock Size:</strong> #{sequence[:stock_size]}</p>\n"
          end
          if sequence[:steps] && sequence[:steps].length > 0
            html += "<table style=\"font-size: 9pt;\">\n"
            html += "<thead><tr><th>Step</th><th>Operation</th><th>Description</th><th>Measurement</th></tr></thead>\n"
            html += "<tbody>\n"
            sequence[:steps].each do |step|
              html += "<tr><td>#{step[:step]}</td><td>#{step[:operation]}</td><td>#{step[:description]}</td><td>#{step[:measurement]}</td></tr>\n"
            end
            html += "</tbody></table>\n"
          end
          html += "</div>\n"
        end
        html += "</div>\n"
      end
      
      # USABLE OFFCUTS
      if @report_data[:usable_offcuts]
        html += <<~HTML
          <div class="section">
          <h2>Usable Offcuts</h2>
          <table>
            <thead><tr><th>Sheet #</th><th>Material</th><th>Estimated Size</th><th>Area (m²)</th></tr></thead>
            <tbody>
        HTML
        @report_data[:usable_offcuts].each do |offcut|
          html += "<tr><td>#{offcut[:board_number]}</td><td>#{offcut[:material]}</td><td>#{offcut[:estimated_dimensions]}</td><td>#{offcut[:area_m2]}</td></tr>\n"
        end
        html += "</tbody></table></div>\n"
      end
      
      # ASSEMBLY VIEWS
      if @assembly_data && @assembly_data[:views]
        html += "<div class='section assembly-section new-page'>\n"
        html += "<h2>Assembly Views</h2>\n"
        html += "<div class=\"assembly-grid\">\n"
        
        @assembly_data[:views].each do |view_name, view_image|
          html += "<div class=\"assembly-view\">\n"
          if view_image.is_a?(String) && view_image.start_with?('data:image')
            html += "<img src=\"#{view_image}\" alt=\"#{view_name} view\">\n"
          end
          html += "<div class=\"assembly-view-label\">#{view_name}</div>\n"
          html += "</div>\n"
        end
        
        html += "</div>\n"
        html += "</div>\n"
      end
      
      # CUT LIST & PART DETAILS
      if @report_data[:parts_placed]
        html += <<~HTML
          <div class="section new-page">
          <h2>Cut List & Part Details</h2>
          <table style="font-size: 9pt;">
            <thead><tr><th>Part ID</th><th>Name</th><th>Dimensions (mm)</th><th>Material</th><th>Sheet #</th><th>Grain</th><th>Edge Banding</th></tr></thead>
            <tbody>
        HTML
        @report_data[:parts_placed].each_with_index do |part, idx|
          part_id = part[:part_unique_id] || part[:instance_id] || "P#{idx + 1}"
          width = (part[:width] || 0).round(1)
          height = (part[:height] || 0).round(1)
          
          # Properly format edge banding
          edge_banding_value = part[:edge_banding]
          if edge_banding_value.is_a?(Hash)
            edge_banding = edge_banding_value[:type] || edge_banding_value['type'] || 'None'
          else
            edge_banding = edge_banding_value.to_s == '' ? 'None' : (edge_banding_value || 'None')
          end
          
          html += "<tr><td>#{part_id}</td><td>#{part[:name]}</td><td>#{width} x #{height}</td><td>#{part[:material]}</td><td>#{part[:board_number]}</td><td>#{part[:grain_direction] || 'Any'}</td><td>#{edge_banding}</td></tr>\n"
        end
        html += "</tbody></table></div>\n"
      end
      
      # FOOTER
      html += <<~HTML
        <div style="margin-top: 30px; padding-top: 15px; border-top: 1px solid #ddd; text-align: center; font-size: 9pt; color: #666;">
          <p>AutoNestCut Professional</p>
          <p>Developed by Int. Arch. M.Shkeir</p>
        </div>
            </div>
        </body>
        </html>
      HTML
      
      html
    end
    
    def generate_default_pdf_path
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      downloads_path = File.join(ENV['USERPROFILE'] || ENV['HOME'], 'Downloads')
      File.join(downloads_path, "AutoNestCut_Report_#{timestamp}.pdf")
    end
  end
end
