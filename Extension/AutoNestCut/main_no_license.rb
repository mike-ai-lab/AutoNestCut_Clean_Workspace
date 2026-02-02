# frozen_string_literal: true

require 'sketchup.rb'

# Core extension files
require_relative 'compatibility'
require_relative 'materials_database'
require_relative 'config'
require_relative 'models/part'
require_relative 'models/board'
require_relative 'processors/model_analyzer'
require_relative 'processors/nester'
require_relative 'ui/dialog_manager'
require_relative 'exporters/diagram_generator'
require_relative 'exporters/report_generator'
require_relative 'util'

module AutoNestCut

  EXTENSION_NAME = 'AutoNestCut v2.1 [NEW FEATURES]'.freeze
  EXTENSION_VERSION = '2.1.0'.freeze
  EXTENSION_DESCRIPTION = 'Automated nesting and cut list generation with image export and clipboard features.'.freeze

  def self.run_extension_feature
    model = Sketchup.active_model
    selection = model.selection

    if selection.empty?
      UI.messagebox("Please select components or groups to analyze for AutoNestCut.")
      return
    end

    begin
      analyzer = ModelAnalyzer.new
      part_types_by_material_and_quantities = analyzer.extract_parts_from_selection(selection)
      original_components = analyzer.get_original_components_data

      if part_types_by_material_and_quantities.empty?
        UI.messagebox("No valid sheet good parts found in your selection for AutoNestCut.")
        return
      end

      dialog_manager = UIDialogManager.new
      hierarchy_tree = analyzer.get_hierarchy_tree
      dialog_manager.show_config_dialog(part_types_by_material_and_quantities, original_components, hierarchy_tree)

    rescue => e
      UI.messagebox("An error occurred during part extraction:\n#{e.message}")
    end
  end

  def self.setup_ui
    unless file_loaded?("#{__FILE__}-ui")
      # Create main menu
      menu = UI.menu('Extensions')
      autonest_menu = menu.add_submenu(EXTENSION_NAME)

      autonest_menu.add_item('Generate Cut List') { AutoNestCut.run_extension_feature }

      # Create toolbar with icon
      toolbar = UI::Toolbar.new(EXTENSION_NAME)
      cmd = UI::Command.new(EXTENSION_NAME) { AutoNestCut.run_extension_feature }
      cmd.tooltip = 'Generate optimized cut lists with NEW image export and clipboard features'
      cmd.status_bar_text = 'AutoNestCut v2.1 - NEW: Image Export & Clipboard Copy'

      toolbar.add_item(cmd)
      toolbar.show

      file_loaded("#{__FILE__}-ui")
    end
  end

  # Module initialization
  unless defined?(@@loaded)
    @@loaded = true
    timestamp = Time.now.strftime("%H:%M:%S")
    puts "✅ AutoNestCut v2.1 Module Loaded [#{timestamp}] - NEW FEATURES ACTIVE"
    
    setup_ui
  end

end