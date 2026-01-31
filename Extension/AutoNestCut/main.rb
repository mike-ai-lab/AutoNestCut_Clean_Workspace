# frozen_string_literal: true

require 'sketchup.rb'

# Check SketchUp version compatibility
if Sketchup.version.to_i < 20
  UI.messagebox("AutoNestCut requires SketchUp 2020 or later. Current version: #{Sketchup.version}")
  return
end

# Load licensing system first
begin
  require_relative '../lib/LicenseManager/license_manager'
  require_relative '../lib/LicenseManager/trial_manager'
  require_relative '../lib/LicenseManager/license_dialog'
  puts "Licensing system loaded successfully"
rescue LoadError => e
  puts "Warning: Could not load licensing system: #{e.message}"
end

module AutoNestCut
  # Core extension files
  require_relative 'compatibility'
  require_relative 'materials_database'
  require_relative 'config'
  require_relative 'models/part'
  require_relative 'models/board'
  require_relative 'models/facade_surface'
  require_relative 'models/cladding_preset'
  require_relative 'processors/model_analyzer'
  require_relative 'processors/nester'
  require_relative 'processors/facade_analyzer'
  require_relative 'processors/component_cache'

  require_relative 'ui/dialog_manager'
  require_relative 'ui/missing_materials_ui'
  require_relative 'ui/progress_dialog'
  require_relative 'ui/view_export_ui'
  require_relative 'ui/material_database_ui'
  require_relative 'processors/async_processor'
  require_relative 'exporters/diagram_generator'
  require_relative 'exporters/report_generator'
  require_relative 'exporters/pdf_generator'
  require_relative 'exporters/facade_reporter'
  require_relative 'exporters/assembly_exporter'
  require_relative 'exporters/svg_vector_exporter'
  require_relative 'exporters/view_export_handler'
  require_relative 'exporters/qr_code_generator'
  require_relative 'exporters/label_generator'
  require_relative 'exporters/label_sheet_generator'
  require_relative 'ui/svg_export_ui'
  require_relative 'scheduler'
  require_relative 'supabase_client'
  require_relative 'util'

  # Utility method for cache-busting HTML dialogs
  def self.set_html_with_cache_busting(dialog, html_file_path)
    cache_buster = Time.now.to_i.to_s
    
    # Read the HTML content
    html_content = File.read(html_file_path, encoding: 'UTF-8')
    
    # Replace relative paths with cache-busted absolute paths
    html_content.gsub!(/(src|href)="(?!https?:\/\/)([^"]*?)"/) do |match|
      type = $1 # 'src' or 'href'
      relative_path = $2 # The actual path
      
      # Skip if it's already an absolute URL or data URL
      next match if relative_path.start_with?('http', 'data:', '//')
      
      # Construct absolute path from the directory of the HTML file
      absolute_path = File.join(File.dirname(html_file_path), relative_path)
      absolute_url = "file:///#{File.expand_path(absolute_path).gsub('\\', '/')}"
      
      # Append cache buster
      "#{type}=\"#{absolute_url}?v=#{cache_buster}\""
    end
    
    # Add cache-busting meta tags and timestamp comment to force reload
    if html_content =~ /<head[^>]*>/i
      cache_meta = <<~META
        <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
        <meta http-equiv="Pragma" content="no-cache">
        <meta http-equiv="Expires" content="0">
        <!-- Cache Buster: #{cache_buster} -->
      META
      html_content.sub!(/<head[^>]*>/i, "\\0\n#{cache_meta}")
    end
    
    # Set the modified HTML content
    dialog.set_html(html_content)
  end

  EXTENSION_NAME = 'Auto Nest Cut'.freeze unless defined?(EXTENSION_NAME)
  EXTENSION_VERSION = '1.0.0'.freeze unless defined?(EXTENSION_VERSION)
  EXTENSION_BUILD = '20250119_1445'.freeze unless defined?(EXTENSION_BUILD)
  EXTENSION_DESCRIPTION = 'Automated nesting and cut list generation for sheet goods.'.freeze unless defined?(EXTENSION_DESCRIPTION)
  EXTENSION_CREATOR = 'Muhamad Shkeir'.freeze unless defined?(EXTENSION_CREATOR)

  # Get the path to the current directory where this file resides
  PATH_ROOT = File.dirname(__FILE__).freeze

  def self.show_documentation
    html_file = File.join(__dir__, 'ui', 'html', 'documentation.html')

    if File.exist?(html_file)
      dialog = UI::HtmlDialog.new(
        dialog_title: "AutoNestCut Documentation",
        preferences_key: "AutoNestCut_Documentation",
        scrollable: true,
        resizable: true,
        width: 1000,
        height: 700,
        left: 100,
        top: 100,
        min_width: 800,
        min_height: 600,
        style: UI::HtmlDialog::STYLE_DIALOG
      )

      AutoNestCut.set_html_with_cache_busting(dialog, html_file)
      dialog.show
    else
      UI.messagebox("Documentation file not found at: #{html_file}")
    end
  end

  def self.open_purchase_page
    purchase_url = "https://autonestcutserver-moeshks-projects.vercel.app"
    UI.openURL(purchase_url)
  end

  # This method is the primary entry point for the extension's main functionality.
  # It's defined directly as a module method (`self.method_name`) for clarity and robustness.
  # Renamed from `activate_extension` to `run_extension_feature` to avoid confusion
  # with SketchUp's internal terminology for extension activation.
  def self.run_extension_feature
    # Check license before allowing extension use
    if defined?(AutoNestCut::LicenseManager)
      unless AutoNestCut::LicenseManager.has_valid_license?
        AutoNestCut::LicenseDialog.show_license_options
        return unless AutoNestCut::LicenseManager.has_valid_license?
      end

      # Start trial countdown if using trial license
      if defined?(AutoNestCut::TrialManager)
        AutoNestCut::TrialManager.start_trial_countdown
      end
    end

    model = Sketchup.active_model
    selection = model.selection

    if selection.empty?
      UI.messagebox("Please select components or groups to analyze for AutoNestCut.")
      return
    end

    begin
      # Initialize async processor (optional)
      # async_processor = AsyncProcessor.new if defined?(AsyncProcessor)
      
      # Store original selection entity for assembly export
      assembly_entity = selection.length == 1 ? selection.first : nil
      
      # Check cache first
      cached = AutoNestCut::ComponentCache.get_cached_analysis(selection)
      
      if cached
        # Validate and check for missing materials
        validator = ComponentValidator.new
        existing_materials = MaterialsDatabase.load_database.merge(MaterialsDatabase.get_default_materials)
        validation_result = validator.validate_and_prepare_materials(cached[:parts_by_material])
        
        # CRITICAL FIX: Apply automatic remappings for materials found with thickness suffixes
        if validation_result[:material_remappings] && validation_result[:material_remappings].any?
          puts "\n🦟 AUTO-REMAPPING: Applying #{validation_result[:material_remappings].length} material remappings"
          validation_result[:material_remappings].each do |original_material, thickness_map|
            thickness_map.each do |thickness, actual_material_name|
              if cached[:parts_by_material].key?(original_material)
                all_parts = cached[:parts_by_material][original_material]
                
                # Filter parts by thickness
                matching_parts = all_parts.select do |part_entry|
                  part_obj = part_entry.is_a?(Hash) && part_entry.key?(:part_type) ? part_entry[:part_type] : part_entry
                  part_obj.thickness.to_f == thickness
                end
                
                other_parts = all_parts - matching_parts
                
                if matching_parts.any?
                  puts "  → Remapping '#{original_material}' (#{thickness}mm) to '#{actual_material_name}' (#{matching_parts.length} parts)"
                  cached[:parts_by_material][actual_material_name] ||= []
                  cached[:parts_by_material][actual_material_name] += matching_parts
                  
                  if other_parts.any?
                    cached[:parts_by_material][original_material] = other_parts
                  else
                    cached[:parts_by_material].delete(original_material)
                  end
                end
              end
            end
          end
          puts "🦟 AUTO-REMAPPING: Complete\n"
        end
        
        if validation_result[:missing_materials].any?
          # Show missing materials dialog
          MissingMaterialsUI.show_dialog(validation_result[:missing_materials], existing_materials) do |user_choices|
            if user_choices
              # Process user choices and create/remap materials
              process_material_choices(user_choices, cached[:parts_by_material], existing_materials)
              
              # Now show config dialog (skip validation since we already handled it)
              dialog_manager = UIDialogManager.new
              dialog_manager.show_config_dialog(cached[:parts_by_material], cached[:original_components], cached[:hierarchy_tree], assembly_entity, true)
            else
              puts "User cancelled material resolution"
            end
          end
        else
          # No missing materials, proceed normally
          dialog_manager = UIDialogManager.new
          dialog_manager.show_config_dialog(cached[:parts_by_material], cached[:original_components], cached[:hierarchy_tree], assembly_entity)
        end
      else
        analyzer = ModelAnalyzer.new
        
        # --- FIX: Changed method call from extract_parts_from_selection to analyze_selection ---
        part_types_by_material_and_quantities = analyzer.analyze_selection(selection)
        # --- END FIX ---
        
        original_components = analyzer.get_original_components_data
        hierarchy_tree = analyzer.get_hierarchy_tree

        if part_types_by_material_and_quantities.empty?
          UI.messagebox("No valid sheet good parts found in your selection for AutoNestCut.")
          return
        end
        
        # Cache the results
        AutoNestCut::ComponentCache.cache_analysis(selection, part_types_by_material_and_quantities, original_components, hierarchy_tree)

        # Validate and check for missing materials
        validator = ComponentValidator.new
        existing_materials = MaterialsDatabase.load_database.merge(MaterialsDatabase.get_default_materials)
        validation_result = validator.validate_and_prepare_materials(part_types_by_material_and_quantities)
        
        # CRITICAL FIX: Apply automatic remappings for materials found with thickness suffixes
        if validation_result[:material_remappings] && validation_result[:material_remappings].any?
          puts "\n🦟 AUTO-REMAPPING: Applying #{validation_result[:material_remappings].length} material remappings"
          validation_result[:material_remappings].each do |original_material, thickness_map|
            thickness_map.each do |thickness, actual_material_name|
              if part_types_by_material_and_quantities.key?(original_material)
                all_parts = part_types_by_material_and_quantities[original_material]
                
                # Filter parts by thickness
                matching_parts = all_parts.select do |part_entry|
                  part_obj = part_entry.is_a?(Hash) && part_entry.key?(:part_type) ? part_entry[:part_type] : part_entry
                  part_obj.thickness.to_f == thickness
                end
                
                other_parts = all_parts - matching_parts
                
                if matching_parts.any?
                  puts "  → Remapping '#{original_material}' (#{thickness}mm) to '#{actual_material_name}' (#{matching_parts.length} parts)"
                  part_types_by_material_and_quantities[actual_material_name] ||= []
                  part_types_by_material_and_quantities[actual_material_name] += matching_parts
                  
                  if other_parts.any?
                    part_types_by_material_and_quantities[original_material] = other_parts
                  else
                    part_types_by_material_and_quantities.delete(original_material)
                  end
                end
              end
            end
          end
          puts "🦟 AUTO-REMAPPING: Complete\n"
        end
        
        if validation_result[:missing_materials].any?
          # Show missing materials dialog
          MissingMaterialsUI.show_dialog(validation_result[:missing_materials], existing_materials) do |user_choices|
            if user_choices
              # Process user choices and create/remap materials
              process_material_choices(user_choices, part_types_by_material_and_quantities, existing_materials)
              
              # Now show config dialog (skip validation since we already handled it)
              dialog_manager = UIDialogManager.new
              dialog_manager.show_config_dialog(part_types_by_material_and_quantities, original_components, hierarchy_tree, assembly_entity, true)
            else
              puts "User cancelled material resolution"
            end
          end
        else
          # No missing materials, proceed normally
          dialog_manager = UIDialogManager.new
          dialog_manager.show_config_dialog(part_types_by_material_and_quantities, original_components, hierarchy_tree, assembly_entity)
        end
      end

    rescue => e
      UI.messagebox("An error occurred during part extraction:\n#{e.message}")
    end
  end

  # Process user choices from missing materials dialog
  def self.process_material_choices(user_choices, parts_by_material, existing_materials)
    puts "=" * 80
    puts "🦟 PROCESSING MATERIAL CHOICES"
    puts "=" * 80
    puts "Received #{user_choices.length} choices"
    puts "User choices JSON: #{user_choices.inspect}"
    puts ""
    
    materials_to_save = {}
    
    user_choices.each do |index_str, choice|
      material_name = choice['materialName']
      thickness = choice['thickness'].to_f
      
      puts "Processing choice #{index_str}:"
      puts "  Material: #{material_name}"
      puts "  Thickness: #{thickness}mm"
      puts "  Type: #{choice['type']}"
      puts ""
      
      case choice['type']
      when 'existing'
        # Remap to existing material
        existing_material_name = choice['existingMaterial']
        puts "  → REMAPPING '#{material_name}' (#{thickness}mm) to '#{existing_material_name}'"
        puts "    Parts before remap: #{parts_by_material.keys.inspect}"
        
        # CRITICAL: Filter parts by BOTH material name AND thickness
        # This handles cases where the same material name has multiple thicknesses
        if parts_by_material.key?(material_name)
          all_parts = parts_by_material[material_name]
          
          # Separate parts by thickness
          matching_thickness_parts = []
          other_thickness_parts = []
          
          all_parts.each do |part_entry|
            part_obj = part_entry.is_a?(Hash) ? part_entry[:part_type] : part_entry
            part_thickness = part_obj.respond_to?(:thickness) ? part_obj.thickness.to_f : 0.0
            
            if (part_thickness - thickness).abs < 0.1
              matching_thickness_parts << part_entry
            else
              other_thickness_parts << part_entry
            end
          end
          
          puts "    Found #{matching_thickness_parts.length} parts with #{thickness}mm thickness"
          puts "    Found #{other_thickness_parts.length} parts with other thicknesses"
          
          if matching_thickness_parts.any?
            # Remap only the matching thickness parts
            if parts_by_material.key?(existing_material_name)
              parts_by_material[existing_material_name].concat(matching_thickness_parts)
              puts "    ✓ Merged #{matching_thickness_parts.length} parts with existing material"
            else
              parts_by_material[existing_material_name] = matching_thickness_parts
              puts "    ✓ Remapped #{matching_thickness_parts.length} parts to new key"
            end
            
            # Keep other thickness parts under original key, or delete if none left
            if other_thickness_parts.any?
              parts_by_material[material_name] = other_thickness_parts
              puts "    ✓ Kept #{other_thickness_parts.length} parts with other thicknesses under '#{material_name}'"
            else
              parts_by_material.delete(material_name)
              puts "    ✓ Removed '#{material_name}' (all parts remapped)"
            end
          else
            puts "    ✗ WARNING: No parts found with #{thickness}mm thickness for '#{material_name}'!"
          end
          
          puts "    Parts after remap: #{parts_by_material.keys.inspect}"
        else
          puts "    ✗ WARNING: Material '#{material_name}' not found in parts_by_material!"
        end
        
      when 'standard'
        # Create standard sheet material
        width = choice['width'].to_f
        height = choice['height'].to_f
        save_to_db = choice['saveToDb']
        
        puts "  → Creating standard sheet '#{material_name}' (#{width}x#{height}x#{thickness}mm)"
        
        material_data = {
          'width' => width,
          'height' => height,
          'thickness' => thickness,
          'price' => 300,
          'currency' => Config.get_cached_settings['default_currency'] || 'USD',
          'density' => 600,
          'auto_generated' => false,
          'created_at' => Time.now.to_s
        }
        
        if save_to_db
          # CRITICAL: Add to array instead of overwriting
          if materials_to_save.key?(material_name)
            # Check if this thickness already exists
            existing_thicknesses = materials_to_save[material_name].map { |m| m['thickness'] }
            unless existing_thicknesses.any? { |t| (t - thickness).abs < 0.01 }
              materials_to_save[material_name] << material_data
              puts "    ✓ Will add #{thickness}mm thickness to existing '#{material_name}'"
            else
              puts "    ℹ️  Thickness #{thickness}mm already exists for '#{material_name}'"
            end
          else
            materials_to_save[material_name] = [material_data]
            puts "    ✓ Will save to database as '#{material_name}'"
          end
        else
          # Add to existing_materials for this session only
          if existing_materials.key?(material_name)
            existing_materials[material_name] = [existing_materials[material_name]] unless existing_materials[material_name].is_a?(Array)
            existing_thicknesses = existing_materials[material_name].map { |m| m['thickness'] }
            unless existing_thicknesses.any? { |t| (t - thickness).abs < 0.01 }
              existing_materials[material_name] << material_data
            end
          else
            existing_materials[material_name] = [material_data]
          end
          puts "    ✓ Session only (not saved) as '#{material_name}'"
        end
        
        # Parts already use this material name, no remapping needed
        if parts_by_material.key?(material_name)
          all_parts = parts_by_material[material_name]
          matching_count = all_parts.count do |part_entry|
            part_obj = part_entry.is_a?(Hash) ? part_entry[:part_type] : part_entry
            part_thickness = part_obj.respond_to?(:thickness) ? part_obj.thickness.to_f : 0.0
            (part_thickness - thickness).abs < 0.1
          end
          puts "    ✓ #{matching_count} parts will use this material"
        end
        
      when 'custom'
        # Create custom part material (exact dimensions from first component)
        puts "  → Creating custom part '#{material_name}' (exact dimensions)"
        
        # CRITICAL FIX: Use original material name with _custom suffix only
        # No thickness in the name - thickness is in the data
        unique_material_name = "#{material_name}_custom"
        
        # Get parts with matching thickness
        if parts_by_material.key?(material_name)
          all_parts = parts_by_material[material_name]
          
          # Separate parts by thickness
          matching_thickness_parts = []
          other_thickness_parts = []
          
          all_parts.each do |part_entry|
            part_obj = part_entry.is_a?(Hash) ? part_entry[:part_type] : part_entry
            part_thickness = part_obj.respond_to?(:thickness) ? part_obj.thickness.to_f : 0.0
            
            if (part_thickness - thickness).abs < 0.1
              matching_thickness_parts << part_entry
            else
              other_thickness_parts << part_entry
            end
          end
          
          puts "    Found #{matching_thickness_parts.length} parts with #{thickness}mm thickness"
          
          if matching_thickness_parts.any?
            first_part = matching_thickness_parts.first
            part_obj = first_part.is_a?(Hash) ? first_part[:part_type] : first_part
            
            if part_obj.respond_to?(:width) && part_obj.respond_to?(:height)
              material_data = {
                'width' => part_obj.width.to_f,
                'height' => part_obj.height.to_f,
                'thickness' => thickness,
                'price' => 300,
                'currency' => Config.get_cached_settings['default_currency'] || 'USD',
                'density' => 600,
                'auto_generated' => true,
                'created_at' => Time.now.to_s
              }
              
              # Custom parts are not saved to database
              existing_materials[unique_material_name] = material_data
              puts "    ✓ Custom part created as '#{unique_material_name}' (not saved to database)"
              puts "    Dimensions: #{material_data['width']}x#{material_data['height']}x#{material_data['thickness']}mm"
              
              # Remap parts to unique material name
              parts_by_material[unique_material_name] = matching_thickness_parts
              puts "    ✓ Remapped #{matching_thickness_parts.length} parts to '#{unique_material_name}'"
              
              # Keep other thickness parts under original key, or delete if none left
              if other_thickness_parts.any?
                parts_by_material[material_name] = other_thickness_parts
                puts "    ✓ Kept #{other_thickness_parts.length} parts with other thicknesses under '#{material_name}'"
              else
                parts_by_material.delete(material_name)
                puts "    ✓ Removed '#{material_name}' (all parts remapped)"
              end
            else
              puts "    ✗ WARNING: Part object doesn't have width/height methods!"
            end
          else
            puts "    ✗ WARNING: No parts found with #{thickness}mm thickness!"
          end
        else
          puts "    ✗ WARNING: Material '#{material_name}' not found in parts_by_material!"
        end
      end
    end
    
    # Save materials to database if any
    if materials_to_save.any?
      current_db = MaterialsDatabase.load_database
      
      # CRITICAL: Merge arrays properly - don't overwrite, append!
      materials_to_save.each do |name, thickness_array|
        if current_db.key?(name)
          # Material exists - merge thickness arrays
          current_db[name] = [current_db[name]] unless current_db[name].is_a?(Array)
          thickness_array.each do |new_thickness_data|
            # Check if this thickness already exists
            existing_thicknesses = current_db[name].map { |m| m['thickness'] }
            unless existing_thicknesses.any? { |t| (t - new_thickness_data['thickness']).abs < 0.01 }
              current_db[name] << new_thickness_data
            end
          end
        else
          # New material
          current_db[name] = thickness_array
        end
      end
      
      MaterialsDatabase.save_database(current_db)
      total_saved = materials_to_save.values.sum(&:length)
      puts "✅ Saved #{materials_to_save.length} materials (#{total_saved} thickness variations) to database"
    end
    
    puts ""
    puts "🦟 FINAL STATE AFTER PROCESSING:"
    puts "  Materials in parts_by_material: #{parts_by_material.keys.inspect}"
    puts "  Materials in existing_materials: #{existing_materials.keys.length} total"
    puts "=" * 80
    puts "🦟 Material choices processed successfully"
    puts "=" * 80
    
    # CRITICAL FIX: Clear the cache after material remapping
    # This ensures the next run will analyze fresh from SketchUp instead of using cached old materials
    AutoNestCut::ComponentCache.clear_cache
    puts "🦟 Cache cleared after material remapping"
  end
  
  def self.show_scheduler
    html_file = File.join(__dir__, 'ui', 'html', 'scheduler.html')
    
    dialog = UI::HtmlDialog.new(
      dialog_title: "Scheduled Exports",
      preferences_key: "AutoNestCut_Scheduler",
      scrollable: true,
      resizable: true,
      width: 600,
      height: 500
    )
    
    AutoNestCut.set_html_with_cache_busting(dialog, html_file)
    
    # Add callbacks for scheduler operations
    dialog.add_action_callback('add_scheduled_task') do |context, name, hour, filters, format, email|
      Scheduler.add_task(name, hour, JSON.parse(filters), format, email)
    end
    
    dialog.add_action_callback('get_scheduled_tasks') do |context|
      tasks = Scheduler.load_tasks
      dialog.execute_script("displayTasks(#{tasks.to_json})")
    end
    
    dialog.add_action_callback('delete_scheduled_task') do |context, task_id|
      tasks = Scheduler.load_tasks
      tasks.reject! { |t| t[:id] == task_id }
      Scheduler.save_tasks(tasks)
    end
    
    dialog.show
  end

  def self.show_facade_calculator
    model = Sketchup.active_model
    selection = model.selection

    if selection.empty?
      UI.messagebox("Please select facade surfaces (faces) to analyze for material calculation.")
      return
    end

    html_file = File.join(__dir__, 'ui', 'html', 'facade_config.html')
    
    dialog = UI::HtmlDialog.new(
      dialog_title: "Facade Materials Calculator",
      preferences_key: "AutoNestCut_Facade",
      scrollable: true,
      resizable: true,
      width: 900,
      height: 700
    )
    
    AutoNestCut.set_html_with_cache_busting(dialog, html_file)
    
    # Initialize facade analyzer
    analyzer = FacadeAnalyzer.new
    surfaces = analyzer.analyze_selection(selection)
    
    # Add callbacks for facade operations
    dialog.add_action_callback('analyze_selected_surfaces') do |context|
      surface_info = {
        count: surfaces.length,
        area: surfaces.sum(&:area_m2).round(2),
        types: get_surface_types_summary(surfaces)
      }
      dialog.execute_script("updateSurfaceInfo(#{surface_info.to_json})")
    end
    
    dialog.add_action_callback('get_facade_presets') do |context|
      presets = load_facade_presets
      dialog.execute_script("displayPresets(#{presets.to_json})")
    end
    
    dialog.add_action_callback('calculate_facade_materials') do |context, settings_json|
      settings = JSON.parse(settings_json)
      preset = find_preset_by_name(settings['preset'])
      
      if preset
        quantities = analyzer.calculate_quantities(surfaces, preset)
        surface_breakdown = analyzer.generate_surface_breakdown(surfaces)
        
        reporter = FacadeReporter.new
        report_data = reporter.generate_facade_report(quantities, surface_breakdown, settings)
        
        dialog.execute_script("displayResults(#{report_data[:cost_estimation].to_json})")
        @last_facade_report = report_data
      end
    end
    
    dialog.add_action_callback('export_facade_report') do |context|
      if @last_facade_report
        filename = UI.savepanel("Save Facade Materials Report", "", "facade_materials.csv")
        if filename
          reporter = FacadeReporter.new
          reporter.export_facade_csv(filename, @last_facade_report)
          UI.messagebox("Facade materials report exported to: #{filename}")
        end
      end
    end
    
    dialog.show
  end

  def self.setup_ui
    # Create main menu
    menu = UI.menu('Extensions')
    autonest_menu = menu.add_submenu(EXTENSION_NAME)

    autonest_menu.add_item('Generate Cut List') { run_extension_feature }
    autonest_menu.add_item('🎯 Flatten for CNC (SVG Export)') { show_svg_export_dialog }
    autonest_menu.add_item('🏷️ Generate QR Label Sheet') { show_label_sheet_generator }
    autonest_menu.add_separator
    autonest_menu.add_item('Material Stock') { show_material_database }
    autonest_menu.add_separator
    autonest_menu.add_item('Documentation - How to...') { AutoNestCut.show_documentation }

    # Add license menu if licensing system is available
    if defined?(AutoNestCut::LicenseDialog)
      autonest_menu.add_separator
      autonest_menu.add_item('Purchase License') { AutoNestCut.open_purchase_page }
      autonest_menu.add_item('License Info') { AutoNestCut::LicenseDialog.show }
      autonest_menu.add_item('Trial Status') { AutoNestCut::LicenseDialog.show_trial_status }
    end

    # Create toolbar
    toolbar = UI::Toolbar.new(EXTENSION_NAME)
    cmd = UI::Command.new(EXTENSION_NAME) { run_extension_feature }
    cmd.tooltip = 'Generate optimized cut lists and nesting diagrams for sheet goods'
    cmd.status_bar_text = 'AutoNestCut - Automated nesting for sheet goods'

    icon_path = File.join(__dir__, 'resources', 'icon.png')
    if File.exist?(icon_path)
      cmd.small_icon = icon_path
      cmd.large_icon = icon_path
    end

    toolbar.add_item(cmd)
    toolbar.show
    
    # Add context menu for SVG export
    setup_context_menu
  end
  
  def self.show_svg_export_dialog
    entity = Sketchup.active_model.selection[0]
    
    unless entity && (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance))
      UI.messagebox(
        "Please select a component or group first.\n\nThe SVG export feature requires a valid 3D component.",
        MB_OK,
        "Selection Required"
      )
      return
    end
    
    SvgExportUI.show_svg_export_dialog(entity)
  end
  
  def self.show_material_database
    AutoNestCut::MaterialDatabaseUI.show_dialog
  end
  
  def self.setup_context_menu
    UI.add_context_menu_handler do |menu|
      entity = Sketchup.active_model.selection[0]
      
      if entity && (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance))
        menu.add_separator
        menu.add_item("🎯 Flatten for CNC (SVG)") do
          SvgExportUI.show_svg_export_dialog(entity)
        end
      end
    end
  end

  # Scheduler timer removed - feature was non-functional

  # Helper methods for facade calculator
  def self.get_surface_types_summary(surfaces)
    types = surfaces.group_by(&:orientation)
    summary = types.keys.join(', ')
    summary.empty? ? 'Mixed' : summary.capitalize
  end
  
  def self.load_facade_presets
    # For now, return built-in presets. Later can load from V121_LAYOUT presets
    [
      {
        name: 'Standard Brick',
        dimensions: '215x65x20mm',
        pattern: 'Running Bond'
      },
      {
        name: 'Large Stone',
        dimensions: '400x200x30mm', 
        pattern: 'Stack Bond'
      },
      {
        name: 'Small Tiles',
        dimensions: '200x200x10mm',
        pattern: 'Grid'
      }
    ]
  end
  
  def self.find_preset_by_name(name)
    # Create a basic preset for testing
    preset_data = {
      'length' => '215',
      'height' => '65', 
      'thickness' => 20.0,
      'joint_length' => 10.0,
      'joint_width' => 10.0,
      'pattern_type' => 'running_bond',
      'color_name' => name
    }
    CladdingPreset.new(preset_data, name)
  end

  # Module initialization
  timestamp = Time.now.strftime("%H:%M:%S")
  puts "✅ AutoNestCut Module Loaded [#{timestamp}] - Build: #{EXTENSION_BUILD}"
  
  setup_ui
  
  if defined?(AutoNestCut::LicenseManager) && defined?(AutoNestCut::TrialManager)
    unless AutoNestCut::LicenseManager.has_valid_license?
      AutoNestCut::LicenseManager.check_existing_trial(false)
    end
    
    if AutoNestCut::TrialManager.trial_active?
      AutoNestCut::TrialManager.start_trial_countdown
    end
  end

end # End of module AutoNestCut
