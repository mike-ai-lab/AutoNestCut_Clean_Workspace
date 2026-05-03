# SVG Vector Export Integration Example
# Add this to your main.rb or dialog_manager.rb

# ============================================================================
# SVG VECTOR EXPORT INTEGRATION
# ============================================================================

# Add this menu item to your SketchUp plugin menu
def self.add_svg_export_menu
  menu = UI.menu("Plugins")
  autonestcut_menu = menu.add_submenu("AutoNestCut")
  
  autonestcut_menu.add_separator
  autonestcut_menu.add_item("🎯 Flatten for CNC (SVG Export)") do
    show_svg_export_dialog
  end
end

# Show the SVG export dialog
def self.show_svg_export_dialog
  entity = Sketchup.active_model.selection[0]
  
  unless entity && (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance))
    UI.messagebox(
      "Please select a component or group first.\n\nThe SVG export feature requires a valid 3D component.",
      MB_OK,
      "Selection Required"
    )
    return
  end
  
  require_relative 'ui/svg_export_ui'
  AutoNestCut::SvgExportUI.show_svg_export_dialog(entity)
end

# ============================================================================
# CONTEXT MENU INTEGRATION
# ============================================================================

# Add right-click context menu for components
def self.add_context_menu
  UI.add_context_menu_handler do |menu|
    entity = Sketchup.active_model.selection[0]
    
    if entity && (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance))
      menu.add_separator
      menu.add_item("🎯 Flatten for CNC") do
        show_svg_export_dialog
      end
    end
  end
end

# ============================================================================
# BATCH EXPORT FUNCTION
# ============================================================================

# Export all selected components as SVG
def self.batch_export_svg
  require_relative 'exporters/svg_vector_exporter'
  
  selected = Sketchup.active_model.selection
  
  if selected.empty?
    UI.messagebox("Please select one or more components.", MB_OK, "No Selection")
    return
  end
  
  face_name = 'Front'  # Could be made configurable
  exported_count = 0
  failed_count = 0
  
  selected.each do |entity|
    next unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
    
    begin
      output_path = SvgVectorExporter.export_face_as_svg(entity, face_name)
      if output_path && File.exist?(output_path)
        exported_count += 1
        puts "✓ Exported: #{File.basename(output_path)}"
      else
        failed_count += 1
      end
    rescue => e
      failed_count += 1
      puts "✗ Failed to export #{entity.name}: #{e.message}"
    end
  end
  
  message = "Batch Export Complete\n\n"
  message += "✓ Successfully exported: #{exported_count}\n"
  message += "✗ Failed: #{failed_count}" if failed_count > 0
  
  UI.messagebox(message, MB_OK, "Batch Export")
end

# ============================================================================
# QUICK EXPORT (NO DIALOG)
# ============================================================================

# Quick export with default settings
def self.quick_export_svg(face_name = 'Front')
  require_relative 'exporters/svg_vector_exporter'
  
  entity = Sketchup.active_model.selection[0]
  
  unless entity && (entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance))
    UI.messagebox("Please select a component.", MB_OK, "Selection Required")
    return
  end
  
  begin
    output_path = SvgVectorExporter.export_face_as_svg(entity, face_name)
    
    if output_path && File.exist?(output_path)
      UI.messagebox(
        "SVG exported successfully!\n\n#{File.basename(output_path)}",
        MB_OK,
        "Export Complete"
      )
      
      # Open file location on Windows
      system("explorer.exe /select,\"#{output_path}\"") if Sketchup.platform == :platform_win
    else
      UI.messagebox("Failed to export SVG.", MB_OK, "Export Error")
    end
  rescue => e
    UI.messagebox("Error: #{e.message}", MB_OK, "Export Error")
  end
end

# ============================================================================
# KEYBOARD SHORTCUT SETUP
# ============================================================================

# Add keyboard shortcuts (optional)
def self.setup_keyboard_shortcuts
  # Ctrl+Shift+E for SVG export
  UI.add_context_menu_handler do |menu|
    # This is handled by the context menu above
  end
end

# ============================================================================
# USAGE EXAMPLES
# ============================================================================

=begin

# In your main.rb initialization:

# Add menu item
AutoNestCut.add_svg_export_menu

# Add context menu
AutoNestCut.add_context_menu

# Usage:
# 1. Select a component in SketchUp
# 2. Right-click and choose "Flatten for CNC"
# 3. Select face and options
# 4. Click "Export SVG"
# 5. File opens in Downloads folder

# Or use quick export:
# AutoNestCut.quick_export_svg('Front')

# Or batch export:
# AutoNestCut.batch_export_svg

=end

# ============================================================================
# DIALOG MANAGER INTEGRATION
# ============================================================================

# Add this to your dialog_manager.rb if using HTML dialogs

class DialogManager
  
  def handle_svg_export_request(params)
    require_relative 'svg_export_ui'
    
    entity = Sketchup.active_model.selection[0]
    return unless entity
    
    AutoNestCut::SvgExportUI.handle_svg_export(entity, params)
  end
  
  # Add callback for SVG export
  def setup_svg_callbacks
    @dialog.add_action_callback("export_svg") do |action_context, params|
      handle_svg_export_request(params)
    end
  end
end

# ============================================================================
# ADVANCED: CUSTOM EXPORT WITH OPTIONS
# ============================================================================

def self.export_svg_with_options(entity, options = {})
  require_relative 'exporters/svg_vector_exporter'
  
  face_name = options[:face] || 'Front'
  include_dimensions = options[:include_dimensions] != false
  include_metadata = options[:include_metadata] != false
  output_path = options[:output_path]
  
  # Export
  svg_path = SvgVectorExporter.export_face_as_svg(entity, face_name, output_path)
  
  # Post-processing if needed
  if include_dimensions && include_metadata
    # SVG already includes these by default
  end
  
  svg_path
end

# Example usage:
# svg_file = export_svg_with_options(
#   entity,
#   face: 'Top',
#   include_dimensions: true,
#   include_metadata: true,
#   output_path: '/custom/path/output.svg'
# )
