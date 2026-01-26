# Emergency License Bypass
# This file provides a temporary bypass for the licensing system
# when the server is experiencing database schema issues

module AutoNestCut
  module LicenseManager
    module EmergencyBypass
      
      def self.create_temporary_license
        # Create a temporary 7-day license for development/emergency use
        expires_at = Time.now + (7 * 24 * 60 * 60) # 7 days from now
        
        payload = {
          license_key: "EMERGENCY-BYPASS-#{Time.now.to_i}",
          device_id: device_hash,
          is_trial: true,
          user_name: "Emergency User",
          email: "emergency@localhost",
          exp: expires_at.to_i
        }
        
        # Create a simple JWT-like token (not cryptographically secure, just for emergency)
        token_data = Base64.strict_encode64(payload.to_json)
        
        # Save to local file
        File.write(LICENSE_FILE_PATH, encode_token(token_data))
        
        UI.messagebox(
          "Emergency license activated!\n\nThis is a temporary 7-day license to bypass server issues.\n\nPlease contact support: muhamad.shkeir@gmail.com",
          MB_OK,
          "Emergency License"
        )
        
        true
      end
      
      def self.is_emergency_license_valid?
        return false unless File.exist?(LICENSE_FILE_PATH)
        
        begin
          encoded_data = File.read(LICENSE_FILE_PATH).strip
          decoded_data = decode_token(encoded_data)
          payload = JSON.parse(Base64.strict_decode64(decoded_data))
          
          # Check if it's an emergency license and still valid
          if payload['license_key'] && payload['license_key'].include?('EMERGENCY-BYPASS')
            return Time.at(payload['exp']) > Time.now if payload['exp']
          end
        rescue
          # If parsing fails, it's not an emergency license
        end
        
        false
      end
      
      private
      
      def self.device_hash
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
      
      def self.encode_token(data)
        Base64.strict_encode64(data.reverse)
      end
      
      def self.decode_token(encoded)
        Base64.strict_decode64(encoded).reverse
      rescue
        encoded
      end
      
    end
  end
end