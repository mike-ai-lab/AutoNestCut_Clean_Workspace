# frozen_string_literal: true

require 'json'
require 'base64'

module AutoNestCut
  class PDFGenerator
    # Generates a professional PDF report with cutting diagrams and assembly views
    # Returns the PDF file path
    def self.generate_pdf_report(report_data, boards_data, assembly_data = nil, settings = {})
      begin
        # Validate required dependencies
        unless check_pdf_library_available
          raise "PDF generation library not available. Please install 'prawn' gem."
        end

        # Prepare report metadata
        project_name = settings['project_name'] || 'AutoNestCut Report'
        timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
        
        # Generate temporary PDF file
        temp_dir = Dir.tmpdir
        pdf_filename = "AutoNestCut_Report_#{Time.now.strftime('%Y%m%d_%H%M%S')}.pdf"
        pdf_path = File.join(temp_dir, pdf_filename)

        # Create PDF document
        create_pdf_document(pdf_path, report_data, boards_data, assembly_data, settings, timestamp)

        puts "PDF report generated successfully: #{pdf_path}"
        pdf_path
      rescue => e
        puts "ERROR generating PDF: #{e.message}"
        puts e.backtrace.join("\n")
        raise e
      end
    end

    # Generates HTML that can be printed to PDF using browser print functionality
    # This is more reliable than trying to use external PDF libraries
    def self.generate_printable_html(report_data, boards_data, assembly_data = nil, settings = {})
      begin
        project_name = settings['project_name'] || 'AutoNestCut Report'
        client_name = settings['client_name'] || ''
        prepared_by = settings['prepared_by'] || 'Int. Arch. M.Shkeir'
        timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
        
        currency = settings['default_currency'] || 'USD'
        units = settings['units'] || 'mm'
        area_units = settings['area_units'] || 'm2'
        
        # Generate HTML content
        html = generate_pdf_html_content(
          report_data,
          boards_data,
          assembly_data,
          project_name,
          client_name,
          prepared_by,
          timestamp,
          currency,
          units,
          area_units
        )

        html
      rescue => e
        puts "ERROR generating printable HTML: #{e.message}"
        puts e.backtrace.join("\n")
        raise e
      end
    end

    private

    def self.check_pdf_library_available
      begin
        require 'prawn'
        require 'prawn/table'
        true
      rescue LoadError
        false
      end
    end

    def self.create_pdf_document(pdf_path, report_data, boards_data, assembly_data, settings, timestamp)
      require 'prawn'
      require 'prawn/table'

      Prawn::Document.generate(pdf_path, page_size: 'A4', margin: [40, 40, 40, 40]) do |pdf|
        # Set default font
        pdf.font 'Helvetica'

        # ===== COVER PAGE =====
        add_cover_page(pdf, settings, timestamp)
        pdf.start_new_page

        # ===== TABLE OF CONTENTS =====
        add_table_of_contents(pdf, report_data, boards_data, assembly_data)
        pdf.start_new_page

        # ===== PROJECT SUMMARY =====
        add_project_summary(pdf, report_data, settings)
        pdf.start_new_page

        # ===== CUTTING DIAGRAMS =====
        if boards_data && !boards_data.empty?
          add_cutting_diagrams_section(pdf, boards_data, settings)
          pdf.start_new_page
        end

        # ===== ASSEMBLY VIEWS =====
        if assembly_data && assembly_data[:views] && !assembly_data[:views].empty?
          add_assembly_views_section(pdf, assembly_data)
          pdf.start_new_page
        end

        # ===== MATERIALS SUMMARY =====
        add_materials_summary(pdf, report_data, settings)
        pdf.start_new_page

        # ===== UNIQUE PARTS =====
        add_unique_parts_section(pdf, report_data, settings)
        pdf.start_new_page

        # ===== DETAILED CUT LIST =====
        add_detailed_cut_list(pdf, report_data, settings)
        pdf.start_new_page

        # ===== CUT SEQUENCES =====
        if report_data[:cut_sequences] && !report_data[:cut_sequences].empty?
          add_cut_sequences_section(pdf, report_data, settings)
          pdf.start_new_page
        end

        # ===== OFFCUTS =====
        if report_data[:usable_offcuts] && !report_data[:usable_offcuts].empty?
          add_offcuts_section(pdf, report_data, settings)
        end
      end
    end

    def self.add_cover_page(pdf, settings, timestamp)
      pdf.font_size 28
      pdf.font 'Helvetica', style: :bold
      pdf.text 'AutoNestCut Report', align: :center, color: '007cba'

      pdf.move_down 10
      pdf.font_size 14
      pdf.font 'Helvetica', style: :normal
      pdf.text settings['project_name'] || 'Untitled Project', align: :center

      pdf.move_down 30
      pdf.font_size 11
      pdf.text "Client: #{settings['client_name'] || 'N/A'}", align: :center
      pdf.text "Prepared by: #{settings['prepared_by'] || 'Int. Arch. M.Shkeir'}", align: :center
      pdf.text "Date: #{timestamp}", align: :center

      pdf.move_down 40
      pdf.stroke_horizontal_line 0, pdf.bounds.width
      pdf.move_down 20

      pdf.font_size 10
      pdf.text 'Professional Nesting & Cut List Report', align: :center, style: :italic
      pdf.text 'Generated by AutoNestCut Extension for SketchUp', align: :center, style: :italic
    end

    def self.add_table_of_contents(pdf, report_data, boards_data, assembly_data)
      pdf.font_size 16
      pdf.font 'Helvetica', style: :bold
      pdf.text 'Table of Contents'

      pdf.move_down 15
      pdf.font_size 10
      pdf.font 'Helvetica', style: :normal

      contents = [
        '1. Project Summary',
        '2. Cutting Diagrams',
        '3. Assembly Views',
        '4. Materials Summary',
        '5. Unique Parts Specifications',
        '6. Detailed Cut List',
        '7. Cut Sequences',
        '8. Usable Offcuts'
      ]

      contents.each do |item|
        pdf.text item, indent_paragraphs: 20
      end
    end

    def self.add_project_summary(pdf, report_data, settings)
      pdf.font_size 16
      pdf.font 'Helvetica', style: :bold
      pdf.text '1. Project Summary'

      pdf.move_down 10
      pdf.font_size 10
      pdf.font 'Helvetica', style: :normal

      summary = report_data[:summary] || {}
      currency_symbol = get_currency_symbol(summary[:currency] || 'USD')

      summary_data = [
        ['Project Name', settings['project_name'] || 'Untitled Project'],
        ['Client', settings['client_name'] || 'N/A'],
        ['Prepared by', settings['prepared_by'] || 'Int. Arch. M.Shkeir'],
        ['Total Parts', (summary[:total_parts_instances] || 0).to_s],
        ['Unique Components', (summary[:total_unique_part_types] || 0).to_s],
        ['Material Sheets Required', (summary[:total_boards] || 0).to_s],
        ['Overall Efficiency', "#{(summary[:overall_efficiency] || 0).round(2)}%"],
        ['Total Waste', "#{(summary[:total_waste_area] || 0).round(2)} #{summary[:area_units] || 'm2'}"],
        ['Total Project Cost', "#{currency_symbol}#{(summary[:total_project_cost] || 0).round(2)}"],
        ['Total Weight', "#{(summary[:total_project_weight_kg] || 0).round(2)} kg"]
      ]

      pdf.table(summary_data, width: pdf.bounds.width) do |table|
        table.header = false
        table.rows.each do |row|
          row.cells.each { |cell| cell.padding = [8, 10] }
          row.cells[0].background_color = 'f0f0f0'
          row.cells[0].font_style = :bold
        end
      end
    end

    def self.add_cutting_diagrams_section(pdf, boards_data, settings)
      pdf.font_size 16
      pdf.font 'Helvetica', style: :bold
      pdf.text '2. Cutting Diagrams'

      pdf.move_down 10

      boards_data.each_with_index do |board, index|
        pdf.font_size 12
        pdf.font 'Helvetica', style: :bold
        pdf.text "Sheet #{index + 1}: #{board['material']}"

        pdf.font_size 9
        pdf.font 'Helvetica', style: :normal
        
        dimensions = "#{board['stock_width']}mm x #{board['stock_height']}mm"
        efficiency = "#{(board['efficiency_percentage'] || 0).round(2)}%"
        waste = "#{(board['waste_percentage'] || 0).round(2)}%"
        parts_count = board['parts'] ? board['parts'].length : 0

        pdf.text "Dimensions: #{dimensions} | Parts: #{parts_count} | Efficiency: #{efficiency} | Waste: #{waste}"
        pdf.move_down 5

        # Note: Actual diagram images would be embedded here if available
        pdf.text '[Cutting Diagram - Visual representation would be embedded here]', style: :italic, color: '999999'
        pdf.move_down 15
      end
    end

    def self.add_assembly_views_section(pdf, assembly_data)
      pdf.font_size 16
      pdf.font 'Helvetica', style: :bold
      pdf.text '3. Assembly Views'

      pdf.move_down 10

      if assembly_data[:entity_name]
        pdf.font_size 12
        pdf.font 'Helvetica', style: :bold
        pdf.text assembly_data[:entity_name]
        pdf.move_down 5
      end

      pdf.font_size 9
      pdf.font 'Helvetica', style: :normal

      views = assembly_data[:views] || {}
      
      if views.empty?
        pdf.text 'No assembly views available'
      end

      # Create a 2x3 grid for assembly views (6 views total)
      view_names = ['Front', 'Back', 'Left', 'Right', 'Top', 'Bottom']
      view_images = []

      view_names.each do |view_name|
        # Views are stored with string keys as data URIs: "data:image/png;base64,..."
        image_data = views[view_name] || views[view_name.to_sym]
        
        if image_data
          view_images << {
            name: view_name,
            data: image_data
          }
        end
      end

      if view_images.empty?
        pdf.text 'No assembly view images available'
      end

      # Embed images in a 2-column grid layout
      view_images.each_with_index do |view, idx|
        # Add line break after every 2 images
        if idx > 0 && idx % 2 == 0
          pdf.move_down 15
        end

        pdf.font_size 10
        pdf.font 'Helvetica', style: :bold
        pdf.text "#{view[:name]} View"
        pdf.move_down 3

        # Handle base64 encoded images (data URIs)
        if view[:data].is_a?(String) && view[:data].start_with?('data:image')
          # Extract base64 data from data URI
          base64_data = view[:data].split(',')[1]
          if base64_data
            begin
              image_bytes = Base64.decode64(base64_data)
              temp_image_path = File.join(Dir.tmpdir, "assembly_view_#{view[:name]}_#{Time.now.to_i}.png")
              File.binwrite(temp_image_path, image_bytes)
              
              # Embed image with max width of 3 inches (200 points)
              pdf.image temp_image_path, width: 200
              
              # Clean up temp file
              File.delete(temp_image_path) rescue nil
            rescue => e
              puts "ERROR: Could not embed assembly image for #{view[:name]}: #{e.message}"
              pdf.text "[Image could not be embedded]", style: :italic, color: '999999'
            end
          else
            puts "ERROR: No base64 data found in data URI for #{view[:name]}"
            pdf.text "[Invalid image data]", style: :italic, color: '999999'
          end
        elsif view[:data].is_a?(String) && File.exist?(view[:data])
          # Handle file path (fallback)
          begin
            pdf.image view[:data], width: 200
          rescue => e
            puts "ERROR: Could not embed assembly image from file #{view[:data]}: #{e.message}"
            pdf.text "[Image could not be embedded]", style: :italic, color: '999999'
          end
        else
          puts "ERROR: Invalid image data for #{view[:name]}: #{view[:data].class}"
          pdf.text "[Image data not available]", style: :italic, color: '999999'
        end

        pdf.move_down 3
      end
    end

    def self.add_materials_summary(pdf, report_data, settings)
      pdf.font_size 16
      pdf.font 'Helvetica', style: :bold
      pdf.text '4. Materials Summary'

      pdf.move_down 10
      pdf.font_size 10
      pdf.font 'Helvetica', style: :normal

      unique_boards = report_data[:unique_board_types] || []
      
      if unique_boards.empty?
        pdf.text 'No material data available'
        return
      end

      materials_data = [['Material', 'Dimensions (mm)', 'Quantity', 'Total Area', 'Price/Sheet', 'Total Cost']]

      unique_boards.each do |board|
        materials_data << [
          board[:material],
          "#{board[:stock_width]} x #{board[:stock_height]}",
          board[:count].to_s,
          "#{(board[:total_area] || 0).round(2)}",
          "#{board[:currency] || 'USD'} #{(board[:price_per_sheet] || 0).round(2)}",
          "#{board[:currency] || 'USD'} #{(board[:total_cost] || 0).round(2)}"
        ]
      end

      pdf.table(materials_data, width: pdf.bounds.width) do |table|
        table.header = true
        table.rows.each_with_index do |row, idx|
          row.cells.each { |cell| cell.padding = [6, 8] }
          if idx == 0
            row.cells.each { |cell| cell.background_color = '007cba'; cell.text_color = 'ffffff'; cell.font_style = :bold }
          else
            row.cells.each { |cell| cell.background_color = idx.even? ? 'f9f9f9' : 'ffffff' }
          end
        end
      end
    end

    def self.add_unique_parts_section(pdf, report_data, settings)
      pdf.font_size 16
      pdf.font 'Helvetica', style: :bold
      pdf.text '5. Unique Parts Specifications'

      pdf.move_down 10
      pdf.font_size 10
      pdf.font 'Helvetica', style: :normal

      unique_parts = report_data[:unique_part_types] || []
      
      if unique_parts.empty?
        pdf.text 'No part data available'
        return
      end

      parts_data = [['Part Name', 'Dimensions (mm)', 'Material', 'Grain', 'Qty', 'Total Area']]

      unique_parts.each do |part|
        parts_data << [
          part[:name],
          "#{part[:width]} × #{part[:height]} × #{part[:thickness]}",
          part[:material],
          part[:grain_direction] || 'Any',
          part[:total_quantity].to_s,
          "#{(part[:total_area] || 0).round(2)}"
        ]
      end

      pdf.table(parts_data, width: pdf.bounds.width) do |table|
        table.header = true
        table.rows.each_with_index do |row, idx|
          row.cells.each { |cell| cell.padding = [6, 8]; cell.font_size = 9 }
          if idx == 0
            row.cells.each { |cell| cell.background_color = '007cba'; cell.text_color = 'ffffff'; cell.font_style = :bold }
          else
            row.cells.each { |cell| cell.background_color = idx.even? ? 'f9f9f9' : 'ffffff' }
          end
        end
      end
    end

    def self.add_detailed_cut_list(pdf, report_data, settings)
      pdf.font_size 16
      pdf.font 'Helvetica', style: :bold
      pdf.text '6. Detailed Cut List'

      pdf.move_down 10
      pdf.font_size 9
      pdf.font 'Helvetica', style: :normal

      parts_placed = report_data[:parts_placed] || []
      
      if parts_placed.empty?
        pdf.text 'No detailed parts available'
        return
      end

      # Group by board for better organization
      parts_by_board = parts_placed.group_by { |p| p[:board_number] }

      parts_by_board.each do |board_num, parts|
        pdf.font_size 11
        pdf.font 'Helvetica', style: :bold
        pdf.text "Board #{board_num}"
        pdf.move_down 5

        pdf.font_size 8
        pdf.font 'Helvetica', style: :normal

        cut_list_data = [['Part ID', 'Name', 'Dimensions (mm)', 'Material', 'Position', 'Rotated', 'Grain']]

        parts.each do |part|
          cut_list_data << [
            part[:part_unique_id] || 'N/A',
            part[:name],
            "#{part[:width]} × #{part[:height]} × #{part[:thickness]}",
            part[:material],
            "X:#{part[:position_x]}, Y:#{part[:position_y]}",
            part[:rotated] || 'No',
            part[:grain_direction] || 'Any'
          ]
        end

        pdf.table(cut_list_data, width: pdf.bounds.width) do |table|
          table.header = true
          table.rows.each_with_index do |row, idx|
            row.cells.each { |cell| cell.padding = [4, 6]; cell.font_size = 8 }
            if idx == 0
              row.cells.each { |cell| cell.background_color = '007cba'; cell.text_color = 'ffffff'; cell.font_style = :bold }
            else
              row.cells.each { |cell| cell.background_color = idx.even? ? 'f9f9f9' : 'ffffff' }
            end
          end
        end

        pdf.move_down 10
      end
    end

    def self.add_cut_sequences_section(pdf, report_data, settings)
      pdf.font_size 16
      pdf.font 'Helvetica', style: :bold
      pdf.text '7. Cut Sequences'

      pdf.move_down 10
      pdf.font_size 10
      pdf.font 'Helvetica', style: :normal

      cut_sequences = report_data[:cut_sequences] || []
      
      if cut_sequences.empty?
        pdf.text 'No cut sequences available'
        return
      end

      cut_sequences.each_with_index do |sequence, idx|
        pdf.font_size 11
        pdf.font 'Helvetica', style: :bold
        pdf.text "Sequence #{idx + 1}"
        pdf.move_down 5

        pdf.font_size 9
        pdf.font 'Helvetica', style: :normal
        pdf.text sequence.to_s, indent_paragraphs: 10
        pdf.move_down 10
      end
    end

    def self.add_offcuts_section(pdf, report_data, settings)
      pdf.font_size 16
      pdf.font 'Helvetica', style: :bold
      pdf.text '8. Usable Offcuts'

      pdf.move_down 10
      pdf.font_size 10
      pdf.font 'Helvetica', style: :normal

      offcuts = report_data[:usable_offcuts] || []
      
      if offcuts.empty?
        pdf.text 'No significant offcuts available'
        return
      end

      offcuts_data = [['Sheet #', 'Material', 'Estimated Size', 'Area (m²)']]

      offcuts.each do |offcut|
        offcuts_data << [
          offcut[:board_number].to_s,
          offcut[:material],
          offcut[:estimated_dimensions],
          offcut[:area_m2].to_s
        ]
      end

      pdf.table(offcuts_data, width: pdf.bounds.width) do |table|
        table.header = true
        table.rows.each_with_index do |row, idx|
          row.cells.each { |cell| cell.padding = [6, 8] }
          if idx == 0
            row.cells.each { |cell| cell.background_color = '007cba'; cell.text_color = 'ffffff'; cell.font_style = :bold }
          else
            row.cells.each { |cell| cell.background_color = idx.even? ? 'f9f9f9' : 'ffffff' }
          end
        end
      end
    end

    def self.get_currency_symbol(currency)
      symbols = {
        'USD' => '$',
        'EUR' => '€',
        'GBP' => '£',
        'JPY' => '¥',
        'CAD' => '$',
        'AUD' => '$',
        'CHF' => 'CHF',
        'CNY' => '¥',
        'SEK' => 'kr',
        'NZD' => '$',
        'SAR' => 'SAR',
        'AED' => 'د.إ'
      }
      symbols[currency] || currency
    end

    def self.generate_pdf_html_content(report_data, boards_data, assembly_data, project_name, client_name, prepared_by, timestamp, currency, units, area_units)
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>AutoNestCut Report - #{project_name}</title>
            <style>
                @page {
                    size: A4;
                    margin: 15mm;
                }
                
                body {
                    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                    line-height: 1.6;
                    color: #333;
                    background: #f5f5f5;
                    margin: 0;
                    padding: 0;
                }
                
                @media print {
                    body {
                        background: white;
                        margin: 0;
                        padding: 0;
                    }
                    .no-print {
                        display: none !important;
                    }
                    .page-break {
                        page-break-after: always;
                    }
                    table {
                        page-break-inside: avoid;
                    }
                    h2, h3 {
                        page-break-after: avoid;
                    }
                }
                
                .pdf-container {
                    max-width: 210mm;
                    min-height: 297mm;
                    margin: 0 auto;
                    padding: 15mm;
                    background: white;
                    box-shadow: 0 0 10px rgba(0,0,0,0.1);
                }
                
                @media print {
                    .pdf-container {
                        box-shadow: none;
                        margin: 0;
                        padding: 15mm;
                        max-width: 100%;
                    }
                }
                
                .cover-page {
                    display: flex;
                    flex-direction: column;
                    justify-content: center;
                    align-items: center;
                    height: 100%;
                    text-align: center;
                    border-bottom: 3px solid #007cba;
                    padding-bottom: 40px;
                }
                
                .cover-page h1 {
                    font-size: 48px;
                    color: #007cba;
                    margin-bottom: 20px;
                    font-weight: 700;
                }
                
                .cover-page .project-name {
                    font-size: 28px;
                    color: #333;
                    margin-bottom: 40px;
                    font-weight: 600;
                }
                
                .cover-page .metadata {
                    font-size: 14px;
                    color: #666;
                    line-height: 2;
                    margin-bottom: 40px;
                }
                
                .cover-page .footer {
                    font-size: 12px;
                    color: #999;
                    font-style: italic;
                    margin-top: 60px;
                }
                
                h2 {
                    font-size: 24px;
                    color: #007cba;
                    margin: 30px 0 20px 0;
                    padding-bottom: 10px;
                    border-bottom: 2px solid #007cba;
                    font-weight: 700;
                }
                
                h3 {
                    font-size: 18px;
                    color: #333;
                    margin: 20px 0 15px 0;
                    font-weight: 600;
                }
                
                h4 {
                    font-size: 14px;
                    color: #555;
                    margin: 15px 0 10px 0;
                    font-weight: 600;
                }
                
                table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 15px 0;
                    font-size: 12px;
                }
                
                th {
                    background: #007cba;
                    color: white;
                    padding: 12px;
                    text-align: left;
                    font-weight: 600;
                    border: 1px solid #005a87;
                }
                
                td {
                    padding: 10px 12px;
                    border: 1px solid #ddd;
                }
                
                tr:nth-child(even) {
                    background: #f9f9f9;
                }
                
                tr:hover {
                    background: #f0f0f0;
                }
                
                .summary-box {
                    background: #f0f9ff;
                    border-left: 4px solid #007cba;
                    padding: 15px;
                    margin: 15px 0;
                    border-radius: 4px;
                }
                
                .summary-box strong {
                    color: #007cba;
                }
                
                .diagram-section {
                    margin: 20px 0;
                    page-break-inside: avoid;
                }
                
                .diagram-image {
                    max-width: 100%;
                    height: auto;
                    border: 1px solid #ddd;
                    border-radius: 4px;
                    margin: 10px 0;
                }
                
                .diagram-info {
                    font-size: 11px;
                    color: #666;
                    margin-top: 8px;
                    font-style: italic;
                }
                
                .page-break {
                    page-break-after: always;
                    margin: 40px 0;
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
                    transition: all 0.3s;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    gap: 8px;
                    min-width: 180px;
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
                
                .efficiency-high {
                    color: #28a745;
                    font-weight: 600;
                }
                
                .efficiency-medium {
                    color: #ffc107;
                    font-weight: 600;
                }
                
                .efficiency-low {
                    color: #dc3545;
                    font-weight: 600;
                }
                
                .material-row {
                    page-break-inside: avoid;
                }
                
                .footer-text {
                    font-size: 10px;
                    color: #999;
                    text-align: center;
                    margin-top: 20px;
                    padding-top: 10px;
                    border-top: 1px solid #ddd;
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
            
            <!-- COVER PAGE -->
            <div class="pdf-container">
                <div class="cover-page">
                    <h1>AutoNestCut</h1>
                    <div class="project-name">#{project_name}</div>
                    <div class="metadata">
                        <div><strong>Client:</strong> #{client_name.empty? ? 'N/A' : client_name}</div>
                        <div><strong>Prepared by:</strong> #{prepared_by}</div>
                        <div><strong>Date:</strong> #{timestamp}</div>
                    </div>
                    <div class="footer">
                        <p>Professional Nesting & Cut List Report</p>
                        <p>Generated by AutoNestCut Extension for SketchUp</p>
                    </div>
                </div>
            </div>
            
            <div class="page-break"></div>
            
            <!-- PROJECT SUMMARY -->
            <div class="pdf-container">
                <h2>Project Summary</h2>
                
                #{generate_summary_section(report_data, currency)}
                
                <div class="summary-box">
                    <strong>Total Project Cost:</strong> #{get_currency_symbol(currency)}#{(report_data[:summary][:total_project_cost] || 0).round(2)}<br>
                    <strong>Overall Efficiency:</strong> #{(report_data[:summary][:overall_efficiency] || 0).round(2)}%<br>
                    <strong>Total Weight:</strong> #{(report_data[:summary][:total_project_weight_kg] || 0).round(2)} kg
                </div>
            </div>
            
            <div class="page-break"></div>
            
            <!-- MATERIALS SUMMARY -->
            <div class="pdf-container">
                <h2>Materials Summary</h2>
                #{generate_materials_table(report_data, currency)}
            </div>
            
            <div class="page-break"></div>
            
            <!-- UNIQUE PARTS -->
            <div class="pdf-container">
                <h2>Unique Parts Specifications</h2>
                #{generate_parts_table(report_data, units)}
            </div>
            
            <div class="page-break"></div>
            
            <!-- CUTTING DIAGRAMS -->
            <div class="pdf-container">
                <h2>Cutting Diagrams</h2>
                #{generate_diagrams_section(boards_data)}
            </div>
            
            <div class="page-break"></div>
            
            <!-- ASSEMBLY VIEWS -->
            #{assembly_data && assembly_data[:views] && !assembly_data[:views].empty? ? generate_assembly_views_html(assembly_data) : ''}
            
            <!-- DETAILED CUT LIST -->
            <div class="pdf-container">
                <h2>Detailed Cut List</h2>
                #{generate_cut_list_section(report_data, units)}
            </div>
            
            <div class="page-break"></div>
            
            <!-- OFFCUTS -->
            <div class="pdf-container">
                <h2>Usable Offcuts</h2>
                #{generate_offcuts_section(report_data, area_units)}
            </div>
            
            <script>
                // Auto-focus print dialog on load (optional)
                // window.addEventListener('load', function() {
                //     setTimeout(() => window.print(), 500);
                // });
            </script>
        </body>
        </html>
      HTML
    end

    def self.generate_summary_section(report_data, currency)
      summary = report_data[:summary] || {}
      currency_symbol = get_currency_symbol(currency)

      <<~HTML
        <table>
            <tr>
                <th>Metric</th>
                <th>Value</th>
            </tr>
            <tr>
                <td>Total Parts</td>
                <td>#{summary[:total_parts_instances] || 0}</td>
            </tr>
            <tr>
                <td>Unique Components</td>
                <td>#{summary[:total_unique_part_types] || 0}</td>
            </tr>
            <tr>
                <td>Material Sheets Required</td>
                <td>#{summary[:total_boards] || 0}</td>
            </tr>
            <tr>
                <td>Total Stock Area</td>
                <td>#{(summary[:total_stock_area] || 0).round(2)} mm²</td>
            </tr>
            <tr>
                <td>Total Used Area</td>
                <td>#{(summary[:total_used_area] || 0).round(2)} mm²</td>
            </tr>
            <tr>
                <td>Total Waste Area</td>
                <td>#{summary[:total_waste_area_absolute] || '0 m²'}</td>
            </tr>
            <tr>
                <td>Overall Waste Percentage</td>
                <td>#{(summary[:overall_waste_percentage] || 0).round(2)}%</td>
            </tr>
            <tr>
                <td>Kerf Width</td>
                <td>#{summary[:kerf_width] || '3.0mm'}</td>
            </tr>
        </table>
      HTML
    end

    def self.generate_materials_table(report_data, currency)
      unique_boards = report_data[:unique_board_types] || []
      currency_symbol = get_currency_symbol(currency)

      if unique_boards.empty?
        return '<p>No material data available</p>'
      end

      html = '<table><tr><th>Material</th><th>Dimensions (mm)</th><th>Qty</th><th>Total Area</th><th>Price/Sheet</th><th>Total Cost</th></tr>'

      unique_boards.each do |board|
        html += "<tr class='material-row'>"
        html += "<td>#{board[:material]}</td>"
        html += "<td>#{board[:stock_width]} × #{board[:stock_height]}</td>"
        html += "<td>#{board[:count]}</td>"
        html += "<td>#{(board[:total_area] || 0).round(2)}</td>"
        html += "<td>#{board[:currency] || currency} #{(board[:price_per_sheet] || 0).round(2)}</td>"
        html += "<td><strong>#{board[:currency] || currency} #{(board[:total_cost] || 0).round(2)}</strong></td>"
        html += '</tr>'
      end

      html += '</table>'
      html
    end

    def self.generate_parts_table(report_data, units)
      unique_parts = report_data[:unique_part_types] || []

      if unique_parts.empty?
        return '<p>No part data available</p>'
      end

      html = "<table><tr><th>Part Name</th><th>Dimensions (#{units})</th><th>Material</th><th>Grain</th><th>Qty</th><th>Total Area</th></tr>"

      unique_parts.each do |part|
        html += '<tr>'
        html += "<td>#{part[:name]}</td>"
        html += "<td>#{part[:width]} × #{part[:height]} × #{part[:thickness]}</td>"
        html += "<td>#{part[:material]}</td>"
        html += "<td>#{part[:grain_direction] || 'Any'}</td>"
        html += "<td>#{part[:total_quantity]}</td>"
        html += "<td>#{(part[:total_area] || 0).round(2)}</td>"
        html += '</tr>'
      end

      html += '</table>'
      html
    end

    def self.generate_diagrams_section(boards_data)
      return '<p>No cutting diagrams available</p>' if !boards_data || boards_data.empty?

      html = ''
      boards_data.each_with_index do |board, index|
        efficiency = board['efficiency_percentage'] || 0
        efficiency_class = if efficiency >= 80
                             'efficiency-high'
                           elsif efficiency >= 60
                             'efficiency-medium'
                           else
                             'efficiency-low'
                           end

        html += "<div class='diagram-section'>"
        html += "<h3>Sheet #{index + 1}: #{board['material']}</h3>"
        html += "<p><strong>Dimensions:</strong> #{board['stock_width']}mm × #{board['stock_height']}mm</p>"
        html += "<p><strong>Parts:</strong> #{board['parts'] ? board['parts'].length : 0}</p>"
        html += "<p><strong>Efficiency:</strong> <span class='#{efficiency_class}'>#{efficiency.round(2)}%</span></p>"
        html += "<p><strong>Waste:</strong> #{(board['waste_percentage'] || 0).round(2)}%</p>"
        html += "<p class='diagram-info'>[Cutting diagram visual representation]</p>"
        html += '</div>'
      end

      html
    end

    def self.generate_cut_list_section(report_data, units)
      parts_placed = report_data[:parts_placed] || []

      if parts_placed.empty?
        return '<p>No detailed parts available</p>'
      end

      parts_by_board = parts_placed.group_by { |p| p[:board_number] }

      html = ''
      parts_by_board.each do |board_num, parts|
        html += "<h3>Board #{board_num}</h3>"
        html += "<table><tr><th>Part ID</th><th>Name</th><th>Dimensions (#{units})</th><th>Material</th><th>Position</th><th>Rotated</th></tr>"

        parts.each do |part|
          html += '<tr>'
          html += "<td>#{part[:part_unique_id] || 'N/A'}</td>"
          html += "<td>#{part[:name]}</td>"
          html += "<td>#{part[:width]} × #{part[:height]} × #{part[:thickness]}</td>"
          html += "<td>#{part[:material]}</td>"
          html += "<td>X:#{part[:position_x]}, Y:#{part[:position_y]}</td>"
          html += "<td>#{part[:rotated] || 'No'}</td>"
          html += '</tr>'
        end

        html += '</table>'
      end

      html
    end

    def self.generate_offcuts_section(report_data, area_units)
      offcuts = report_data[:usable_offcuts] || []

      if offcuts.empty?
        return '<p>No significant offcuts available</p>'
      end

      html = "<table><tr><th>Sheet #</th><th>Material</th><th>Estimated Size</th><th>Area (#{area_units})</th></tr>"

      offcuts.each do |offcut|
        html += '<tr>'
        html += "<td>#{offcut[:board_number]}</td>"
        html += "<td>#{offcut[:material]}</td>"
        html += "<td>#{offcut[:estimated_dimensions]}</td>"
        html += "<td>#{offcut[:area_m2]}</td>"
        html += '</tr>'
      end

      html += '</table>'
      html
    end

    def self.generate_assembly_views_html(assembly_data)
      return '' unless assembly_data && assembly_data[:views]

      views = assembly_data[:views] || {}
      entity_name = assembly_data[:entity_name] || 'Assembly'
      
      if views.empty?
        return ''
      end

      html = '<div class="page-break"></div>'
      html += '<div class="pdf-container">'
      html += '<h2>3. Assembly Views</h2>'
      html += "<h3>#{entity_name}</h3>"
      html += '<div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px; margin-bottom: 30px;">'

      # Create a 2x3 grid for assembly views (6 views total)
      view_names = ['Front', 'Back', 'Left', 'Right', 'Top', 'Bottom']
      view_count = 0

      view_names.each do |view_name|
        # Check for both direct path and base64 data
        # Views are stored with string keys as data URIs: "data:image/png;base64,..."
        image_data = views[view_name] || views[view_name.to_sym]
        
        if image_data
          # Handle base64 encoded images (data URIs)
          if image_data.is_a?(String) && image_data.start_with?('data:image')
            html += '<div style="page-break-inside: avoid; border: 1px solid #ddd; border-radius: 4px; padding: 10px; background: #f9f9f9;">'
            html += "<h4 style='margin: 0 0 10px 0; text-align: center; font-size: 14px; color: #555;'>#{view_name} View</h4>"
            html += "<img src='#{image_data}' style='width: 100%; height: auto; border: 1px solid #ddd; border-radius: 4px; display: block;' />"
            html += '</div>'
            view_count += 1
          end
        end
      end

      html += '</div>'
      html += '</div>'
      html
    end
  end
end
