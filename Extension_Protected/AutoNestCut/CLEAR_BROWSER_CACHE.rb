# Clear browser cache and force reload
puts "Clearing browser cache and reloading extension..."

# Force Ruby reload
Object.send(:remove_const, :AutoNestCut) if defined?(AutoNestCut)

# Reload extension
load 'C:\Users\Administrator\Desktop\AUTOMATION\cutlist\AutoNestCut\AutoNestCut_Clean_Workspace\Extension\POWER_LOADER.rb'

puts "Extension reloaded with v2.4.0 - Label & Table Fix"
puts "Close and reopen the extension dialog to see changes"