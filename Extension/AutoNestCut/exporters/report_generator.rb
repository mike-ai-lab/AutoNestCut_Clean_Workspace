# filename: report_generator.rb
require 'csv'
require_relative '../util' # Ensure Util module is loaded

# Safely require optional dependencies
begin
  require_relative 'cut_sequence_generator'
rescue LoadError => e
  puts "WARNING: cut_sequence_generator not available: #{e.message}"
end

begin
  require_relative 'assembly_exporter'
rescue LoadError => e
  puts "WARNING: assembly_exporter not available: #{e.message}"
end

module AutoNestCut
  class ReportGenerator

    def generate_report_data(boards, settings = {})
      current_settings = Config.get_cached_settings
      
      # CRITICAL FIX: Ensure stock_materials is always a Hash
      if current_settings['stock_materials'] && !current_settings['stock_materials'].is_a?(Hash)
        puts "CRITICAL: stock_materials is #{current_settings['stock_materials'].class}, resetting to empty Hash"
        current_settings['stock_materials'] = {}
      end
      current_settings['stock_materials'] ||= {}
      
      currency = current_settings['default_currency'] || 'USD'
      units = current_settings['units'] || 'mm'
      precision = current_settings['precision'] || 1
      area_units = current_settings['area_units'] || 'm2'
      
      # Keep all data in mm for calculation, frontend handles display conversion
      parts_placed_on_boards = []
      unique_part_types_summary = {}

      boards_summary = []
      unique_board_types = {}
      total_waste_area = 0
      overall_total_stock_area = 0

      global_part_instance_counter = 1

      boards.each_with_index do |board, board_idx|
        board_number = board_idx + 1
        board_material = board.material
        
        # DEBUG: Log board material
        puts "\n=== BOARD MATERIAL DEBUG ==="
        puts "Board ##{board_number}"
        puts "board.material: #{board_material.inspect}"
        puts "============================\n"
        
        stock_materials = current_settings['stock_materials'] || {}
        # Ensure stock_materials is a Hash, not an Array
        unless stock_materials.is_a?(Hash)
          puts "WARNING: stock_materials is #{stock_materials.class}, converting to Hash"
          stock_materials = {}
        end
        
        # DEBUG: Check what we're working with
        puts "DEBUG: stock_materials class: #{stock_materials.class}"
        puts "DEBUG: stock_materials keys: #{stock_materials.keys.first(5).inspect if stock_materials.is_a?(Hash)}"
        puts "DEBUG: board_material: #{board_material.inspect}"
        
        material_data = stock_materials[board_material]
        puts "DEBUG: material_data class: #{material_data.class if material_data}"
        puts "DEBUG: material_data: #{material_data.inspect if material_data}"
        
        # CRITICAL FIX: Handle case where material_data is an Array (should be a Hash)
        if material_data.is_a?(Array) && material_data.length > 0
          puts "WARNING: material_data is an Array, extracting first element"
          material_data = material_data.first
        end
        
        # Ensure material_data is also a Hash
        material_data = {} unless material_data.is_a?(Hash)
        
        density = material_data['density'] || 600
        
        # Fix stock_materials for board.total_weight_kg call
        fixed_stock_materials = stock_materials.transform_values do |val|
          val.is_a?(Array) && val.length > 0 ? val.first : val
        end
        board_weight = board.total_weight_kg(fixed_stock_materials)
        
        board_info = {
          board_number: board_number,
          material: board_material,
          stock_size_mm: "#{board.stock_width.round(1)} x #{board.stock_height.round(1)} mm",
          stock_width: board.stock_width,
          stock_height: board.stock_height,
          parts_count: board.parts_on_board.length,
          used_area: board.used_area,
          waste_area: board.waste_area,
          waste_percentage: board.calculate_waste_percentage,
          efficiency_percentage: board.efficiency_percentage,
          weight_kg: board_weight.round(2),
          units: units,
          precision: precision
        }
        boards_summary << board_info

        # Track unique board types
        board_key = "#{board_material}_#{board.stock_width.round(1)}x#{board.stock_height.round(1)}"
        unique_board_types[board_key] ||= {
          material: board_material,
          dimensions_mm: "#{board.stock_width.round(1)} x #{board.stock_height.round(1)} mm",
          stock_width: board.stock_width,
          stock_height: board.stock_height,
          count: 0,
          total_area: 0.0,
          units: units
        }
        unique_board_types[board_key][:count] += 1
        unique_board_types[board_key][:total_area] += board.total_area
        
        # Add pricing calculation with currency (using global default currency for new materials)
        stock_materials = current_settings['stock_materials'] || {} # FIX: Use current_settings
        # Ensure stock_materials is a Hash, not an Array
        stock_materials = {} unless stock_materials.is_a?(Hash)
        material_info = stock_materials[board_material]
        
        # Handle Array case
        if material_info.is_a?(Array) && material_info.length > 0
          material_info = material_info.first
        end
        
        if material_info && material_info.is_a?(Hash)
          price = material_info['price'] || 0
          material_currency = material_info['currency'] || currency # Use material's specific currency if saved, else global default
          unique_board_types[board_key][:price_per_sheet] = price
          unique_board_types[board_key][:currency] = material_currency
          unique_board_types[board_key][:total_cost] = unique_board_types[board_key][:count] * price
        else # Fallback for materials not found in stock_materials
          unique_board_types[board_key][:price_per_sheet] = 0
          unique_board_types[board_key][:currency] = currency
          unique_board_types[board_key][:total_cost] = 0
        end

        total_waste_area += board.waste_area
        overall_total_stock_area += board.total_area

        board.parts_on_board.each do |part_instance|
          part_instance.instance_id = "P#{global_part_instance_counter}"
          global_part_instance_counter += 1

          part_material = part_instance.material
          if part_material == 'No Material' || part_material.nil? || part_material.empty?
            stock_materials_local = current_settings['stock_materials'] || {}
            stock_materials_local = {} unless stock_materials_local.is_a?(Hash)
            part_material = stock_materials_local.keys.first || 'No Material'
          end
          
          stock_materials_local = current_settings['stock_materials'] || {}
          stock_materials_local = {} unless stock_materials_local.is_a?(Hash)
          material_data = stock_materials_local[part_material]
          
          # Handle Array case
          if material_data.is_a?(Array) && material_data.length > 0
            material_data = material_data.first
          end
          material_data = {} unless material_data.is_a?(Hash)
          
          density = material_data['density'] || 600
          part_weight = part_instance.weight_kg(density)
          
          parts_placed_on_boards << {
            part_unique_id: part_instance.instance_id,
            name: part_instance.name,
            width: part_instance.width.round(2),
            height: part_instance.height.round(2),
            thickness: part_instance.thickness.round(2),
            material: part_material,
            area: part_instance.area.round(precision),
            weight_kg: part_weight.round(3),
            board_number: board_number,
            position_x: part_instance.x.round(2),
            position_y: part_instance.y.round(2),
            rotated: part_instance.rotated ? "Yes" : "No",
            grain_direction: part_instance.grain_direction || "Any",
            edge_banding: part_instance.edge_banding || "None",
            units: units
          }

          unique_part_types_summary[part_instance.name] ||= {
            name: part_instance.name,
            width: part_instance.width.round(2),
            height: part_instance.height.round(2),
            thickness: part_instance.thickness.round(2),
            material: part_material,
            grain_direction: part_instance.grain_direction || "Any",
            edge_banding: part_instance.edge_banding || "None",
            total_quantity: 0,
            total_area: 0.0,
            total_weight_kg: 0.0,
            units: units
          }
          unique_part_types_summary[part_instance.name][:total_quantity] += 1
          unique_part_types_summary[part_instance.name][:total_area] += part_instance.area
          unique_part_types_summary[part_instance.name][:total_weight_kg] += part_weight
        end
      end

      overall_waste_percentage = overall_total_stock_area > 0 ? (total_waste_area.to_f / overall_total_stock_area * 100).round(2) : 0
      
      total_project_cost = unique_board_types.values.sum { |board| board[:total_cost] || 0 }
      
      # Fix stock_materials for total_weight_kg calls (handle Array values)
      fixed_stock_materials_for_weight = (current_settings['stock_materials'] || {}).transform_values do |val|
        val.is_a?(Array) && val.length > 0 ? val.first : val
      end
      total_project_weight = boards.sum { |board| board.total_weight_kg(fixed_stock_materials_for_weight) }

      # Generate cut sequences with error handling
      cut_sequences = []
      begin
        cut_generator = CutSequenceGenerator.new
        cut_sequences = cut_generator.generate_cut_sequences(boards)
      rescue => e
        puts "WARNING: Cut sequence generation failed: #{e.message}"
        cut_sequences = []
      end
      
      # Edge banding summary generation removed (incomplete implementation)
      
      # Calculate usable offcuts with error handling
      usable_offcuts = []
      begin
        usable_offcuts = calculate_usable_offcuts(boards)
      rescue => e
        puts "WARNING: Offcuts calculation failed: #{e.message}"
        usable_offcuts = []
      end
      
      report_data = {
        parts_placed: parts_placed_on_boards,
        unique_part_types: unique_part_types_summary.values.sort_by { |p| p[:name] },
        unique_board_types: unique_board_types.values.sort_by { |b| (b[:material] || '').to_s },
        boards: boards_summary, # This contains per-board data, not unique types
        cut_sequences: cut_sequences,

        usable_offcuts: usable_offcuts,
        summary: {
          total_parts_instances: parts_placed_on_boards.length,
          total_unique_part_types: unique_part_types_summary.keys.length,
          total_boards: boards.length,
          total_stock_area: overall_total_stock_area.round(precision),
          total_used_area: (overall_total_stock_area - total_waste_area).round(precision),
          total_waste_area: total_waste_area.round(precision),
          total_waste_area_absolute: "#{(total_waste_area / (area_units == 'm2' ? 1000000 : window.areaFactors[area_units] || 1000000)).round(2)} #{area_units == 'm2' ? 'm²' : area_units}",
          overall_waste_percentage: overall_waste_percentage,
          overall_efficiency: (100.0 - overall_waste_percentage),
          total_project_cost: total_project_cost.round(2),
          total_project_weight_kg: total_project_weight.round(2),
          kerf_width: "#{(current_settings['kerf_width'] || 3.0).round(1)}mm",
          project_name: current_settings['project_name'] || 'Untitled Project',
          client_name: current_settings['client_name'] || '',
          currency: currency,
          units: units,
          precision: precision,
          area_units: area_units
        }
      }
      
      report_data
    end
    
    def export_csv(filename, report_data)
      # Sanitize filename to prevent path traversal
      safe_filename = File.basename(filename)
      safe_path = File.join(Dir.tmpdir, safe_filename)
      
      File.open(safe_path, 'w') do |file|
        # Get current settings for consistent formatting
        current_settings = Config.get_cached_settings
        units = current_settings['units'] || 'mm'
        precision = current_settings['precision'] || 1
        
        file.puts "Name,Width (#{units}),Height (#{units}),Thickness (#{units}),Material,Grain,Edge Banding,Quantity,Total Area"
        
        parts = report_data[:unique_part_types] || []
        parts.each do |part|
          width = (part[:width] / (current_settings['unit_factors'] || {'mm' => 1})[units]).round(precision)
          height = (part[:height] / (current_settings['unit_factors'] || {'mm' => 1})[units]).round(precision)
          thickness = (part[:thickness] / (current_settings['unit_factors'] || {'mm' => 1})[units]).round(precision)
          
          line = "#{part[:name]},#{width},#{height},#{thickness},#{part[:material]},#{part[:grain_direction] || 'Any'},#{part[:edge_banding] || 'None'},#{part[:total_quantity]},#{part[:total_area]}"
          file.puts line
        end
      end
    end
    
    def export_interactive_html(report_data_json, assembly_data = nil)
      begin
        data = JSON.parse(report_data_json)
        report_data = data['report']
        boards_data = data['diagrams']
        original_components = data['original_components'] || []
        hierarchy_tree = data['hierarchy_tree'] || []
        
        # Get current settings
        current_settings = Config.get_cached_settings
        timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
        
        # Generate the complete HTML with embedded data and functionality
        html_content = generate_interactive_html_content(report_data, boards_data, original_components, hierarchy_tree, current_settings, timestamp, assembly_data)
        
        # Save to file
        model = Sketchup.active_model
        model_name = File.basename(model.path, '.skp') if model.path && !model.path.empty?
        model_name ||= 'AutoNestCut_Report'
        
        filename = "#{model_name}_Interactive_Report.html"
        
        # Use file dialog to let user choose location
        file_path = UI.savepanel("Save Interactive HTML Report", nil, filename)
        
        if file_path
          File.write(file_path, html_content, encoding: 'UTF-8')
          puts "Interactive HTML report saved to: #{file_path}"
          
          # Open the file in default browser
          if Sketchup.platform == :platform_win
            system("start \"\" \"#{file_path}\"")
          elsif Sketchup.platform == :platform_osx
            system("open \"#{file_path}\"")
          end
          
          UI.messagebox("Interactive HTML report exported successfully!\n\nFile saved to: #{file_path}")
        end
        
      rescue => e
        puts "ERROR: Failed to export interactive HTML: #{e.message}"
        puts e.backtrace.join("\n")
        UI.messagebox("Failed to export interactive HTML report: #{e.message}")
      end
    end
    
    def capture_assembly_data(entity)
      return nil unless entity && (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance))
      
      begin
        require 'base64'
        
        entity_name = entity.name.to_s.strip.empty? ? "Assembly" : entity.name
        
        selected_views = {
          'Front' => true, 'Back' => true, 'Left' => true,
          'Right' => true, 'Top' => true, 'Bottom' => true
        }
        
        puts "DEBUG: Capturing assembly views for: #{entity_name}"
        views = AssemblyExporter.capture_assembly_views(entity, "1", selected_views)
        puts "DEBUG: Views captured: #{views.keys.inspect if views}"
        
        # Get component-grouped geometry with explode vectors
        geometry_data = extract_component_geometry(entity)
        geometry_data = { parts: [] } unless geometry_data && geometry_data[:parts]
        puts "DEBUG: Geometry parts count: #{geometry_data[:parts].length if geometry_data}"

        # Encode views to base64 data URIs
        encoded_views = {}
        if views && views.is_a?(Hash)
          views.each do |view_name, image_path|
            if File.exist?(image_path)
              begin
                image_data = File.binread(image_path)
                base64_data = Base64.strict_encode64(image_data)
                encoded_views[view_name] = "data:image/jpeg;base64,#{base64_data}"
                puts "DEBUG: Encoded #{view_name} view to base64 data URI"
              rescue => e
                puts "WARNING: Failed to encode #{view_name}: #{e.message}"
              end
            end
          end
        end

        {
          entity_name: entity_name,
          views: encoded_views,
          geometry: geometry_data
        }
      rescue => e
        puts "WARNING: Failed to capture assembly data: #{e.message}"
        puts e.backtrace.join("\n")
        nil
      end
    end
    
    private
    
    def extract_component_geometry(entity)
      parts = []
      parent_center = entity.bounds.center
      
      # Get sub-components
      entities = entity.is_a?(Sketchup::ComponentInstance) ? entity.definition.entities : entity.entities
      sub_parts = entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      
      sub_parts.each do |part|
        # Calculate explode vector - MUST use transformed bounds center
        part_global_center = part.bounds.center.transform(part.transformation)
        raw_vector = part_global_center - parent_center
        raw_vector = Geom::Vector3d.new(0, 0, 1) if raw_vector.length == 0
        
        # Use the FULL normalized vector, not just dominant axis
        axis_vector = raw_vector.clone
        axis_vector.normalize!
        
        # Extract geometry for this component
        faces = []
        collect_component_faces(part, part.transformation, faces)
        
        # Get the actual part name
        part_name = if part.is_a?(Sketchup::ComponentInstance)
          part.definition.name
        elsif part.is_a?(Sketchup::Group)
          part.name
        else
          "Part"
        end
        part_name = "Part" if part_name.nil? || part_name.empty?
        
        parts << {
          name: part_name,
          explode_vector: [axis_vector.x, axis_vector.z, -axis_vector.y],
          faces: faces
        }
      end
      
      { parts: parts }
    end
    
    def collect_component_faces(entity, transformation, faces)
      entities = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
      current_transform = transformation
      
      entities.each do |e|
        if e.is_a?(Sketchup::Face)
          vertices = []
          e.outer_loop.vertices.each do |v|
            pt = v.position.transform(current_transform)
            vertices << {
              x: pt.x.to_mm / 100.0,
              y: pt.y.to_mm / 100.0,
              z: pt.z.to_mm / 100.0
            }
          end
          
          color = e.material ? (e.material.color.to_i & 0xFFFFFF) : 0x74b9ff
          faces << { vertices: vertices, color: color }
          
        elsif e.is_a?(Sketchup::Group)
          collect_component_faces(e, current_transform * e.transformation, faces)
        elsif e.is_a?(Sketchup::ComponentInstance)
          collect_component_faces(e, current_transform * e.transformation, faces)
        end
      end
    end
    
    private
    
    def generate_interactive_html_content(report_data, boards_data, original_components, hierarchy_tree, settings, timestamp, assembly_data = nil)
      # Read the base HTML, CSS, and JS files
      ui_path = File.join(__dir__, '..', 'ui', 'html')
      
      # Read all required files
      main_html = File.read(File.join(ui_path, 'main.html'))
      style_css = File.read(File.join(ui_path, 'style.css'))
      diagrams_style_css = File.read(File.join(ui_path, 'diagrams_style.css'))
      resizer_css = File.read(File.join(ui_path, 'resizer_fix.css'))
      diagrams_js = File.read(File.join(ui_path, 'diagrams_report.js'))
      resizer_js = File.read(File.join(ui_path, 'resizer_fix.js'))
      table_customization_js = File.read(File.join(ui_path, 'table_customization.js'))
      
      # Extract the body content from main.html (everything between <body> tags)
      body_match = main_html.match(/<body[^>]*>(.*?)<\/body>/m)
      body_content = body_match ? body_match[1] : main_html
      
      # Remove SketchUp-specific elements and modify for standalone use
      body_content = clean_html_for_export(body_content)
      
      # NOTE: Assembly data is now handled entirely by JavaScript in diagrams_report.js
      # The renderAssemblyViews() function will populate the #assemblyViewsContainer
      # Do NOT insert assembly HTML here to avoid duplication
      
      # Load table settings from localStorage (if available in SketchUp context)
      table_settings = {}
      begin
        # Try to get table settings from a settings file or default
        table_settings_file = File.join(Dir.home, '.autonestcut', 'table_settings.json')
        if File.exist?(table_settings_file)
          table_settings = JSON.parse(File.read(table_settings_file))
        end
      rescue => e
        puts "WARNING: Could not load table settings: #{e.message}"
      end
      
      # Convert assembly_data from symbol keys to string keys for JSON serialization
      assembly_data_for_export = nil
      if assembly_data && assembly_data.is_a?(Hash)
        puts "DEBUG: Converting assembly_data to export format"
        puts "DEBUG: assembly_data[:views] count: #{assembly_data[:views].length if assembly_data[:views].is_a?(Hash)}"
        
        assembly_data_for_export = {
          'entity_name' => assembly_data[:entity_name],
          'views' => assembly_data[:views],
          'geometry' => assembly_data[:geometry]
        }
        
        puts "DEBUG: assembly_data_for_export created with keys: #{assembly_data_for_export.keys.inspect}"
      end
      
      # Prepare the data as JSON with proper escaping
      export_data = {
        diagrams: boards_data,
        report: report_data,
        original_components: original_components,
        hierarchy_tree: hierarchy_tree,
        settings: settings,
        timestamp: timestamp,
        tableSettings: table_settings,
        assembly_data: assembly_data_for_export
      }
      
      # Convert to JSON - no additional escaping needed for JSON script tag
      json_data = export_data.to_json
      
      # Generate the complete standalone HTML
      html_template = <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>AutoNestCut Interactive Report - #{settings['project_name'] || 'Untitled Project'}</title>
            <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
            <style>
                #{style_css}
                #{diagrams_style_css}
                #{resizer_css}
                
                /* Export-specific styles */
                .header-controls .action-buttons .tab-button:not(.report-action-btn) {
                    display: none !important;
                }
                
                .settings-btn {
                    display: none !important;
                }
                
                .tabs .tab-button:first-child {
                    display: none !important;
                }
                
                .header-content {
                    text-align: center;
                    width: 100%;
                }
                
                .header {
                    justify-content: center;
                    padding: 20px;
                }
                
                .export-info {
                    background: #f0f9ff;
                    border: 1px solid #0ea5e9;
                    border-radius: 8px;
                    padding: 12px 16px;
                    margin: 16px;
                    font-size: 14px;
                    color: #0c4a6e;
                }
                
                .export-info strong {
                    color: #0369a1;
                }
                
                /* Auto-show report tab */
                #configTab {
                    display: none !important;
                }
                
                #reportTabContent {
                    display: flex !important;
                }
                
                .tabs .tab-button:last-child {
                    background: #ffffff;
                    color: #24292e;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.12);
                }
                
                /* Ensure proper layout for exported HTML */
                body {
                    height: 100vh;
                    overflow: hidden;
                    margin: 0;
                    padding: 0;
                }
                
                .container {
                    height: 100vh;
                    display: flex;
                }
                
                .diagrams-container {
                    height: 100%;
                    overflow-y: auto;
                    flex: 1;
                    padding: 20px;
                    padding-bottom: 100px;
                    box-sizing: border-box;
                }
                
                .report-container {
                    height: 100%;
                    overflow-y: auto;
                    flex: 1;
                    padding: 20px;
                    padding-bottom: 100px;
                    box-sizing: border-box;
                }
                
                #resizer {
                    background: #d0d7de;
                    cursor: col-resize;
                    width: 8px;
                    min-height: 100%;
                    transition: background 0.2s;
                }
                
                #resizer:hover {
                    background: #8c959f;
                }
                
                /* Responsive design for smaller screens */
                @media (max-width: 768px) {
                    .container {
                        flex-direction: column;
                        height: auto;
                    }
                    
                    #resizer {
                        display: none;
                    }
                    
                    .diagrams-container,
                    .report-container {
                        flex: none;
                        height: auto;
                        min-height: 400px;
                    }
                }
            </style>
        </head>
        <body>
            #{body_content}
            
            <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
            <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
            
            <script id="embedded-data" type="application/json">
