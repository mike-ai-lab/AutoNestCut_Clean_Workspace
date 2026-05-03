# frozen_string_literal: true
# encoding: UTF-8

require 'base64'
require 'json'
require 'prawn'
require 'tmpdir'

# Load RQRCode for QR code generation
begin
  require 'rqrcode'
rescue LoadError
  puts "WARNING: rqrcode gem not available. QR code labels will not be generated."
end

module AutoNestCut
  class ReportPdfExporter
    
    # --- MODERN MINIMAL DESIGN CONSTANTS ---
    COLOR_TEXT_MAIN = '1A1A1A'      # Almost black
    COLOR_TEXT_SECONDARY = '6B7280'  # Gray-500
    COLOR_ACCENT = '2563EB'          # Blue-600
    COLOR_BORDER = 'E5E7EB'          # Gray-200
    COLOR_SECTION_NUMBER = '9CA3AF'  # Gray-400
    
    # --- INDUSTRIAL LABEL DESIGN CONSTANTS ---
    COLOR_ORANGE = 'E65100'          # Orange accent
    COLOR_METAL = 'D0D0D0'           # Metallic gray
    LABEL_BORDER_WIDTH = 1.5         # Border width in points
    
    FONT_SIZE_H1 = 28
    FONT_SIZE_H2 = 18
    FONT_SIZE_H3 = 14
    FONT_SIZE_BODY = 10
    FONT_SIZE_SMALL = 9
    
    # Section numbering
    @section_counter = 0
    
    def initialize
      @report_data = {}
      @diagrams_data = []
      @assembly_data = nil
      @diagram_images = []
      @section_counter = 0
      @toc_entries = []
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
    
    # Export to PDF file directly
    def export_to_pdf(output_path = nil, preview_mode = false)
      begin
        output_path ||= generate_default_pdf_path
        
        puts "\n" + "="*80
        puts "DEBUG: PDF EXPORT STARTING (REDESIGNED)"
        puts "="*80
        
        # Force UTF-8 encoding on output path
        output_path = output_path.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        
        # Generate PDF using Prawn
        Prawn::Document.generate(output_path, 
          page_size: 'A4',
          page_layout: :portrait,
          margin: [50, 50, 50, 50],  # Consistent margins
          info: {
            Title: 'AutoNestCut Manufacturing Report',
            Author: 'Int. Arch. M.Shkeir',
            Subject: 'Cut List & Nesting Analysis',
            Creator: 'AutoNestCut Professional',
            Producer: 'AutoNestCut',
            CreationDate: Time.now
          }
        ) do |pdf|
          old_encoding = Encoding.default_external
          Encoding.default_external = Encoding::UTF_8
          
          begin
            setup_pdf_fonts(pdf)
            render_pdf_content(pdf)
            add_page_numbers(pdf)
          ensure
            Encoding.default_external = old_encoding
          end
        end
        
        puts "\n" + "="*80
        puts "DEBUG: PDF EXPORT COMPLETED SUCCESSFULLY"
        puts "="*80
        
        if preview_mode
          show_preview_dialog(output_path)
        end
        
        return output_path
        
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
    
    # Helper method to ensure strings are UTF-8 encoded
    def ensure_utf8(value)
      case value
      when String
        if value.encoding == Encoding::UTF_8
          value.valid_encoding? ? value : value.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
        else
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
    
    # Setup PDF fonts
    def setup_pdf_fonts(pdf)
      begin
        if File.exist?('C:/Windows/Fonts/Arial.ttf')
          pdf.font_families.update('Arial' => {
            normal: 'C:/Windows/Fonts/Arial.ttf',
            bold: 'C:/Windows/Fonts/Arialbd.ttf',
            italic: 'C:/Windows/Fonts/Ariali.ttf',
            bold_italic: 'C:/Windows/Fonts/Arialbi.ttf'
          })
          pdf.font 'Arial'
        else
          pdf.font 'Helvetica'
        end
      rescue => e
        puts "WARNING: Could not load font: #{e.message}"
        pdf.font 'Helvetica'
      end
    end
    
    # Get next section number
    def next_section_number
      @section_counter += 1
      @section_counter
    end
    
    # Add TOC entry
    def add_toc_entry(title, page_number, level = 1)
      @toc_entries << { title: title, page: page_number, level: level }
    end
    
    # Render all PDF content
    def render_pdf_content(pdf)
      puts "\nDEBUG: RENDERING PDF CONTENT (REDESIGNED)..."
      
      # 1. Cover Page
      render_cover_page(pdf)
      
      # 2. Table of Contents (placeholder - will be filled after)
      pdf.start_new_page
      toc_page = pdf.page_number
      
      # 3. Project Summary
      pdf.start_new_page
      add_toc_entry("#{next_section_number}. Project Summary", pdf.page_number)
      render_project_summary(pdf)
      
      # 4. Materials & Inventory
      if has_materials_data?
        check_page_break(pdf, 200)
        add_toc_entry("#{next_section_number}. Materials & Inventory", pdf.page_number)
        render_materials_inventory(pdf)
      end
      
      # 5. Part Types
      if has_parts_data?
        check_page_break(pdf, 200)
        add_toc_entry("#{next_section_number}. Part Types", pdf.page_number)
        render_part_types(pdf)
      end
      
      # 6. Sheet Layout Plans
      if has_diagrams_data?
        pdf.start_new_page
        add_toc_entry("#{next_section_number}. Sheet Layout Plans", pdf.page_number)
        render_sheet_layouts(pdf)
      end
      
      # 7. Cutting Instructions
      if has_cut_sequences?
        pdf.start_new_page
        add_toc_entry("#{next_section_number}. Cutting Instructions", pdf.page_number)
        render_cutting_instructions(pdf)
      end
      
      # 8. Assembly Views
      if has_assembly_data?
        pdf.start_new_page
        add_toc_entry("#{next_section_number}. Assembly Views", pdf.page_number)
        render_assembly_views(pdf)
      end
      
      # 9. Detailed Cut List
      if has_parts_data?
        pdf.start_new_page
        add_toc_entry("#{next_section_number}. Detailed Cut List", pdf.page_number)
        render_detailed_cut_list(pdf)
      end
      
      # 10. Part Labels (QR Codes)
      if has_parts_data?
        pdf.start_new_page
        add_toc_entry("#{next_section_number}. Part Labels", pdf.page_number)
        render_part_labels(pdf)
      end
      
      # 11. Cost Analysis
      if has_materials_data?
        pdf.start_new_page
        add_toc_entry("#{next_section_number}. Cost Analysis", pdf.page_number)
        render_cost_analysis(pdf)
      end
      
      # Now render TOC
      pdf.go_to_page(toc_page)
      render_table_of_contents(pdf)
      
      puts "DEBUG: PDF CONTENT RENDERING COMPLETE"
    end
    
    # Check if page break is needed
    def check_page_break(pdf, required_space)
      if pdf.cursor < required_space
        pdf.start_new_page
      end
    end
    
    # Data availability checks
    def has_materials_data?
      @report_data[:unique_board_types] && @report_data[:unique_board_types].length > 0
    end
    
    def has_parts_data?
      @report_data[:parts_placed] && @report_data[:parts_placed].length > 0
    end
    
    def has_diagrams_data?
      @diagrams_data && @diagrams_data.length > 0
    end
    
    def has_cut_sequences?
      @report_data[:cut_sequences] && @report_data[:cut_sequences].length > 0
    end
    
    def has_assembly_data?
      @assembly_data && @assembly_data[:views] && @assembly_data[:views].length > 0
    end
    
    # ===== COVER PAGE =====
    def render_cover_page(pdf)
      pdf.move_down 120
      
      # Title
      pdf.font_size(FONT_SIZE_H1) do
        pdf.text "Manufacturing Report", align: :center, style: :bold, color: COLOR_TEXT_MAIN
      end
      
      pdf.move_down 20
      
      # Subtitle
      pdf.font_size(FONT_SIZE_H3) do
        pdf.text "Cut List & Nesting Analysis", align: :center, color: COLOR_TEXT_SECONDARY
      end
      
      pdf.move_down 80
      
      # Thin separator line
      pdf.stroke_color COLOR_BORDER
      pdf.stroke do
        pdf.horizontal_line 150, pdf.bounds.width - 150, at: pdf.cursor
      end
      
      pdf.move_down 60
      
      # Key metrics in clean grid
      summary = @report_data[:summary] || {}
      
      metrics = [
        ["Total Parts", summary[:total_parts_instances] || 0],
        ["Sheets Required", summary[:total_boards] || 0],
        ["Material Efficiency", "#{(summary[:overall_efficiency] || 0).round(1)}%"],
        ["Total Cost", "#{summary[:currency] || 'USD'} #{(summary[:total_project_cost] || 0).round(2)}"]
      ]
      
      metrics.each_slice(2) do |row|
        pdf.indent(80) do
          row.each_with_index do |(label, value), idx|
            x_offset = idx * 200
            pdf.bounding_box([x_offset, pdf.cursor], width: 180, height: 60) do
              pdf.font_size(FONT_SIZE_SMALL) do
                pdf.text label, color: COLOR_TEXT_SECONDARY
              end
              pdf.move_down 8
              pdf.font_size(FONT_SIZE_H2) do
                pdf.text value.to_s, style: :bold, color: COLOR_TEXT_MAIN
              end
            end
          end
        end
        pdf.move_down 70
      end
      
      # Footer
      pdf.move_down 100
      pdf.font_size(FONT_SIZE_SMALL) do
        pdf.text "Generated on #{Time.now.strftime('%B %d, %Y at %H:%M')}", 
          align: :center, color: COLOR_TEXT_SECONDARY
        pdf.move_down 5
        pdf.text "AutoNestCut Professional", 
          align: :center, color: COLOR_TEXT_SECONDARY, style: :italic
      end
    end
    
    # ===== TABLE OF CONTENTS =====
    def render_table_of_contents(pdf)
      pdf.move_down 40
      
      pdf.font_size(FONT_SIZE_H2) do
        pdf.text "Table of Contents", style: :bold, color: COLOR_TEXT_MAIN
      end
      
      pdf.move_down 30
      
      @toc_entries.each do |entry|
        indent_amount = (entry[:level] - 1) * 20
        
        pdf.indent(indent_amount) do
          y_position = pdf.cursor
          
          # Title on left
          pdf.text entry[:title], size: FONT_SIZE_BODY, color: COLOR_TEXT_MAIN, inline_format: true
          
          # Page number on right
          page_text = entry[:page].to_s
          page_width = pdf.width_of(page_text, size: FONT_SIZE_BODY)
          pdf.draw_text page_text, at: [pdf.bounds.width - page_width - indent_amount, y_position], 
            size: FONT_SIZE_BODY, style: :bold, color: COLOR_TEXT_SECONDARY
          
          pdf.move_down 18
        end
      end
    end
    
    # ===== SECTION HEADER =====
    def render_section_header(pdf, section_number, title)
      pdf.move_down 30
      
      # Section number in gray
      pdf.font_size(FONT_SIZE_SMALL) do
        pdf.text "SECTION #{section_number}", color: COLOR_SECTION_NUMBER, style: :bold
      end
      
      pdf.move_down 8
      
      # Section title
      pdf.font_size(FONT_SIZE_H2) do
        pdf.text title, style: :bold, color: COLOR_TEXT_MAIN
      end
      
      pdf.move_down 5
      
      # Underline
      pdf.stroke_color COLOR_BORDER
      pdf.stroke do
        pdf.horizontal_line 0, 100, at: pdf.cursor
      end
      
      pdf.move_down 25
    end
    
    # ===== PROJECT SUMMARY =====
    def render_project_summary(pdf)
      render_section_header(pdf, @section_counter, "Project Summary")
      
      summary = @report_data[:summary] || {}
      
      data = [
        ["Total Part Instances", (summary[:total_parts_instances] || 0).to_s],
        ["Unique Part Types", (summary[:total_unique_part_types] || 0).to_s],
        ["Sheets Required", (summary[:total_boards] || 0).to_s],
        ["Material Efficiency", "#{(summary[:overall_efficiency] || 0).round(1)}%"],
        ["Total Waste", summary[:total_waste_area_absolute] || 'N/A'],
        ["Total Weight", "#{(summary[:total_project_weight_kg] || 0).round(2)} kg"],
        ["Total Cost", "#{summary[:currency] || 'USD'} #{(summary[:total_project_cost] || 0).round(2)}"]
      ]
      
      render_clean_table(pdf, [["Metric", "Value"]] + data)
    end
    
    # ===== MATERIALS & INVENTORY =====
    def render_materials_inventory(pdf)
      render_section_header(pdf, @section_counter, "Materials & Inventory")
      
      table_data = [["Material", "Dimensions", "Qty", "Area (m²)", "Unit Price", "Total Cost"]]
      
      @report_data[:unique_board_types].each do |board|
        width = board[:stock_width] || 2440
        height = board[:stock_height] || 1220
        
        table_data << [
          board[:material] || '',
          "#{width.round(0)} × #{height.round(0)} mm",
          board[:count].to_s,
          ((board[:total_area] || 0) / 1000000).round(2).to_s,
          "#{board[:currency] || 'USD'} #{(board[:price_per_sheet] || 0).round(2)}",
          "#{board[:currency] || 'USD'} #{(board[:total_cost] || 0).round(2)}"
        ]
      end
      
      render_clean_table(pdf, table_data)
    end
    
    # ===== PART TYPES =====
    def render_part_types(pdf)
      render_section_header(pdf, @section_counter, "Part Types")
      
      table_data = [["Name", "Dimensions (mm)", "Material", "Qty", "Area (m²)"]]
      
      @report_data[:unique_part_types].each do |part|
        w = (part[:width] || 0).round(1)
        h = (part[:height] || 0).round(1)
        t = (part[:thickness] || 0).round(1)
        
        table_data << [
          part[:name] || '',
          "#{w} × #{h} × #{t}",
          part[:material] || '',
          (part[:total_quantity] || 0).to_s,
          ((part[:total_area] || 0) / 1000000).round(3).to_s
        ]
      end
      
      render_clean_table(pdf, table_data)
    end
    
    # ===== SHEET LAYOUTS =====
    def render_sheet_layouts(pdf)
      render_section_header(pdf, @section_counter, "Sheet Layout Plans")
      
      @diagrams_data.each_with_index do |board, idx|
        if idx > 0
          pdf.start_new_page
        end
        
        # Board title
        pdf.font_size(FONT_SIZE_H3) do
          pdf.text "Sheet #{idx + 1}: #{board[:material] || 'Unknown'}", 
            style: :bold, color: COLOR_TEXT_MAIN
        end
        
        pdf.move_down 10
        
        # Board specs
        width = board[:stock_width] || 2440
        height = board[:stock_height] || 1220
        efficiency = (board[:efficiency_percentage] || 0).round(1)
        parts_count = board[:parts_count] || 0
        
        pdf.font_size(FONT_SIZE_SMALL) do
          pdf.text "Size: #{width.round(0)} × #{height.round(0)} mm  |  " +
                   "Parts: #{parts_count}  |  " +
                   "Efficiency: #{efficiency}%", 
            color: COLOR_TEXT_SECONDARY
        end
        
        pdf.move_down 20
        
        # Diagram image
        diagram_img = @diagram_images.find { |img| (img[:index] || img['index']) == idx }
        if diagram_img && (diagram_img[:image] || diagram_img['image'])
          embed_diagram_image(pdf, diagram_img[:image] || diagram_img['image'], idx)
        else
          pdf.text "Diagram not available", color: COLOR_TEXT_SECONDARY, style: :italic
        end
      end
    end
    
    # ===== CUTTING INSTRUCTIONS =====
    def render_cutting_instructions(pdf)
      render_section_header(pdf, @section_counter, "Cutting Instructions")
      
      @report_data[:cut_sequences].each_with_index do |sequence, idx|
        check_page_break(pdf, 150)
        
        # Sheet title
        pdf.font_size(FONT_SIZE_H3) do
          pdf.text "Sheet #{sequence[:board_number] || idx + 1}: #{sequence[:material] || 'Unknown'}", 
            style: :bold, color: COLOR_TEXT_MAIN
        end
        
        pdf.move_down 5
        pdf.font_size(FONT_SIZE_SMALL) do
          pdf.text "Stock Size: #{sequence[:stock_size] || sequence[:stock_dimensions] || 'N/A'}", 
            color: COLOR_TEXT_SECONDARY
        end
        
        pdf.move_down 15
        
        # Steps table
        steps = sequence[:steps] || sequence[:cut_sequence] || []
        if steps.length > 0
          table_data = [["Step", "Operation", "Description", "Measurement"]]
          
          steps.each do |step|
            table_data << [
              step[:step].to_s,
              step[:operation] || step[:type] || '',
              step[:description] || '',
              step[:measurement] || ''
            ]
          end
          
          render_clean_table(pdf, table_data)
        else
          pdf.text "No cutting steps available", color: COLOR_TEXT_SECONDARY, style: :italic
        end
        
        pdf.move_down 20
      end
    end
    
    # ===== ASSEMBLY VIEWS =====
    def render_assembly_views(pdf)
      render_section_header(pdf, @section_counter, "Assembly Views")
      
      views = @assembly_data[:views] || {}
      entity_name = @assembly_data[:entity_name] || "Assembly"
      
      views.each_with_index do |(view_name, view_image), idx|
        if idx > 0
          pdf.start_new_page
        end
        
        # Professional view title
        view_title = format_view_title(view_name, entity_name)
        
        pdf.font_size(FONT_SIZE_H3) do
          pdf.text view_title, style: :bold, color: COLOR_TEXT_MAIN
        end
        
        pdf.move_down 5
        pdf.font_size(FONT_SIZE_SMALL) do
          pdf.text "Orthographic Projection", color: COLOR_TEXT_SECONDARY
        end
        
        pdf.move_down 20
        
        # Image with border
        embed_assembly_image(pdf, view_image)
      end
    end
    
    # Format view title professionally
    def format_view_title(view_name, entity_name)
      view_name_str = view_name.to_s
      
      # Map basic view names to professional titles
      view_mapping = {
        'front' => 'Front Elevation',
        'back' => 'Rear Elevation',
        'left' => 'Left Side Elevation',
        'right' => 'Right Side Elevation',
        'top' => 'Top View (Plan)',
        'bottom' => 'Bottom View',
        'iso' => 'Isometric View',
        'perspective' => 'Perspective View'
      }
      
      formatted = view_mapping[view_name_str.downcase] || view_name_str.capitalize
      
      "#{entity_name} - #{formatted}"
    end
    
    # ===== DETAILED CUT LIST =====
    def render_detailed_cut_list(pdf)
      render_section_header(pdf, @section_counter, "Detailed Cut List")
      
      # FIXED: Added Board#, Cost, and Level columns to match UI
      # FIXED: Using instance_id (P1, P2, etc.) instead of part_unique_id (entity IDs)
      table_data = [["ID", "Name", "Dimensions", "Material", "Grain", "Edge Band", "Board#", "Cost", "Level"]]
      
      # Calculate costs for level categorization
      costs = []
      @report_data[:parts_placed].each do |part|
        w = (part[:width] || 0) / 1000.0  # Convert to meters
        h = (part[:height] || 0) / 1000.0
        area_m2 = w * h
        
        # Find material price
        material_name = part[:material] || ''
        board_type = @report_data[:unique_board_types]&.find { |bt| bt[:material] == material_name }
        price_per_sheet = board_type ? (board_type[:price_per_sheet] || 0) : 0
        stock_area_m2 = board_type ? ((board_type[:stock_width] || 2440) * (board_type[:stock_height] || 1220) / 1_000_000.0) : 3.0
        
        part_cost = stock_area_m2 > 0 ? (area_m2 / stock_area_m2) * price_per_sheet : 0
        costs << part_cost if part_cost > 0
      end
      
      # Calculate cost levels (low/avg/high)
      avg_cost = costs.length > 0 ? costs.sum / costs.length : 0
      low_threshold = avg_cost * 0.7
      high_threshold = avg_cost * 1.3
      
      currency = @report_data[:summary]&.[](:currency) || 'USD'
      
      @report_data[:parts_placed].each_with_index do |part, idx|
        # FIXED: Use instance_id (P1, P2, etc.) instead of part_unique_id
        part_id = part[:instance_id] || "P#{idx + 1}"
        w = (part[:width] || 0).round(1)
        h = (part[:height] || 0).round(1)
        
        # Calculate part cost
        area_m2 = (w / 1000.0) * (h / 1000.0)
        material_name = part[:material] || ''
        board_type = @report_data[:unique_board_types]&.find { |bt| bt[:material] == material_name }
        price_per_sheet = board_type ? (board_type[:price_per_sheet] || 0) : 0
        stock_area_m2 = board_type ? ((board_type[:stock_width] || 2440) * (board_type[:stock_height] || 1220) / 1_000_000.0) : 3.0
        part_cost = stock_area_m2 > 0 ? (area_m2 / stock_area_m2) * price_per_sheet : 0
        
        # Determine cost level
        cost_level = if part_cost <= low_threshold
          'Budget'
        elsif part_cost >= high_threshold
          'Premium'
        else
          'Standard'
        end
        
        edge_band = part[:edge_banding]
        if edge_band.is_a?(Hash)
          edge_band = edge_band[:type] || edge_band['type'] || 'None'
        else
          edge_band = edge_band || 'None'
        end
        
        table_data << [
          part_id,
          part[:name] || '',
          "#{w}×#{h}",  # Removed space to save width
          part[:material] || '',
          part[:grain_direction] || 'Any',
          edge_band,
          part[:board_number].to_s,
          "#{currency} #{part_cost.round(2)}",
          cost_level
        ]
      end
      
      render_clean_table(pdf, table_data)
    end
    
    # ===== PART LABELS =====
    def render_part_labels(pdf)
      render_section_header(pdf, @section_counter, "Part Labels")
      
      pdf.font_size(FONT_SIZE_BODY) do
        pdf.text "QR code labels for each part. Scan with any QR code reader to view part details.", 
          color: COLOR_TEXT_SECONDARY
      end
      
      pdf.move_down 30
      
      # FIXED: Modern industrial label format - 3x3 grid = 9 labels per page (not 12)
      label_width_mm = 65
      label_height_mm = 65  # Square format for modern design
      cols = 3
      rows = 3  # FIXED: Changed from 4 to 3 rows = 9 labels per page max
      spacing_h_mm = 5
      spacing_v_mm = 8
      
      # Calculate total width needed for labels
      total_width_needed_mm = (cols * label_width_mm) + ((cols - 1) * spacing_h_mm)
      
      # Get available width from PDF bounds (in points) and convert to mm
      available_width_pt = pdf.bounds.width
      available_width_mm = available_width_pt / 2.83465
      
      # Calculate left margin to center labels
      margin_left_mm = (available_width_mm - total_width_needed_mm) / 2
      
      labels_per_page = cols * rows  # 9 labels per page
      
      # Starting Y position from current cursor
      start_y_pt = pdf.cursor
      
      # Generate labels from unique part types
      part_counter = 1
      label_index = 0
      
      (@report_data[:unique_part_types] || []).each do |part_type|
        quantity = part_type[:total_quantity] || 1
        
        quantity.times do |i|
          # Start new page if needed (every 9 labels)
          if label_index > 0 && label_index % labels_per_page == 0
            pdf.start_new_page
            render_section_header(pdf, @section_counter, "Part Labels (continued)")
            pdf.move_down 20
            start_y_pt = pdf.cursor
          end
          
          # Calculate position on current page
          label_on_page = label_index % labels_per_page
          row = label_on_page / cols
          col = label_on_page % cols
          
          # Calculate position in mm
          x_mm = margin_left_mm + (col * (label_width_mm + spacing_h_mm))
          y_offset_mm = row * (label_height_mm + spacing_v_mm)
          
          # Convert to points
          x_pos = mm_to_pt(x_mm)
          y_pos = start_y_pt - mm_to_pt(y_offset_mm)
          
          # Render label at calculated position
          render_label(pdf, {
            part_id: "#{part_counter}",
            name: part_type[:name] || "Part",
            width: part_type[:width] || 0,
            height: part_type[:height] || 0,
            thickness: part_type[:thickness] || 0,
            material: part_type[:material] || "Unknown",
            board_number: 1  # Default board number for unique types
          }, x_pos, y_pos, label_width_mm, label_height_mm)
          
          part_counter += 1
          label_index += 1
        end
      end
      
      # Move cursor to bottom to prevent overlap
      last_row = ((label_index - 1) % labels_per_page) / cols
      pdf.move_cursor_to(start_y_pt - mm_to_pt((last_row + 1) * (label_height_mm + spacing_v_mm)) - 20)
    end
    
    # Render a single label with QR code - MODERN INDUSTRIAL DESIGN
    def render_label(pdf, part_data, x, y, width_mm, height_mm)
      width_pt = mm_to_pt(width_mm)
      height_pt = mm_to_pt(height_mm)
      
      # Layout Calculations
      top_h = height_pt * 0.32
      left_w = width_pt * 0.38
      metal_size = top_h
      
      pdf.line_width LABEL_BORDER_WIDTH
      
      # === 1. BACKGROUND ZONES ===
      
      # Top Banner (White)
      pdf.fill_color 'FFFFFF'
      pdf.fill_rectangle [x, y], width_pt, top_h
      
      # Left Column (Orange)
      pdf.fill_color COLOR_ORANGE
      pdf.fill_rectangle [x, y - top_h], left_w, (height_pt - top_h)
      
      # Right Column (White)
      pdf.fill_color 'FFFFFF'
      pdf.fill_rectangle [x + left_w, y - top_h], (width_pt - left_w), (height_pt - top_h)
      
      # === 2. DIAGONAL HATCHING (Top of Orange Section) ===
      pdf.stroke_color '000000'
      pdf.line_width 0.5
      hatch_h = (height_pt - top_h) * 0.45
      
      # Draw diagonal lines
      (0..40).each do |i|
        offset = i * 3
        x1 = x
        y1 = y - top_h - offset
        x2 = x + offset
        y2 = y - top_h
        
        # Only draw if within bounds
        if x2 <= x + left_w && y1 >= y - top_h - hatch_h
          pdf.stroke_line [x1, y1], [x2, y2]
        end
      end
      
      # === 3. METALLIC CORNER (Gradient Effect) ===
      # Create gradient effect with overlapping rectangles
      pdf.fill_color 'FFFFFF'
      pdf.fill_rectangle [x + width_pt - metal_size, y], metal_size, metal_size
      
      pdf.fill_color COLOR_METAL
      pdf.fill_rectangle [x + width_pt - metal_size + 5, y - 5], metal_size - 10, metal_size - 10
      
      pdf.fill_color 'A0A0A0'
      pdf.fill_rectangle [x + width_pt - metal_size + 10, y - 10], metal_size - 20, metal_size - 20
      
      # === 4. DIVIDING LINES ===
      pdf.stroke_color '000000'
      pdf.line_width LABEL_BORDER_WIDTH
      
      # Horizontal divider
      pdf.stroke_horizontal_line x, x + width_pt, at: y - top_h
      
      # Vertical divider (orange/white)
      pdf.stroke_vertical_line y - top_h, y - height_pt, at: x + left_w
      
      # Vertical divider (banner/metal)
      pdf.stroke_vertical_line y, y - top_h, at: x + width_pt - metal_size
      
      # Outer border
      pdf.stroke_rectangle [x, y], width_pt, height_pt
      
      # === 5. TEXT CONTENT ===
      
      # Extract data
      part_id = (part_data[:part_id] || "N/A").to_s
      board = part_data[:board_number] || 1
      w_dim = (part_data[:width] || 0).to_f.round(1)
      h_dim = (part_data[:height] || 0).to_f.round(1)
      t_dim = (part_data[:thickness] || 0).to_f.round(1)
      
      # Format dimensions with .0 for whole numbers
      w_str = (w_dim % 1 == 0 ? "#{w_dim.to_i}.0" : w_dim.to_s)
      h_str = (h_dim % 1 == 0 ? "#{h_dim.to_i}.0" : h_dim.to_s)
      t_str = (t_dim % 1 == 0 ? "#{t_dim.to_i}.0" : t_dim.to_s)
      
      # Header - "Part 4" (FIXED: removed underscore)
      pdf.fill_color '000000'
      pdf.font_size(top_h * 0.4) do
        pdf.draw_text "Part #{part_id}", 
          at: [x + 5, y - (top_h/2) + 6], 
          style: :bold
      end
      
      # Right Column - Dimensions
      dim_x = x + left_w + 5
      dim_y = y - top_h - 10
      
      pdf.font_size(7) do
        pdf.fill_color '888888'
        pdf.draw_text "Dimensions (mm)", at: [dim_x, dim_y]
      end
      
      # Large dimension values with labels
      pdf.font_size(5) do
        pdf.fill_color '888888'
        # W label
        pdf.draw_text "W", at: [dim_x, dim_y - 15], style: :bold
        # H label
        pdf.draw_text "H", at: [dim_x, dim_y - 27], style: :bold
        # TH label
        pdf.draw_text "TH", at: [dim_x, dim_y - 39], style: :bold
      end
      
      pdf.font_size(11) do
        pdf.fill_color '000000'
        # Width value
        pdf.draw_text w_str, at: [dim_x + 12, dim_y - 15], style: :bold
        # Height value
        pdf.draw_text h_str, at: [dim_x + 12, dim_y - 27], style: :bold
        # Thickness value
        pdf.draw_text t_str, at: [dim_x + 12, dim_y - 39], style: :bold
      end
      
      # Footer section - FIXED: Line positioned above text to avoid overlap
      footer_text_y = y - height_pt + 12
      footer_line_y = footer_text_y + 8  # Line is 8pt above the text
      
      # Footer line (positioned ABOVE the text)
      pdf.stroke_color '000000'
      pdf.line_width 0.5
      pdf.stroke_horizontal_line dim_x, x + width_pt - 5, at: footer_line_y
      
      # Footer text (below the line)
      pdf.font_size(7) do
        pdf.fill_color '000000'
        pdf.draw_text "ID: P#{part_id}", at: [dim_x, footer_text_y], style: :bold
        
        # Board number (right aligned)
        board_text = "B##{board}"
        board_width = pdf.width_of(board_text, size: 7, style: :bold)
        pdf.draw_text board_text, 
          at: [x + width_pt - 5 - board_width, footer_text_y], 
          style: :bold
      end
      
      # === 6. QR CODE (In solid orange area) ===
      qr_data = format_qr_data(part_data)
      
      begin
        require 'rqrcode'
        qrcode = RQRCode::QRCode.new(qr_data, level: :l)
        
        # QR code size and position
        qr_size = left_w * 0.7
        qr_x = x + (left_w - qr_size) / 2
        
        # Center vertically in solid orange section (below hatching)
        qr_available_height = (height_pt - top_h) - hatch_h
        qr_y = y - top_h - hatch_h - (qr_available_height - qr_size) / 2
        
        # Draw QR code
        render_qr_code(pdf, qrcode, qr_x, qr_y, qr_size)
        
      rescue LoadError
        pdf.font_size(8) do
          pdf.fill_color '000000'
          pdf.draw_text "QR N/A", at: [x + left_w/2 - 10, y - height_pt/2], style: :bold
        end
      rescue => e
        puts "WARNING: Could not generate QR code for part #{part_id}: #{e.message}"
        pdf.font_size(8) do
          pdf.fill_color 'FF0000'
          pdf.draw_text "QR Error", at: [x + left_w/2 - 15, y - height_pt/2], style: :bold
        end
      end
    end
    
    # Render QR code as squares
    def render_qr_code(pdf, qrcode, x, y, size_pt)
      modules = qrcode.modules
      module_count = modules.size
      module_size = size_pt / module_count
      
      pdf.fill_color '000000'
      
      modules.each_with_index do |row, row_idx|
        row.each_with_index do |cell, col_idx|
          if cell
            module_x = x + (col_idx * module_size)
            module_y = y - (row_idx * module_size)
            pdf.fill_rectangle [module_x, module_y], module_size, module_size
          end
        end
      end
      
      pdf.fill_color '000000'  # Reset fill color
    end
    
    # Format QR data
    def format_qr_data(part_data)
      qr_text = "PART: #{part_data[:part_id]}\n"
      qr_text += "NAME: #{part_data[:name]}\n"
      qr_text += "SIZE: #{part_data[:width].round(1)} x #{part_data[:height].round(1)} x #{part_data[:thickness].round(1)}mm\n"
      qr_text += "MATERIAL: #{part_data[:material]}"
      qr_text
    end
    
    # Convert mm to points (1mm = 2.83465pt)
    def mm_to_pt(mm)
      mm * 2.83465
    end
    
    # ===== COST ANALYSIS =====
    def render_cost_analysis(pdf)
      render_section_header(pdf, @section_counter, "Cost Analysis")
      
      table_data = [["Material", "Sheets", "Unit Cost", "Total Cost"]]
      
      @report_data[:unique_board_types].each do |board|
        table_data << [
          board[:material] || '',
          board[:count].to_s,
          "#{board[:currency] || 'USD'} #{(board[:price_per_sheet] || 0).round(2)}",
          "#{board[:currency] || 'USD'} #{(board[:total_cost] || 0).round(2)}"
        ]
      end
      
      render_clean_table(pdf, table_data)
      
      # Total
      summary = @report_data[:summary] || {}
      pdf.move_down 20
      pdf.font_size(FONT_SIZE_H3) do
        pdf.text "Total Project Cost: #{summary[:currency] || 'USD'} #{(summary[:total_project_cost] || 0).round(2)}", 
          style: :bold, color: COLOR_TEXT_MAIN, align: :right
      end
    end
    
    # ===== CLEAN TABLE RENDERER =====
    def render_clean_table(pdf, data)
      return if data.nil? || data.empty?
      
      # Calculate optimal column widths based on content
      col_widths = calculate_column_widths(pdf, data)
      
      # Render header
      render_table_header(pdf, data.first, col_widths)
      
      # Render data rows
      data[1..-1].each_with_index do |row, row_idx|
        # Check if we need a new page
        if pdf.cursor < 50
          pdf.start_new_page
          render_table_header(pdf, data.first, col_widths)
        end
        
        render_table_row(pdf, row, col_widths, row_idx)
      end
      
      pdf.move_down 15
    end
    
    # Calculate optimal column widths based on content
    def calculate_column_widths(pdf, data)
      return [] if data.nil? || data.empty?
      
      num_cols = data.first.length
      max_widths = Array.new(num_cols, 0)
      
      # Find maximum width needed for each column
      data.each do |row|
        row.each_with_index do |cell, col_idx|
          text = cell.to_s
          # Measure text width with padding (20pt padding + 10pt safety margin)
          text_width = pdf.width_of(text, size: FONT_SIZE_SMALL) + 30
          max_widths[col_idx] = [max_widths[col_idx], text_width].max
        end
      end
      
      # Calculate total width needed
      total_needed = max_widths.sum
      available_width = pdf.bounds.width
      
      # If total needed is less than available, use actual widths
      if total_needed <= available_width
        return max_widths
      end
      
      # FIXED: Optimize column widths for tables with many columns
      # Identify column types: ID, short text, medium text, long text
      col_widths = Array.new(num_cols, 0)
      
      # Define minimum and maximum widths for different column types
      min_id_width = 40      # For ID columns (P1, P2, etc.)
      min_short_width = 50   # For Board#, Grain, etc.
      min_medium_width = 70  # For Cost, Level, Edge Band
      min_long_width = 90    # For Name, Material, Dimensions
      
      # Categorize columns based on header names (first row)
      headers = data.first
      short_cols = []
      medium_cols = []
      long_cols = []
      id_cols = []
      
      headers.each_with_index do |header, idx|
        header_str = header.to_s.downcase
        if header_str == 'id'
          id_cols << idx
        elsif ['board#', 'sheet', 'grain', 'qty', 'count'].include?(header_str)
          short_cols << idx
        elsif ['cost', 'level', 'edge band', 'edge banding', 'price/sheet'].include?(header_str)
          medium_cols << idx
        else
          long_cols << idx
        end
      end
      
      # Allocate fixed widths to ID and short columns
      reserved_width = (id_cols.length * min_id_width) + 
                       (short_cols.length * min_short_width) + 
                       (medium_cols.length * min_medium_width)
      remaining_width = available_width - reserved_width
      
      # Distribute remaining width to long columns
      long_cols_total = long_cols.sum { |idx| max_widths[idx] }
      
      max_widths.each_with_index do |width, idx|
        if id_cols.include?(idx)
          col_widths[idx] = [width, min_id_width].min.clamp(min_id_width, min_id_width + 10)
        elsif short_cols.include?(idx)
          col_widths[idx] = [width, min_short_width].min.clamp(min_short_width, min_short_width + 15)
        elsif medium_cols.include?(idx)
          col_widths[idx] = [width, min_medium_width].min.clamp(min_medium_width, min_medium_width + 20)
        else
          # Long columns get proportional share of remaining width
          if long_cols_total > 0 && remaining_width > 0
            proportion = width.to_f / long_cols_total
            col_widths[idx] = [remaining_width * proportion, min_long_width].max
          else
            col_widths[idx] = min_long_width
          end
        end
      end
      
      # Final adjustment: if still too wide, scale down proportionally
      total_width = col_widths.sum
      if total_width > available_width
        scale_factor = available_width / total_width
        col_widths.map! { |w| w * scale_factor }
      end
      
      col_widths
    end
    
    def render_table_header(pdf, header, col_widths)
      y_position = pdf.cursor
      
      # Header background
      pdf.fill_color 'F3F4F6'
      pdf.fill_rectangle [0, y_position], pdf.bounds.width, 28
      pdf.fill_color '000000'
      
      # Header text
      x_offset = 0
      header.each_with_index do |cell, i|
        text = truncate_text(pdf, cell.to_s, col_widths[i] - 20, FONT_SIZE_SMALL)
        pdf.draw_text text, 
          at: [x_offset + 10, y_position - 17], 
          size: FONT_SIZE_SMALL, 
          style: :bold,
          color: COLOR_TEXT_SECONDARY
        x_offset += col_widths[i]
      end
      
      pdf.move_down 28
      
      # Header border
      pdf.stroke_color COLOR_BORDER
      pdf.line_width 1
      pdf.stroke_horizontal_rule
      pdf.move_down 2
    end
    
    def render_table_row(pdf, row, col_widths, row_idx)
      y_pos = pdf.cursor
      
      # Alternating background
      if row_idx.even?
        pdf.fill_color 'F9FAFB'
        pdf.fill_rectangle [0, y_pos], pdf.bounds.width, 22
        pdf.fill_color '000000'
      end
      
      # Row text
      x_offset = 0
      row.each_with_index do |cell, col_idx|
        text = truncate_text(pdf, cell.to_s, col_widths[col_idx] - 20, FONT_SIZE_SMALL)
        pdf.draw_text text, 
          at: [x_offset + 10, y_pos - 14], 
          size: FONT_SIZE_SMALL,
          color: COLOR_TEXT_MAIN
        x_offset += col_widths[col_idx]
      end
      
      pdf.move_down 22
      
      # Row border
      pdf.stroke_color COLOR_BORDER
      pdf.line_width 0.5
      pdf.stroke_horizontal_rule
      pdf.move_down 2
    end
    
    def truncate_text(pdf, text, max_width, font_size)
      return text if pdf.width_of(text, size: font_size) <= max_width
      
      truncated = text
      while pdf.width_of(truncated + '...', size: font_size) > max_width && truncated.length > 3
        truncated = truncated[0..-2]
      end
      truncated + '...'
    end
    
    # ===== EMBED DIAGRAM IMAGE =====
    def embed_diagram_image(pdf, image_data, index)
      begin
        if image_data.is_a?(String) && image_data.start_with?('data:image')
          base64_data = image_data.sub(/^data:image\/[^;]+;base64,/, '')
          decoded_image = Base64.decode64(base64_data)
          
          temp_file = File.join(Dir.tmpdir, "diagram_#{index}_#{Time.now.to_i}.png")
          File.binwrite(temp_file, decoded_image)
          
          available_height = pdf.cursor - 60
          
          # Image with border
          pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width, height: available_height) do
            pdf.image temp_file, 
              fit: [pdf.bounds.width - 4, available_height - 4], 
              position: :center, 
              vposition: :center
            pdf.stroke_bounds
          end
          
          File.delete(temp_file) if File.exist?(temp_file)
        end
      rescue => e
        puts "WARNING: Could not embed diagram: #{e.message}"
        pdf.text "Diagram unavailable", color: COLOR_TEXT_SECONDARY, style: :italic
      end
    end
    
    # ===== EMBED ASSEMBLY IMAGE =====
    def embed_assembly_image(pdf, view_image)
      begin
        if view_image.is_a?(String) && view_image.start_with?('data:image')
          base64_data = view_image.sub(/^data:image\/[^;]+;base64,/, '')
          decoded_image = Base64.decode64(base64_data)
          
          temp_file = File.join(Dir.tmpdir, "assembly_#{Time.now.to_i}.png")
          File.binwrite(temp_file, decoded_image)
          
          available_height = pdf.cursor - 60
          
          # Image with border
          pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width, height: available_height) do
            pdf.image temp_file, 
              fit: [pdf.bounds.width - 4, available_height - 4], 
              position: :center, 
              vposition: :center
            pdf.stroke_bounds
          end
          
          File.delete(temp_file) if File.exist?(temp_file)
        elsif File.exist?(view_image)
          available_height = pdf.cursor - 60
          
          pdf.bounding_box([0, pdf.cursor], width: pdf.bounds.width, height: available_height) do
            pdf.image view_image, 
              fit: [pdf.bounds.width - 4, available_height - 4], 
              position: :center, 
              vposition: :center
            pdf.stroke_bounds
          end
        end
      rescue => e
        puts "WARNING: Could not embed assembly view: #{e.message}"
        pdf.text "Image unavailable", color: COLOR_TEXT_SECONDARY, style: :italic
      end
    end
    
    # ===== PAGE NUMBERS =====
    def add_page_numbers(pdf)
      pdf.number_pages "Page <page> of <total>", 
        at: [pdf.bounds.right - 100, 0],
        align: :right,
        size: FONT_SIZE_SMALL,
        color: COLOR_TEXT_SECONDARY,
        start_count_at: 2  # Skip cover page
    end
    
    # ===== HELPER METHODS =====
    def generate_default_pdf_path
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      filename = "AutoNestCut_Report_#{timestamp}.pdf"
      File.join(Dir.tmpdir, filename)
    end
    
    def show_preview_dialog(pdf_path)
      dialog = UI::HtmlDialog.new(
        {
          :dialog_title => "Report PDF Preview",
          :preferences_key => "com.autonestcut.report_preview",
          :scrollable => false,
          :resizable => true,
          :width => 1400,
          :height => 900,
          :left => 50,
          :top => 50,
          :min_width => 800,
          :min_height => 600,
          :style => UI::HtmlDialog::STYLE_DIALOG
        }
      )
      
      # Convert PDF path to file:// URL for embedding
      pdf_url = "file:///" + pdf_path.gsub("\\", "/")
      
      # Count pages (estimate based on data)
      page_count = estimate_page_count
      
      html_content = generate_report_preview_html(pdf_url, page_count)
      
      dialog.set_html(html_content)
      
      # Add callback for export button
      dialog.add_action_callback("export_report") do |action_context|
        # Ask user where to save
        save_path = UI.savepanel("Save Report PDF", "", "AutoNestCut_Report.pdf")
        if save_path
          begin
            # Copy temp file to chosen location
            require 'fileutils'
            FileUtils.cp(pdf_path, save_path)
            UI.messagebox("Report PDF exported successfully to:\n#{save_path}")
            dialog.close
            # Open the saved PDF
            UI.openURL("file:///#{save_path}")
          rescue => e
            UI.messagebox("Error exporting report: #{e.message}")
          end
        end
      end
      
      # Add callback for cancel button
      dialog.add_action_callback("cancel_export") do |action_context|
        dialog.close
      end
      
      dialog.show
    end
    
    def estimate_page_count
      # Estimate pages based on content
      pages = 1 # Cover page
      pages += 1 # TOC
      pages += 1 if @report_data && @report_data[:summary] # Summary page
      pages += (@report_data[:unique_board_types]&.length || 0) > 0 ? 1 : 0 # Materials page
      pages += (@report_data[:unique_part_types]&.length || 0) > 0 ? 1 : 0 # Parts page
      pages += (@diagrams_data&.length || 0) # Diagram pages (one per sheet)
      pages += (@report_data[:cut_sequences]&.length || 0) > 0 ? 1 : 0 # Cut sequences
      pages += (@assembly_data && @assembly_data[:views]&.length || 0) # Assembly pages (one per view)
      pages += (@report_data[:parts_placed]&.length || 0) > 0 ? 1 : 0 # Detailed cut list
      pages += (@report_data[:unique_board_types]&.length || 0) > 0 ? 1 : 0 # Cost analysis
      pages
    end
    
    def generate_report_preview_html(pdf_url, page_count)
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <title>Report PDF Preview</title>
          <style>
            * {
              margin: 0;
              padding: 0;
              box-sizing: border-box;
            }
            
            body {
              background: #2b2b2b;
              overflow: hidden;
              width: 100vw;
              height: 100vh;
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif;
            }
            
            .pdf-viewer {
              width: 100%;
              height: 100%;
            }
            
            .pdf-viewer embed {
              width: 100%;
              height: 100%;
              border: none;
            }
            
            .floating-actions {
              position: fixed;
              bottom: 30px;
              right: 30px;
              display: flex;
              gap: 12px;
              z-index: 1000;
            }
            
            .btn {
              padding: 14px 28px;
              font-size: 14px;
              font-weight: 600;
              border: none;
              border-radius: 8px;
              cursor: pointer;
              transition: all 0.2s ease;
              box-shadow: 0 4px 12px rgba(0,0,0,0.3);
              font-family: inherit;
              display: flex;
              align-items: center;
              gap: 8px;
            }
            
            .btn-export {
              background: #10B981;
              color: white;
            }
            
            .btn-export:hover {
              background: #059669;
              transform: translateY(-2px);
              box-shadow: 0 6px 16px rgba(16, 185, 129, 0.4);
            }
            
            .btn-cancel {
              background: #6B7280;
              color: white;
            }
            
            .btn-cancel:hover {
              background: #4B5563;
              transform: translateY(-2px);
              box-shadow: 0 6px 16px rgba(107, 114, 128, 0.4);
            }
            
            .info-bar {
              position: fixed;
              top: 0;
              left: 0;
              right: 0;
              background: rgba(31, 41, 55, 0.95);
              backdrop-filter: blur(10px);
              padding: 12px 24px;
              display: flex;
              justify-content: space-between;
              align-items: center;
              z-index: 999;
              border-bottom: 1px solid rgba(255, 255, 255, 0.1);
            }
            
            .info-bar-left {
              display: flex;
              align-items: center;
              gap: 16px;
            }
            
            .info-bar-title {
              color: white;
              font-size: 14px;
              font-weight: 600;
            }
            
            .info-bar-meta {
              color: #9CA3AF;
              font-size: 12px;
            }
            
            .pdf-viewer {
              padding-top: 48px;
              height: calc(100vh - 48px);
            }
          </style>
        </head>
        <body>
          <div class="info-bar">
            <div class="info-bar-left">
              <span class="info-bar-title">Manufacturing Report Preview</span>
              <span class="info-bar-meta">~#{page_count} pages</span>
            </div>
          </div>
          
          <div class="pdf-viewer">
            <embed src="#{pdf_url}" type="application/pdf">
          </div>
          
          <div class="floating-actions">
            <button class="btn btn-cancel" onclick="cancelExport()">
              <span>✕</span>
              <span>Close</span>
            </button>
            <button class="btn btn-export" onclick="exportReport()">
              <span>💾</span>
              <span>Export PDF</span>
            </button>
          </div>
          
          <script>
            function exportReport() {
              window.location = 'skp:export_report';
            }
            
            function cancelExport() {
              window.location = 'skp:cancel_export';
            }
          </script>
        </body>
        </html>
      HTML
    end
  end
end
