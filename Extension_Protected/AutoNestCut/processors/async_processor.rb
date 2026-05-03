module AutoNestCut
  class AsyncProcessor
    
    BATCH_SIZE_ANALYZER = 25  # Reduced for better responsiveness
    BATCH_SIZE_NESTER = 5     # Smaller batches for nesting
    ASYNC_THRESHOLD = 15      # Lower threshold for async processing
    MAX_PROCESSING_TIME = 300 # 5 minutes timeout
    PROGRESS_UPDATE_INTERVAL = 0.02 # More frequent updates
    
    def initialize
      @progress_dialog = nil
      @start_time = nil
      @cancelled = false
    end
    
    def should_use_async?(selection)
      component_count = count_total_components(selection)
      component_count >= ASYNC_THRESHOLD
    end
    
    def process_with_progress(selection, settings, &completion_callback)
      component_count = count_total_components(selection)
      
      if should_use_async?(selection)
        process_async(selection, settings, component_count, &completion_callback)
      else
        process_sync(selection, settings, &completion_callback)
      end
    end
    
    private
    
    def count_total_components(selection)
      count = 0
      selection.each do |entity|
        count += count_components_recursive(entity)
      end
      count
    end
    
    def count_components_recursive(entity)
      count = 0
      
      if entity.is_a?(Sketchup::ComponentInstance)
        count = 1
        entity.definition.entities.each do |child|
          count += count_components_recursive(child)
        end
      elsif entity.is_a?(Sketchup::Group)
        entity.entities.each do |child|
          count += count_components_recursive(child)
        end
      end
      
      count
    end
    
    def process_async(selection, settings, component_count, &completion_callback)
      @start_time = Time.now
      @cancelled = false
      @step = 0
      @total_steps = 6  # Increased for more granular progress
      @component_count = component_count
      
      # Show progress dialog
      @progress_dialog = ProgressDialog.new
      @progress_dialog.show("Processing #{component_count} Components", component_count)
      
      # Start processing in chunks with timers
      @selection = selection
      @settings = settings
      @completion_callback = completion_callback
      
      start_chunked_processing
    end
    
    def process_sync(selection, settings, &completion_callback)
      begin
        analyzer = ModelAnalyzer.new
        parts_by_material = analyzer.extract_parts_from_selection(selection)
        original_components = analyzer.get_original_components_data
        hierarchy_tree = analyzer.get_hierarchy_tree
        
        if parts_by_material.empty?
          UI.messagebox("No valid sheet good parts found in your selection.")
          return
        end
        
        nester = Nester.new
        boards = nester.optimize_boards(parts_by_material, settings)
        
        result = {
          parts_by_material: parts_by_material,
          original_components: original_components,
          hierarchy_tree: hierarchy_tree,
          boards: boards
        }
        
        completion_callback.call(result) if completion_callback
        
      rescue => e
        UI.messagebox("Processing error: #{e.message}")
        puts "Sync processing error: #{e.message}"
      end
    end
    
    def start_chunked_processing
      @step = 1
      update_progress(@step, @total_steps, "Initializing analysis...", 5)
      
      @analyzer = ModelAnalyzer.new
      @processed_components = 0
      
      UI.start_timer(PROGRESS_UPDATE_INTERVAL, false) { process_step_2 }
    end
    
    def process_step_2
      return if check_cancellation
      
      @step = 2
      update_progress(@step, @total_steps, "Extracting component data...", 15)
      
      UI.start_timer(PROGRESS_UPDATE_INTERVAL, false) do
        begin
          # Process in smaller batches for better progress feedback
          @parts_by_material = extract_parts_in_batches(@selection)
          
          if @parts_by_material.empty?
            @progress_dialog.close
            UI.messagebox("No valid sheet good parts found.")
            return
          end
          
          UI.start_timer(PROGRESS_UPDATE_INTERVAL, false) { process_step_3 }
        rescue => e
          @progress_dialog.close
          UI.messagebox("Analysis error: #{e.message}")
        end
      end
    end
    
    def process_step_3
      return if check_cancellation
      
      @step = 3
      update_progress(@step, @total_steps, "Building component hierarchy...", 35)
      
      UI.start_timer(PROGRESS_UPDATE_INTERVAL, false) do
        begin
          @original_components = @analyzer.get_original_components_data
          @hierarchy_tree = @analyzer.get_hierarchy_tree
          
          UI.start_timer(PROGRESS_UPDATE_INTERVAL, false) { process_step_4 }
        rescue => e
          @progress_dialog.close
          UI.messagebox("Hierarchy error: #{e.message}")
        end
      end
    end
    
    def process_step_4
      return if check_cancellation
      
      @step = 4
      update_progress(@step, @total_steps, "Preparing nesting optimization...", 50)
      
      UI.start_timer(PROGRESS_UPDATE_INTERVAL, false) do
        begin
          @nester = Nester.new
          @material_groups = @parts_by_material.keys
          @current_material_index = 0
          @boards = []
          
          UI.start_timer(PROGRESS_UPDATE_INTERVAL, false) { process_step_5 }
        rescue => e
          @progress_dialog.close
          UI.messagebox("Nesting preparation error: #{e.message}")
        end
      end
    end
    
    def process_step_5
      return if check_cancellation
      
      if @current_material_index < @material_groups.length
        material = @material_groups[@current_material_index]
        progress_percent = 50 + ((@current_material_index.to_f / @material_groups.length) * 35)
        
        @step = 5
        update_progress(@step, @total_steps, "Optimizing #{material} layout...", progress_percent)
        
        UI.start_timer(PROGRESS_UPDATE_INTERVAL, false) do
          begin
            # Process one material at a time
            material_parts = { material => @parts_by_material[material] }
            material_boards = @nester.optimize_boards(material_parts, @settings)
            @boards.concat(material_boards)
            
            @current_material_index += 1
            UI.start_timer(PROGRESS_UPDATE_INTERVAL, false) { process_step_5 }
          rescue => e
            @progress_dialog.close
            UI.messagebox("Nesting error for #{material}: #{e.message}")
          end
        end
      else
        UI.start_timer(PROGRESS_UPDATE_INTERVAL, false) { process_step_6 }
      end
    end
    
    def process_step_6
      return if check_cancellation
      
      @step = 6
      update_progress(@step, @total_steps, "Finalizing results...", 100)
      
      UI.start_timer(0.1, false) do
        @progress_dialog.close
        
        result = {
          parts_by_material: @parts_by_material,
          original_components: @original_components,
          hierarchy_tree: @hierarchy_tree,
          boards: @boards
        }
        
        @completion_callback.call(result) if @completion_callback
      end
    end
    
    def extract_parts_in_batches(selection)
      parts_by_material = {}
      batch_count = 0
      
      selection.each_slice(BATCH_SIZE_ANALYZER) do |batch|
        batch_count += 1
        batch_progress = (batch_count * BATCH_SIZE_ANALYZER.to_f / @component_count) * 20
        update_progress(2, @total_steps, "Processing batch #{batch_count}...", 15 + batch_progress)
        
        batch_parts = @analyzer.extract_parts_from_selection(batch)
        
        # Merge results
        batch_parts.each do |material, parts|
          parts_by_material[material] ||= []
          parts_by_material[material].concat(parts)
        end
        
        # Allow UI updates between batches
        sleep(0.001) if batch_count % 5 == 0
      end
      
      parts_by_material
    end
    
    def check_cancellation
      if @progress_dialog && @progress_dialog.cancelled?
        @progress_dialog.close
        true
      else
        false
      end
    end
    

    
    def update_progress(step, total_steps, message, percentage)
      return unless @progress_dialog
      
      @progress_dialog.update_progress(step, total_steps, message, percentage)
      
      # Allow UI to update with shorter sleep for better responsiveness
      sleep(0.005)
    end
    

  end
end