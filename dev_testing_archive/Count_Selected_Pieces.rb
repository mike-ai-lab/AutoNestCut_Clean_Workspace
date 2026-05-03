require 'sketchup.rb'

module CountSelectedPieces

  def self.count_from_selection
    model = Sketchup.active_model
    selection = model.selection

    if selection.empty?
      UI.messagebox("No selection detected.")
      return
    end

    @total_count = 0
    @breakdown = Hash.new(0)

    selection.each do |entity|
      traverse(entity)
    end

    report = "SELECTION PIECE COUNT\n"
    report << "----------------------\n"
    report << "Total Pieces: #{@total_count}\n\n"
    report << "Breakdown:\n"

    @breakdown.each do |name, count|
      report << "- #{name}: #{count}\n"
    end

    UI.messagebox(report)
  end

  def self.traverse(entity)
    return unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)

    @total_count += 1

    name =
      if entity.is_a?(Sketchup::ComponentInstance)
        entity.definition.name.to_s.strip.empty? ? "Unnamed Component" : entity.definition.name
      else
        "Group"
      end

    @breakdown[name] += 1

    entity.definition.entities.each do |child|
      traverse(child)
    end
  end

  unless @menu_loaded
    UI.add_context_menu_handler do |menu|
      sel = Sketchup.active_model.selection
      next if sel.empty?

      menu.add_separator
      menu.add_item("Count Selected Pieces") {
        CountSelectedPieces.count_from_selection
      }
    end

    @menu_loaded = true
  end

end
