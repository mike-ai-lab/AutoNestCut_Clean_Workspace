require_relative '../materials_database'

module AutoNestCut
  class MaterialDatabaseUI
    
    def self.show_dialog
      # Create or show existing dialog
      if @dialog && @dialog.visible?
        @dialog.bring_to_front
        return
      end
      
      html_path = File.join(__dir__, 'html', 'material_database.html')
      
      unless File.exist?(html_path)
        UI.messagebox("Error: Material database HTML file not found.\n\nPath: #{html_path}", MB_OK)
        return
      end
      
      @dialog = UI::HtmlDialog.new(
        {
          :dialog_title => "Material Database Manager - AutoNestCut",
          :preferences_key => "com.autonestcut.material_database",
          :scrollable => true,
          :resizable => true,
          :width => 1000,
          :height => 600,
          :left => 100,
          :top => 100,
          :min_width => 800,
          :min_height => 400,
          :style => UI::HtmlDialog::STYLE_DIALOG
        }
      )
      
      # Use the same cache-busting method as main dialog
      AutoNestCut.set_html_with_cache_busting(@dialog, html_path)
      
      # Setup callbacks
      setup_callbacks
      
      @dialog.show
    end
    
    private
    
    def self.setup_callbacks
      # Callback: Get materials data
      @dialog.add_action_callback('get_materials_data') do |action_context|
        begin
          materials = MaterialsDatabase.load_database
          
          # Migration: Add flagged_no_material to existing no_material_ entries
          materials.each do |name, data|
            data_array = data.is_a?(Array) ? data : [data]
            
            data_array.each do |mat|
              if name.start_with?('no_material_') && !mat.key?('flagged_no_material')
                mat['flagged_no_material'] = true
              end
            end
          end
          
          # Convert array format to single object for frontend
          flattened_materials = {}
          materials.each do |name, data|
            if data.is_a?(Array) && data.length > 0
              flattened_materials[name] = data[0]
            elsif data.is_a?(Hash)
              flattened_materials[name] = data
            end
          end
          
          MaterialsDatabase.save_database(materials)
          
          json_data = JSON.generate(flattened_materials)
          @dialog.execute_script("receiveMaterialsData('#{escape_js(json_data)}');")
        rescue => e
          puts "ERROR loading materials: #{e.message}"
          puts e.backtrace.join("\n")
          @dialog.execute_script("receiveMaterialsData('{}');")
        end
      end
      
      # Callback: Save materials data
      @dialog.add_action_callback('save_materials_data') do |action_context, json_string|
        begin
          materials = JSON.parse(json_string)
          
          # Handle both Hash and Array formats
          materials.each do |name, data|
            if data.is_a?(Array)
              data.each do |thickness_data|
                thickness_data['width'] = thickness_data['width'].to_f
                thickness_data['height'] = thickness_data['height'].to_f
                thickness_data['thickness'] = thickness_data['thickness'].to_f
                thickness_data['price'] = thickness_data['price'].to_f
                thickness_data['currency'] = thickness_data['currency'].to_s.upcase
                thickness_data['density'] = thickness_data['density'] || 600
              end
            elsif data.is_a?(Hash)
              data['width'] = data['width'].to_f
              data['height'] = data['height'].to_f
              data['thickness'] = data['thickness'].to_f
              data['price'] = data['price'].to_f
              data['currency'] = data['currency'].to_s.upcase
              data['density'] = data['density'] || 600
            end
          end
          
          MaterialsDatabase.save_database(materials)
          
          @dialog.execute_script("showToast('Materials saved successfully');")
        rescue => e
          puts "ERROR saving materials: #{e.message}"
          puts e.backtrace.join("\n")
          @dialog.execute_script("showToast('Error saving materials: #{escape_js(e.message)}');")
        end
      end
      
      # Callback: Confirm delete
      @dialog.add_action_callback('confirm_delete') do |action_context, material_name|
        result = UI.messagebox("Delete material '#{material_name}'?", MB_YESNO)
        confirmed = (result == IDYES)
        @dialog.execute_script("confirmDeleteCallback('#{escape_js(material_name)}', #{confirmed});")
      end
      
      # Callback: Confirm refresh
      @dialog.add_action_callback('confirm_refresh') do |action_context|
        result = UI.messagebox("You have unsaved changes. Refresh anyway?", MB_YESNO)
        confirmed = (result == IDYES)
        @dialog.execute_script("confirmRefreshCallback(#{confirmed});")
      end
      
      # Callback: Prompt for new material name
      @dialog.add_action_callback('prompt_add_material') do |action_context|
        result = UI.inputbox(['Material Name:'], [''], 'Add New Material')
        if result
          name = result[0].to_s.strip
          @dialog.execute_script("addMaterialCallback('#{escape_js(name)}');")
        end
      end
      
      # Callback: Show error message
      @dialog.add_action_callback('show_error') do |action_context, message|
        @dialog.execute_script("showToast('#{escape_js(message)}');")
      end
      
      # Callback: Export CSV
      @dialog.add_action_callback('export_csv') do |action_context, csv_data|
        path = UI.savepanel('Export Materials as CSV', '', 'materials.csv')
        if path
          File.write(path, csv_data)
          @dialog.execute_script("showToast('CSV exported successfully');")
        end
      end
      
      # Callback: Export JSON
      @dialog.add_action_callback('export_json') do |action_context, json_data|
        path = UI.savepanel('Export Materials as JSON', '', 'materials.json')
        if path
          File.write(path, json_data)
          @dialog.execute_script("showToast('JSON exported successfully');")
        end
      end
      
      # Callback: Copy to clipboard
      @dialog.add_action_callback('copy_to_clipboard') do |action_context, text_data|
        # Use SketchUp's clipboard (Windows only, Mac needs different approach)
        begin
          if Sketchup.platform == :platform_win
            # Windows clipboard via Win32API
            require 'win32ole'
            clip = WIN32OLE.new('htmlfile')
            clip.parentWindow.clipboardData.setData('text', text_data)
            @dialog.execute_script("showToast('Copied to clipboard');")
          else
            # Mac fallback - save to temp file
            temp_file = File.join(ENV['TMPDIR'] || '/tmp', 'materials_clipboard.txt')
            File.write(temp_file, text_data)
            @dialog.execute_script("showToast('Saved to temp file');")
          end
        rescue => e
          @dialog.execute_script("showToast('Clipboard operation failed');")
        end
      end
      
      # Callback: Confirm batch delete
      @dialog.add_action_callback('confirm_batch_delete') do |action_context, materials_string|
        materials = materials_string.split('|||')
        result = UI.messagebox("Delete #{materials.length} selected materials?", MB_YESNO)
        confirmed = (result == IDYES)
        @dialog.execute_script("confirmBatchDeleteCallback(#{confirmed});")
      end
      
      # Callback: Load default materials
      @dialog.add_action_callback('load_default_materials') do |action_context|
        begin
          defaults = MaterialsDatabase.get_default_materials
          json_data = JSON.generate(defaults)
          @dialog.execute_script("receiveDefaultMaterials('#{escape_js(json_data)}');")
        rescue => e
          puts "ERROR loading default materials: #{e.message}"
          @dialog.execute_script("showToast('Error loading default materials: #{escape_js(e.message)}');")
        end
      end
    end
    
    # Escape JavaScript strings
    def self.escape_js(string)
      string.gsub(/['\\]/) { |match| "\\#{match}" }
            .gsub(/\r\n|\n|\r/, "\\n")
            .gsub(/\t/, "\\t")
    end
  end
end
