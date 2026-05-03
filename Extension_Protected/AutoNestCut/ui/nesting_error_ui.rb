require 'json'

module AutoNestCut
  class NestingErrorUI
    
    def self.show_error(error_message, error_details = {})
      # Parse error message to extract details
      parsed_details = parse_error_message(error_message)
      merged_details = parsed_details.merge(error_details)
      
      # Create dialog
      dialog = UI::HtmlDialog.new(
        {
          :dialog_title => "Nesting Error - AutoNestCut",
          :preferences_key => "com.autonestcut.nesting_error",
          :scrollable => true,
          :resizable => false,
          :width => 750,
          :height => 800,
          :left => 200,
          :top => 50,
          :style => UI::HtmlDialog::STYLE_DIALOG
        }
      )
      
      # Load HTML
      html_path = File.join(__dir__, 'html', 'nesting_error_dialog.html')
      dialog.set_file(html_path)
      
      # Handle open materials stock callback
      dialog.add_action_callback('open_materials_stock') do |action_context|
        dialog.close
        # Open materials stock dialog
        begin
          MaterialsDatabaseUI.show_dialog if defined?(MaterialsDatabaseUI)
        rescue => e
          puts "Error opening materials stock: #{e.message}"
        end
      end
      
      # Handle close callback
      dialog.add_action_callback('close_dialog') do |action_context|
        dialog.close
      end
      
      # Initialize dialog with error data when ready
      dialog.add_action_callback('ready') do |action_context|
        error_data = {
          message: error_message,
          componentName: merged_details[:component_name],
          componentSize: merged_details[:component_size],
          sheetSize: merged_details[:sheet_size],
          materialName: merged_details[:material_name],
          stackTrace: merged_details[:stack_trace]
        }
        
        js = "initializeError(#{error_data.to_json});"
        dialog.execute_script(js)
      end
      
      # Show dialog
      dialog.show
      
      dialog
    end
    
    private
    
    def self.parse_error_message(message)
      details = {}
      
      # Parse message like: "Unable to place component 'Part_16' (450.0x2600.0mm) on sheet (2440.0x1220.0mm) for material 'Color J07'"
      if message =~ /Unable to place component '([^']+)' \(([0-9.]+)x([0-9.]+)mm\) on sheet \(([0-9.]+)x([0-9.]+)mm\) for material '([^']+)'/
        details[:component_name] = $1
        details[:component_size] = "#{$2.to_f.round(1)}×#{$3.to_f.round(1)}mm"
        details[:sheet_size] = "#{$4.to_f.round(1)}×#{$5.to_f.round(1)}mm"
        details[:material_name] = $6
      end
      
      details
    end
    
  end
end
