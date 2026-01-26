# filename: cut_sequence_generator.rb
require_relative '../util'

module AutoNestCut
  class CutSequenceGenerator
    
    def initialize
      # Initialize any required settings
    end
    
    def generate_cut_sequences(boards)
      cut_sequences = []
      
      boards.each_with_index do |board, index|
        board_number = index + 1
        
        # Get current settings for units
        current_settings = Config.get_cached_settings
        units = current_settings['units'] || 'mm'
        precision = current_settings['precision'] || 1
        
        # Convert dimensions for display
        stock_width = board.stock_width / (current_settings['unit_factors'] || {'mm' => 1})[units]
        stock_height = board.stock_height / (current_settings['unit_factors'] || {'mm' => 1})[units]
        
        board_sequence = {
          board_number: board_number,
          material: board.material,
          stock_dimensions: "#{stock_width.round(precision)} x #{stock_height.round(precision)} #{units}",
          cut_sequence: generate_board_cut_sequence(board, units, precision)
        }
        
        cut_sequences << board_sequence
      end
      
      cut_sequences
    end
    
    private
    
    def generate_board_cut_sequence(board, units, precision)
      sequence = []
      step_counter = 1
      
      # Start with stock preparation
      stock_width = board.stock_width / (Config.get_cached_settings['unit_factors'] || {'mm' => 1})[units]
      stock_height = board.stock_height / (Config.get_cached_settings['unit_factors'] || {'mm' => 1})[units]
      
      sequence << {
        step: step_counter,
        type: "Setup",
        description: "Prepare stock material",
        measurement: "#{stock_width.round(precision)} x #{stock_height.round(precision)} #{units}"
      }
      step_counter += 1
      
      # Generate cuts for each part
      if board.parts_on_board && board.parts_on_board.length > 0
        # Sort parts by position for logical cutting sequence
        sorted_parts = board.parts_on_board.sort_by { |part| [part.y, part.x] }
        
        sorted_parts.each_with_index do |part, idx|
          part_width = part.width / (Config.get_cached_settings['unit_factors'] || {'mm' => 1})[units]
          part_height = part.height / (Config.get_cached_settings['unit_factors'] || {'mm' => 1})[units]
          
          # Sanitize part name for display
          part_name = sanitize_text(part.name)
          
          # Primary cut (usually length)
          sequence << {
            step: step_counter,
            type: "Cut",
            description: "Cut #{part_name} - Length",
            measurement: "#{part_width.round(precision)} #{units}"
          }
          step_counter += 1
          
          # Secondary cut (usually width)
          sequence << {
            step: step_counter,
            type: "Cut", 
            description: "Cut #{part_name} - Width",
            measurement: "#{part_height.round(precision)} #{units}"
          }
          step_counter += 1
          
          # Edge banding if required
          if part.edge_banding && part.edge_banding != 'None'
            eb_value = ""
            if part.edge_banding.is_a?(Hash)
              eb_type = part.edge_banding[:type] || part.edge_banding['type'] || "Standard"
              eb_edges = part.edge_banding[:edges] || part.edge_banding['edges']
              
              if eb_edges.is_a?(Array)
                eb_value = "#{eb_type} (#{eb_edges.join(', ')})"
              else
                eb_value = "#{eb_type} (#{eb_edges})"
              end
            else
              eb_value = part.edge_banding.to_s
            end

            sequence << {
              step: step_counter,
              type: "Edge Band",
              description: "Apply edge banding to #{part_name}",
              measurement: eb_value
            }
            step_counter += 1
          end
        end
      else
        sequence << {
          step: step_counter,
          type: "Note",
          description: "No parts placed on this board",
          measurement: "N/A"
        }
      end
      
      sequence
    end
    
    def sanitize_text(text)
      return "" if text.nil?
      text.to_s.gsub('#', 'No.')
    end
  end
end