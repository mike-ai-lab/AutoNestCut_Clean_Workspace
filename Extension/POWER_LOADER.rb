# AutoNestCut Extension Loader
require 'sketchup'

module AutoNestCutPowerLoader
  EXT_PATH = "C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/Extension" unless const_defined?(:EXT_PATH)

  def self.cleanup
    # Remove menu items
    begin
      menu = UI.menu('Extensions')
      submenu = menu.get_submenu('Auto Nest Cut')
      submenu.each { |item| item.remove } if submenu
    rescue => e
      # Menu might not exist
    end
    
    # Remove nested constants
    if Object.const_defined?(:AutoNestCut)
      AutoNestCut.constants.each do |const|
        AutoNestCut.send(:remove_const, const) rescue nil
      end
      Object.send(:remove_const, :AutoNestCut)
    end
    
    # Clear loaded features
    $LOADED_FEATURES.delete_if { |f| f.include?('AutoNestCut') || f.include?('autonestcut') }
    
    GC.start
  end

  def self.load_extension
    main_file = File.join(EXT_PATH, "AutoNestCut", "main.rb")
    if File.exist?(main_file)
      begin
        load main_file
      rescue => e
        UI.messagebox("Extension Load Error:\n#{e.message}\n\nCheck Ruby Console for details.")
        puts "ERROR: #{e.message}"
        puts e.backtrace.join("\n")
      end
    end
  end

  def self.reload
    cleanup
    load_extension
    puts "✅ Extension reloaded - UI should be visible"
  end
end

AutoNestCutPowerLoader.reload