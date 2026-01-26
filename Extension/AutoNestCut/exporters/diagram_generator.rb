module AutoNestCut
  class DiagramGenerator
    def prepare_diagram_data(boards)
      boards.map(&:to_h)
    end
  end
end