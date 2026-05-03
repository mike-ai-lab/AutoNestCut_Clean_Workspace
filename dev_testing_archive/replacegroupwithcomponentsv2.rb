# Plugin: Replace Groups With Component Tool V2
# Version: 2.0.0
# Adds toolbar + context menu to replace selected groups with a component instance
# Fixed rotation issues and added preview functionality

require 'sketchup.rb'

module Fonoun
  module ReplaceGroupsWithComponentV2

    PLUGIN_NAME = "Replace Groups With Component V2"
    VERSION = "2.0.0"

    class ReplacerTool
      def initialize(component_def, component_instance)
        @definition = component_def
        @component_instance = component_instance
        @picked = []
        @preview_mode = false
        @preview_instances = []
        @current_group = nil
        @rotation_angle = 0.0
        @preview_transformation = nil
      end

      def activate
        Sketchup.status_text = "Click groups to select/deselect. Press Enter to replace, R for preview mode."
      end

      def deactivate
        clear_previews
      end

      def onLButtonDown(flags, x, y, view)
        if @preview_mode
          handle_preview_click(x, y, view)
        else
          handle_selection_click(x, y, view)
        end
      end

      def handle_selection_click(x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        picked = ph.best_picked

        return unless picked.is_a?(Sketchup::Group)

        if @picked.include?(picked)
          @picked.delete(picked)
        else
          @picked << picked
        end

        Sketchup.active_model.selection.clear
        Sketchup.active_model.selection.add(@picked)
      end

      def handle_preview_click(x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        picked = ph.best_picked

        return unless picked.is_a?(Sketchup::Group)

        @current_group = picked
        @rotation_angle = 0.0
        show_preview
        Sketchup.status_text = "Preview mode: Use arrow keys to rotate, Enter to confirm, Esc to cancel."
      end

      def onKeyDown(key, repeat, flags, view)
        case key
        when 13 # Enter
          if @preview_mode && @current_group
            confirm_preview_replacement
          else
            replace_all_groups
          end
        when 27 # Escape
          if @preview_mode
            exit_preview_mode
          end
        when 82 # R key
          toggle_preview_mode
        when VK_LEFT
          if @preview_mode && @current_group
            @rotation_angle -= 15.0
            show_preview
          end
        when VK_RIGHT
          if @preview_mode && @current_group
            @rotation_angle += 15.0
            show_preview
          end
        when VK_UP
          if @preview_mode && @current_group
            @rotation_angle -= 1.0
            show_preview
          end
        when VK_DOWN
          if @preview_mode && @current_group
            @rotation_angle += 1.0
            show_preview
          end
        end
      end

      def toggle_preview_mode
        @preview_mode = !@preview_mode
        if @preview_mode
          Sketchup.status_text = "Preview mode ON: Click a group to preview replacement."
          clear_previews
        else
          Sketchup.status_text = "Preview mode OFF: Click groups to select/deselect. Press Enter when done."
          clear_previews
          @current_group = nil
        end
      end

      def show_preview
        return unless @current_group

        clear_previews
        
        # Calculate the corrected transformation
        corrected_transformation = calculate_corrected_transformation(@current_group)
        
        # Apply additional rotation if in preview mode
        if @rotation_angle != 0.0
          rotation_transform = Geom::Transformation.rotation(
            corrected_transformation.origin,
            corrected_transformation.zaxis,
            Math.radians(@rotation_angle)
          )
          corrected_transformation = corrected_transformation * rotation_transform
        end

        @preview_transformation = corrected_transformation

        # Create preview instance with transparency
        model = Sketchup.active_model
        preview_instance = model.active_entities.add_instance(@definition, corrected_transformation)
        
        # Make it semi-transparent
        preview_instance.material = create_preview_material
        
        @preview_instances << preview_instance
        
        view = Sketchup.active_model.active_view
        view.invalidate
      end

      def create_preview_material
        model = Sketchup.active_model
        materials = model.materials
        
        # Create or get preview material
        preview_material = materials["PreviewMaterial_V2"]
        unless preview_material
          preview_material = materials.add("PreviewMaterial_V2")
          preview_material.color = [100, 150, 255]
          preview_material.alpha = 0.5
        end
        
        preview_material
      end

      def clear_previews
        return if @preview_instances.empty?
        
        model = Sketchup.active_model
        model.active_entities.erase_entities(@preview_instances)
        @preview_instances.clear
        
        view = Sketchup.active_model.active_view
        view.invalidate
      end

      def confirm_preview_replacement
        return unless @current_group && @preview_transformation

        model = Sketchup.active_model
        model.start_operation("#{PLUGIN_NAME} - Preview Replace", true)

        # Remove preview
        clear_previews

        # Replace the group
        model.active_entities.erase_entities(@current_group)
        new_instance = model.active_entities.add_instance(@definition, @preview_transformation)

        model.commit_operation
        
        @current_group = nil
        @preview_transformation = nil
        exit_preview_mode
        
        Sketchup.status_text = "Group replaced with custom positioning."
      end

      def exit_preview_mode
        clear_previews
        @preview_mode = false
        @current_group = nil
        @rotation_angle = 0.0
        @preview_transformation = nil
        Sketchup.status_text = "Click groups to select/deselect. Press Enter when done."
      end

      def replace_all_groups
        return if @picked.empty?

        model = Sketchup.active_model
        model.start_operation(PLUGIN_NAME, true)

        @picked.each do |group|
          corrected_transformation = calculate_corrected_transformation(group)
          model.active_entities.erase_entities(group)
          model.active_entities.add_instance(@definition, corrected_transformation)
        end

        model.commit_operation
        model.selection.clear
        Sketchup.status_text = "#{@picked.length} groups replaced with corrected positioning."
        model.select_tool(nil)
      end

      def calculate_corrected_transformation(group)
        # Get the group's transformation
        group_transform = group.transformation
        
        # Get the component's original transformation for reference
        component_transform = @component_instance.transformation
        
        # Extract position from group
        group_origin = group_transform.origin
        
        # Extract scale from group (if any)
        group_scale = [
          group_transform.xaxis.length,
          group_transform.yaxis.length,
          group_transform.zaxis.length
        ]
        
        # Get the group's bounding box to understand its orientation
        group_bounds = group.bounds
        group_center = group_bounds.center
        
        # Calculate the offset from group origin to its center
        center_offset = group_center - group.transformation.origin
        
        # Create a transformation that preserves the group's position and orientation
        # but uses the component's default orientation
        
        # Start with the component's base orientation (identity rotation)
        corrected_transform = Geom::Transformation.new
        
        # Apply the group's scale if it's not uniform
        unless group_scale.all? { |s| (s - 1.0).abs < 0.001 }
          scale_transform = Geom::Transformation.scaling(group_scale[0], group_scale[1], group_scale[2])
          corrected_transform = corrected_transform * scale_transform
        end
        
        # Position the component at the group's location
        # Adjust for any center offset to maintain proper positioning
        final_origin = group_origin
        
        # Create final transformation with corrected position
        position_transform = Geom::Transformation.new(final_origin)
        corrected_transform = position_transform * corrected_transform
        
        corrected_transform
      end
    end

    def self.run
      model = Sketchup.active_model
      selection = model.selection

      unless selection.length == 1 && selection.first.is_a?(Sketchup::ComponentInstance)
        return # No popup - silent operation
      end

      component_instance = selection.first
      definition = component_instance.definition
      model.select_tool(ReplacerTool.new(definition, component_instance))
    end

    unless file_loaded?(__FILE__)
      # Toolbar
      cmd = UI::Command.new("#{PLUGIN_NAME} v#{VERSION}") {
        self.run
      }
      
      # Use the existing icon
      icon_path = File.join(File.dirname(__FILE__), "icons", "replace_grp.png")
      if File.exist?(icon_path)
        cmd.small_icon = cmd.large_icon = icon_path
      end
      
      cmd.tooltip = "Replace Groups With Component V2 - Fixed rotation and preview mode"
      cmd.status_bar_text = "Select a component, then groups to replace. Press R for preview mode."

      toolbar = UI::Toolbar.new("Fonoun Tools V2")
      toolbar.add_item(cmd)
      toolbar.restore

      # Context menu
      UI.add_context_menu_handler do |menu|
        selection = Sketchup.active_model.selection
        if selection.length == 1 && selection.first.is_a?(Sketchup::ComponentInstance)
          menu.add_separator
          menu.add_item("Replace Groups With Component V2") {
            self.run
          }
        end
      end

      file_loaded(__FILE__)
    end

  end # module
end # outer module