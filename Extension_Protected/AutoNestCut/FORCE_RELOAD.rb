# Force reload extension to clear cache
puts "Forcing extension reload..."

# Clear Ruby constants
Object.send(:remove_const, :AutoNestCut) if defined?(AutoNestCut)

# Reload extension
load 'C:\Users\Administrator\Desktop\AUTOMATION\cutlist\AutoNestCut\AutoNestCut_Clean_Workspace\Extension\POWER_LOADER.rb'

puts "Extension reloaded with v2.3.0 - Dimension Fix"