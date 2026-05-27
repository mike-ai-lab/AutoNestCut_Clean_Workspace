# frozen_string_literal: true
require_relative '../processors/material_checker'

module AutoNestCut
  module MaterialCheckerUI

    def self.show_dialog
      model     = Sketchup.active_model
      selection = model.selection

      if selection.empty?
        UI.messagebox("Please select the assembly or components you want to check before running Material Check.")
        return
      end

      # Run the scan immediately — it's fast
      result = MaterialChecker.scan(selection)

      html_file = File.join(__dir__, 'html', 'material_checker.html')

      dialog = UI::HtmlDialog.new(
        dialog_title:    "Material Check — AutoNestCut",
        preferences_key: "AutoNestCut_MaterialChecker",
        scrollable:      false,
        resizable:       true,
        width:           860,
        height:          560,
        min_width:       700,
        min_height:      420,
        style:           UI::HtmlDialog::STYLE_DIALOG
      )

      AutoNestCut.set_html_with_cache_busting(dialog, html_file)

      dialog.add_action_callback('proceed_to_nesting') do |_ctx|
        dialog.close
        AutoNestCut.run_extension_feature
      end

      dialog.add_action_callback('close_material_checker') do |_ctx|
        dialog.close
      end

      # Push scan data to the dialog once it's ready
      dialog.set_on_closed {}
      dialog.show

      # Inject data after a short delay to ensure the page has loaded
      dialog.add_action_callback('ready') do |_ctx|
        json = result.to_json
        dialog.execute_script("loadData(#{json});")
      end

      # Fallback: also inject via set_html callback timing
      # Use a one-shot timer to push data after the dialog renders
      UI.start_timer(0.3, false) do
        begin
          json = result.to_json
          dialog.execute_script("loadData(#{json});")
        rescue
          # Dialog may have been closed already
        end
      end
    end

  end
end
