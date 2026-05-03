# Test script to verify nesting efficiency improvements
# This tests the same components shown in the screenshot

require_relative 'Extension/AutoNestCut/models/shape'
require_relative 'Extension/AutoNestCut/models/part'
require_relative 'Extension/AutoNestCut/models/board'

module NestingEfficiencyTest
  def self.test_nesting
    puts "\n" + "="*80
    puts "NESTING EFFICIENCY TEST"
    puts "="*80
    
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      puts "\n❌ ERROR: No components selected!"
      puts "Please select the components from your test and run this script again."
      return
    end
    
    puts "\n📦 Testing #{selection.length} selected components..."
    
    # Create parts from selection
    parts = []
    selection.each do |entity|
      next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      
      begin
        part = AutoNestCut::Part.new(entity)
        parts << part
        puts "  ✓ #{part.name}: #{part.width.round(1)}x#{part.height.round(1)}mm (#{part.shape ? part.shape.type : 'rectangle'})"
      rescue => e
        puts "  ✗ Failed to create part from #{entity.name}: #{e.message}"
      end
    end
    
    if parts.empty?
      puts "\n❌ No valid parts found!"
      return
    end
    
    # Sort by area (largest first)
    parts.sort_by! { |p| -p.area }
    
    puts "\n" + "-"*80
    puts "NESTING SIMULATION"
    puts "-"*80
    
    # Create board
    board = AutoNestCut::Board.new("Plywood_Test", 2440.0, 1220.0)
    kerf_width = 3.0
    
    placed_count = 0
    failed_count = 0
    
    parts.each_with_index do |part, idx|
      puts "\n[#{idx + 1}/#{parts.length}] Placing: #{part.name} (#{part.width.round(1)}x#{part.height.round(1)}mm)"
      
      position = board.find_best_position(part, kerf_width)
      
      if position
        x, y = position
        board.add_part(part, x, y, kerf_width)
        placed_count += 1
        puts "  ✓ Placed at (#{x.round(1)}, #{y.round(1)})"
        puts "  Board efficiency: #{board.efficiency_percentage.round(2)}%"
      else
        failed_count += 1
        puts "  ✗ Could not find position"
      end
    end
    
    puts "\n" + "="*80
    puts "RESULTS"
    puts "="*80
    puts "Total parts: #{parts.length}"
    puts "Placed: #{placed_count}"
    puts "Failed: #{failed_count}"
    puts ""
    puts "Board dimensions: #{board.stock_width.round(1)} x #{board.stock_height.round(1)} mm"
    puts "Used area: #{board.used_area.round(2)} mm²"
    puts "Total area: #{board.total_area.round(2)} mm²"
    puts "Waste area: #{board.waste_area.round(2)} mm²"
    puts ""
    puts "EFFICIENCY: #{board.efficiency_percentage.round(2)}%"
    puts "="*80
    
    if board.efficiency_percentage < 50
      puts "\n⚠️  WARNING: Efficiency is below 50%"
      puts "This may indicate a nesting algorithm issue."
    elsif board.efficiency_percentage >= 60
      puts "\n✅ GOOD: Efficiency is above 60%"
      puts "Nesting algorithm is working well for these parts."
    else
      puts "\n✓ ACCEPTABLE: Efficiency is between 50-60%"
      puts "This is typical for irregular shapes."
    end
    
    # Show part positions
    puts "\n" + "-"*80
    puts "PART POSITIONS"
    puts "-"*80
    board.parts_on_board.each_with_index do |part, idx|
      puts "#{idx + 1}. #{part.name}: (#{part.x.round(1)}, #{part.y.round(1)}) - #{part.width.round(1)}x#{part.height.round(1)}mm"
    end
    puts "="*80
  end
end

# Run the test
NestingEfficiencyTest.test_nesting
