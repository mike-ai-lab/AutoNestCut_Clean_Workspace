require 'json'

module AutoNestCut
  class MissingMaterialsUI
    
    def self.show_dialog(missing_materials, existing_materials, &callback)
      # Create dialog
      dialog = UI::HtmlDialog.new(
        {
          :dialog_title => "Missing Materials - AutoNestCut",
          :preferences_key => "com.autonestcut.missing_materials",
          :scrollable => true,
          :resizable => true,
          :width => 850,
          :height => 700,
          :left => 200,
          :top => 100,
          :min_width => 600,
          :min_height => 400,
          :style => UI::HtmlDialog::STYLE_DIALOG
        }
      )
      
      # Load HTML
      html_path = File.join(__dir__, 'html', 'missing_materials_dialog.html')
      dialog.set_file(html_path)
      
      # Handle material choices callback
      dialog.add_action_callback('material_choices') do |action_context, json_string|
        begin
          puts "=" * 80
          puts "🦟 DIALOG CALLBACK: material_choices"
          puts "=" * 80
          puts "Raw JSON received: #{json_string[0..200]}..." # First 200 chars
          
          choices = JSON.parse(json_string)
          puts "Parsed #{choices.length} choices successfully"
          choices.each do |key, choice|
            puts "  Choice #{key}: #{choice['type']} for #{choice['materialName']}"
          end
          
          dialog.close
          puts "Dialog closed, calling Ruby callback..."
          callback.call(choices) if callback
          puts "Callback completed"
          puts "=" * 80
        rescue => e
          puts "ERROR processing material choices: #{e.message}"
          puts e.backtrace
        end
      end
      
      # Handle cancel callback
      dialog.add_action_callback('cancel_dialog') do |action_context|
        dialog.close
        callback.call(nil) if callback
      end
      
      # Initialize dialog with data when ready
      dialog.add_action_callback('ready') do |action_context|
        # Prepare missing materials data
        materials_data = missing_materials.map do |mat|
          {
            name: mat[:name],
            thickness: mat[:thickness],
            component_count: mat[:component_count],
            components: mat[:components]
          }
        end
        
        # Prepare available materials data (only relevant fields)
        # CRITICAL: Materials are now arrays of thickness variations
        available_data = []
        existing_materials.each do |name, data|
          # Handle both array (new format) and hash (legacy format)
          thickness_variations = data.is_a?(Array) ? data : [data]
          
          thickness_variations.each do |variation|
            available_data << {
              name: name,
              width: variation['width'].to_f,
              height: variation['height'].to_f,
              thickness: variation['thickness'].to_f
            }
          end
        end
        
        # Send data to dialog
        js = "initializeDialog(#{materials_data.to_json}, #{available_data.to_json});"
        dialog.execute_script(js)
      end
      
      # Show dialog
      dialog.show
      
      dialog
    end
    
  end
end
