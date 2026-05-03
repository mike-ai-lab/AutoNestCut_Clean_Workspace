# Secure Update System
module AutoNestCut
  module UpdateSystem
    UPDATE_URL = 'https://autonestcutserver-moeshks-projects.vercel.app/api/updates'
    
    def self.check_for_updates
      begin
        require 'net/http'
        require 'json'
        
        uri = URI(UPDATE_URL)
        response = Net::HTTP.get_response(uri)
        
        if response.code == '200'
          update_info = JSON.parse(response.body)
          current_version = AutoNestCut::EXTENSION_VERSION
          
          if version_newer?(update_info['version'], current_version)
            show_update_dialog(update_info)
          end
        end
      rescue => e
        puts "Update check failed: #{e.message}"
      end
    end
    
    private
    
    def self.version_newer?(new_version, current_version)
      new_parts = new_version.split('.').map(&:to_i)
      current_parts = current_version.split('.').map(&:to_i)
      
      new_parts <=> current_parts > 0
    end
    
    def self.show_update_dialog(update_info)
      message = "AutoNestCut Update Available!

"
      message += "Current Version: #{AutoNestCut::EXTENSION_VERSION}
"
      message += "New Version: #{update_info['version']}

"
      message += "Changes:
#{update_info['changelog']}

"
      message += "Would you like to download the update?"
      
      result = UI.messagebox(message, MB_YESNO)
      if result == IDYES
        UI.openURL(update_info['download_url'])
      end
    end
  end
end
