# AutoNestCut License Information Dialog
require 'json'
require_relative 'license_manager'

module AutoNestCut
  class LicenseDialog

    def self.show
      license_info = get_license_info
      html_content = generate_html(license_info)

      dialog = UI::HtmlDialog.new(
        dialog_title: "AutoNestCut License Information",
        preferences_key: "AutoNestCut_License_Dialog",
        scrollable: true,
        resizable: false,
        width: 450,
        height: 400,
        left: 200,
        top: 200,
        min_width: 450,
        min_height: 400,
        max_width: 450,
        max_height: 400,
        style: UI::HtmlDialog::STYLE_DIALOG
      )

      dialog.set_html(html_content)

      dialog.add_action_callback("remove_license") do |action_context|
        result = UI.messagebox(
          "Are you sure you want to remove the current license?\n\nThis will disable the extension until re-activation.",
          MB_YESNO,
          "Remove License"
        )
        if result == IDYES
          remove_license
          dialog.close
          UI.messagebox("License removed. Extension disabled.\n\nRestart SketchUp to re-activate.", MB_OK, "License Removed")
          # Immediately disable extension functionality
          disable_extension
        end
      end

      dialog.add_action_callback("purchase_license") do |action_context|
        show_purchase_dialog
      end

      dialog.show
    end

    def self.show_trial_status
      license_info = get_license_info
      if license_info[:status] == 'licensed'
        UI.messagebox("You are fully licensed. No trial needed.", MB_OK, "License Status")
      else
        # Show trial status
        trial_status = check_trial_status
        if trial_status[:active]
          UI.messagebox("Trial active. Days remaining: #{trial_status[:days_remaining]}", MB_OK, "Trial Status")
        else
          UI.messagebox("Your trial has expired or no trial found.\n\nTo purchase a full license, contact: muhamad.shkeir@gmail.com", MB_OK, "Trial Status")
        end
      end
    end

    def self.show_license_options
      html_content = generate_options_html

      dialog = UI::HtmlDialog.new(
        dialog_title: "AutoNestCut - Get Started",
        preferences_key: "AutoNestCut_Options_Dialog",
        scrollable: false,
        resizable: false,
        width: 500,
        height: 400,
        left: 200,
        top: 200,
        style: UI::HtmlDialog::STYLE_DIALOG
      )

      dialog.set_html(html_content)

      dialog.add_action_callback("start_trial") do |action_context|
        dialog.close
        start_trial
      end

      dialog.add_action_callback("enter_license") do |action_context|
        dialog.close
        enter_license_key
      end

      dialog.add_action_callback("purchase_license") do |action_context|
        dialog.close
        show_purchase_dialog
      end

      dialog.show
    end

    private

    def self.get_license_info
      info = {
        extension_name: "AutoNestCut",
        version: "V 1.0",
        status: "Unknown",
        days_remaining: "N/A",
        licensed_by: "AutoNestCut Development Team",
        licensed_to: "N/A",
        user_name: "N/A"
      }

      if File.exist?(AutoNestCut::LicenseManager::LICENSE_FILE_PATH)
        begin
          encoded_jwt = File.read(AutoNestCut::LicenseManager::LICENSE_FILE_PATH).strip
          jwt_token = AutoNestCut::LicenseManager.send(:decode_token, encoded_jwt)
          if AutoNestCut::LicenseManager.validate_jwt(jwt_token)
            payload = AutoNestCut::LicenseManager.send(:decode_jwt_payload, jwt_token)

            is_trial = payload['is_trial'] == true
            info[:status] = is_trial ? 'trial' : 'licensed'
            info[:licensed_to] = payload['email'] || 'N/A'
            info[:user_name] = payload['name'] || payload['user_name'] || 'N/A'
            info[:is_trial] = is_trial

            if payload['exp'] && is_trial
              remaining_seconds = payload['exp'] - Time.now.to_i
              days_left = (remaining_seconds / (24 * 60 * 60)).ceil
              info[:days_remaining] = [days_left, 0].max.to_s
            else
              info[:days_remaining] = "-"
            end
          else
            info[:status] = "Invalid"
          end
        rescue => e
          info[:status] = "Error: #{e.message}"
        end
      else
        info[:status] = "Not Activated"
      end

      info
    end

    def self.remove_license
      if File.exist?(AutoNestCut::LicenseManager::LICENSE_FILE_PATH)
        File.delete(AutoNestCut::LicenseManager::LICENSE_FILE_PATH)
        # Clear any cached license state
        AutoNestCut::LicenseManager.instance_variable_set(:@license_checked, nil)
      end
    end

    def self.disable_extension
      # Remove all AutoNestCut menus and toolbars
      begin
        UI.remove_toolbar('AutoNestCut') if UI.toolbar('AutoNestCut')
      rescue
      end

      # Clear status
      Sketchup.status_text = ""
    end

    def self.show_purchase_dialog
      purchase_url = "https://autonestcutserver-moeshks-projects.vercel.app"
      UI.openURL(purchase_url)
    end

    def self.start_trial
      # Start trial logic
      UI.messagebox("Free trial started! You have 7 days to use AutoNestCut.", MB_OK, "Trial Started")
    end

    def self.enter_license_key
      # Show dialog to enter license key
      prompts = ["Enter License Key:"]
      defaults = [""]
      input = UI.inputbox(prompts, defaults, "Enter License Key")
      if input
        key = input[0].strip
        if key.empty?
          UI.messagebox("License key cannot be empty.", MB_OK, "Error")
          return
        end
        # Validate and save license
        if AutoNestCut::LicenseManager.activate_license(key)
          UI.messagebox("License activated successfully!", MB_OK, "Success")
        else
          UI.messagebox("Invalid license key. Please check and try again.", MB_OK, "Error")
        end
      end
    end

    def self.check_trial_status
      # Check trial status
      trial_file = File.join(AutoNestCut::LicenseManager::PLUGIN_DIR, 'trial.dat')
      if File.exist?(trial_file)
        trial_data = JSON.parse(File.read(trial_file))
        if trial_data['active'] && Time.now.to_i < trial_data['expires']
          days_remaining = ((trial_data['expires'] - Time.now.to_i) / 86400).ceil
          return {active: true, days_remaining: days_remaining}
        else
          return {active: false, reason: 'Trial expired'}
        end
      else
        return {active: false, reason: 'No trial found'}
      end
    end

    def self.generate_html(info)
      is_trial = info[:status] == 'trial'
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            :root {
              --gitbook-primary: #3b82f6;
              --gitbook-primary-dark: #2563eb;
              --gitbook-bg: #ffffff;
              --gitbook-sidebar: #f8fafc;
              --gitbook-border: #e2e8f0;
              --gitbook-text: #1e293b;
              --gitbook-text-muted: #64748b;
              --gitbook-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
            }

            * {
              box-sizing: border-box;
            }

            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Inter', sans-serif;
              margin: 0;
              padding: 20px;
              background: var(--gitbook-bg);
              color: var(--gitbook-text);
              line-height: 1.7;
              font-size: 15px;
            }

            .container {
              background: var(--gitbook-bg);
              border: 1px solid var(--gitbook-border);
              padding: 32px;
              max-width: 480px;
              margin: 0 auto;
              border-radius: 12px;
              box-shadow: var(--gitbook-shadow);
            }

            .header {
              text-align: center;
              margin-bottom: 32px;
              padding-bottom: 16px;
              border-bottom: 1px solid var(--gitbook-border);
            }

            .title {
              font-size: 24px;
              font-weight: 700;
              color: var(--gitbook-text);
              margin: 0;
              letter-spacing: -0.025em;
              display: flex;
              align-items: center;
              justify-content: center;
              gap: 12px;
            }

            .info-row {
              display: flex;
              justify-content: space-between;
              align-items: center;
              padding: 12px 0;
              border-bottom: 1px solid var(--gitbook-border);
            }

            .info-row:last-of-type {
              border-bottom: none;
            }

            .label {
              font-weight: 600;
              color: var(--gitbook-text);
              font-size: 14px;
            }

            .value {
              font-weight: 400;
              color: var(--gitbook-text-muted);
              font-size: 14px;
              text-align: right;
            }

            .status-container {
              display: flex;
              gap: 12px;
              align-items: center;
            }

            .status-badge {
              padding: 6px 16px;
              border-radius: 6px;
              font-size: 13px;
              font-weight: 600;
              border: 1px solid var(--gitbook-border);
              background: var(--gitbook-sidebar);
              color: var(--gitbook-text-muted);
            }

            .status-badge.active {
              background: var(--gitbook-primary);
              border-color: var(--gitbook-primary);
              color: white;
            }

            .purchase-btn {
              background: var(--gitbook-primary);
              color: white;
              border: none;
              padding: 6px 12px;
              border-radius: 6px;
              cursor: pointer;
              font-size: 12px;
              font-weight: 600;
              margin-left: 8px;
              transition: all 0.15s ease;
            }

            .purchase-btn:hover {
              background: var(--gitbook-primary-dark);
            }

            .button-container {
              text-align: center;
              margin-top: 32px;
              padding-top: 24px;
              border-top: 1px solid var(--gitbook-border);
            }

            .remove-btn {
              background: #dc3545;
              color: white;
              border: none;
              padding: 12px 24px;
              border-radius: 8px;
              cursor: pointer;
              font-size: 14px;
              font-weight: 600;
              transition: all 0.15s ease;
              display: flex;
              align-items: center;
              justify-content: center;
            }

            .remove-btn:hover {
              background: #c82333;
              transform: translateY(-1px);
            }
            
            .purchase-btn {
              display: flex;
              align-items: center;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1 class="title">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect width="18" height="11" x="3" y="11" rx="2" ry="2"/>
                  <circle cx="12" cy="5" r="2"/>
                  <path d="M12 7v4"/>
                </svg>
                License Information
              </h1>
            </div>

            <div class="info-row">
              <span class="label">Extension:</span>
              <span class="value">#{info[:extension_name]}</span>
            </div>

            <div class="info-row">
              <span class="label">Version:</span>
              <span class="value">#{info[:version]}</span>
            </div>

            <div class="info-row">
              <span class="label">Status:</span>
              <div class="status-container">
                <span class="status-badge #{is_trial ? '' : 'active'}">Licensed</span>
                <span class="status-badge #{is_trial ? 'active' : ''}">Free Trial</span>
                #{is_trial ? '<button class="purchase-btn" onclick="sketchup.purchase_license()"><svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="margin-right: 4px;"><circle cx="8" cy="21" r="1"/><circle cx="19" cy="21" r="1"/><path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57L20.42 9H5.12"/></svg>Purchase</button>' : ''}
              </div>
            </div>

            <div class="info-row">
              <span class="label">Days Remaining:</span>
              <span class="value">#{info[:days_remaining]}</span>
            </div>

            <div class="info-row">
              <span class="label">Licensed By:</span>
              <span class="value">#{info[:licensed_by]}</span>
            </div>

            <div class="info-row">
              <span class="label">Licensed To:</span>
              <span class="value">#{info[:user_name] != 'N/A' ? info[:user_name] : info[:licensed_to]}</span>
            </div>

            <div class="button-container">
              <button class="remove-btn" onclick="sketchup.remove_license()">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" style="margin-right: 6px;">
                  <polyline points="3,6 5,6 21,6"/>
                  <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
                  <line x1="10" y1="11" x2="10" y2="17"/>
                  <line x1="14" y1="11" x2="14" y2="17"/>
                </svg>
                Remove License
              </button>
            </div>
          </div>
        </body>
        </html>
      HTML
    end

    def self.generate_options_html
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Inter', sans-serif;
              margin: 0;
              padding: 20px;
              background: #f8fafc;
              color: #1e293b;
              line-height: 1.7;
              font-size: 15px;
            }
            .container {
              background: white;
              border: 1px solid #e2e8f0;
              padding: 32px;
              max-width: 480px;
              margin: 0 auto;
              border-radius: 12px;
              box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
            }
            .header {
              text-align: center;
              margin-bottom: 32px;
              padding-bottom: 16px;
              border-bottom: 1px solid #e2e8f0;
            }
            .title {
              font-size: 24px;
              font-weight: 700;
              color: #1e293b;
              margin: 0;
              letter-spacing: -0.025em;
              display: flex;
              align-items: center;
              justify-content: center;
              gap: 12px;
            }
            .subtitle {
              font-size: 16px;
              color: #64748b;
              margin: 8px 0 0 0;
            }
            .options {
              display: flex;
              flex-direction: column;
              gap: 16px;
            }
            .option {
              background: #f8fafc;
              border: 1px solid #e2e8f0;
              border-radius: 8px;
              padding: 20px;
              cursor: pointer;
              transition: all 0.15s ease;
              position: relative;
            }
            .option:hover {
              background: #f1f5f9;
              border-color: #3b82f6;
              transform: translateY(-2px);
              box-shadow: 0 4px 12px rgba(59, 130, 246, 0.15);
            }
            .option-icon {
              position: absolute;
              top: 20px;
              right: 20px;
              color: #64748b;
              transition: color 0.15s ease;
            }
            .option:hover .option-icon {
              color: #3b82f6;
            }
            .option-title {
              font-size: 18px;
              font-weight: 600;
              color: #1e293b;
              margin: 0 0 8px 0;
            }
            .option-description {
              font-size: 14px;
              color: #64748b;
              margin: 0;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1 class="title">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
                </svg>
                Welcome to AutoNestCut
              </h1>
              <p class="subtitle">Choose how you'd like to get started</p>
            </div>
            <div class="options">
              <div class="option" onclick="sketchup.start_trial()">
                <svg class="option-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <circle cx="12" cy="12" r="10"/>
                  <polyline points="12,6 12,12 16,14"/>
                </svg>
                <h3 class="option-title">Start Free Trial</h3>
                <p class="option-description">Try AutoNestCut for 7 days with full features. No credit card required.</p>
              </div>
              <div class="option" onclick="sketchup.enter_license()">
                <svg class="option-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <rect width="18" height="11" x="3" y="11" rx="2" ry="2"/>
                  <circle cx="12" cy="5" r="2"/>
                  <path d="M12 7v4"/>
                </svg>
                <h3 class="option-title">Enter License Key</h3>
                <p class="option-description">Already have a license? Enter your key to activate.</p>
              </div>
              <div class="option" onclick="sketchup.purchase_license()">
                <svg class="option-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <circle cx="8" cy="21" r="1"/>
                  <circle cx="19" cy="21" r="1"/>
                  <path d="M2.05 2.05h2l2.66 12.42a2 2 0 0 0 2 1.58h9.78a2 2 0 0 0 1.95-1.57L20.42 9H5.12"/>
                </svg>
                <h3 class="option-title">Purchase License</h3>
                <p class="option-description">Get lifetime access with all features and updates.</p>
              </div>
            </div>
          </div>
        </body>
        </html>
      HTML
    end

  end
end