# AI Client Test - Test the SketchUp AI Integration
# This script tests the WebSocket connection and commands
#
# Usage: ruby ai_client_test.rb

require 'socket'
require 'json'
require 'base64'
require 'digest/sha1'

class AIClient
  def initialize(host = 'localhost', port = 8080)
    @host = host
    @port = port
    @socket = nil
  end

  def connect
    puts "Connecting to SketchUp AI Server at #{@host}:#{@port}..."
    @socket = TCPSocket.new(@host, @port)

    # WebSocket handshake
    handshake_request = "GET / HTTP/1.1\r\n"
    handshake_request += "Host: #{@host}:#{@port}\r\n"
    handshake_request += "Upgrade: websocket\r\n"
    handshake_request += "Connection: Upgrade\r\n"
    handshake_request += "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n"
    handshake_request += "Sec-WebSocket-Version: 13\r\n"
    handshake_request += "\r\n"

    @socket.write(handshake_request)

    # Read handshake response
    response = @socket.gets("\r\n\r\n")
    if response.include?("101 Switching Protocols")
      puts "✓ WebSocket connection established"
      true
    else
      puts "✗ WebSocket handshake failed"
      false
    end
  rescue => e
    puts "✗ Connection failed: #{e.message}"
    false
  end

  def send_command(command)
    return false unless @socket

    begin
      # Send WebSocket frame with masking
      data = command.to_json
      header = [0x81, 0x80, data.length].pack('CCC') # FIN + text frame + mask flag
      mask_key = (0...4).map { rand(0..255) }.pack('C*')
      masked_data = data.bytes.zip(mask_key.bytes.cycle).map { |b, m| (b ^ m).chr }.join

      @socket.write(header + mask_key + masked_data)

      # Read response
      response = receive_message
      JSON.parse(response) if response
    rescue => e
      puts "✗ Command failed: #{e.message}"
      nil
    end
  end

  def receive_message
    begin
      # Read WebSocket frame header
      header = @socket.read(2)
      return nil unless header

      # Parse header
      fin = (header[0].ord & 0x80) != 0
      opcode = header[0].ord & 0x0F
      mask = (header[1].ord & 0x80) != 0
      payload_len = header[1].ord & 0x7F

      # Handle extended payload lengths
      if payload_len == 126
        payload_len = @socket.read(2).unpack('n')[0]
      elsif payload_len == 127
        payload_len = @socket.read(8).unpack('Q>')[0]
      end

      # Read masking key (servers don't mask frames to clients)
      mask_key = mask ? @socket.read(4) : nil

      # Read payload
      payload = @socket.read(payload_len)

      # Unmask payload if necessary
      if mask && mask_key
        payload = payload.bytes.zip(mask_key.bytes.cycle).map { |b, m| (b ^ m).chr }.join
      end

      # Only process text frames
      payload if opcode == 1 && fin
    rescue
      nil
    end
  end

  def disconnect
    @socket.close if @socket
    puts "Disconnected from SketchUp AI Server"
  end

  def test_commands
    puts "\n=== Testing SketchUp AI Commands ===\n"

    # Test 1: Get scene info
    puts "1. Testing get_scene_info..."
    result = send_command({ command: 'get_scene_info' })
    if result && result['scene_info']
      puts "✓ Scene info received:"
      puts "  Model: #{result['scene_info']['model_name']}"
      puts "  Entities: #{result['scene_info']['entities_count']}"
      puts "  Components: #{result['scene_info']['components_count']}"
    else
      puts "✗ Failed to get scene info"
    end

    # Test 2: Get components
    puts "\n2. Testing get_components..."
    result = send_command({ command: 'get_components' })
    if result && result['components']
      puts "✓ Components found: #{result['components'].length}"
      result['components'].first(3).each do |comp|
        puts "  - #{comp['name']} at [#{comp['position'].join(', ')}]"
      end
    else
      puts "✗ Failed to get components"
    end

    # Test 3: Get materials
    puts "\n3. Testing get_materials..."
    result = send_command({ command: 'get_materials' })
    if result && result['materials']
      puts "✓ Materials found: #{result['materials'].length}"
      result['materials'].first(3).each do |mat|
        puts "  - #{mat['name']}"
      end
    else
      puts "✗ Failed to get materials"
    end

    # Test 4: Create box
    puts "\n4. Testing create_box..."
    result = send_command({
      command: 'create_box',
      params: { width: 50, height: 50, depth: 50 }
    })
    if result && result['success']
      puts "✓ Box created successfully"
    else
      puts "✗ Failed to create box: #{result['error']}"
    end

    # Test 5: Get selection
    puts "\n5. Testing get_selection..."
    result = send_command({ command: 'get_selection' })
    if result && result['selection']
      puts "✓ Selection info received: #{result['selection'].length} items"
    else
      puts "✗ Failed to get selection"
    end

    # Test 6: Analyze model
    puts "\n6. Testing analyze_model..."
    result = send_command({ command: 'analyze_model' })
    if result && result['model_stats']
      puts "✓ Model analysis complete:"
      puts "  Faces: #{result['model_stats']['total_faces']}"
      puts "  Edges: #{result['model_stats']['total_edges']}"
      puts "  Issues: #{result['potential_issues'].length}"
    else
      puts "✗ Failed to analyze model"
    end

    # Test 7: Test extension
    puts "\n7. Testing test_extension..."
    result = send_command({
      command: 'test_extension',
      params: { name: 'My Test Extension' }
    })
    if result && result['test_results']
      puts "✓ Extension test complete:"
      result['test_results'].each do |test|
        status_icon = test['status'] == 'PASS' ? '✓' : '✗'
        puts "  #{status_icon} #{test['test']}: #{test['details']}"
      end
      puts "  Overall: #{result['overall_status']}"
    else
      puts "✗ Failed to test extension"
    end
  end
end

# Run the test
if __FILE__ == $0
  puts "SketchUp AI Integration - Client Test"
  puts "===================================="

  client = AIClient.new

  if client.connect
    client.test_commands
    client.disconnect
  else
    puts "Failed to connect to SketchUp AI Server"
    puts "Make sure the server is running on port 8080"
  end
end