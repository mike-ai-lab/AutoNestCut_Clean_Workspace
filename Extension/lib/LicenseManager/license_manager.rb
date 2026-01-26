# AutoNestCut License Manager
require 'net/http'
require 'uri'
require 'json'
require 'digest'
require 'base64'
require 'openssl'
require 'fileutils'

# Load emergency bypass
begin
  require_relative 'emergency_bypass'
rescue LoadError
  # Emergency bypass not available
end

module AutoNestCut
  module LicenseManager

    # Remove constants if they exist to prevent warnings
    remove_const(:BASE_URL) if defined?(BASE_URL)
    remove_const(:VALIDATE_URL) if defined?(VALIDATE_URL)
    remove_const(:CREATE_TRIAL_URL) if defined?(CREATE_TRIAL_URL)
    remove_const(:CHECK_TRIAL_URL) if defined?(CHECK_TRIAL_URL)
    remove_const(:RSA_PUBLIC_KEY) if defined?(RSA_PUBLIC_KEY)
    remove_const(:LICENSE_DIR) if defined?(LICENSE_DIR)
    remove_const(:LICENSE_FILE_PATH) if defined?(LICENSE_FILE_PATH)

    # Server endpoints (production ready)
    BASE_URL = ENV['AUTONESTCUT_SERVER_URL'] || 'https://autonestcutserver-9wztmzw4g-moeshks-projects.vercel.app'
    VALIDATE_URL = "#{BASE_URL}/validate-license"
    CREATE_TRIAL_URL = "#{BASE_URL}/create-trial"
    CHECK_TRIAL_URL = "#{BASE_URL}/check-trial"

    # Public key for verifying JWT coming from Supabase
    RSA_PUBLIC_KEY = <<~KEY
    -----BEGIN PUBLIC KEY-----
    MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnq6ZjpeDrfFx6gNPrZFb
    SdQ4lFNglbUwlZQGHch8Vd/x3GakelTvbxx13bYCKZlE21BBcGCednj7pU1iAWau
    u0nkTBP91Ebdmd8AwLlnZc+6kjkn+HMTSzTcCD/CqN1TQIEpZ7yEL65rJWcRlmNE
    2hndRi0asLZ3XOKDzNj2sSl2ftCt+PkWp0LRrUOBtiLghFaeSm88UYJ/FFP5kK9G
    AmP4kdRHQo3LPQpY5w2kLPk9IMYZQnI7x9Ecrc8XehOSBFAZCqY6ciUi3qHed9Ow
    0951VRJAQGUeeXjQYvsAvHPvGIXQj7XgcOG8DFswf0NZLzGyUa/c1iykO4iClOb4
    XwIDAQAB
    -----END PUBLIC KEY-----
    KEY

    # Save license here on Windows (obfuscated filename)
    LICENSE_DIR = File.join(ENV['APPDATA'], 'AutoNestCut')
    LICENSE_FILE_PATH = File.join(LICENSE_DIR, '.anc_auth_cache')
    FileUtils.mkdir_p(LICENSE_DIR) unless Dir.exist?(LICENSE_DIR)

    class << self

      def has_valid_license?
        # Check for emergency bypass license first
        if defined?(EmergencyBypass) && EmergencyBypass.is_emergency_license_valid?
          return true
        end
        
        # First check local license file
        if File.exist?(LICENSE_FILE_PATH)
          encoded_jwt = File.read(LICENSE_FILE_PATH).strip
          jwt = decode_token(encoded_jwt)
          payload = decode_jwt_payload(jwt)
          if payload && payload['exp']
            return Time.at(payload['exp']) > Time.now
          elsif payload
            return true
          end
        end
        
        # If no local license, check server for existing trial
        check_existing_trial
      end

      def show_license_options
        # Check for emergency bypass license first
        if defined?(EmergencyBypass) && EmergencyBypass.is_emergency_license_valid?
          return true
        end
        
        # First check if there's an existing trial on this device
        existing_trial = check_existing_trial
        return true if existing_trial
        
        result = UI.messagebox(
          "AutoNestCut License Required.\n\nYES → Start 7-Day Free Trial\nNO → Enter License Key\nCANCEL → Purchase options",
          MB_YESNOCANCEL,
          "AutoNestCut License"
        )

        return start_free_trial if result == IDYES
        return enter_license_key if result == IDNO
        purchase_info
        false
      end

      def start_free_trial
        info = UI.inputbox(['Name:', 'Email:'], ['', ''], 'Start Trial')
        return false unless info && !info[0].empty? && !info[1].empty?

        result = server_request(CREATE_TRIAL_URL, {
          name: info[0].strip,
          email: info[1].strip,
          device_id: device_hash
        })

        if result == :trial_used
          UI.messagebox("Trial already used on this device.\n\nPurchase a full license to continue.\n\nEmail: muhamad.shkeir@gmail.com")
          return false
        elsif result.is_a?(Hash) && result['error']
          if result['error'].include?('expired')
            UI.messagebox("Your trial has expired.\n\nPurchase a full license to continue.\n\nEmail: muhamad.shkeir@gmail.com")
          else
            UI.messagebox("Trial issue: #{result['error']}\n\nContact support: muhamad.shkeir@gmail.com")
          end
          return false
        elsif result == :invalid_email
          UI.messagebox("Invalid email format.\n\nPlease enter a valid email address.")
          return false
        end

        if result.is_a?(Hash) && result['jwt_token']
          File.write(LICENSE_FILE_PATH, encode_token(result['jwt_token']))
          days = result['remaining_days'] || 7
          UI.messagebox(result['message'] || "Trial activated for #{days} days.")
          return true
        elsif result
          File.write(LICENSE_FILE_PATH, encode_token(result))
          UI.messagebox("Trial activated for 7 days.")
          return true
        end
        false
      end

      def enter_license_key
        input = UI.inputbox(['License Key:'], [''], 'Activate License')
        return false unless input && !input[0].empty?
        key = input[0].strip.upcase

        # Accept multiple license key formats
        unless key.match?(/^(ANC|PRM)-[A-Z0-9]{4}-[A-Z0-9]{4}$/) || key.match?(/^[A-Z0-9]{8}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{12}$/)
          UI.messagebox("Invalid license key format.\n\nExpected formats:\n• ANC-XXXX-XXXX\n• Standard UUID format\n\nPlease check your license key and try again.", MB_OK, "Invalid License Key")
          return false
        end

        # Show progress message
        UI.messagebox("Validating license key...\nPlease wait.", MB_OK, "Validating License")
        
        result = server_request(VALIDATE_URL, {
          license_key: key,
          device_id: device_hash,
          country: get_country_code
        })

        if result.is_a?(Hash) && result['error']
          case result['error']
          when /Invalid license key/i
            UI.messagebox("License key not found.\n\nPlease check your license key or contact support:\nmuhamad.shkeir@gmail.com", MB_OK, "License Not Found")
          when /bound to another device/i
            UI.messagebox("This license is already activated on another device.\n\nEach license can only be used on one device.\n\nContact support for assistance:\nmuhamad.shkeir@gmail.com", MB_OK, "License Already Used")
          when /expired/i
            UI.messagebox("This license has expired.\n\nContact support for renewal:\nmuhamad.shkeir@gmail.com", MB_OK, "License Expired")
          when /Server maintenance/i, /activated_at/i
            # Server has database issues - offer emergency bypass
            if defined?(EmergencyBypass)
              emergency_result = UI.messagebox(
                "Server is temporarily unavailable due to maintenance.\n\nWould you like to activate a temporary 7-day emergency license?\n\nYES = Activate Emergency License\nNO = Try Again Later",
                MB_YESNO,
                "Server Maintenance"
              )
              return EmergencyBypass.create_temporary_license if emergency_result == IDYES
            else
              UI.messagebox("Server maintenance in progress.\n\nPlease try again in a few minutes.\n\nContact support if the issue persists:\nmuhamad.shkeir@gmail.com", MB_OK, "Server Maintenance")
            end
          else
            UI.messagebox("License validation failed:\n#{result['error']}\n\nContact support:\nmuhamad.shkeir@gmail.com", MB_OK, "Validation Error")
          end
          return false
        end

        if result.is_a?(Hash) && result['jwt_token']
          jwt_token = result['jwt_token']
        elsif result.is_a?(String)
          jwt_token = result
        else
          UI.messagebox("Invalid response from server.\n\nPlease try again or contact support:\nmuhamad.shkeir@gmail.com", MB_OK, "Server Error")
          return false
        end

        # Validate the JWT token before saving
        unless validate_jwt(jwt_token)
          UI.messagebox("Invalid license token received.\n\nContact support:\nmuhamad.shkeir@gmail.com", MB_OK, "Invalid Token")
          return false
        end

        # Save the license
        File.write(LICENSE_FILE_PATH, encode_token(jwt_token))
        
        # Get license details for confirmation
        payload = decode_jwt_payload(jwt_token)
        user_name = payload['user_name'] || payload['name'] || 'User'
        is_trial = payload['is_trial'] == true
        license_type = is_trial ? 'Trial' : 'Full'
        
        if payload['exp']
          expires_at = Time.at(payload['exp'])
          days_remaining = ((expires_at - Time.now) / (24 * 60 * 60)).ceil
          expiry_text = is_trial ? "\n\nTrial expires in #{days_remaining} days." : "\n\nExpires: #{expires_at.strftime('%B %d, %Y')}"
        else
          expiry_text = "\n\nLifetime license - never expires!"
        end
        
        UI.messagebox("✅ License activated successfully!\n\nWelcome, #{user_name}\nLicense Type: #{license_type}#{expiry_text}\n\nYou can now use AutoNestCut.", MB_OK, "License Activated")
        true
      end

      def validate_jwt(jwt)
        payload = decode_jwt_payload(jwt)
        return false unless payload

        key = OpenSSL::PKey::RSA.new(RSA_PUBLIC_KEY)
        header, payload_part, signature = jwt.split('.')
        data = "#{header}.#{payload_part}"
        sig = Base64.urlsafe_decode64(signature)

        key.verify(OpenSSL::Digest::SHA256.new, sig, data)
      rescue
        false
      end

      def check_existing_trial(show_message = true)
        result = server_request(CHECK_TRIAL_URL, { device_id: device_hash })
        
        if result.is_a?(Hash) && result['has_trial'] && result['jwt_token']
          File.write(LICENSE_FILE_PATH, encode_token(result['jwt_token']))
          days = result['remaining_days'] || 0
          if show_message
            UI.messagebox(
              "Welcome back! Your AutoNestCut trial has #{days} days remaining.\n\nYou can continue using the extension on this device.",
              MB_OK,
              "Trial Restored"
            )
          end
          return true
        end
        
        false
      rescue => e
        false
      end
      
      private

      def server_request(url, body)
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.read_timeout = 30
        http.open_timeout = 10
        
        req = Net::HTTP::Post.new(uri.request_uri)
        req['Content-Type'] = 'application/json'
        req['User-Agent'] = 'AutoNestCut-SketchUp/1.0'
        req.body = body.to_json

        response = http.request(req)
        
        case response
        when Net::HTTPRedirection
          location = response['location']
          return server_request(location, body)
        else
          res = response
        end
        
        # Handle specific error codes
        case res.code
        when '400'
          error_data = JSON.parse(res.body) rescue { 'error' => 'Bad request' }
          return error_data
        when '403'
          error_data = JSON.parse(res.body) rescue { 'error' => 'License is bound to another device' }
          return error_data
        when '404'
          return { 'error' => 'Invalid license key' }
        when '409'
          data = JSON.parse(res.body) rescue {}
          if data['error'] && data['error'].include?('expired')
            return data
          end
          return :trial_used
        when '410'
          return { 'error' => 'License expired' }
        when '500'
          error_data = JSON.parse(res.body) rescue { 'error' => 'Server error. Please try again later.' }
          # Handle database schema issues gracefully
          if error_data['error'] && error_data['error'].include?('activated_at')
            puts "[LICENSE] Database schema issue detected - attempting fallback"
            return { 'error' => 'Server maintenance in progress. Please try again in a few minutes.' }
          end
          return error_data
        end
        
        return { 'error' => "HTTP #{res.code}: #{res.message}" } unless res.is_a?(Net::HTTPSuccess)

        data = JSON.parse(res.body)
        return data if data.is_a?(Hash) && (data['jwt_token'] || data['message'] || data['error'])
        data['jwt'] || data['jwt_token'] || data
      rescue Net::TimeoutError
        { 'error' => 'Connection timeout. Please check your internet connection and try again.' }
      rescue Net::OpenTimeout
        { 'error' => 'Connection timeout. Please check your internet connection and try again.' }
      rescue SocketError
        { 'error' => 'Network error. Please check your internet connection.' }
      rescue => e
        { 'error' => "Network error: #{e.message}" }
      end

      def decode_jwt_payload(token)
        parts = token.split('.')
        return nil unless parts.length == 3

        payload = parts[1]
        payload += '=' * (4 - payload.length % 4) if payload.length % 4 != 0
        JSON.parse(Base64.urlsafe_decode64(payload))
      rescue
        nil
      end

      def device_hash
        name = ENV['COMPUTERNAME'] || 'pc'
        user = ENV['USERNAME'] || 'user'
        id = 'unknown'
        begin
          raw = `reg query "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Cryptography" /v MachineGuid 2>nul`
          id = raw.split('REG_SZ').last.strip if raw.include?('REG_SZ')
        rescue
        end
        Digest::SHA256.hexdigest("#{name}-#{user}-#{id}")
      end
      
      def get_country_code
        # Try to get country from system locale
        begin
          locale = `powershell -Command "Get-Culture | Select-Object -ExpandProperty Name" 2>nul`.strip
          return locale.split('-').last.upcase if locale.include?('-')
        rescue
        end
        'US' # Default fallback
      end

      def purchase_info
        UI.messagebox("To purchase a full license:\nEmail: muhamad.shkeir@gmail.com")
      end

      # Simple obfuscation for JWT storage
      def encode_token(jwt)
        Base64.strict_encode64(jwt.reverse)
      end

      def decode_token(encoded)
        Base64.strict_decode64(encoded).reverse
      rescue
        encoded # fallback for unencoded tokens
      end

    end
  end
end
