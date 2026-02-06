module AutoNestCut
  class Nester

    def optimize_boards(part_types_by_material_and_quantities, settings, progress_callback = nil)
      boards = []
      stock_materials_config = settings['stock_materials']
      kerf_width = settings['kerf_width'].to_f || 3.0
      allow_rotation = settings['allow_rotation'] || true
      @progress_callback = progress_callback
      @current_settings = settings # Store settings for auto-fix updates
      
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
            
            # AUTO-FIX: Try to automatically resolve the issue
            auto_fix_result = auto_fix_unplaceable_part(unplaceable_part, material, stock_width, stock_height, kerf_width, allow_rotation)
            
            if auto_fix_result[:fixed]
              # Notify user about the auto-fix
              report_progress("⚠️ Auto-fixed: #{auto_fix_result[:message]}", base_overall_progress + 50)
              
              # Apply the fix and retry with updated dimensions
              if auto_fix_result[:new_stock_width] && auto_fix_result[:new_stock_height]
                stock_width = auto_fix_result[:new_stock_width]
                stock_height = auto_fix_result[:new_stock_height]
                
                # Update stock materials config for this material
                stock_materials_config = @current_settings['stock_materials'] || {}
                stock_materials_config[material] = {
                  'width' => stock_width,
                  'height' => stock_height
                }
                @current_settings['stock_materials'] = stock_materials_config
                
                # Retry nesting with new dimensions
                return nest_individual_parts(individual_parts_to_place, material, stock_width, stock_height, kerf_width, allow_rotation, base_overall_progress, total_materials)
              end
            else
              # Could not auto-fix, raise error
              error_msg = "Unable to place component '#{unplaceable_part.name}' (#{unplaceable_part.width.round(1)}x#{unplaceable_part.height.round(1)}mm) on sheet (#{stock_width.round(1)}x#{stock_height.round(1)}mm) for material '#{material}'. #{auto_fix_result[:reason]}"
              raise StandardError, error_msg
            end
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
    
    # Auto-fix method to handle unplaceable parts gracefully
    def auto_fix_unplaceable_part(part, material, current_width, current_height, kerf_width, allow_rotation)
      part_width = part.width
      part_height = part.height
      
      # Calculate required dimensions (with some margin for kerf and spacing)
      margin = kerf_width * 2 + 10 # Extra margin for safety
      required_width = part_width + margin
      required_height = part_height + margin
      
      # Check if rotation would help (if not already allowed)
      if !allow_rotation && part_height > current_height && part_width <= current_height
        return {
          fixed: true,
          message: "Enabled rotation for material '#{material}' to fit component '#{part.name}'",
          enable_rotation: true
        }
      end
      
      # Check if part fits with rotation
      fits_rotated = allow_rotation && (
        (part_width <= current_width && part_height <= current_height) ||
        (part_height <= current_width && part_width <= current_height)
      )
      
      if fits_rotated
        # Part should fit with rotation, might be kerf issue
        return {
          fixed: false,
          reason: "Component should fit with rotation enabled. Try reducing kerf width in settings."
        }
      end
      
      # Calculate new sheet dimensions needed
      # For tall components, use the component height as the new sheet dimension
      new_width = [current_width, required_width, required_height].max
      new_height = [current_height, required_height, required_width].max
      
      # Round up to nearest 100mm for standard sizing
      new_width = ((new_width / 100.0).ceil * 100).to_f
      new_height = ((new_height / 100.0).ceil * 100).to_f
      
      # For very tall components (like wardrobe panels), be more flexible
      # Check if this is a tall vertical component
      is_tall_component = part_height > 2000 || part_width > 2000
      
      if is_tall_component
        # For tall components, just ensure the sheet can accommodate them
        # Use the larger dimension as width (horizontal on sheet)
        new_width = [part_width, part_height].max + margin
        new_height = [part_width, part_height].min + margin
        
        # Round up to nearest 100mm
        new_width = ((new_width / 100.0).ceil * 100).to_f
        new_height = ((new_height / 100.0).ceil * 100).to_f
        
        return {
          fixed: true,
          message: "Auto-adjusted sheet size for '#{material}' to #{new_width.round(0)}×#{new_height.round(0)}mm to accommodate tall component '#{part.name}' (#{part_width.round(0)}×#{part_height.round(0)}mm)",
          new_stock_width: new_width,
          new_stock_height: new_height
        }
      end
      
      # For normal components, check if adjustment is reasonable (not more than 100% increase)
      width_increase = ((new_width - current_width) / current_width * 100).round(1)
      height_increase = ((new_height - current_height) / current_height * 100).round(1)
      
      if width_increase > 100 && height_increase > 100
        return {
          fixed: false,
          reason: "Component is too large (requires #{width_increase}% width increase, #{height_increase}% height increase). Consider splitting the component or using a different material."
        }
      end
      
      # Auto-fix: Adjust sheet dimensions
      {
        fixed: true,
        message: "Auto-adjusted sheet size for '#{material}' from #{current_width.round(0)}×#{current_height.round(0)}mm to #{new_width.round(0)}×#{new_height.round(0)}mm to fit component '#{part.name}' (#{part_width.round(0)}×#{part_height.round(0)}mm)",
        new_stock_width: new_width,
        new_stock_height: new_height
      }
    end
  end
end
