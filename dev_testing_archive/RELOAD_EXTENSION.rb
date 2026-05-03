# Force reload the AutoNestCut extension
# Run this in SketchUp Ruby Console to reload the extension

# Unload the module
Object.send(:remove_const, :AutoNestCut) if defined?(AutoNestCut)

# Reload the main extension file
load 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/Extension/autonestcut.rb'

puts "AutoNestCut extension reloaded successfully!"
