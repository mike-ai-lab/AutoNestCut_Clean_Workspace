# Force reload AutoNestCut extension
begin
  # Clear loaded files
  $LOADED_FEATURES.delete_if { |f| f.include?('AutoNestCut') || f.include?('autonestcut') }
  
  # Remove constants
  Object.send(:remove_const, :AutoNestCut) if defined?(AutoNestCut)
  
  # Directly load main.rb
  load File.join(__dir__, 'Extension', 'AutoNestCut', 'main.rb')
  
  puts "✅ AutoNestCut extension force reloaded"
rescue => e
  puts "❌ Error reloading: #{e.message}"
  puts e.backtrace.join("\n")
end