#{json_data}
            </script>
            
            <script>
                // Load embedded data
                var EMBEDDED_DATA = JSON.parse(document.getElementById('embedded-data').textContent);
                
                // Add showTab function
                function showTab(tabName) {
                    // This is a stub for exported HTML - report is always shown
                    console.log('showTab called:', tabName);
                }
                
                // Mock SketchUp interface for standalone operation
                window.sketchup = {
                    export_csv: function(data) {
                        console.log('CSV export requested:', data);
                        alert('CSV export is not available in the standalone report. Please use the original SketchUp extension.');
                    },
                    print_pdf: function(data) {
                        console.log('PDF export requested');
                        window.print();
                    }
                };
                
                function callRuby(method, args) {
                    if (window.sketchup && window.sketchup[method]) {
                        window.sketchup[method](args);
                    } else {
                        console.log('Ruby method called:', method, args);
                    }
                }
                
                // Initialize the report with embedded data
                document.addEventListener('DOMContentLoaded', function() {
                    // Set up global settings from embedded data
                    if (EMBEDDED_DATA.settings) {
                        window.currentUnits = EMBEDDED_DATA.settings.units || 'mm';
                        window.currentPrecision = EMBEDDED_DATA.settings.precision ?? 1;
                        window.currentAreaUnits = EMBEDDED_DATA.settings.area_units || 'm2';
                        window.defaultCurrency = EMBEDDED_DATA.settings.default_currency || 'USD';
                    }
                    
                    // Initialize globals
                    window.currencySymbols = window.currencySymbols || {
                        'USD': '$', 'EUR': 'Ôé¼', 'GBP': '┬ú', 'JPY': '┬Ñ', 'CAD': '$', 'AUD': '$',
                        'CHF': 'CHF', 'CNY': '┬Ñ', 'SEK': 'kr', 'NZD': '$', 'SAR': 'SAR', 'AED': 'Ï».ÏÑ'
                    };
                    
                    window.areaFactors = window.areaFactors || {
                        'mm2': 1, 'cm2': 100, 'm2': 1000000, 'in2': 645.16, 'ft2': 92903.04
                    };
                    
                    window.unitFactors = window.unitFactors || {
                        'mm': 1, 'cm': 10, 'm': 1000, 'in': 25.4, 'ft': 304.8
                    };
                    
                    // Load the report data
                    if (typeof receiveData === 'function') {
                        receiveData(EMBEDDED_DATA);
                    }
                    
                    // Show report tab by default
                    setTimeout(() => {
                        if (typeof showTab === 'function') {
                            showTab('report');
                        }
                        
                        // Initialize resizer
                        if (typeof initResizer === 'function') {
                            initResizer();
                        }
                        
                        // Ensure cut sequences and offcuts are rendered
                        setTimeout(() => {
                            if (EMBEDDED_DATA.report) {
                                if (typeof renderCutSequences === 'function' && EMBEDDED_DATA.report.cut_sequences) {
                                    renderCutSequences(EMBEDDED_DATA.report);
                                }
                                if (typeof renderOffcutsTable === 'function' && EMBEDDED_DATA.report.usable_offcuts) {
                                    renderOffcutsTable(EMBEDDED_DATA.report);
                                }
                            }
                            
                            // Reinitialize table customization after all tables are rendered
                            if (typeof reinitializeTableCustomization === 'function') {
                                reinitializeTableCustomization();
                            }
                        }, 600);
                    }, 100);
                    
                    // Fix modal close functionality
                    const modal = document.getElementById('partModal');
                    if (modal) {
                        const closeBtn = modal.querySelector('.close');
                        if (closeBtn) {
                            closeBtn.onclick = function() {
                                modal.style.display = 'none';
                            };
                        }
                        
                        window.onclick = function(event) {
                            if (event.target === modal) {
                                modal.style.display = 'none';
                            }
                        };
                        
                        document.addEventListener('keydown', function(e) {
                            if (e.key === 'Escape' && modal.style.display === 'block') {
                                modal.style.display = 'none';
                            }
                        });
                    }
                });
            </script>
            
            <script>
                #{diagrams_js}
            </script>
            
            <script>
                #{resizer_js}
            </script>
            
            <script>
                #{table_customization_js}
            </script>
            
            <script>
                // Initialize table customization for exported HTML
                document.addEventListener('DOMContentLoaded', function() {
                    // Load saved table settings from localStorage before rendering
                    if (typeof loadTableSettings === 'function') {
                        loadTableSettings();
                    }
                    
                    // Delay initialization to ensure tables are rendered
                    setTimeout(() => {
                        if (typeof initTableCustomization === 'function') {
                            initTableCustomization();
                        }
                        
                        // Ensure all tables have proper IDs
                        document.querySelectorAll('.table-with-controls table').forEach((table, idx) => {
                            if (!table.id) {
                                table.id = `exportedTable_${idx}`;
                            }
                        });
                        
                        // Apply saved settings immediately
                        if (typeof applyAllTableSettings === 'function') {
                            applyAllTableSettings();
                        }
                    }, 800);
                });
            </script>
            
            <script>
                // Additional export-specific functionality
                
                // Override export functions for standalone mode
                function exportInteractiveHTML() {
                    alert('You are already viewing the interactive HTML report!');
                }
                
                function exportToPDF() {
                    window.print();
                }
                
                // Enhanced print styles
                const printStyles = document.createElement('style');
                printStyles.textContent = `
                    @media print {
                        .export-info { display: none; }
                        .header-controls { display: none; }
                        .report-header { display: none; }
                        .table-controls { display: none; }
                        .modal-overlay { display: none; }
                        .table-customization-panel { display: none; }
                        #resizer { display: none; }
                        .container { display: block; }
                        .diagrams-container, .report-container { 
                            width: 100% !important;
                            flex: none !important;
                            page-break-inside: avoid;
                        }
                        .diagram-card { 
                            page-break-inside: avoid;
                            margin-bottom: 20px;
                        }
                        .table-with-controls {
                            page-break-inside: avoid;
                            margin-bottom: 20px;
                        }
                    }
                `;
                document.head.appendChild(printStyles);
                
                // Enhanced auto-scroll to diagram functionality with piece highlighting
                function scrollToPieceDiagram(partId, boardNumber) {
                    // Find the board diagram that contains this piece
                    const boardIndex = boardNumber - 1;
                    
                    if (boardIndex < 0 || boardIndex >= (window.g_boardsData || []).length) {
                        console.warn(`Board ${boardNumber} not found`);
                        return;
                    }
                    
                    const diagramContainer = document.getElementById('diagramsContainer');
                    if (!diagramContainer) {
                        console.warn('Diagrams container not found');
                        return;
                    }
                    
                    // Find the canvas for this board
                    const diagrams = diagramContainer.querySelectorAll('.diagram-card');
                    let targetCard = null;
                    let targetCanvas = null;
                    
                    if (boardIndex < diagrams.length) {
                        targetCard = diagrams[boardIndex];
                        targetCanvas = targetCard.querySelector('canvas');
                    }
                    
                    if (targetCard) {
                        // Scroll the diagram card into view with smooth animation
                        targetCard.scrollIntoView({ 
                            behavior: 'smooth', 
                            block: 'center',
                            inline: 'nearest'
                        });
                        
                        // Add visual highlight to the card
                        targetCard.style.transition = 'all 0.3s ease';
                        targetCard.style.boxShadow = '0 0 20px rgba(0, 124, 186, 0.5)';
                        targetCard.style.transform = 'scale(1.02)';
                        
                        // Highlight the specific piece on the canvas if possible
                        if (targetCanvas && targetCanvas.partData) {
                            highlightPieceOnCanvas(targetCanvas, partId);
                        }
                        
                        setTimeout(() => {
                            targetCard.style.boxShadow = '';
                            targetCard.style.transform = '';
                        }, 3000);
                    }
                }
                
                // Highlight specific piece on canvas
                function highlightPieceOnCanvas(canvas, partId) {
                    if (!canvas.partData) return;
                    
                    const ctx = canvas.getContext('2d');
                    
                    // Find the piece with matching ID
                    for (let partData of canvas.partData) {
                        const partLabel = String(partData.part.instance_id || partData.part.part_unique_id || '');
                        if (partLabel === partId) {
                            // Draw highlight border around the piece
                            ctx.save();
                            ctx.strokeStyle = '#ff6b35';
                            ctx.lineWidth = 4;
                            ctx.setLineDash([8, 4]);
                            
                            // Draw animated highlight
                            let dashOffset = 0;
                            const animateHighlight = () => {
                                ctx.clearRect(partData.x - 6, partData.y - 6, partData.width + 12, partData.height + 12);
                                
                                // Redraw the piece (simplified)
                                ctx.fillStyle = getMaterialColor(partData.part.material);
                                ctx.fillRect(partData.x, partData.y, partData.width, partData.height);
                                
                                // Draw animated highlight
                                ctx.lineDashOffset = dashOffset;
                                ctx.strokeRect(partData.x - 2, partData.y - 2, partData.width + 4, partData.height + 4);
                                
                                dashOffset += 0.5;
                                if (dashOffset < 50) {
                                    requestAnimationFrame(animateHighlight);
                                } else {
                                    // Redraw canvas normally
                                    if (canvas.drawCanvas) {
                                        canvas.drawCanvas();
                                    }
                                }
                            };
                            
                            animateHighlight();
                            ctx.restore();
                            break;
                        }
                    }
                }
                
                // Make scrollToPieceDiagram globally available
                window.scrollToPieceDiagram = scrollToPieceDiagram;
            </script>
        </body>
        </html>
      HTML
      
      html_template
    end
    
    def clean_html_for_export(html_content)
      # Remove SketchUp-specific buttons and elements
      html_content = html_content.gsub(/<button[^>]*onclick="processNesting\(\)"[^>]*>.*?<\/button>/m, '')
      html_content = html_content.gsub(/<button[^>]*onclick="refreshConfiguration\(\)"[^>]*>.*?<\/button>/m, '')
      html_content = html_content.gsub(/<button[^>]*onclick="window\.close\(\)"[^>]*>.*?<\/button>/m, '')
      
      # Remove external script references (we embed them inline)
      html_content = html_content.gsub(/<script[^>]*src="app\.js"[^>]*><\/script>/m, '')
      html_content = html_content.gsub(/<script[^>]*src="diagrams_report\.js"[^>]*><\/script>/m, '')
      html_content = html_content.gsub(/<script[^>]*src="resizer_fix\.js"[^>]*><\/script>/m, '')
      html_content = html_content.gsub(/<script[^>]*src="table_customization\.js"[^>]*><\/script>/m, '')
      html_content = html_content.gsub(/<script[^>]*src="export_validator\.js"[^>]*><\/script>/m, '')
      
      html_content
    end
    
    private
    

    
    def calculate_usable_offcuts(boards)
      offcuts = []
      
      boards.each_with_index do |board, index|
        # Calculate remaining area after parts placement
        used_area = board.parts_on_board.sum { |p| p.area || 0 }
        remaining_area = (board.total_area || 0) - used_area
        
        # Only consider significant offcuts (>0.01 m2)
        if remaining_area > 10000 # 10000 mm2 = 0.01 m2
          # Estimate usable dimensions (simplified) with division by zero protection
          stock_width = board.stock_width || 2440
          stock_height = board.stock_height || 1220
          
          estimated_width = [(stock_width * 0.8).round(0), 100].max # Minimum 100mm width
          estimated_height = estimated_width > 0 ? (remaining_area / estimated_width).round(0) : 0
          
          offcuts << {
            board_number: index + 1,
            material: board.material,
            estimated_dimensions: "#{estimated_width} x #{estimated_height}mm",
            area: remaining_area.round(0),
            area_m2: (remaining_area / 1000000.0).round(3)
          }
        end
      end
      
      offcuts
    end

    def self.generate_scheduled_report(filters, format)
      # Get current model data
      model = Sketchup.active_model
      selection = model.selection.empty? ? model.entities : model.selection
      
      # Analyze model
      analyzer = AutoNestCut::Processors::ModelAnalyzer.new
      parts_by_material = analyzer.analyze_selection(selection) # Renamed parts to parts_by_material
      
      # Convert the parts_by_material hash into a flat array of part objects for filtering and nesting
      all_parts_for_nesting = []
      parts_by_material.each do |material_name, part_types_array|
        part_types_array.each do |part_type_data|
          part_type = part_type_data[:part_type]
          quantity = part_type_data[:total_quantity]
          quantity.times { all_parts_for_nesting << part_type.create_placed_instance } # Create instances for nesting
        end
      end
      
      # Apply filters
      filtered_parts = apply_filters(all_parts_for_nesting, filters) # Use the flattened array
      
      # Get current global settings (need this for nester)
      current_settings = Config.get_cached_settings
      
      # Generate nesting
      nester = AutoNestCut::Processors::Nester.new
      boards = nester.nest_parts(filtered_parts, current_settings) # Pass settings to nester
      
      # Generate report in requested format
      generator = new
      report_data = generator.generate_report_data(boards, current_settings) # Pass settings to report_data generation
      
      case format.downcase
      when 'csv'
        generate_csv_data(report_data)
      when 'json'
        report_data.to_json
      else
        report_data.to_json
      end
    end
    
    private
    
    def self.apply_filters(parts, filters)
      return parts unless filters && !filters.empty?
      
      filtered = parts
      filtered = filtered.select { |p| p.material == filters['material'] } if filters['material'] && filters['material'] != 'All'
      filtered = filtered.select { |p| p.thickness >= filters['min_thickness'] } if filters['min_thickness'] && filters['min_thickness'].to_f > 0
      filtered = filtered.select { |p| p.thickness <= filters['max_thickness'] } if filters['max_thickness'] && filters['max_thickness'].to_f > 0
      filtered
    end
    
    def self.generate_csv_data(report_data)
      csv_string = ""
      CSV.generate(csv_string) do |csv|
        csv << ["UNIQUE PART TYPES SUMMARY"]
        csv << ["Name", "Width (mm)", "Height (mm)", "Thickness (mm)", "Material", "Quantity", "Total Area (mm2)"]
        (report_data[:unique_part_types] || []).each do |part|
          csv << [
            part[:name].to_s,
            (part[:width] || 0).to_f.round(2),
            (part[:height] || 0).to_f.round(2),
            (part[:thickness] || 0).to_f.round(2),
            part[:material].to_s,
            (part[:total_quantity] || 0).to_i,
            (part[:total_area] || 0).to_f.round(2)
          ]
        end
        
        csv << []
        csv << ["SUMMARY"]
        summary = report_data[:summary] || {}
        csv << ["Total Parts", (summary[:total_parts_instances] || 0).to_i]
        csv << ["Total Boards", (summary[:total_boards] || 0).to_i]
        currency_symbol = case (summary[:currency] || 'USD')
                         when 'USD' then '$'
                         when 'EUR' then 'Ôé¼'
                         when 'GBP' then '┬ú'
                         when 'SAR' then 'SAR '
                         when 'AED' then 'Ï».ÏÑ '
                         else (summary[:currency] || 'USD') + ' '
                         end
        csv << ["Total Cost", "#{currency_symbol}#{('%.2f' % (summary[:total_project_cost] || 0).to_f)}"]
      end
      csv_string
    end
    
      end
end
