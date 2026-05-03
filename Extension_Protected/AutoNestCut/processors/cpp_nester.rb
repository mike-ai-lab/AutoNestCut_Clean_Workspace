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
      
      prep_start = Time.now
      puts "DEBUG: [CppNester] Starting JSON preparation..."
      
      # Convert Ruby data to JSON format for C++
      input_data = prepare_input_json(part_types_by_material_and_quantities, settings)
      
      prep_time = Time.now - prep_start
      puts "DEBUG: [CppNester] JSON preparation took #{prep_time.round(2)}s"
      
      # Create temp files for IPC
      temp_dir = Dir.tmpdir
      input_file = File.join(temp_dir, "autonestcut_input_#{Time.now.to_i}.json")
      output_file = File.join(temp_dir, "autonestcut_output_#{Time.now.to_i}.json")
      
      begin
        # Write input JSON
        write_start = Time.now
        File.write(input_file, input_data.to_json)
        write_time = Time.now - write_start
        puts "DEBUG: [CppNester] JSON write took #{write_time.round(2)}s"
        
        report_progress("Running C++ nesting solver...", 10)
        
        # Call C++ executable with timeout
        command = "\"#{@cpp_exe_path}\" \"#{input_file}\" \"#{output_file}\""
        
        puts "\n" + "="*80
        puts "DEBUG: [CppNester] Calling C++ solver"
        puts "="*80
        puts "Command: #{command}"
        puts "Input file size: #{File.size(input_file)} bytes"
        
        # Execute with 30 second timeout
        require 'timeout'
        start_time = Time.now
        output = ""
        exit_code = 0
        
        begin
          Timeout.timeout(30) do
            output = `#{command} 2>&1`
            exit_code = $?.exitstatus
          end
        rescue Timeout::Error
          puts "ERROR: C++ solver timed out after 30 seconds!"
          raise StandardError, "C++ solver timed out - falling back to Ruby nester"
        end
        
        elapsed = Time.now - start_time
        
        puts "Exit code: #{exit_code}"
        puts "C++ execution time: #{elapsed.round(2)}s"
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
      puts "DEBUG: [reconstruct_boards] Starting reconstruction..."
      puts "DEBUG: [reconstruct_boards] Boards in JSON: #{result_json['boards'].length}"
      puts "DEBUG: [reconstruct_boards] Placements in JSON: #{result_json['placements'].length}"
      
      # Group placements by board_id
      placements_by_board = {}
      result_json['placements'].each do |placement|
        board_id = placement['board_id']
        placements_by_board[board_id] ||= []
        placements_by_board[board_id] << placement
      end
      
      puts "DEBUG: [reconstruct_boards] Placements per board:"
      placements_by_board.each do |board_id, placements|
        puts "  Board #{board_id}: #{placements.length} parts"
      end
      
      # Reconstruct Board objects
      boards = []
      result_json['boards'].each do |board_data|
        board_id = board_data['id']
        material = board_data['material']
        stock_width = board_data['width']
        stock_height = board_data['height']
        
        puts "DEBUG: [reconstruct_boards] Creating board #{board_id} for material #{material}"
        
        board = Board.new(material, stock_width, stock_height)
        
        # Add parts to board using stored instances
        placements = placements_by_board[board_id] || []
        placements.each do |placement|
          part_id = placement['part_id']
          part_instance = @part_instances[part_id]
          
          if part_instance
            # CRITICAL: Create a NEW instance for each placement!
            # The same part_id should NOT be reused across boards
            placed_part = part_instance.create_placed_instance
            
            # Apply placement data
            placed_part.x = placement['x']
            placed_part.y = placement['y']
            rotation = placement['rotation']
            placed_part.rotated = (rotation == 90 || rotation == 270)
            
            # If rotated, swap dimensions
            if placed_part.rotated && rotation == 90
              placed_part.width, placed_part.height = placed_part.height, placed_part.width
            end
            
            board.parts_on_board << placed_part
          else
            puts "WARNING: Could not find part instance for ID: #{part_id}"
          end
        end
        
        puts "DEBUG: [reconstruct_boards] Board #{board_id} has #{board.parts_on_board.length} parts"
        boards << board
      end
      
      puts "DEBUG: [reconstruct_boards] Total boards created: #{boards.length}"
      boards
    end
  end
end
