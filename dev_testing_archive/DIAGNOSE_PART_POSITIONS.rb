# Diagnostic script to check if parts are being placed outside board boundaries

require_relative 'Extension/AutoNestCut/models/shape'
require_relative 'Extension/AutoNestCut/models/part'
require_relative 'Extension/AutoNestCut/models/board'

module PartPositionDiagnostic
  def self.diagnose
    puts "\n" + "="*80
    puts "PART POSITION DIAGNOSTIC"
    puts "="*80
    
    model = Sketchup.active_model
    selection = model.selection
    
    if selection.empty?
      puts "\n❌ ERROR: No components selected!"
      return
    end
    
    # Create parts
    parts = []
    selection.each do |entity|
      next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      begin
        part = AutoNestCut::Part.new(entity)
        parts << part
      rescue => e
        puts "Failed: #{e.message}"
      end
    end
    
    return if parts.empty?
    
    # Sort by area
    parts.sort_by! { |p| -p.area }
    
    # Create board
    board_width = 2440.0
    board_height = 1220.0
    board = AutoNestCut::Board.new("Test", board_width, board_height)
    kerf_width = 3.0
    
    puts "\nBoard dimensions: #{board_width} x #{board_height} mm"
    puts "Kerf width: #{kerf_width} mm"
    puts "\n" + "-"*80
    
    parts.each_with_index do |part, idx|
      puts "\n[#{idx + 1}] #{part.name}"
      puts "  Dimensions: #{part.width.round(1)} x #{part.height.round(1)} mm"
      puts "  Shape: #{part.shape ? part.shape.type : 'rectangle'}"
      
      # Try to find position
      position = board.find_best_position(part, kerf_width)
      
      if position
        x, y = position
        
        # CHECK BOUNDARIES BEFORE ADDING
        part_right = x + part.width + kerf_width
        part_bottom = y + part.height + kerf_width
        
        puts "  Position found: (#{x.round(1)}, #{y.round(1)})"
        puts "  Part right edge: #{part_right.round(1)} mm (board width: #{board_width} mm)"
        puts "  Part bottom edge: #{part_bottom.round(1)} mm (board height: #{board_height} mm)"
        
        # Check if outside bounds
        if part_right > board_width
          puts "  ❌ ERROR: Part extends #{(part_right - board_width).round(1)}mm BEYOND RIGHT EDGE!"
        end
        
        if part_bottom > board_height
          puts "  ❌ ERROR: Part extends #{(part_bottom - board_height).round(1)}mm BEYOND BOTTOM EDGE!"
        end
        
        if x < 0
          puts "  ❌ ERROR: Part starts #{(-x).round(1)}mm BEFORE LEFT EDGE!"
        end
        
        if y < 0
          puts "  ❌ ERROR: Part starts #{(-y).round(1)}mm BEFORE TOP EDGE!"
        end
        
        if part_right <= board_width && part_bottom <= board_height && x >= 0 && y >= 0
          puts "  ✓ Part is WITHIN bounds"
        end
        
        # Add part to board
        board.add_part(part, x, y, kerf_width)
        
      else
        puts "  ❌ No position found"
      end
    end
    
    puts "\n" + "="*80
    puts "FINAL BOARD STATE"
    puts "="*80
    puts "Parts on board: #{board.parts_on_board.length}"
    puts "Efficiency: #{board.efficiency_percentage.round(2)}%"
    
    puts "\n" + "-"*80
    puts "ALL PART POSITIONS:"
    puts "-"*80
    
    board.parts_on_board.each_with_index do |part, idx|
      part_right = part.x + part.width + kerf_width
      part_bottom = part.y + part.height + kerf_width
      
      status = ""
      if part_right > board_width || part_bottom > board_height || part.x < 0 || part.y < 0
        status = " ❌ OUTSIDE BOUNDS!"
      else
        status = " ✓"
      end
      
      puts "#{idx + 1}. #{part.name}#{status}"
      puts "   Position: (#{part.x.round(1)}, #{part.y.round(1)})"
      puts "   Size: #{part.width.round(1)} x #{part.height.round(1)} mm"
      puts "   Right edge: #{part_right.round(1)} mm"
      puts "   Bottom edge: #{part_bottom.round(1)} mm"
    end
    
    puts "="*80
  end
end

# Run diagnostic
PartPositionDiagnostic.diagnose
