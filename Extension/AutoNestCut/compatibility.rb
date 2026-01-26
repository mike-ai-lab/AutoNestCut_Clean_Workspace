# AutoNestCut/compatibility.rb
module AutoNestCut
  module Compatibility
    # Get user's AppData folder on Windows or Home directory on other OSes
    def self.user_app_data_path
      if Sketchup.platform == :platform_win
        ENV['APPDATA']
      else
        ENV['HOME'] # For macOS/Linux if SketchUp runs there
      end
    end

    # Get user's Desktop path
    def self.desktop_path
      if Sketchup.platform == :platform_win
        File.join(ENV['USERPROFILE'], 'Desktop')
      else
        File.join(ENV['HOME'], 'Desktop')
      end
    end

    # Get user's Documents path
    def self.documents_path
      if Sketchup.platform == :platform_win
        File.join(ENV['USERPROFILE'], 'Documents')
      else
        File.join(ENV['HOME'], 'Documents')
      end
    end

    # Add other compatibility methods here if needed, e.g.,
    # def self.load_json(file_path)
    #   # ...
    # end
  end
end
