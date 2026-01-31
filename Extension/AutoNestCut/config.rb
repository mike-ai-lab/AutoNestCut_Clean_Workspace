require 'json'
require_relative 'compatibility'

module AutoNestCut
  module Config
    CONFIG_FILE = File.join(Compatibility.user_app_data_path, 'AutoNestCut', 'config.json')

    def self.ensure_config_folder
      folder = File.dirname(CONFIG_FILE)
      Dir.mkdir(folder) unless Dir.exist?(folder)
    end

    def self.load_global_settings
      ensure_config_folder
      return {} unless File.exist?(CONFIG_FILE)
      JSON.parse(File.read(CONFIG_FILE))
    rescue JSON::ParserError => e
      puts "Warning: Config file corrupted. Resetting to default."
      {}
    rescue => e
      puts "Error loading config: #{e.message}"
      {}
    end

    def self.save_global_settings(new_settings)
      ensure_config_folder
      current_settings = load_global_settings
      merged_settings = current_settings.merge(new_settings)
      File.write(CONFIG_FILE, merged_settings.to_json)
      @cached_settings = merged_settings
    rescue => e
      puts "Error saving config: #{e.message}"
    end

    def self.get_cached_settings
      @cached_settings ||= load_global_settings
      # Ensure auto_create_materials setting exists (default: true)
      @cached_settings['auto_create_materials'] = true unless @cached_settings.key?('auto_create_materials')
      
      # Ensure label settings exist (default values)
      unless @cached_settings.key?('label_settings')
        @cached_settings['label_settings'] = {
          'enabled' => true,
          'qr_enabled' => true,
          'show_in_pdf' => true,
          'show_in_ui' => false,  # Don't clutter UI diagrams
          'qr_size' => 20,
          'label_position' => 'auto',
          'label_style' => 'compact',
          'font_size' => 10
        }
      end
      
      @cached_settings
    end
  end
end
