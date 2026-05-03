# SketchUp Extension Example - Using AI Integration
# This shows how to integrate the AI WebSocket server into your existing extension
#
# Add this to your extension's main file

require_relative 'sketchup_ai_integration'

module YourExtensionName
  module AIIntegration
    def self.start_ai_server
      # Start the AI WebSocket server
      start_sketchup_ai_server(8080)
      puts "Your Extension: AI Integration started"
    end
    
    def self.stop_ai_server
      # Stop the AI WebSocket server
      stop_sketchup_ai_server
      puts "Your Extension: AI Integration stopped"
    end
    
    def self.add_ai_menu
      # Add menu items for AI integration
      UI.menu('Extensions').add_item('Start AI Server') { start_ai_server }
      UI.menu('Extensions').add_item('Stop AI Server') { stop_ai_server }
      UI.menu('Extensions').add_item('Test AI Connection') { test_ai_connection }
    end
    
    def self.test_ai_connection
      # Simple test to verify AI integration is working
      model = Sketchup.active_model
      if model
        UI.messagebox("AI Integration Test:\nModel: #{model.name}\nEntities: #{model.entities.count}")
      else
        UI.messagebox("No active model found")
      end
    end
  end
end

# Initialize AI integration when extension loads
if defined?(Sketchup)
  # Start the server automatically
  YourExtensionName::AIIntegration.start_ai_server
  
  # Add menu items
  YourExtensionName::AIIntegration.add_ai_menu
  
  puts "Your Extension: AI Integration loaded successfully"
end

# Example of how to use AI commands in your extension:
#
# # Send a command to AI
# def send_ai_command(command_hash)
#   # This would be implemented to send commands to connected AI clients
#   # For now, the server handles incoming commands automatically
# end
#
# # Example usage in your extension methods:
# def your_extension_method
#   # Your extension logic here
#   
#   # Notify AI about what happened
#   # send_ai_command({ command: 'extension_event', data: { action: 'your_action' } })
# end