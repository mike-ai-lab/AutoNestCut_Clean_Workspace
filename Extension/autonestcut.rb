# This file MUST be placed directly in your SketchUp Plugins folder
# (e.g., C:\Users\<YourUser>\AppData\Roaming\SketchUp\SketchUp 202x\SketchUp\Plugins)
# or in the root of your extension's folder if it's structured as a true extension.

require 'sketchup.rb'

puts "TRACE: AutoNestCut.rb (the extension loader) is starting to load."

module AutoNestCut
  # Define constants for the extension (good practice for registration)
  # main.rb will redefine these fully, but good to have placeholders for the extension object
  EXTENSION_NAME = 'Auto Nest Cut'.freeze
  EXTENSION_VERSION = '1.0.0'.freeze # Placeholder, update as needed
  EXTENSION_DESCRIPTION = 'Automated nesting and cut list generation for sheet goods.'.freeze
  EXTENSION_CREATOR = 'Muhamad Shkeir'.freeze # Assuming creator from email

  # This is the actual extension object that SketchUp's ExtensionManager uses.
  # It should be defined only once.
  # The __FILE__ here refers to this loader.rb
  unless file_loaded?(__FILE__)
    puts "TRACE: AutoNestCut.rb (loader): file_loaded? is false for THIS loader, proceeding to register extension."

    extension = SketchupExtension.new(EXTENSION_NAME, File.join(__dir__, 'AutoNestCut', 'main.rb'))
    extension.description = EXTENSION_DESCRIPTION
    extension.version = EXTENSION_VERSION
    extension.creator = EXTENSION_CREATOR
    
    Sketchup.register_extension(extension, true) # `true` means load immediately

    puts "TRACE: AutoNestCut.rb (loader): Extension registered with SketchUp. main.rb will be required by SketchUp."
    file_loaded(__FILE__)
  else
    puts "TRACE: AutoNestCut.rb (loader): This loader file has already been processed, skipping registration."
  end
end
puts "TRACE: AutoNestCut.rb (loader) finished executing."
