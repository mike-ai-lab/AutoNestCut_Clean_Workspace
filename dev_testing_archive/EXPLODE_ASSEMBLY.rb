require 'sketchup.rb'

module ExplodedViewTool
  
  def self.show_viewer
    model = Sketchup.active_model
    selection = model.selection

    # 1. Validation: Ensure a single component/group is selected
    if selection.empty? || selection.length > 1
      UI.messagebox("Please select exactly one component or group to view.")
      return
    end

    instance = selection[0]
    unless instance.is_a?(Sketchup::ComponentInstance) || instance.is_a?(Sketchup::Group)
      UI.messagebox("Selection must be a Component or Group.")
      return
    end

    # 2. Prepare Data for Explosion
    # We need to act on the *definition* entities to move the parts.
    # To avoid messing up other copies of this component in the model, we make this one unique.
    if instance.is_a?(Sketchup::ComponentInstance)
      instance.make_unique
    end
    
    definition = instance.definition
    # Find all immediate sub-components/groups
    parts = definition.entities.select { |e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group) }

    if parts.empty?
      UI.messagebox("The selected object has no nested parts to explode!")
      return
    end

    # 3. Calculate Vectors
    # We calculate a vector from the center of the parent to the center of each part.
    # This creates a "Radial Explosion" effect.
    parent_center = definition.bounds.center
    
    # Store original transformations to restore them later
    part_data = parts.map do |part|
      center = part.bounds.center
      vector = center - parent_center
      
      # Fallback for parts exactly at the center (rare, but prevents error)
      vector = Geom::Vector3d.new(0, 0, 1) if vector.length == 0
      
      {
        :entity => part,
        :original_trans => part.transformation,
        :vector => vector.normalize,
        :distance_factor => definition.bounds.diagonal / 2.0 # Scale movement relative to object size
      }
    end

    # 4. Create the HTML Dialog (The Viewer)
    dialog = UI::HtmlDialog.new(
      {
        :dialog_title => "Exploded View Viewer",
        :preferences_key => "com.example.explodedview",
        :scrollable => false,
        :resizable => true,
        :width => 400,
        :height => 150,
        :style => UI::HtmlDialog::STYLE_DIALOG
      }
    )

    # HTML Interface (Slider)
    html_content = <<-HTML
      <!DOCTYPE html>
      <html>
      <head>
        <style>
          body { font-family: Arial, sans-serif; padding: 20px; background-color: #f0f0f0; text-align: center; }
          h3 { margin-top: 0; color: #333; }
          .slider-container { width: 100%; margin-top: 20px; }
          input[type=range] { width: 100%; }
          .label { margin-top: 10px; font-size: 12px; color: #666; }
        </style>
      </head>
      <body>
        <h3>Explode Component</h3>
        <div class="slider-container">
          <input type="range" min="0" max="100" value="0" id="explodeSlider" oninput="updateExplosion(this.value)">
        </div>
        <div class="label">Drag slider to explode parts</div>

        <script>
          function updateExplosion(val) {
            // Send the slider value to Ruby
            sketchup.explode_geometry(val);
          }
        </script>
      </body>
      </html>
    HTML

    dialog.set_html(html_content)

    # 5. Define Ruby Callback (Logic)
    dialog.add_action_callback("explode_geometry") do |action_context, value|
      percentage = value.to_f / 100.0
      
      # Start an operation to allow clean undo/redo stack (optional, mostly visual here)
      model.start_operation("Explode View", true, false, true)
      
      part_data.each do |data|
        # Math: New Position = Original Position + (Vector * Percentage * Scale)
        translation_dist = data[:distance_factor] * percentage
        move_vector = data[:vector].clone
        move_vector.length = translation_dist
        
        transform = Geom::Transformation.translation(move_vector)
        
        # Apply transformation relative to original state
        data[:entity].transformation = transform * data[:original_trans]
      end
      
      model.commit_operation
      
      # Force SketchUp to redraw the view immediately
      model.active_view.invalidate
    end

    # 6. Cleanup on Close
    # When the user closes the window, reset the component to its original state.
    dialog.set_on_closed do
      model.start_operation("Reset View", true)
      part_data.each do |data|
        data[:entity].transformation = data[:original_trans]
      end
      model.commit_operation
    end

    dialog.center
    dialog.show
  end
end

# Run the tool
ExplodedViewTool.show_viewer