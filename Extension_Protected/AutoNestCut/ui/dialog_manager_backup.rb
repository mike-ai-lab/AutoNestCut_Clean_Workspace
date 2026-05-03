require 'json'
require 'thread' # Required for using Ruby's Thread and Queue classes
require 'digest' # Required for generating cache keys (e.g., MD5)
require_relative '../config' # Ensure the Config module is loaded
require_relative '../materials_database' # Ensure MaterialsDatabase is loaded
require_relative '../exporters/report_generator' # Ensure ReportGenerator is loaded
require_relative '../processors/model_analyzer' # Ensure ModelAnalyzer is loaded
require_relative '../processors/nester' # Ensure Nester is loaded
require_relative '../compatibility' # Ensure Compatibility is loaded for desktop_path etc.
require_relative '../models/part' # Ensure Part class is loaded

module AutoNestCut
  class UIDialogManager

    # Cache for nesting results to avoid recalculating if inputs haven't changed
    # Key: cache_key (MD5 hash of parts and nesting settings), Value: Array of Board objects
    @nesting_cache = {}

    # Flag to indicate if processing was cancelled by user
    @processing_cancelled = false

    def initialize
      # Ensure cache and cancellation flag are initialized for each new manager instance
      @nesting_cache = {}
      @processing_cancelled = false
    end

    def show_config_dialog(parts_by_material, original_components = [], hierarchy_tree = [], assembly_entity = nil)
      @parts_by_material = parts_by_material
      @original_components = original_components
      @hierarchy_tree = hierarchy_tree
      @assembly_entity = assembly_entity
      @assembly_data = nil
      
      # Capture assembly data if entity is provided
      if @assembly_entity
        @assembly_data = capture_assembly_data(@assembly_entity)
        puts "DEBUG: Assembly data captured: #{@assembly_data.keys.inspect}"
      end
      
      # Use HtmlDialog for SU2017+ or WebDialog for older versions
      if defined?(UI::HtmlDialog)
        @dialog = UI::HtmlDialog.new(
          dialog_title: "AutoNestCut",
          preferences_key: "AutoNestCut_Main",
          scrollable: true,
          resizable: true,
          width: 620,
          height: 420
        )
      else
        @dialog = UI::WebDialog.new(
          "AutoNestCut",
          true,
          "AutoNestCut_Main",
          1200, # Fallback to a larger size for WebDialog
          750,
          100,
          100,
          true
        )
      end

      html_file = File.join(__dir__, 'html', 'main.html')
      @dialog.set_file(html_file)

      # Send initial data to dialog when it's ready
      @dialog.add_action_callback("ready") do |action_context|
        puts "DEBUG: Frontend is ready. Sending initial data."
        send_initial_data
      end

      # Handle global settings update from UI (units, precision, currency, area_units)
      @dialog.add_action_callback("update_global_setting") do |action_context, setting_json|
        begin
          setting_data = JSON.parse(setting_json)
          key = setting_data['key']
          value = setting_data['value']
          
          # Use Config module for persistence
          Config.save_global_settings({key => value})
          puts "DEBUG: Global setting updated: #{key} = #{value}"
          
          # After updating a global setting, re-send initial data to ensure UI consistency
          # The JS `receiveInitialData` will then trigger `displayMaterials` and `renderReport` as needed.
          send_initial_data
        rescue => e
          puts "ERROR updating global setting: #{e.message}"
          @dialog.execute_script("showError('Error updating setting: #{e.message.gsub("'", "\\'")}')")
        end
      end

      # Handle materials database save from UI
      @dialog.add_action_callback("save_materials") do |action_context, materials_json|
        begin
          materials = JSON.parse(materials_json)
          MaterialsDatabase.save_database(materials)
          puts "DEBUG: Materials database saved successfully."
        rescue => e
          puts "ERROR saving materials: #{e.message}"
          @dialog.execute_script("showError('Error saving materials: #{e.message.gsub("'", "\\'")}')")
        end
      end

      # Handle processing (nesting and report generation)
      @dialog.add_action_callback("process") do |action_context, settings_json|
        begin
          puts "DEBUG: Process callback started"
          new_settings_from_ui = JSON.parse(settings_json)
          
          # Save global settings from the UI's full settings object
          Config.save_global_settings({
            'kerf_width' => new_settings_from_ui['kerf_width'],
            'allow_rotation' => new_settings_from_ui['allow_rotation'],
            'default_currency' => new_settings_from_ui['default_currency'],
            'units' => new_settings_from_ui['units'],
            'precision' => new_settings_from_ui['precision'],
            'area_units' => new_settings_from_ui['area_units']
          })
          
          # Save material data (including updates to prices/dimensions if any)
          MaterialsDatabase.save_database(new_settings_from_ui['stock_materials'])

          # Always use async processing for nesting (with caching)
          # Fetch the *latest* settings from Config for processing to ensure consistency
          latest_settings = Config.get_cached_settings
          
          # Combine detected materials with stock materials for Nester input
          # This ensures that Nester has correct dimensions for ALL materials,
          # including those dynamically added from the model if not in stock_materials.
          all_materials_for_nester = MaterialsDatabase.load_database # Start with stock
          
          # Merge in properties from `parts_by_material` for detected but not defined materials
          @parts_by_material.each do |material_name, part_types|
            if !all_materials_for_nester.key?(material_name)
                # If a detected material is not in stock_materials, create a default entry for it.
                # Nester needs dimensions for all materials it encounters.
                first_part_type_data = part_types.first # This is a hash like {:part_type=>PartObject, :total_quantity=>1}
                
                # Initialize thickness_val with a default
                thickness_val = 18.0
                
                part_obj_from_entry = nil
                if first_part_type_data.is_a?(Hash) && first_part_type_data.key?(:part_type)
                  part_obj_from_entry = first_part_type_data[:part_type]
                elsif first_part_type_data.is_a?(AutoNestCut::Part)
                  part_obj_from_entry = first_part_type_data
                end

                if part_obj_from_entry.is_a?(AutoNestCut::Part) && part_obj_from_entry.respond_to?(:thickness)
                  thickness_val = part_obj_from_entry.thickness
                end
                
                all_materials_for_nester[material_name] = {
                    'width' => 2440, # Default board size
                    'height' => 1220,
                    'thickness' => thickness_val, # Use the determined thickness_val
                    'price' => 0,
                    'currency' => latest_settings['default_currency'] || 'USD'
                }
            end
          end
          latest_settings['stock_materials'] = all_materials_for_nester # Update settings for Nester

          # Validate component dimensions before processing
          puts "DEBUG: Starting validation"
          validation_result = validate_component_dimensions(@parts_by_material, latest_settings['stock_materials'])
          puts "DEBUG: Validation result: #{validation_result.inspect}"
          
          if validation_result[:has_errors]
            error_msg = validation_result[:message]
            puts "DEBUG: Validation error message: #{error_msg}"
            UI.messagebox(error_msg)
            next
          end

          puts "DEBUG: Validation passed, starting nesting"
          process_with_async_nesting(latest_settings)

        rescue => e
          puts "ERROR in process callback: #{e.message}"
          puts e.backtrace
          error_msg = js_escape(e.message)
          @dialog.execute_script("showError('Error processing: #{error_msg}')")
          @dialog.execute_script("hideProgressOverlay()")
        end
      end

      # Export CSV report
      @dialog.add_action_callback("export_csv") do |action_context, report_data_json|
        begin
          if report_data_json && !report_data_json.empty?
            if report_data_json.is_a?(String)
              report_data = JSON.parse(report_data_json, symbolize_names: true)
            else
              report_data = report_data_json
            end
            export_csv_report(report_data, Config.get_cached_settings)
          else
            UI.messagebox("Error exporting CSV: No report data available")
          end
        rescue => e
          UI.messagebox("Error exporting CSV: #{e.message}")
        end
      end


    @dialog.add_action_callback("export_to_pdf") do |action_context, html_content|
      begin
        pdf_generator = ProfessionalPDFGenerator.new
        pdf_generator.generate_professional_pdf(html_content, @settings)
        @dialog.execute_script("hideProgressOverlay();")
      rescue => e
        puts "ERROR: Failed to generate professional PDF: #{e.message}"
        @dialog.execute_script("hideProgressOverlay(); showError('Error generating PDF: #{e.message.gsub("'", "\\'")}')")
      end
    end

      @dialog.add_action_callback("export_interactive_html") do |action_context, report_data_json|
        begin
          puts "DEBUG: Interactive HTML export requested"
          report_generator = ReportGenerator.new
          report_generator.export_interactive_html(report_data_json)
        rescue => e
          puts "ERROR exporting interactive HTML: #{e.message}"
          UI.messagebox("Error exporting HTML: #{e.message}")
        end
      end
      
      @dialog.add_action_callback("save_html_report") do |action_context, html_content|
        begin
          model_name = Sketchup.active_model.title.empty? ? "Untitled" : Sketchup.active_model.title.gsub(/[^\w]/, '_')
          base_name = "AutoNestCut_Report_#{model_name}"
          counter = 1
          documents_path = Compatibility.documents_path
          
          loop do
            filename = "#{base_name}_#{counter}.html"
            full_path = File.join(documents_path, filename)
            
            unless File.exist?(full_path)
              File.write(full_path, html_content, encoding: 'UTF-8')
              UI.messagebox("Interactive HTML report exported to Documents: #{filename}")
              break
            end
            
            counter += 1
          end
        rescue => e
          UI.messagebox("Error exporting HTML: #{e.message}")
        end
      end
      
      @dialog.add_action_callback("print_pdf") do |action_context, html_content|
        begin
          print_dialog = UI::HtmlDialog.new(
            dialog_title: "AutoNestCut PDF Preview",
            preferences_key: "AutoNestCut_PDF_Preview",
            scrollable: true,
            resizable: true,
            width: 900,
            height: 800
          )
          
          print_dialog.set_html(html_content)
          print_dialog.show
        rescue => e
          puts "ERROR opening PDF preview: #{e.message}"
          puts e.backtrace
          UI.messagebox("Error opening PDF preview: #{e.message}")
        end
      end

      @dialog.add_action_callback("back_to_config") do |action_context|
        @dialog.execute_script("showConfigTab()")
      end

      @dialog.add_action_callback("load_default_materials") do |action_context|
        puts "DEBUG: Loading default materials."
        defaults = MaterialsDatabase.get_default_materials
        MaterialsDatabase.save_database(defaults)
        send_initial_data # Refresh UI with new defaults
      end

      @dialog.add_action_callback("import_materials_csv") do |action_context|
        puts "DEBUG: Importing materials CSV."
        file_path = UI.openpanel("Select Materials CSV File", "", "CSV Files|*.csv||")
        if file_path
          imported = MaterialsDatabase.import_csv(file_path)
          unless imported.empty?
            existing = MaterialsDatabase.load_database
            merged = existing.merge(imported)
            MaterialsDatabase.save_database(merged)
            send_initial_data # Refresh UI
            UI.messagebox("Imported #{imported.keys.length} materials successfully!")
          else
            UI.messagebox("No valid materials found in CSV file.")
          end
        end
      end

      @dialog.add_action_callback("export_materials_database") do |action_context|
        documents_path = Compatibility.documents_path
        filename = "AutoNestCut_Materials_Database_#{Time.now.strftime('%Y%m%d')}.csv"
        file_path = File.join(documents_path, filename)

        materials = MaterialsDatabase.load_database
        MaterialsDatabase.save_database(materials)

        require 'fileutils'
        FileUtils.cp(MaterialsDatabase.database_file, file_path)
        UI.messagebox("Materials database exported to Documents: #{filename}")
      end

      @dialog.add_action_callback("highlight_material") do |action_context, material_name|
        highlight_components_by_material(material_name)
      end

      @dialog.add_action_callback("clear_highlight") do |action_context|
        clear_component_highlight
      end

      @dialog.add_action_callback("refresh_config") do |action_context|
        puts "DEBUG: Frontend requested config refresh."
        # Invalidate cache when input components are refreshed, as parts_by_material will change
        @nesting_cache = {}
        @last_processed_cache_key = nil # Clear the last key too
        refresh_configuration_data
      end

      @dialog.add_action_callback("refresh_report") do |action_context|
        puts "DEBUG: Frontend requested report refresh."
        # This means recalculate report data with current settings, not re-nest the parts
        # Pass current settings to ensure the report reflects them (e.g., unit/currency changes)
        refresh_report_display_with_current_settings
      end
      
      @dialog.add_action_callback("cancel_processing") do |action_context|
        @processing_cancelled = true
        @dialog.execute_script("updateProgressOverlay('Cancelling process...', 0)")
      end
      
      @dialog.add_action_callback("clear_nesting_cache") do |action_context|
        @nesting_cache = {}
        @last_processed_cache_key = nil
        puts "Nesting cache cleared manually"
      end

      @dialog.show
    end

    private

    # Capture assembly data from the assembly entity
    def capture_assembly_data(assembly_entity)
      return {} unless assembly_entity
      
      assembly_data = {}
      
      begin
        # Try to get assembly views if the entity has them
        if assembly_entity.respond_to?(:get_attribute)
          # Check for stored assembly views
          views_data = assembly_entity.get_attribute('AutoNestCut', 'assembly_views', nil)
          if views_data
            assembly_data['views'] = JSON.parse(views_data) rescue {}
          end
        end
        
        # If no views found, try to generate them
        if assembly_data['views'].nil? || assembly_data['views'].empty?
          assembly_data['views'] = generate_assembly_views(assembly_entity)
        end
      rescue => e
        puts "DEBUG: Error capturing assembly data: #{e.message}"
        assembly_data['views'] = {}
      end
      
      assembly_data
    end

    # Generate assembly views from the entity
    def generate_assembly_views(assembly_entity)
      views = {}
      
      begin
        # Standard view names
        view_names = ['Front', 'Top', 'Right', 'Back', 'Left', 'Bottom', 'Iso']
        
        view_names.each do |view_name|
          # Try to get view data from entity attributes
          view_data = assembly_entity.get_attribute('AutoNestCut', "view_#{view_name}", nil) rescue nil
          
          if view_data
            views["#{view_name}_base64"] = view_data
          end
        end
      rescue => e
        puts "DEBUG: Error generating assembly views: #{e.message}"
      end
      
      views
    end

    # Helper method to escape strings for safe JavaScript execution
    def js_escape(str)
      return '' if str.nil?
      str.to_s
         .gsub('\\', '\\\\')
         .gsub("\n", '\\n')
         .gsub("\r", '')
         .gsub("'", "\\'")  
         .gsub('"', '\\"')
    end

    def validate_component_dimensions(parts_by_material, stock_materials)
      errors = []
      
      parts_by_material.each do |material_name, part_types|
        stock_config = stock_materials[material_name]
        next unless stock_config
        
        stock_width = stock_config['width'].to_f
        stock_height = stock_config['height'].to_f
        stock_thickness = stock_config['thickness'].to_f
        
        part_types.each do |part_entry|
          part_obj = part_entry.is_a?(Hash) ? part_entry[:part_type] : part_entry
          next unless part_obj.respond_to?(:width) && part_obj.respond_to?(:height) && part_obj.respond_to?(:thickness)
          
          part_width = part_obj.width.to_f
          part_height = part_obj.height.to_f
          part_thickness = part_obj.thickness.to_f
          
          if (part_thickness - stock_thickness).abs > 0.1
            errors << {
              component: part_obj.name,
              material: material_name,
              issue: 'thickness',
              part_value: part_thickness.round(1),
              stock_value: stock_thickness.round(1)
            }
          end
          
          fits_normal = part_width <= stock_width && part_height <= stock_height
          fits_rotated = part_height <= stock_width && part_width <= stock_height
          
          unless fits_normal || fits_rotated
            if part_width > stock_width && part_height > stock_height
              errors << {
                component: part_obj.name,
                material: material_name,
                issue: 'size',
                part_value: "#{part_width.round(1)}├ù#{part_height.round(1)}",
                stock_value: "#{stock_width.round(1)}├ù#{stock_height.round(1)}"
              }
            elsif part_width > stock_width
              errors << {
                component: part_obj.name,
                material: material_name,
                issue: 'width',
                part_value: part_width.round(1),
                stock_value: stock_width.round(1)
              }
            elsif part_height > stock_height
              errors << {
                component: part_obj.name,
                material: material_name,
                issue: 'height',
                part_value: part_height.round(1),
                stock_value: stock_height.round(1)
              }
            end
          end
        end
      end
      
      if errors.any?
        errors_by_material = errors.group_by { |e| e[:material] }
        message = format_validation_message(errors_by_material)
        { has_errors: true, errors_by_material: errors_by_material, message: message }
      else
        { has_errors: false }
      end
    end

    def format_validation_message(errors_by_material)
      msg = "ÔÜá´©Å COMPATIBILITY ISSUES FOUND\n\n"
      msg += "The following components don't match their sheet specifications:\n\n"
      
      errors_by_material.each do |material, errors|
        msg += "\n­ƒôï Material: #{material}\n"
        errors.each do |error|
          case error[:issue]
          when 'thickness'
            msg += "  ÔÇó #{error[:component]}: thickness #{error[:part_value]}mm Ôëá sheet #{error[:stock_value]}mm\n"
          when 'width'
            msg += "  ÔÇó #{error[:component]}: width #{error[:part_value]}mm > sheet #{error[:stock_value]}mm\n"
          when 'height'
            msg += "  ÔÇó #{error[:component]}: height #{error[:part_value]}mm > sheet #{error[:stock_value]}mm\n"
          when 'size'
            msg += "  ÔÇó #{error[:component]}: size #{error[:part_value]}mm > sheet #{error[:stock_value]}mm\n"
          end
        end
      end
      
      thickness_errors = errors_by_material.values.flatten.select { |e| e[:issue] == 'thickness' }
      if thickness_errors.any?
        suggested_thickness = thickness_errors.first[:part_value]
        material_name = thickness_errors.first[:material]
        msg += "\n­ƒÆí Quick Fix:\n"
        msg += "  Change '#{material_name}' sheet thickness to #{suggested_thickness}mm\n"
      end
      
      msg += "\nÔ£Å´©Å Update sheet dimensions in the materials list above and try again."
      msg
    end

    # Sends all initial data (settings, parts, materials, etc.) to the frontend
    def send_initial_data
      # Load all materials from the database first
      loaded_materials = MaterialsDatabase.load_database
      
      # Get current global settings from a configuration manager (e.g., Config.rb)
      current_settings = Config.get_cached_settings

      # Ensure `stock_materials` in settings reflects the loaded database
      current_settings['stock_materials'] = loaded_materials

      # Auto-load detected materials into stock_materials for UI display if they don't exist
      @parts_by_material.each do |material_name, part_types|
        first_part_entry = part_types.first
        
        # Extract the Part object
        part_obj_from_entry = nil
        if first_part_entry.is_a?(Hash) && first_part_entry.key?(:part_type)
          part_obj_from_entry = first_part_entry[:part_type]
        else
          part_obj_from_entry = first_part_entry
        end

        thickness_val = 18.0
        if part_obj_from_entry.respond_to?(:thickness)
          thickness_val = part_obj_from_entry.thickness
        end
        
        unless current_settings['stock_materials'].key?(material_name)
          # Create new auto-detected material
          current_settings['stock_materials'][material_name] = {
            'width' => 2440,
            'height' => 1220,
            'thickness' => thickness_val,
            'price' => 0,
            'currency' => current_settings['default_currency'] || 'USD',
            'auto_generated' => true
          }
        end
      end
      # Save these potentially new materials to the database so they persist
      MaterialsDatabase.save_database(current_settings['stock_materials'])

      # Combine initial data for frontend
      initial_data = {
        settings: current_settings, # Contains global settings (units, currency, etc.) and stock_materials
        parts_by_material: serialize_parts_by_material(@parts_by_material),
        original_components: @original_components,
        model_materials: get_model_materials, # Materials from SketchUp model
        hierarchy_tree: @hierarchy_tree
      }
      
      script = "receiveInitialData(#{initial_data.to_json})"
      @dialog.execute_script(script)
    rescue => e
      puts "ERROR in send_initial_data: #{e.message}"
      puts e.backtrace
      @dialog.execute_script("showError('Error loading initial data: #{e.message.gsub("'", "\\'")}')")
    end

    # ======================================================================================
    # ASYNCHRONOUS NESTING PROCESSING WITH CACHING
    # ======================================================================================

    # Queue for communication between background thread and UI thread
    @nesting_queue = nil
    # Reference to the background thread
    @nesting_thread = nil
    # Reference to the UI timer for watching the queue
    @nesting_watcher_timer = nil

    # Store the cache key of the last successfully processed nesting
    @last_processed_cache_key = nil

    # Generates a unique, stable hash key for the given parts and settings
    def generate_cache_key(parts_by_material_hash, settings)
      # Return a distinct key for empty parts to avoid accidental cache hits
      return Digest::MD5.hexdigest("EMPTY_PARTS_#{Time.now.to_i}") if parts_by_material_hash.nil? || parts_by_material_hash.empty?

      # Create a canonical representation of parts_by_material
      serialized_parts = parts_by_material_hash.map do |material, parts_array|
        [material.to_s, parts_array.map do |part_entry|
          part_type = part_entry.is_a?(Hash) && part_entry.key?(:part_type) ? part_entry[:part_type] : part_entry
          {
            name: part_type.name.to_s,
            width: part_type.width.to_f,
            height: part_type.height.to_f,
            thickness: part_type.thickness.to_f, # Include thickness in cache key
            total_quantity: (part_entry[:total_quantity] || 1).to_i
          }
        end.sort_by { |p| [p[:name], p[:width], p[:height], p[:thickness], p[:total_quantity]] }]
      end.sort_by(&:first).to_json

      # Extract only nesting-relevant settings that affect the *nesting pattern* or *outcome*
      nesting_stock_materials = if settings['stock_materials']
                                  settings['stock_materials'].transform_values do |material_data|
                                    material_data.reject { |k, _v| k == 'price' || k == 'currency' } # Remove price and currency from cache key
                                  end
                                else
                                  {}
                                end

      nesting_settings = {
        'stock_materials' => nesting_stock_materials,
        'kerf_width' => settings['kerf_width'],
        'allow_rotation' => settings['allow_rotation']
        # Add any other settings from Config that directly influence the nesting result
      }.to_json

      # Combine and hash
      Digest::MD5.hexdigest(serialized_parts + nesting_settings)
    end

    def process_with_async_nesting(settings)
      @processing_cancelled = false # Reset cancellation flag at the start of a new process

      @dialog.execute_script("showProgressOverlay('Preparing optimization...', 0)")

      @settings = settings # Store current settings for report generation later
      @boards = [] # Clear previous boards data

      # Initialize communication queue and thread references
      @nesting_queue = Queue.new
      @nesting_thread = nil
      @nesting_watcher_timer = nil

      current_cache_key = generate_cache_key(@parts_by_material, settings)

      if @nesting_cache.key?(current_cache_key)
        # --- CACHE HIT ---
        @dialog.execute_script("updateProgressOverlay('Using cached results...', 10)")
        cached_boards = @nesting_cache[current_cache_key]
        @last_processed_cache_key = current_cache_key

        # Simulate quick completion with a very short timer to allow UI update
        UI.start_timer(0.01, false) do
          generate_report_and_show_tab(cached_boards)
          @dialog.execute_script("hideProgressOverlay()")
        end
      else
        # --- CACHE MISS ---
        start_nesting_background_thread(current_cache_key) # Pass key to store results later
        start_nesting_progress_watcher
      end
    end

    # Starts the heavy nesting computation in a separate background thread
    def start_nesting_background_thread(cache_key)
      parts_by_material_for_thread = @parts_by_material.dup
      settings_for_thread = @settings.dup

      @nesting_thread = Thread.new do
        begin
          nester = Nester.new
          boards_result = []
          
          nester_progress_callback = lambda do |message, percentage|
            unless @processing_cancelled
              @nesting_queue.push({ type: :progress, message: message, percentage: percentage })
            end
          end

          @nesting_queue.push({ type: :progress, message: "Starting optimization...", percentage: 5 })
          boards_result = nester.optimize_boards(parts_by_material_for_thread, settings_for_thread, nester_progress_callback)
          
          if @processing_cancelled
            @nesting_queue.push({ type: :cancelled })
          else
            @nesting_queue.push({ type: :complete, boards: boards_result, cache_key: cache_key })
          end

        rescue StandardError => e
          puts "Background nesting thread error: #{e.message}\n#{e.backtrace.join("\n")}"
          @nesting_queue.push({ type: :error, message: "Nesting calculation failed: #{e.message}" })
        end
      end
    end

    # Starts a UI timer to periodically check the queue for messages from the background thread
    def start_nesting_progress_watcher
      @nesting_watcher_timer = UI.start_timer(0.1, true) do
        process_queue_message # Process one message at a time to prevent blocking
      end
    end

    # Processes a single message from the queue on the main UI thread
    def process_queue_message
      return unless @nesting_queue
      return if @nesting_queue.empty?

      message = @nesting_queue.pop(true)

      case message[:type]
      when :progress
        pct = message[:percentage].clamp(0, 100)
        @dialog.execute_script("updateProgressOverlay('#{message[:message].gsub("'", "\\'")}', #{pct})")
      when :error
        finalize_nesting_process
        @dialog.execute_script("hideProgressOverlay()")
        @dialog.execute_script("showError('#{message[:message].gsub("'", "\\'")}')")
      when :cancelled
        finalize_nesting_process
        @dialog.execute_script("hideProgressOverlay()")
        @dialog.execute_script("showError('Nesting process cancelled by user.')") # Changed to showError for explicit feedback
      when :complete
        @dialog.execute_script("updateProgressOverlay('All nesting calculations complete. Preparing reports...', 90)")
        
        finalize_nesting_process 

        @boards = message[:boards]
        @last_processed_cache_key = message[:cache_key]

        if message[:cache_key] && @boards && !@boards.empty?
          @nesting_cache[message[:cache_key]] = @boards
          puts "Nesting results cached for key: #{message[:cache_key]}"
        end
        
        UI.start_timer(0.01, false) do
          generate_report_and_show_tab(@boards)
        end
      end
    rescue ThreadError
      # Ignore, just means no message was available this tick.
    end

    # Cleans up the background thread and UI timer
    def finalize_nesting_process
      if @nesting_watcher_timer && (defined?(UI.valid_timer?) ? UI.valid_timer?(@nesting_watcher_timer) : true)
        UI.stop_timer(@nesting_watcher_timer)
      end
      @nesting_watcher_timer = nil

      if @nesting_thread && @nesting_thread.alive?
        @nesting_thread.kill
        @nesting_thread.join
      end
      @nesting_thread = nil

      @nesting_queue.clear if @nesting_queue
      @nesting_queue = nil

      @processing_cancelled = false
    end

    # Generates the report data and displays the report tab in the dialog
    def generate_report_and_show_tab(boards)
      @dialog.execute_script("updateProgressOverlay('Generating reports...', 95)")

      if boards.empty?
        @dialog.execute_script("hideProgressOverlay()")
        @dialog.execute_script("showError('General failure: No boards could be generated. Check material settings and part dimensions. Ensure all components fit within sheet width, height, and thickness.')")
        return
      end

      # Perform actual report data generation (passing the current @settings)
      report_generator = ReportGenerator.new
      report_data = report_generator.generate_report_data(boards, @settings)

      # Prepare data for dialog
      data = {
        diagrams: boards.map(&:to_h), # Assuming Board objects have a to_h method
        report: report_data,
        original_components: @original_components,
        hierarchy_tree: @hierarchy_tree
      }

      @dialog.execute_script("updateProgressOverlay('Finalizing...', 100)")
      @dialog.execute_script("hideProgressOverlay()")
      @dialog.execute_script("showReportTab(#{data.to_json})")
    rescue StandardError => e
      puts "ERROR in generate_report_and_show_tab: #{e.message}"
      puts e.backtrace
      @dialog.execute_script("hideProgressOverlay()")
      @dialog.execute_script("showError('Error generating report: #{e.message.gsub("'", "\\'")}')")
    end

    # ======================================================================================
    # END ASYNCHRONOUS NESTING PROCESSING
    # ======================================================================================

    def serialize_parts_by_material(parts_by_material_hash)
      result = {}
      parts_by_material_hash.each do |material, parts|
        result[material] = parts.map do |part_entry|
          # Robustly extract Part object
          part_type_obj = nil
          total_quantity = 1
          
          if part_entry.is_a?(Hash) && part_entry.key?(:part_type)
            part_type_obj = part_entry[:part_type]
            total_quantity = part_entry[:total_quantity] || 1
          elsif part_entry.is_a?(AutoNestCut::Part)
            part_type_obj = part_entry
            total_quantity = 1
          end

          if part_type_obj.is_a?(AutoNestCut::Part)
            {
              name: part_type_obj.name || 'Unnamed Part',
              width: part_type_obj.width || 0,
              height: part_type_obj.height || 0,
              thickness: part_type_obj.thickness || 0,
              total_quantity: total_quantity
            }
          else
            nil # Return nil to filter out invalid entries
          end
        end.compact # Remove nil entries
      end
      result
    end

    def get_model_materials
      materials = []
      Sketchup.active_model.materials.each do |material|
        materials << {
          name: material.display_name || material.name,
          color: material.color ? material.color.to_a[0..2] : [200, 200, 200]
        }
      end
      materials
    end

    def highlight_components_by_material(material_name)
      model = Sketchup.active_model
      selection = model.selection
      selection.clear

      matching_entities = []

      if @original_components && !@original_components.empty?
        @original_components.each do |comp_data|
          # Use string comparison for material names
          if comp_data[:material].to_s.strip.downcase == material_name.to_s.strip.downcase
            found_entity = find_entity_by_id(model, comp_data[:entity_id])
            if found_entity
              matching_entities << found_entity
            end
          end
        end
      end
      
      model.selection.add(matching_entities)

      if matching_entities.any?
        view = model.active_view
        view.zoom(matching_entities)
      else
        puts "DEBUG: No components found with material: #{material_name}"
        UI.messagebox("No components found with material: #{material_name}")
      end
    end

    # Helper method to find an entity by its ID recursively in the model
    def find_entity_by_id(model, entity_id)
      return nil unless entity_id

      # First, check model.find_entities_by_id (if available and entity_id is a valid ID from SketchUp::Entity)
      # Note: model.find_entities_by_id expects an array of IDs and returns entities.
      # For a single ID, iterating is generally safer or using specific methods.
      # If entity_id is not an integer (e.g., from an attribute), this won't work.
      # Assuming entity_id is from Sketchup::Entity#entityID, which is an integer.
      
      # Simpler direct iteration approach:
      model.entities.each do |entity|
        return entity if entity.entityID == entity_id
        if entity.is_a?(Sketchup::Group)
          found = find_entity_in_container(entity, entity_id)
          return found if found
        elsif entity.is_a?(Sketchup::ComponentInstance)
          # Search inside the component's definition entities
          found = find_entity_in_container(entity.definition, entity_id)
          return found if found
        end
      end
      nil
    end

    # Recursive helper for find_entity_by_id
    def find_entity_in_container(container, entity_id)
      return nil unless container.respond_to?(:entities)

      container.entities.each do |entity|
        return entity if entity.entityID == entity_id
        if entity.is_a?(Sketchup::Group)
          found = find_entity_in_container(entity, entity_id)
          return found if found
        elsif entity.is_a?(Sketchup::ComponentInstance)
          found = find_entity_in_container(entity.definition, entity_id)
          return found if found
        end
      end
      nil
    end

    def clear_component_highlight
      Sketchup.active_model.selection.clear
    end

    def refresh_configuration_data
      model = Sketchup.active_model
      selection = model.selection

      if selection.empty?
        @dialog.execute_script("showError('Please select components or groups to analyze for refresh.')")
        return
      end

      begin
        analyzer = ModelAnalyzer.new
        @parts_by_material = analyzer.analyze_selection(selection) # Use the more comprehensive analyze_selection
        @original_components = analyzer.get_original_components_data
        @hierarchy_tree = analyzer.get_hierarchy_tree

        if @parts_by_material.empty?
          @dialog.execute_script("showError('No valid sheet good parts found in your selection.')")
          return
        end

        # Send refreshed data to the dialog. `send_initial_data` already handles populating settings
        # and stock materials from detected parts.
        send_initial_data
      rescue => e
        puts "ERROR refreshing data: #{e.message}"
        puts e.backtrace
        @dialog.execute_script("showError('Error refreshing data: #{e.message.gsub("'", "\\'")}')")
      end
    end

    # Refreshes only the report display using the last computed boards and current settings
    def refresh_report_display_with_current_settings
      return unless @boards && !@boards.empty? # Ensure boards are available from a previous run

      # Load current settings, as display-only settings might have changed since last nesting
      @settings = Config.get_cached_settings # Update @settings to ensure report generation uses latest config

      begin
        generate_report_and_show_tab(@boards)
      rescue => e
        puts "ERROR refreshing report display: #{e.message}"
        puts e.backtrace
        @dialog.execute_script("showError('Error refreshing report display: #{e.message.gsub("'", "\\'")}')")
      end
    end

    def export_csv_report(report_data, global_settings)
      model_name = Sketchup.active_model.title.empty? ? "Untitled" : Sketchup.active_model.title.gsub(/[^\w]/, '_')
      base_name = "AutoNestCut_Report_#{model_name}"
      counter = 1
      documents_path = Compatibility.documents_path

      loop do
        filename = "#{base_name}_#{counter}.csv"
        full_path = File.join(documents_path, filename)

        unless File.exist?(full_path)
          begin
            reporter = ReportGenerator.new
            reporter.export_csv(full_path, report_data)
            UI.messagebox("CSV report exported to Documents: #{filename}")
            return
          rescue => e
            UI.messagebox("Error exporting CSV: #{e.message}")
            return
          end
        end
        counter += 1
      end
    end

    def export_csv_new(report_data)
      require 'csv'
      
      model_name = Sketchup.active_model.title.empty? ? "Untitled" : Sketchup.active_model.title.gsub(/[^\w]/, '_')
      filename = "Cutting_List_#{model_name}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.csv"
      desktop_path = File.join(ENV['USERPROFILE'] || ENV['HOME'], 'Desktop')
      full_path = File.join(desktop_path, filename)
      
      CSV.open(full_path, 'w') do |csv|
        csv << ["Part Types"]
        csv << ["Name", "Width", "Height", "Material", "Quantity"]
        
        if report_data[:unique_part_types]
          report_data[:unique_part_types].each do |part|
            csv << [
              part[:name] || '',
              part[:width] || 0,
              part[:height] || 0,
              part[:material] || '',
              part[:total_quantity] || 0
            ]
          end
        end
        
        csv << []
        csv << ["Summary"]
        if report_data[:summary]
          csv << ["Total Parts", report_data[:summary][:total_parts_instances] || 0]
          csv << ["Total Boards", report_data[:summary][:total_boards] || 0]
          csv << ["Total Cost", report_data[:summary][:total_project_cost] || 0]
        end
      end
      
      UI.messagebox("CSV exported to Desktop: #{filename}")
    rescue => e
      UI.messagebox("CSV export failed: #{e.message}")
    end

    def export_interactive_html_report(report_data)
      model_name = Sketchup.active_model.title.empty? ? "Untitled" : Sketchup.active_model.title.gsub(/[^\w]/, '_')
      base_name = "AutoNestCut_Report_#{model_name}"
      counter = 1
      documents_path = Compatibility.documents_path

      loop do
        filename = "#{base_name}_#{counter}.html"
        full_path = File.join(documents_path, filename)

        unless File.exist?(full_path)
          html_content = generate_standalone_html(report_data)
          File.write(full_path, html_content, encoding: 'UTF-8')
          UI.messagebox("Interactive HTML report exported to Documents: #{filename}")
          return
        end

        counter += 1
      end
    end

    def generate_standalone_html(report_data)
      css_file = File.join(__dir__, 'html', 'style.css')
      diagrams_css_file = File.join(__dir__, 'html', 'diagrams_style.css')
      js_file = File.join(__dir__, 'html', 'diagrams_report.js')
      
      css_content = File.exist?(css_file) ? File.read(css_file) : ''
      diagrams_css_content = File.exist?(diagrams_css_file) ? File.read(diagrams_css_file) : ''
      js_content = File.exist?(js_file) ? File.read(js_file) : ''
      
      # Add current interface styling overrides for consistency
      current_styling = <<~CSS
        /* Updated styling to match current interface */
        .materials-header {
          display: grid;
          grid-template-columns: 300px 120px 120px 120px 120px 80px 80px;
          gap: 12px;
          padding: 12px 16px;
          background: linear-gradient(135deg, #f8fafc, #f1f5f9);
          border: 1px solid #e1e5e9;
          border-radius: 8px;
          font-size: 14px;
          font-weight: 700;
          color: #1a1a1a;
          margin-bottom: 12px;
          font-family: 'Inter', sans-serif !important;
          box-shadow: 0 1px 3px rgba(0,0,0,0.05);
          width: fit-content;
        }
        
        .material-item {
          display: grid;
          grid-template-columns: 300px 120px 120px 120px 120px 80px 80px;
          gap: 12px;
          padding: 12px 16px;
          border-radius: 8px;
          align-items: center;
          margin-bottom: 8px;
          border: 1px solid #e1e5e9;
          transition: all 0.2s ease;
          background: #ffffff;
        }
        
        .parts-card table {
          width: 100%;
          border-collapse: collapse;
        }
        
        /* Enhanced table styling for exports */
        th, td {
          text-align: left !important;
          padding: 8px 12px;
          border-bottom: 1px solid #d0d7de;
          font-family: 'Inter', sans-serif !important;
          vertical-align: middle;
        }
        
        th {
          background: #f5f5f5 !important;
          font-weight: 700;
          position: sticky;
          top: 0;
          z-index: 10;
        }
        
        tbody tr:hover {
          background: #f6f8fa !important;
        }
        
        /* Right-align numeric columns */
        th:nth-child(n+2):not(th:nth-child(5)):not(th:nth-child(1)),
        td:nth-child(n+2):not(td:nth-child(5)):not(td:nth-child(1)) {
          text-align: right !important;
        }
        
        /* Keep text columns left-aligned */
        th:nth-child(1), td:nth-child(1),
        th:nth-child(5), td:nth-child(5) {
          text-align: left !important;
        }
        
        .total-highlight {
          font-weight: 600;
          color: #1a1a1a;
          background: #f0f9ff !important;
        }
        
        /* Cut sequence styling */
        .cut-sequence-board {
          margin-bottom: 24px;
          padding: 16px;
          border: 1px solid #d0d7de;
          border-radius: 6px;
          background: #f8fafc;
        }
        
        .cut-sequence-board h4 {
          margin: 0 0 8px 0;
          font-size: 16px;
          font-weight: 600;
          color: #1a1a1a;
          font-family: 'Inter', sans-serif !important;
        }
        
        .cut-sequence-table {
          width: 100%;
          margin-top: 12px;
        }
        
        .cut-sequence-table th {
          background: #ffffff !important;
          font-weight: 600;
        }
        
        .cut-sequence-table td:first-child {
          font-weight: 600;
          color: #007cba;
        }
      CSS

      <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <title>AutoNestCut Interactive Report</title>
        <style>
        #{css_content}
        #{diagrams_css_content}
        #{current_styling}
        body { margin: 0; padding: 0; height: 100vh; display: flex; flex-direction: column; }
        .floating-print { position: fixed; top: 20px; right: 20px; z-index: 1000; background: #007cba; color: white; border: none; padding: 12px; border-radius: 50%; cursor: pointer; box-shadow: 0 2px 8px rgba(0,0,0,0.2); }
        .floating-print:hover { background: #005a87; }
        </style>
      </head>
      <body>
        <button class="floating-print" onclick="window.print()" title="Print Report">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline points="6,9 6,2 18,2 18,9"/>
            <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/>
            <polyline points="6,14 6,22 18,22 18,14"/>
          </svg>
        </button>
        
        <div class="container">
          <div id="diagramsContainer" class="diagrams-container">
            <h2>Cutting Diagrams</h2>
          </div>
          <div class="resizer" id="resizer"></div>
          <div id="reportContainer" class="report-container">
            <h2>Materials Used</h2>
            <div class="table-with-controls">
              <table id="materialsUsedTable"></table>
            </div>
            
            <h2>Overall Summary</h2>
            <div class="table-with-controls">
              <table id="summaryTable"></table>
            </div>
            
            <h2>Unique Part Types</h2>
            <div class="table-with-controls">
              <table id="uniquePartTypesTable"></table>
            </div>
            
            <h2>Material Requirements</h2>
            <div class="table-with-controls">
              <table id="materialRequirementsTable"></table>
            </div>
            
            <h2>Sheet Inventory Summary</h2>
            <div class="table-with-controls">
              <table id="sheetInventoryTable"></table>
            </div>
            
            <h2>Cut Sequences</h2>
            <div id="cutSequenceContainer"></div>
            
            <h2>Usable Offcuts</h2>
            <div class="table-with-controls">
              <table id="offcutsTable"></table>
            </div>
            
            <h2>Cut List & Part Details</h2>
            <div class="tree-controls">
              <button type="button" id="treeToggle" onclick="toggleTreeView()">Show Tree Structure</button>
              <div class="tree-search" id="treeSearchContainer" style="display: none;">
                <input type="text" id="treeSearch" placeholder="Search components..." oninput="filterTree()">
                <button type="button" onclick="clearTreeSearch()">Clear</button>
                <button type="button" onclick="expandAll()">Expand All</button>
                <button type="button" onclick="collapseAll()">Collapse All</button>
              </div>
            </div>
            <div id="treeStructure" class="tree-structure" style="display: none;"></div>
            <div class="table-with-controls">
              <table id="partsTable"></table>
            </div>
          </div>
        </div>
        
        <div id="partModal" class="modal">
          <div class="modal-content">
            <span class="close">&times;</span>
            <div class="modal-controls"><button id="projectionToggle">Orthographic</button></div>
            <canvas id="modalCanvas" width="500" height="400"></canvas>
            <div id="modalInfo"></div>
          </div>
        </div>
        
        <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
        <script src="https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js"></script>
        <script>#{js_content}</script>
        <script>
          const reportData = #{report_data.to_json};
          document.addEventListener('DOMContentLoaded', () => {
            receiveData(reportData);
            
            // Add Material Requirements table
            const materialReqTable = document.getElementById('materialRequirementsTable');
            if (materialReqTable && reportData.diagrams) {
              materialReqTable.innerHTML = generateBoardsSummaryTableHTML(reportData.diagrams);
            }
            
            // Add Cut Sequences
            if (typeof renderCutSequences === 'function' && reportData.report.cut_sequences) {
              renderCutSequences(reportData.report);
            }
            
            // Add Offcuts table
            const offcutsTable = document.getElementById('offcutsTable');
            if (offcutsTable && reportData.report.usable_offcuts) {
              if (reportData.report.usable_offcuts.length === 0) {
                offcutsTable.innerHTML = '<thead><tr><th>Sheet #</th><th>Material</th><th>Estimated Size</th><th>Area (m²)</th></tr></thead><tbody><tr><td colspan="4">No significant offcuts</td></tr></tbody>';
              } else {
                let html = '<thead><tr><th>Sheet #</th><th>Material</th><th>Estimated Size</th><th>Area (m²)</th></tr></thead><tbody>';
                reportData.report.usable_offcuts.forEach(offcut => {
                  html += `<tr><td>${offcut.board_number}</td><td>${offcut.material}</td><td>${offcut.estimated_dimensions}</td><td>${offcut.area_m2}</td></tr>`;
                });
                html += '</tbody>';
                offcutsTable.innerHTML = html;
              }
            }
            
            initResizer();
            const modal = document.getElementById('partModal');
            const closeBtns = document.querySelectorAll('#partModal .close');
            closeBtns.forEach(btn => btn.addEventListener('click', () => modal.style.display = 'none'));
            window.addEventListener('click', (e) => { if (e.target === modal) modal.style.display = 'none'; });
          });
          
          function generateBoardsSummaryTableHTML(boardsData) {
            if (!boardsData || boardsData.length === 0) return '<thead><tr><th>Sheet</th><th>Material</th><th>Dimensions</th><th>Parts</th><th>Efficiency</th><th>Waste</th></tr></thead><tbody><tr><td colspan="6">No material requirements available</td></tr></tbody>';
            
            const reportUnits = window.currentUnits || 'mm';
            const reportPrecision = window.currentPrecision ?? 1;
            
            let html = `<thead><tr><th>Sheet</th><th>Material</th><th>Dimensions (${reportUnits})</th><th>Parts Count</th><th>Efficiency</th><th>Waste</th></tr></thead><tbody>`;
            
            boardsData.forEach((board, index) => {
              const width = (board.stock_width || 0) / (window.unitFactors[reportUnits] || 1);
              const height = (board.stock_height || 0) / (window.unitFactors[reportUnits] || 1);
              
              html += `<tr>
                <td>Sheet ${index + 1}</td>
                <td>${board.material}</td>
                <td>${formatNumber(width, reportPrecision)} ├ù ${formatNumber(height, reportPrecision)}</td>
                <td>${board.parts ? board.parts.length : 0}</td>
                <td>${formatNumber(board.efficiency_percentage, 1)}%</td>
                <td>${formatNumber(board.waste_percentage, 1)}%</td>
              </tr>`;
            });
            
            html += `</tbody>`;
            return html;
          }
        </script>
      </body>
      </html>
      HTML
    end
  end
end
