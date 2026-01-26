# Test script for exact-fit parts nesting
# This tests the fix for components with dimensions exactly matching sheet dimensions

require_relative 'models/board'

module AutoNestCut
  # Mock Part class for testing
  class MockPart
    attr_accessor :name, :width, :height, :x, :y, :rotated
    
    def initialize(name, width, height)
      @name = name
      @width = width
      @height = height
      @x = 0.0
      @y = 0.0
      @rotated = false
    end
    
    def area
      @width * @height
    end
  end
  
  class TestExactFitNesting
    
    def self.run_tests
      puts "\n" + "="*80
      puts "TESTING: Exact-Fit Parts Nesting"
      puts "="*80
      
      test_exact_fit_part_placement
      test_exact_fit_with_kerf
      test_multiple_parts_with_exact_fit
      
      puts "\n" + "="*80
      puts "ALL TESTS COMPLETED"
      puts "="*80
    end
    
    def self.test_exact_fit_part_placement
      puts "\nTest 1: Exact-fit part placement (no kerf)"
      
      # Create a board 232x348
      board = Board.new("TEST_MATERIAL", 232.0, 348.0)
      
      # Create a part that exactly matches: 232x348
      part = MockPart.new("TestPart", 232.0, 348.0)
      
      # Try to find position with kerf=0
      position = board.find_best_position(part, 0)
      
      if position && position == [0.0, 0.0]
        puts "✓ PASS: Exact-fit part found position at [0, 0] with kerf=0"
      else
        puts "✗ FAIL: Expected position [0, 0], got #{position.inspect}"
      end
    end
    
    def self.test_exact_fit_with_kerf
      puts "\nTest 2: Exact-fit part placement (with kerf=3)"
      
      # Create a board 232x348
      board = Board.new("TEST_MATERIAL", 232.0, 348.0)
      
      # Create a part that exactly matches: 232x348
      part = MockPart.new("TestPart", 232.0, 348.0)
      
      # Try to find position with kerf=3
      # This should use the special case for exact-fit parts
      position = board.find_best_position(part, 3)
      
      if position && position == [0.0, 0.0]
        puts "✓ PASS: Exact-fit part found position at [0, 0] with kerf=3 (special case)"
      else
        puts "✗ FAIL: Expected position [0, 0], got #{position.inspect}"
      end
    end
    
    def self.test_multiple_parts_with_exact_fit
      puts "\nTest 3: Multiple parts - exact-fit should only work on empty board"
      
      # Create a board 232x348
      board = Board.new("TEST_MATERIAL", 232.0, 348.0)
      
      # Create first part that exactly matches: 232x348
      part1 = MockPart.new("Part1", 232.0, 348.0)
      
      # Place it
      position1 = board.find_best_position(part1, 3)
      if position1
        board.add_part(part1, position1[0], position1[1], 3)
        puts "✓ Part 1 placed at #{position1.inspect}"
      else
        puts "✗ Part 1 could not be placed"
        return
      end
      
      # Try to place a second part (should fail - board is full)
      part2 = MockPart.new("Part2", 100.0, 100.0)
      position2 = board.find_best_position(part2, 3)
      
      if position2.nil?
        puts "✓ PASS: Second part correctly rejected (board is full)"
      else
        puts "✗ FAIL: Second part should not fit, but got position #{position2.inspect}"
      end
    end
  end
end

# Run the tests
AutoNestCut::TestExactFitNesting.run_tests
