# License Security Hardening
module AutoNestCut
  module LicenseHardening
    
    def self.hardware_fingerprint
      # Generate unique hardware fingerprint
      require 'digest'
      
      system_info = [
        ENV['COMPUTERNAME'] || ENV['HOSTNAME'],
        ENV['USERNAME'] || ENV['USER'],
        `wmic csproduct get uuid`.split("
")[1]&.strip rescue 'unknown'
      ].compact.join('|')
      
      Digest::SHA256.hexdigest(system_info)[0..15]
    end
    
    def self.verify_license_binding(license_data)
      return false unless license_data
      
      stored_fingerprint = license_data['hardware_id']
      current_fingerprint = hardware_fingerprint
      
      stored_fingerprint == current_fingerprint
    end
    
    def self.encrypt_license_data(data)
      # Simple XOR encryption (use proper encryption in production)
      key = hardware_fingerprint
      encrypted = data.bytes.zip(key.bytes.cycle).map { |a, b| a ^ b }
      encrypted.pack('C*').unpack1('H*')
    end
    
    def self.decrypt_license_data(encrypted_hex)
      encrypted = [encrypted_hex].pack('H*').bytes
      key = hardware_fingerprint
      decrypted = encrypted.zip(key.bytes.cycle).map { |a, b| a ^ b }
      decrypted.pack('C*')
    end
  end
end
