require 'json'
require 'tmpdir'
require 'fileutils'

module AutoNestCut
  # C++ Nester Wrapper - calls external C++ executable for high-performance nesting
  class CppNester
    
    def initialize
      @cpp_exe_path = File.join(__dir__, '..', 'cpp', 'nester.exe')
      @progress_callback = nil
    end
    
    # Check if C++ solver is available
    def self.available?
      exe_path = File.join(__dir__, '..', 'cpp', 'nester.exe')
      File.exist?(exe_path)
    end
    
    def optimize_boards(part_types_by_material_and_quantities, settings, progress_callback = nil)
      @progress_callback = progress_callback
      
      unless File.exist?(@cpp_exe_path)
        raise StandardError, "C++ nester executable not found at: #{@cpp_exe_path}"
      end
      
      report_progress("Preparing nesting data...", 5)
      
      # Convert Ruby data to JSON format for C++
      input_data = prepare_input_json(part_types_by_material_and_quantities, settings)
      
      # Create temp files for IPC
      temp_dir = Dir.tmpdir
      input_file = File.join(temp_dir, "autonestcut_input_#{Time.now.to_i}.json")
      output_file = File.join(temp_dir, "autonestcut_output_#{Time.now.to_i}.json")
      
      begin
        # Write input JSON
        File.write(input_file, input_data.to_json)
        
        report_progress("Running C++ nesting solver...", 10)
        
        # Call C++ executable
        command = "\"#{@cpp_exe_path}\" \"#{input_file}\" \"#{output_file}\""
        
        puts "\n" + "="*80
        puts "DEBUG: Calling C++ Nester"
        puts "="*80
        puts "Command: #{command}"
        
        # Execute and capture output
        start_time = Time.now
        output = `#{command} 2>&1`
        exit_code = $?.exitstatus
        elapsed = Time.now - start_time
        
        puts "Exit code: #{exit_code}"
        puts "Elapsed time: #{elapsed.round(2)}s"
        puts "Output:\n#{output}"
        puts "="*80
        
        if exit_code != 0
          raise StandardError, "C++ nester failed with exit code #{exit_code}:\n#{output}"
        end
        
        unless File.exist?(output_file)
          raise StandardError, "C++ nester did not create output file"
        end
        
        report_progress("Processing results...", 85)
        
        # Read and parse output JSON
        result_json = JSON.parse(File.read(output_file))
        
        # Convert JSON back to Ruby Board objects
        boards = reconstruct_boards(result_json, part_types_by_material_and_quantities, settings)
        
        report_progress("Nesting complete!", 100)
        
        puts "DEBUG: C++ nesting complete - #{boards.length} boards created in #{elapsed.round(2)}s"
        
        boards
        
      ensure
        # Cleanup temp files
        File.delete(input_file) if File.exist?(input_file)
        File.delete(output_file) if File.exist?(output_file)
      end
    end
    
    private
    
    def report_progress(message, percentage)
      @progress_callback.call(message, percentage) if @progress_callback
    end
    
    def prepare_input_json(part_types_by_material_and_quantities, settings)
      stock_materials_config = settings['stock_materials']
      kerf_width = settings['kerf_width'].to_f || 3.0
      allow_rotation = settings['allow_rotation'] || true
      
      # Collect unique materials and their board sizes
      boards = []
      materials_seen = {}
      
      part_types_by_material_and_quantities.each do |material, _|
        next if materials_seen[material]
        materials_seen[material] = true
        
        stock_dims = stock_materials_config[material]
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
        
        boards << {
          material: material,
          width: stock_width,
          height: stock_height
        }
      end
      
      # Create individual part instances with unique IDs and store for reconstruction
      parts = []
      @part_instances = {} # Store instances by ID for reconstruction
      part_id_counter = 1
      
      part_types_by_material_and_quantities.each do |material, types_and_quantities_for_material|
        types_and_quantities_for_material.each do |entry|
          part_type = entry[:part_type]
          total_quantity = entry[:total_quantity]
          
          total_quantity.times do
            part_instance = part_type.create_placed_instance
            
            # Assign unique ID for tracking
            part_id = "part_#{part_id_counter}"
            part_instance.instance_id = part_id
            part_id_counter += 1
            
            # Store instance for later reconstruction
            @part_instances[part_id] = part_instance
            
            parts << {
              id: part_id,
              name: part_instance.name,
              material: part_instance.material,
              width: part_instance.width,
              height: part_instance.height,
              thickness: part_instance.thickness,
              grain_direction: part_instance.grain_direction || 'any'
            }
          end
        end
      end
      
      {
        boards: boards,
        parts: parts,
        settings: {
          kerf: kerf_width,
          allow_rotation: allow_rotation,
          timeout_ms: 60000
        }
      }
    end
    
    def reconstruct_boards(result_json, part_types_by_material_and_quantities, settings)
      # Group placements by board_id
      placements_by_board = {}
      result_json['placements'].each do |placement|
        board_id = placement['board_id']
        placements_by_board[board_id] ||= []
        placements_by_board[board_id] << placement
      end
      
      # Reconstruct Board objects
      boards = []
      result_json['boards'].each do |board_data|
        board_id = board_data['id']
        material = board_data['material']
        stock_width = board_data['width']
        stock_height = board_data['height']
        
        board = Board.new(material, stock_width, stock_height)
        
        # Add parts to board using stored instances
        placements = placements_by_board[board_id] || []
        placements.each do |placement|
          part_id = placement['part_id']
          part_instance = @part_instances[part_id]
          
          if part_instance
            # Apply placement data
            part_instance.x = placement['x']
            part_instance.y = placement['y']
            rotation = placement['rotation']
            part_instance.rotated = (rotation == 90 || rotation == 270)
            
            # If rotated, swap dimensions
            if part_instance.rotated && rotation == 90
              part_instance.width, part_instance.height = part_instance.height, part_instance.width
            end
            
            board.parts_on_board << part_instance
          else
            puts "WARNING: Could not find part instance for ID: #{part_id}"
          end
        end
        
        boards << board
      end
      
      boards
    end
  end
end
