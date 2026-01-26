# AutoNestCut Trial Management
require_relative 'license_manager'

module AutoNestCut
  module TrialManager
    
    class << self
      
      def get_trial_days_remaining
        return 0 unless File.exist?(LicenseManager::LICENSE_FILE_PATH)
        
        begin
          encoded_jwt = File.read(LicenseManager::LICENSE_FILE_PATH).strip
          jwt_token = LicenseManager.send(:decode_token, encoded_jwt)
          payload = LicenseManager.send(:decode_jwt_payload, jwt_token)
          return 0 unless payload && payload['exp']
          
          remaining_seconds = payload['exp'] - Time.now.to_i
          remaining_days = (remaining_seconds / (24 * 60 * 60)).ceil
          
          return [remaining_days, 0].max
        rescue
          return 0
        end
      end
      
      def show_trial_status
        # Check server for most up-to-date trial status (silent check)
        if defined?(AutoNestCut::LicenseManager)
          AutoNestCut::LicenseManager.check_existing_trial(false)
        end
        
        days = get_trial_days_remaining
        if days > 0
          UI.messagebox(
            "Your AutoNestCut trial has #{days} days remaining.\n\nYou can continue using the extension on this device.\n\nTo purchase a full license, contact: muhamad.shkeir@gmail.com",
            MB_OK,
            "Trial Status"
          )
        else
          UI.messagebox(
            "Your trial has expired or no trial found.\n\nTo purchase a full license, contact: muhamad.shkeir@gmail.com",
            MB_OK,
            "Trial Status"
          )
        end
        true
      end
      
      def start_trial_countdown
        days_remaining = get_trial_days_remaining
        
        if days_remaining > 0
          UI.start_timer(5.0, true) do
            update_trial_status
          end
        end
      end
      
      def update_trial_status
        days_remaining = get_trial_days_remaining
        
        if days_remaining <= 0
          show_trial_expired
          return false
        end
        
        Sketchup.status_text = "AutoNestCut Trial: #{days_remaining} days remaining"
        
        if days_remaining <= 2 && !@trial_warning_shown
          UI.messagebox(
            "Your AutoNestCut trial expires in #{days_remaining} days.\n\nPurchase a full license to continue using AutoNestCut.\n\nEmail: muhamad.shkeir@gmail.com",
            MB_OK,
            "Trial Expiring Soon"
          )
          @trial_warning_shown = true
        end
        
        return true
      end
      
      def show_trial_expired
        return if @trial_expired_shown
        @trial_expired_shown = true
        
        result = UI.messagebox(
          "Your AutoNestCut trial has expired.\n\nWould you like to purchase a full license?",
          MB_YESNO,
          "Trial Expired"
        )
        
        if result == IDYES
          UI.messagebox(
            "Purchase AutoNestCut Full License\n\nEmail: muhamad.shkeir@gmail.com",
            MB_OK,
            "Purchase License"
          )
        end
        
        File.delete(LicenseManager::LICENSE_FILE_PATH) if File.exist?(LicenseManager::LICENSE_FILE_PATH)
      end
      
      def trial_active?
        return false unless File.exist?(LicenseManager::LICENSE_FILE_PATH)
        
        begin
          encoded_jwt = File.read(LicenseManager::LICENSE_FILE_PATH).strip
          jwt_token = LicenseManager.send(:decode_token, encoded_jwt)
          payload = LicenseManager.send(:decode_jwt_payload, jwt_token)
          return false unless payload
          
          # Check if it's a trial and still valid
          is_trial = payload['is_trial'] == true
          if is_trial && payload['exp']
            return Time.at(payload['exp']) > Time.now
          elsif !is_trial
            return true # Full license
          end
          
          false
        rescue
          false
        end
      end
      
    end
  end
end