require 'json'
require_relative '../util'
require_relative '../config'

module AutoNestCut
  class ProfessionalPDFGenerator
    
    def initialize
      @temp_html_file = nil
    end
    
    def generate_professional_pdf(report_data, boards_data, settings = {})
      puts "DEBUG: Generating professional PDF with report data and boards data"
      
      # Get current settings
      current_settings = Config.get_cached_settings.merge(settings)
      currency = current_settings['default_currency'] || 'USD'
      units = current_settings['units'] || 'mm'
      precision = current_settings['precision'] || 1
      area_units = current_settings['area_units'] || 'm2'
      
      # Generate professional HTML content
      html_content = generate_professional_html(report_data, boards_data, current_settings)
      
      # Create temporary HTML file
      temp_dir = File.join(Dir.tmpdir, 'autonestcut_pdf')
      Dir.mkdir(temp_dir) unless Dir.exist?(temp_dir)
      
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      @temp_html_file = File.join(temp_dir, "professional_report_#{timestamp}.html")
      
      begin
        File.write(@temp_html_file, html_content, encoding: 'UTF-8')
        puts "DEBUG: Professional HTML written to: #{@temp_html_file}"
      rescue => e
        puts "ERROR: Failed to write HTML file: #{e.message}"
        return nil
      end
      
      # Show PDF preview in browser
      show_pdf_preview(@temp_html_file)
      
      @temp_html_file
    end
    
    private
    
    def generate_professional_html(report_data, boards_data, settings)
      currency = settings['default_currency'] || 'USD'
      units = settings['units'] || 'mm'
      precision = settings['precision'] || 1
      area_units = settings['area_units'] || 'm2'
      
      currency_symbol = get_currency_symbol(currency)
      area_unit_label = get_area_unit_label(area_units)
      
      # Generate timestamp
      timestamp = Time.now.strftime('%B %d, %Y at %I:%M %p')
      
      html = <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>AutoNestCut Professional Report</title>
            <style>
                @page {
                    size: A4;
                    margin: 15mm;
                }
                
                @media print {
                    body { margin: 0; }
                    .no-print { display: none !important; }
                    .page-break { page-break-before: always; }
                    .avoid-break { page-break-inside: avoid; }
                }
                
                * {
                    box-sizing: border-box;
                }
                
                body {
                    font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
                    line-height: 1.4;
                    color: #2c3e50;
                    background: white;
                    margin: 0;
                    padding: 20px;
                    font-size: 11px;
                }
                
                .header {
                    text-align: center;
                    border-bottom: 3px solid #3498db;
                    padding-bottom: 20px;
                    margin-bottom: 30px;
                    background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
                    padding: 30px 20px 20px;
                    border-radius: 8px;
                }
                
                .header h1 {
                    color: #2c3e50;
                    margin: 0 0 10px 0;
                    font-size: 28px;
                    font-weight: 700;
                    letter-spacing: -0.5px;
                }
                
                .header .subtitle {
                    color: #3498db;
                    font-size: 16px;
                    font-weight: 600;
                    margin: 0 0 15px 0;
                }
                
                .header .meta {
                    color: #7f8c8d;
                    font-size: 12px;
                    margin: 0;
                }
                
                .executive-summary {
                    background: linear-gradient(135deg, #e8f5e8 0%, #f0f8f0 100%);
                    border: 1px solid #27ae60;
                    border-radius: 10px;
                    padding: 25px;
                    margin-bottom: 30px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                }
                
                .executive-summary h2 {
                    color: #27ae60;
                    margin: 0 0 20px 0;
                    font-size: 20px;
                    font-weight: 700;
                    display: flex;
                    align-items: center;
                }
                
                .executive-summary h2::before {
                    content: "📊";
                    margin-right: 10px;
                    font-size: 24px;
                }
                
                .summary-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
                    gap: 20px;
                    margin-top: 15px;
                }
                
                .summary-card {
                    background: white;
                    border-radius: 8px;
                    padding: 15px;
                    border-left: 4px solid #3498db;
                    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                }
                
                .summary-card .label {
                    font-size: 10px;
                    color: #7f8c8d;
                    text-transform: uppercase;
                    font-weight: 600;
                    letter-spacing: 0.5px;
                    margin-bottom: 5px;
                }
                
                .summary-card .value {
                    font-size: 18px;
                    font-weight: 700;
                    color: #2c3e50;
                    margin: 0;
                }
                
                .summary-card.cost {
                    border-left-color: #e74c3c;
                }
                
                .summary-card.cost .value {
                    color: #e74c3c;
                    font-size: 22px;
                }
                
                .summary-card.efficiency {
                    border-left-color: #f39c12;
                }
                
                .section {
                    margin-bottom: 35px;
                    background: white;
                    border-radius: 8px;
                    overflow: hidden;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.08);
                }
                
                .section-header {
                    background: linear-gradient(135deg, #34495e 0%, #2c3e50 100%);
                    color: white;
                    padding: 15px 20px;
                    margin: 0;
                    font-size: 16px;
                    font-weight: 600;
                    display: flex;
                    align-items: center;
                }
                
                .section-header::before {
                    margin-right: 10px;
                    font-size: 18px;
                }
                
                .section-header.parts::before { content: "🔧"; }
                .section-header.boards::before { content: "📋"; }
                .section-header.materials::before { content: "🏗️"; }
                .section-header.cost::before { content: "💰"; }
                
                .section-content {
                    padding: 20px;
                }
                
                .professional-table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 0;
                    font-size: 10px;
                    background: white;
                }
                
                .professional-table th {
                    background: linear-gradient(135deg, #ecf0f1 0%, #bdc3c7 100%);
                    color: #2c3e50;
                    padding: 12px 8px;
                    text-align: left;
                    font-weight: 700;
                    border: 1px solid #bdc3c7;
                    font-size: 9px;
                    text-transform: uppercase;
                    letter-spacing: 0.3px;
                }
                
                .professional-table td {
                    padding: 10px 8px;
                    border: 1px solid #ecf0f1;
                    vertical-align: top;
                }
                
                .professional-table tbody tr:nth-child(even) {
                    background: #f8f9fa;
                }
                
                .professional-table tbody tr:hover {
                    background: #e3f2fd;
                }
                
                .text-center { text-align: center; }
                .text-right { text-align: right; }
                .font-bold { font-weight: 700; }
                .text-primary { color: #3498db; }
                .text-success { color: #27ae60; }
                .text-warning { color: #f39c12; }
                .text-danger { color: #e74c3c; }
                
                .board-layout {
                    background: #f8f9fa;
                    border: 1px solid #dee2e6;
                    border-radius: 8px;
                    padding: 20px;
                    margin-bottom: 20px;
                }
                
                .board-title {
                    color: #2c3e50;
                    font-size: 14px;
                    font-weight: 700;
                    margin: 0 0 15px 0;
                    display: flex;
                    align-items: center;
                }
                
                .board-title::before {
                    content: "📐";
                    margin-right: 8px;
                }
                
                .board-stats {
                    display: grid;
                    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
                    gap: 15px;
                    margin-bottom: 15px;
                }
                
                .board-stat {
                    background: white;
                    padding: 10px;
                    border-radius: 6px;
                    border-left: 3px solid #3498db;
                }
                
                .board-stat .stat-label {
                    font-size: 9px;
                    color: #7f8c8d;
                    text-transform: uppercase;
                    font-weight: 600;
                    margin-bottom: 3px;
                }
                
                .board-stat .stat-value {
                    font-size: 12px;
                    font-weight: 700;
                    color: #2c3e50;
                }
                
                .parts-list {
                    background: white;
                    border-radius: 6px;
                    padding: 15px;
                    margin-top: 10px;
                }
                
                .parts-list h4 {
                    margin: 0 0 10px 0;
                    font-size: 11px;
                    color: #34495e;
                    font-weight: 600;
                }
                
                .parts-grid {
                    display: grid;
                    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
                    gap: 8px;
                }
                
                .part-item {
                    background: #f8f9fa;
                    padding: 8px 10px;
                    border-radius: 4px;
                    border-left: 2px solid #3498db;
                    font-size: 9px;
                }
                
                .part-name {
                    font-weight: 600;
                    color: #2c3e50;
                    margin-bottom: 2px;
                }
                
                .part-details {
                    color: #7f8c8d;
                    font-size: 8px;
                }
                
                .total-row {
                    background: linear-gradient(135deg, #d5f4e6 0%, #c8e6c9 100%) !important;
                    font-weight: 700;
                    color: #1b5e20;
                    border-top: 2px solid #27ae60 !important;
                }
                
                .footer {
                    text-align: center;
                    margin-top: 40px;
                    padding-top: 20px;
                    border-top: 2px solid #ecf0f1;
                    color: #7f8c8d;
                    font-size: 10px;
                }
                
                .footer .logo {
                    font-size: 14px;
                    font-weight: 700;
                    color: #3498db;
                    margin-bottom: 5px;
                }
                
                .print-controls {
                    position: fixed;
                    top: 20px;
                    right: 20px;
                    z-index: 1000;
                    background: white;
                    padding: 15px;
                    border-radius: 8px;
                    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
                    border: 1px solid #dee2e6;
                }
                
                .print-btn {
                    background: linear-gradient(135deg, #3498db 0%, #2980b9 100%);
                    color: white;
                    border: none;
                    padding: 12px 24px;
                    border-radius: 6px;
                    cursor: pointer;
                    font-size: 12px;
                    font-weight: 600;
                    margin-right: 10px;
                    transition: all 0.3s ease;
                }
                
                .print-btn:hover {
                    transform: translateY(-2px);
                    box-shadow: 0 4px 12px rgba(52, 152, 219, 0.3);
                }
                
                .close-btn {
                    background: #95a5a6;
                    color: white;
                    border: none;
                    padding: 12px 24px;
                    border-radius: 6px;
                    cursor: pointer;
                    font-size: 12px;
                    font-weight: 600;
                    transition: all 0.3s ease;
                }
                
                .close-btn:hover {
                    background: #7f8c8d;
                }
                
                .efficiency-bar {
                    width: 100%;
                    height: 8px;
                    background: #ecf0f1;
                    border-radius: 4px;
                    overflow: hidden;
                    margin-top: 5px;
                }
                
                .efficiency-fill {
                    height: 100%;
                    background: linear-gradient(90deg, #e74c3c 0%, #f39c12 50%, #27ae60 100%);
                    border-radius: 4px;
                    transition: width 0.3s ease;
                }
            </style>
        </head>
        <body>
            <div class="print-controls no-print">
                <button class="print-btn" onclick="window.print()">🖨️ Print PDF</button>
                <button class="close-btn" onclick="window.close()">✕ Close</button>
            </div>
            
            <div class="header">
                <h1>AutoNestCut Professional Report</h1>
                <p class="subtitle">Optimized Cut List & Material Analysis</p>
                <p class="meta">Generated on #{timestamp}</p>
            </div>
            
            <div class="executive-summary avoid-break">
                <h2>Executive Summary</h2>
                <div class="summary-grid">
                    <div class="summary-card">
                        <div class="label">Total Parts</div>
                        <div class="value">#{report_data[:summary][:total_parts_instances] || 0}</div>
                    </div>
                    <div class="summary-card">
                        <div class="label">Unique Types</div>
                        <div class="value">#{report_data[:summary][:total_unique_part_types] || 0}</div>
                    </div>
                    <div class="summary-card">
                        <div class="label">Boards Required</div>
                        <div class="value">#{report_data[:summary][:total_boards] || 0}</div>
                    </div>
                    <div class="summary-card efficiency">
                        <div class="label">Material Efficiency</div>
                        <div class="value">#{format_number(report_data[:summary][:overall_efficiency] || 0, 1)}%</div>
                        <div class="efficiency-bar">
                            <div class="efficiency-fill" style="width: #{report_data[:summary][:overall_efficiency] || 0}%"></div>
                        </div>
                    </div>
                    <div class="summary-card cost">
                        <div class="label">Total Project Cost</div>
                        <div class="value">#{currency_symbol}#{format_number(report_data[:summary][:total_project_cost] || 0, 2)}</div>
                    </div>
                </div>
            </div>
      HTML
      
      # Add Unique Part Types section
      if report_data[:unique_part_types] && !report_data[:unique_part_types].empty?
        html += generate_parts_section(report_data[:unique_part_types], units, precision, area_unit_label)
      end
      
      # Add Board Layouts section
      if boards_data && !boards_data.empty?
        html += generate_boards_section(boards_data, units, precision)
      end
      
      # Add Materials Cost Analysis section
      if report_data[:unique_board_types] && !report_data[:unique_board_types].empty?
        html += generate_cost_section(report_data[:unique_board_types], currency_symbol)
      end
      
      # Add footer
      html += <<~HTML
            <div class="footer">
                <div class="logo">AutoNestCut v2.7.0</div>
                <p>Professional Cut List & Nesting Software</p>
                <p>Report generated on #{timestamp}</p>
            </div>
        </body>
        </html>
      HTML
      
      html
    end
    
    def generate_parts_section(parts, units, precision, area_unit_label)
      html = <<~HTML
        <div class="section avoid-break">
            <h2 class="section-header parts">Unique Part Types</h2>
            <div class="section-content">
                <table class="professional-table">
                    <thead>
                        <tr>
                            <th>Part Name</th>
                            <th class="text-center">Width (#{units})</th>
                            <th class="text-center">Height (#{units})</th>
                            <th class="text-center">Thickness (#{units})</th>
                            <th>Material</th>
                            <th class="text-center">Grain</th>
                            <th class="text-center">Edge Banding</th>
                            <th class="text-center">Quantity</th>
                            <th class="text-center">Total Area (#{area_unit_label})</th>
                        </tr>
                    </thead>
                    <tbody>
      HTML
      
      parts.each do |part|
        width = convert_dimension(part[:width] || 0, units, precision)
        height = convert_dimension(part[:height] || 0, units, precision)
        thickness = convert_dimension(part[:thickness] || 0, units, precision)
        area = convert_area(part[:total_area] || 0, area_unit_label, precision)
        
        html += <<~HTML
          <tr>
              <td class="font-bold text-primary">#{escape_html(part[:name])}</td>
              <td class="text-center">#{width}</td>
              <td class="text-center">#{height}</td>
              <td class="text-center">#{thickness}</td>
              <td>#{escape_html(part[:material])}</td>
              <td class="text-center">#{part[:grain_direction] || 'Any'}</td>
              <td class="text-center">#{part[:edge_banding] || 'None'}</td>
              <td class="text-center font-bold">#{part[:total_quantity]}</td>
              <td class="text-center">#{area}</td>
          </tr>
        HTML
      end
      
      html += <<~HTML
                    </tbody>
                </table>
            </div>
        </div>
      HTML
      
      html
    end
    
    def generate_boards_section(boards_data, units, precision)
      html = <<~HTML
        <div class="section page-break">
            <h2 class="section-header boards">Board Layout Summary</h2>
            <div class="section-content">
      HTML
      
      boards_data.each_with_index do |board, index|
        width = convert_dimension(board[:stock_width] || board['stock_width'] || 0, units, precision)
        height = convert_dimension(board[:stock_height] || board['stock_height'] || 0, units, precision)
        efficiency = board[:efficiency_percentage] || board['efficiency_percentage'] || 0
        waste = 100 - efficiency
        parts_count = (board[:parts] || board['parts'] || []).length
        
        html += <<~HTML
          <div class="board-layout avoid-break">
              <h3 class="board-title">#{escape_html(board[:material] || board['material'])} - Board #{index + 1}</h3>
              <div class="board-stats">
                  <div class="board-stat">
                      <div class="stat-label">Dimensions</div>
                      <div class="stat-value">#{width} × #{height} #{units}</div>
                  </div>
                  <div class="board-stat">
                      <div class="stat-label">Parts Count</div>
                      <div class="stat-value">#{parts_count}</div>
                  </div>
                  <div class="board-stat">
                      <div class="stat-label">Efficiency</div>
                      <div class="stat-value text-success">#{format_number(efficiency, 1)}%</div>
                  </div>
                  <div class="board-stat">
                      <div class="stat-label">Waste</div>
                      <div class="stat-value text-warning">#{format_number(waste, 1)}%</div>
                  </div>
              </div>
        HTML
        
        parts = board[:parts] || board['parts'] || []
        if !parts.empty?
          html += <<~HTML
            <div class="parts-list">
                <h4>Parts on this board:</h4>
                <div class="parts-grid">
          HTML
          
          parts.each do |part|
            part_width = convert_dimension(part[:width] || part['width'] || 0, units, precision)
            part_height = convert_dimension(part[:height] || part['height'] || 0, units, precision)
            
            html += <<~HTML
              <div class="part-item">
                  <div class="part-name">#{escape_html(part[:name] || part['name'])}</div>
                  <div class="part-details">#{part_width} × #{part_height} #{units}</div>
                  #{part[:edge_banding] && part[:edge_banding] != 'None' ? "<div class=\"part-details\">Edge: #{part[:edge_banding]}</div>" : ''}
                  #{part[:grain_direction] && part[:grain_direction] != 'Any' ? "<div class=\"part-details\">Grain: #{part[:grain_direction]}</div>" : ''}
              </div>
            HTML
          end
          
          html += <<~HTML
                </div>
            </div>
          HTML
        end
        
        html += "</div>"
      end
      
      html += <<~HTML
            </div>
        </div>
      HTML
      
      html
    end
    
    def generate_cost_section(board_types, currency_symbol)
      html = <<~HTML
        <div class="section avoid-break">
            <h2 class="section-header cost">Cost Analysis</h2>
            <div class="section-content">
                <table class="professional-table">
                    <thead>
                        <tr>
                            <th>Material</th>
                            <th class="text-center">Sheets Required</th>
                            <th class="text-center">Price per Sheet</th>
                            <th class="text-center">Total Cost</th>
                        </tr>
                    </thead>
                    <tbody>
      HTML
      
      total_cost = 0
      board_types.each do |board|
        cost = board[:total_cost] || 0
        total_cost += cost
        
        html += <<~HTML
          <tr>
              <td class="font-bold">#{escape_html(board[:material])}</td>
              <td class="text-center">#{board[:count]}</td>
              <td class="text-center">#{currency_symbol}#{format_number(board[:price_per_sheet] || 0, 2)}</td>
              <td class="text-center font-bold">#{currency_symbol}#{format_number(cost, 2)}</td>
          </tr>
        HTML
      end
      
      html += <<~HTML
                        <tr class="total-row">
                            <td colspan="3" class="text-right font-bold">TOTAL PROJECT COST:</td>
                            <td class="text-center font-bold" style="font-size: 14px;">#{currency_symbol}#{format_number(total_cost, 2)}</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
      HTML
      
      html
    end
    
    def show_pdf_preview(html_file_path)
      # Convert to file:// URL for cross-platform compatibility
      file_url = "file:///#{File.expand_path(html_file_path).gsub('\\', '/')}"
      
      puts "DEBUG: Opening PDF preview at: #{file_url}"
      
      # Open in default browser for PDF preview (non-blocking)
      Thread.new do
        begin
          if Sketchup.platform == :platform_win
            system("start \"\" \"#{file_url}\"")
          elsif Sketchup.platform == :platform_osx
            system("open \"#{file_url}\"")
          else
            system("xdg-open \"#{file_url}\"")
          end
        rescue => e
          puts "DEBUG: Error opening browser: #{e.message}"
        end
      end
    end
    
    def convert_dimension(value_mm, target_units, precision)
      return '0' if value_mm.nil? || value_mm == 0
      
      factor = case target_units
               when 'mm' then 1
               when 'cm' then 10
               when 'm' then 1000
               when 'in' then 25.4
               when 'ft' then 304.8
               else 1
               end
      
      converted = value_mm.to_f / factor
      format_number(converted, precision)
    end
    
    def convert_area(area_mm2, target_units, precision)
      return '0' if area_mm2.nil? || area_mm2 == 0
      
      factor = case target_units
               when 'mm²' then 1
               when 'cm²' then 100
               when 'm²' then 1000000
               when 'in²' then 645.16
               when 'ft²' then 92903.04
               else 1000000
               end
      
      converted = area_mm2.to_f / factor
      format_number(converted, precision)
    end
    
    def format_number(value, precision)
      return '0' if value.nil? || value == 0
      
      if precision == 0
        value.round.to_s
      else
        sprintf("%.#{precision}f", value)
      end
    end
    
    def get_currency_symbol(currency)
      symbols = {
        'USD' => '$', 'EUR' => '€', 'GBP' => '£', 'JPY' => '¥',
        'CAD' => 'C$', 'AUD' => 'A$', 'CHF' => 'CHF', 'SEK' => 'kr',
        'NOK' => 'kr', 'DKK' => 'kr', 'PLN' => 'zł', 'SAR' => 'ر.س',
        'AED' => 'د.إ', 'KWD' => 'د.ك', 'QAR' => 'ر.ق', 'BHD' => 'د.ب'
      }
      symbols[currency] || currency
    end
    
    def get_area_unit_label(area_units)
      labels = {
        'mm2' => 'mm²', 'cm2' => 'cm²', 'm2' => 'm²',
        'in2' => 'in²', 'ft2' => 'ft²'
      }
      labels[area_units] || 'm²'
    end
    
    def escape_html(text)
      return '' if text.nil?
      text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;').gsub("'", '&#39;')
    end
    
    def cleanup_temp_files
      if @temp_html_file && File.exist?(@temp_html_file)
        File.delete(@temp_html_file)
        puts "DEBUG: Cleaned up temporary HTML file"
      end
    end
  end
end