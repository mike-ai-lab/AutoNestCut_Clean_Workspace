# Reload files with detailed timing logs

puts "="*80
puts "RELOADING FILES WITH DETAILED TIMING LOGS"
puts "="*80

load 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/Extension/AutoNestCut/ui/dialog_manager.rb'
puts "✓ Reloaded dialog_manager.rb (with cache timing)"

load 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/Extension/AutoNestCut/models/board.rb'
puts "✓ Reloaded board.rb"

load 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/Extension/AutoNestCut/processors/nester.rb'
puts "✓ Reloaded nester.rb"

load 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace/Extension/AutoNestCut/processors/cpp_nester.rb'
puts "✓ Reloaded cpp_nester.rb (with 30s timeout)"

puts "="*80
puts "FILES RELOADED - Now try nesting and watch the console!"
puts "="*80
puts ""
puts "You'll see timing for:"
puts "  - generate_cache_key (serialization, settings, hash)"
puts "  - get_cached_boards (cache lookup, validation)"
puts "  - Part creation time"
puts "  - find_best_position (if > 50ms)"
puts "  - try_place_part (if > 100ms)"
puts ""
puts "This will show us WHERE the hang is happening!"
puts "="*80
