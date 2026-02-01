module AutoNestCut
  class Nester

    def optimize_boards(part_types_by_material_and_quantities, settings, progress_callback = nil)
      boards = []
      stock_materials_config = settings['stock_materials']
      kerf_width = settings['kerf_width'].to_f || 3.0
      allow_rotation = settings['allow_rotation'] || true
      @progress_callback = progress_callback
      
      total_materials = part_types_by_material_and_quantities.keys.length
      start_time = Time.now
      
      part_types_by_material_and_quantities.each_with_index do |(material_key, types_and_quantities_for_material), material_index|
        current_material_base_progress = (material_index.to_f / total_materials * 80).round(1)
        
        # Extract material name, thickness, and grain from the key
        # Format: "MaterialName_18.0mm_grain_L" or "MaterialName_18.0mm_grain_Any"
        key_parts = material_key.split('_grain_')
        material_with_thickness = key_parts[0]
        grain_direction = key_parts[1] || 'Any'
        
        # Extract original material name (remove thickness suffix)
        original_material = material_with_thickness.split('_')[0..-2].join('_')
        
        # Create display name with grain info
        grain_display = grain_direction == 'Any' ? '' : " (Grain: #{grain_direction})"
        display_name = "#{original_material}#{grain_display}"
        
        # Ensure progress is at least 5% to show something is happening
        progress_to_report = [current_material_base_progress + 5, 5].max
        report_progress("Processing material: #{display_name}...", progress_to_report)
        
        # Use original material name for stock lookup
        stock_dims = stock_materials_config[original_material]
        if stock_dims.nil?
          stock_width, stock_height = 2440.0, 1220.0
        elsif stock_dims.is_a?(Hash)
          stock_width = stock_dims['width'].to_f
          stock_height = stock_dims['height'].to_f
        elsif stock_dims.is_a?(Array) && stock_dims.length == 2
          stock_width, stock_height = stock_dims[0].to_f, stock_dims[1].to_f
        else
          stock_width, stock_height = 2440.0, 1220.0
        end

        all_individual_parts_to_place = []
        
        types_and_quantities_for_material.each do |entry|
          part_type = entry[:part_type]
          total_quantity = entry[:total_quantity]
          total_quantity.times do
            all_individual_parts_to_place << part_type.create_placed_instance
          end
        end

        report_progress("Nesting parts for #{original_material}...", current_material_base_progress + 10)

        # Pass original material name (not the key with thickness) to nest_individual_parts
        material_boards = nest_individual_parts(all_individual_parts_to_place, original_material, stock_width, stock_height, kerf_width, allow_rotation, current_material_base_progress + 10, total_materials)
        boards.concat(material_boards)
      end
      
      report_progress("Nesting optimization complete!", 90)
      boards
    end

    private
    
    def report_progress(message, percentage)
      @progress_callback.call(message, percentage) if @progress_callback
    end

    def nest_individual_parts(individual_parts_to_place, material, stock_width, stock_height, kerf_width, allow_rotation, base_overall_progress = 0, total_materials = 1)
      boards = []
      remaining_parts = individual_parts_to_place.dup

      remaining_parts.sort_by! { |part_instance| -part_instance.area }

      board_count = 0
      total_parts = individual_parts_to_place.length
      placed_parts = 0
      last_progress_update = 0
      last_progress_time = Time.now

      while !remaining_parts.empty?
        board_count += 1
        board = Board.new(material, stock_width, stock_height)
        parts_successfully_placed_on_this_board = []
        parts_that_could_not_fit_yet = []

        remaining_parts.each do |part_instance|
          if try_place_part_on_board(part_instance, board, kerf_width, allow_rotation)
            parts_successfully_placed_on_this_board << part_instance
            placed_parts += 1
          else
            parts_that_could_not_fit_yet << part_instance
          end
        end
        
        # Update progress more frequently - every part or every 2 seconds
        current_time = Time.now
        current_progress = (placed_parts.to_f / total_parts * 70).round(0)
        time_since_last_update = current_time - last_progress_time
        
        if current_progress - last_progress_update >= 5 || time_since_last_update >= 2.0 || remaining_parts.empty?
          report_progress("Board ##{board_count}: #{placed_parts}/#{total_parts} parts placed", base_overall_progress + current_progress)
          last_progress_update = current_progress
          last_progress_time = current_time
        end
        
        remaining_parts = parts_that_could_not_fit_yet

        if !parts_successfully_placed_on_this_board.empty?
          boards << board
        else
          unless remaining_parts.empty?
            unplaceable_part = remaining_parts.first
            error_msg = "Unable to place component '#{unplaceable_part.name}' (#{unplaceable_part.width.round(1)}x#{unplaceable_part.height.round(1)}mm) on sheet (#{stock_width.round(1)}x#{stock_height.round(1)}mm) for material '#{material}'. Check dimensions and kerf settings."
            raise StandardError, error_msg
          end
          break
        end
      end
      
      boards
    end

    def try_place_part_on_board(part_instance, board, kerf_width, allow_rotation)
      # Store original dimensions to revert if rotation doesn't work
      original_width = part_instance.width
      original_height = part_instance.height
      original_rotated_state = part_instance.rotated

      # Try current orientation
      position = board.find_best_position(part_instance, kerf_width)
      
      if position
        board.add_part(part_instance, position[0], position[1], kerf_width)
        return true
      end

      # Try rotated orientation if allowed and not already rotated
      if allow_rotation && part_instance.can_rotate? && !part_instance.rotated
        part_instance.rotate!
        
        position = board.find_best_position(part_instance, kerf_width)
        
        if position
          board.add_part(part_instance, position[0], position[1], kerf_width)
          return true
        else
          # If rotated part doesn't fit, revert to original state
          part_instance.rotate!
          part_instance.width = original_width
          part_instance.height = original_height
          part_instance.rotated = original_rotated_state
        end
      end
      
      false
    end
  end
end
