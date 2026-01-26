module AutoNestCut
  class Board
    attr_accessor :material, :stock_width, :stock_height, :parts_on_board
    attr_reader :free_rectangles # For debugging, if needed
    
    def initialize(material, stock_width, stock_height)
      @material = material
      @stock_width = stock_width.to_f
      @stock_height = stock_height.to_f
      @parts_on_board = []
      # Initialize with one large free rectangle covering the whole board: [x, y, width, height]
      @free_rectangles = [[0.0, 0.0, @stock_width, @stock_height]]
    end
    
    # Add a part to the board and update the free rectangles.
    # kerf_width is critical as it defines the actual space the part + kerf consumes.
    def add_part(part, x, y, kerf_width = 0)
      part.x = x
      part.y = y
      @parts_on_board << part
      
      # The space occupied by the part, including kerf
      placed_rect_with_kerf = [x, y, part.width + kerf_width, part.height + kerf_width]
      
      updated_free_rects = []
      @free_rectangles.each do |free_rect|
        if intersects?(free_rect, placed_rect_with_kerf)
          # If they intersect, subtract the placed part's rectangle from the free rectangle
          new_rects = subtract_rect(free_rect, placed_rect_with_kerf)
          updated_free_rects.concat(new_rects)
        else
          # If no intersection, the free rectangle remains as is
          updated_free_rects << free_rect
        end
      end
      
      # Filter out any invalid rectangles (width or height <= 0)
      @free_rectangles = updated_free_rects.select { |r| r[2] > 0 && r[3] > 0 }
      
      # Sort free rectangles by Y then X for a consistent "bottom-left" bias in finding positions
      @free_rectangles.sort_by! { |fr| [fr[1], fr[0]] }
    end
    
    def used_area
      @parts_on_board.sum(&:area)
    end
    
    def total_area
      @stock_width * @stock_height
    end
    
    def waste_area
      total_area - used_area
    end
    
    def calculate_waste_percentage
      return 0.0 if total_area == 0.0
      (waste_area.to_f / total_area * 100).round(2)
    end
    
    def efficiency_percentage
      100.0 - calculate_waste_percentage
    end

    def total_weight_kg(stock_materials)
      material_data = stock_materials[@material] || {}
      density = material_data['density'] || 600
      @parts_on_board.sum { |part| part.weight_kg(density) }
    end
    
    # Checks if a part would fit within the overall board boundaries.
    # Kerf is included in the boundary check to ensure the part + kerf spacing fits.
    def can_fit_part_within_board_bounds?(part, x, y, kerf_width = 0)
      part_right = x + part.width + kerf_width
      part_bottom = y + part.height + kerf_width
      
      return false if part_right > @stock_width || part_bottom > @stock_height
      true
    end
    
    # Finds the best position for a part on the board using the free rectangles strategy.
    # It prefers the bottom-leftmost available space.
    def find_best_position(part, kerf_width = 0)
      # Special case: if the part exactly matches the board dimensions and the board is empty,
      # allow it to be placed without kerf spacing (exact-fit parts)
      if @parts_on_board.empty? && 
         (part.width - @stock_width).abs < 0.1 && 
         (part.height - @stock_height).abs < 0.1
        return [0.0, 0.0]
      end
      
      effective_part_width = part.width + kerf_width
      effective_part_height = part.height + kerf_width

      @free_rectangles.each do |fr_x, fr_y, fr_w, fr_h|
        # Check if the part (with kerf) fits within the current free rectangle
        if effective_part_width <= fr_w && effective_part_height <= fr_h
          # If it fits, the bottom-left corner of the free rectangle is a candidate position.
          # Since @free_rectangles is sorted by Y then X, this gives a "bottom-left first" fit.
          candidate_x = fr_x
          candidate_y = fr_y

          # Also do a final check against overall board boundaries (redundant if free_rects are always within bounds,
          # but a good safeguard, especially for edge cases).
          if can_fit_part_within_board_bounds?(part, candidate_x, candidate_y, kerf_width)
            return [candidate_x, candidate_y] # Return the first valid position found
          end
        end
      end
      nil # No suitable position found
    end

    # This method needs to be public so `dialog_manager.rb` can call it.
    def to_h
      # Convert free rectangles to offcuts data
      offcuts_data = @free_rectangles.map do |rect|
        {
          x: rect[0],
          y: rect[1],
          width: rect[2],
          height: rect[3],
          area: (rect[2] * rect[3]).round(2)
        }
      end
      
      {
        material: @material,
        stock_width: @stock_width,
        stock_height: @stock_height,
        parts_count: @parts_on_board.length,
        used_area: used_area,
        waste_area: waste_area,
        waste_percentage: calculate_waste_percentage,
        efficiency_percentage: efficiency_percentage,
        parts: @parts_on_board.map(&:to_h),
        offcuts: offcuts_data
      }
    end

    private # All methods below this line are private

    # Checks if two rectangles intersect.
    # Rect format: [x, y, width, height]
    def intersects?(rect1, rect2)
      x1, y1, w1, h1 = rect1
      x2, y2, w2, h2 = rect2
      
      !(x1 + w1 <= x2 || x2 + w2 <= x1 || y1 + h1 <= y2 || y2 + h2 <= y1)
    end

    # Subtracts `rect_to_subtract` from `original_rect`.
    # Returns an array of new rectangles that represent the remaining area.
    # Rect format: [x, y, width, height]
    def subtract_rect(original_rect, rect_to_subtract)
      # Unpack coordinates and dimensions for clarity
      ox, oy, ow, oh = original_rect
      sx, sy, sw, sh = rect_to_subtract
      
      new_rects = []

      # Calculate the intersection rectangle
      ix1 = [ox, sx].max
      iy1 = [oy, sy].max
      ix2 = [ox + ow, sx + sw].min
      iy2 = [oy + oh, sy + sh].min
      
      # If there's no actual intersection (this check is mostly handled by intersects? but good safeguard)
      if ix2 <= ix1 || iy2 <= iy1
        return [original_rect] # No subtraction, return original
      end

      # Create up to four new rectangles representing the remaining space around the intersection
      
      # 1. Left piece of original_rect (to the left of the subtracted intersection)
      if ox < ix1
        new_rects << [ox, oy, ix1 - ox, oh]
      end
      # 2. Right piece of original_rect (to the right of the subtracted intersection)
      if ox + ow > ix2
        new_rects << [ix2, oy, (ox + ow) - ix2, oh]
      end
      
      # 3. Bottom piece of original_rect (below the subtracted intersection, constrained by intersection X-bounds)
      if oy < iy1
        new_rects << [ix1, oy, ix2 - ix1, iy1 - oy]
      end
      # 4. Top piece of original_rect (above the subtracted intersection, constrained by intersection X-bounds)
      if oy + oh > iy2
        new_rects << [ix1, iy2, ix2 - ix1, (oy + oh) - iy2]
      end
      
      # Filter out any rectangles with zero or negative width/height
      new_rects.select { |r| r[2] > 0 && r[3] > 0 }
    end
  end
end
