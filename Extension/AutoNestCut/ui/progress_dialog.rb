module AutoNestCut
  class ProgressDialog
    
    def initialize
      @dialog = nil
      @current_step = 0
      @total_steps = 0
      @start_time = nil
      @is_cancelled = false
    end
    
    def show(title = "Processing Cut List", estimated_components = 0)
      @start_time = Time.now
      @estimated_components = estimated_components
      @is_cancelled = false
      
      @dialog = UI::HtmlDialog.new(
        dialog_title: title,
        preferences_key: "AutoNestCut_Progress",
        scrollable: false,
        resizable: false,
        width: 480,
        height: 320,
        left: 200,
        top: 200,
        style: UI::HtmlDialog::STYLE_DIALOG
      )
      
      html_content = generate_progress_html
      @dialog.set_html(html_content)
      
      # Handle cancel button
      @dialog.add_action_callback("cancel_processing") do |context|
        @is_cancelled = true
        @dialog.close if @dialog
      end
      
      @dialog.show
      
      # Start animation
      @dialog.execute_script("startSpinner();")
    end
    
    def update_progress(step, total_steps, message, percentage = nil)
      return if @is_cancelled || !@dialog
      
      @current_step = step
      @total_steps = total_steps
      
      # Calculate percentage if not provided
      percentage ||= ((step.to_f / total_steps) * 100).round(1) if total_steps > 0
      percentage = [percentage, 100].min if percentage
      
      # Calculate estimated time remaining
      elapsed = Time.now - @start_time
      eta = calculate_eta(elapsed, step, total_steps)
      
      script = "updateProgress(#{step}, #{total_steps}, '#{escape_js(message)}', #{percentage}, '#{eta}');"
      @dialog.execute_script(script)
    end
    
    def close
      @dialog.close if @dialog
      @dialog = nil
    end
    
    def cancelled?
      @is_cancelled
    end
    
    private
    
    def calculate_eta(elapsed, current_step, total_steps)
      return "Calculating..." if current_step == 0 || total_steps == 0
      
      rate = current_step.to_f / elapsed
      remaining_steps = total_steps - current_step
      remaining_seconds = remaining_steps / rate
      
      if remaining_seconds < 60
        "#{remaining_seconds.round}s remaining"
      elsif remaining_seconds < 3600
        minutes = (remaining_seconds / 60).round
        "#{minutes}m remaining"
      else
        hours = (remaining_seconds / 3600).round(1)
        "#{hours}h remaining"
      end
    end
    
    def escape_js(text)
      text.to_s.gsub("'", "\\'").gsub("\n", "\\n").gsub("\r", "\\r")
    end
    
    def generate_progress_html
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            * {
              margin: 0;
              padding: 0;
              box-sizing: border-box;
            }
            
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
              background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
              height: 100vh;
              display: flex;
              align-items: center;
              justify-content: center;
              overflow: hidden;
            }
            
            .progress-container {
              background: rgba(255, 255, 255, 0.95);
              backdrop-filter: blur(20px);
              border-radius: 20px;
              padding: 40px;
              width: 400px;
              text-align: center;
              box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
              border: 1px solid rgba(255, 255, 255, 0.2);
            }
            
            .spinner-container {
              margin-bottom: 30px;
              position: relative;
              height: 80px;
              display: flex;
              align-items: center;
              justify-content: center;
            }
            
            .spinner {
              width: 60px;
              height: 60px;
              border: 3px solid rgba(102, 126, 234, 0.1);
              border-top: 3px solid #667eea;
              border-radius: 50%;
              animation: spin 1s linear infinite;
            }
            
            .spinner-icon {
              position: absolute;
              width: 24px;
              height: 24px;
              top: 50%;
              left: 50%;
              transform: translate(-50%, -50%);
              opacity: 0.8;
            }
            
            @keyframes spin {
              0% { transform: rotate(0deg); }
              100% { transform: rotate(360deg); }
            }
            
            .progress-info h2 {
              color: #2d3748;
              font-size: 24px;
              font-weight: 600;
              margin-bottom: 8px;
            }
            
            .progress-status {
              color: #667eea;
              font-size: 14px;
              font-weight: 500;
              margin-bottom: 20px;
              min-height: 20px;
            }
            
            .progress-bar-container {
              background: rgba(102, 126, 234, 0.1);
              border-radius: 10px;
              height: 8px;
              margin-bottom: 15px;
              overflow: hidden;
            }
            
            .progress-bar {
              background: linear-gradient(90deg, #667eea, #764ba2);
              height: 100%;
              width: 0%;
              border-radius: 10px;
              transition: width 0.3s ease;
            }
            
            .progress-details {
              display: flex;
              justify-content: space-between;
              align-items: center;
              margin-bottom: 25px;
              font-size: 12px;
              color: #718096;
            }
            
            .progress-percentage {
              font-weight: 600;
              color: #667eea;
            }
            
            .cancel-button {
              background: linear-gradient(135deg, #ff6b6b, #ee5a52);
              color: white;
              border: none;
              padding: 12px 24px;
              border-radius: 25px;
              font-size: 14px;
              font-weight: 500;
              cursor: pointer;
              transition: all 0.3s ease;
              box-shadow: 0 4px 15px rgba(255, 107, 107, 0.3);
            }
            
            .cancel-button:hover {
              transform: translateY(-2px);
              box-shadow: 0 6px 20px rgba(255, 107, 107, 0.4);
            }
            
            .cancel-button:active {
              transform: translateY(0);
            }
            
            .fade-in {
              animation: fadeIn 0.5s ease-in;
            }
            
            @keyframes fadeIn {
              from { opacity: 0; transform: translateY(20px); }
              to { opacity: 1; transform: translateY(0); }
            }
          </style>
        </head>
        <body>
          <div class="progress-container fade-in">
            <div class="spinner-container">
              <div class="spinner" id="spinner"></div>
              <svg class="spinner-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91-6.91a2.12 2.12 0 0 1 0-3l2.83-2.83a2.12 2.12 0 0 1 3 0l.4.4a1 1 0 0 0 1.4 0l1.6-1.6a1 1 0 0 0 0-1.4l-.4-.4a4.12 4.12 0 0 0-5.83 0l-2.83 2.83a4.12 4.12 0 0 0 0 5.83l6.91 6.91a8 8 0 0 0 10.6-10.6l-3.77 3.77z"/>
              </svg>
            </div>
            
            <div class="progress-info">
              <h2>AutoNestCut Processing</h2>
              <div class="progress-status" id="status">Initializing...</div>
            </div>
            
            <div class="progress-bar-container">
              <div class="progress-bar" id="progressBar"></div>
            </div>
            
            <div class="progress-details">
              <span id="stepInfo">Step 0 of 0</span>
              <span class="progress-percentage" id="percentage">0%</span>
              <span id="eta">Calculating...</span>
            </div>
            
            <button class="cancel-button" onclick="cancelProcessing()">
              Cancel Processing
            </button>
          </div>
          
          <script>
            function startSpinner() {
              const spinner = document.getElementById('spinner');
              spinner.style.animation = 'spin 1s linear infinite';
            }
            
            function updateProgress(step, totalSteps, message, percentage, eta) {
              document.getElementById('status').textContent = message;
              document.getElementById('stepInfo').textContent = `Step ${step} of ${totalSteps}`;
              document.getElementById('percentage').textContent = `${percentage}%`;
              document.getElementById('eta').textContent = eta;
              document.getElementById('progressBar').style.width = `${percentage}%`;
            }
            
            function cancelProcessing() {
              if (window.sketchup) {
                window.sketchup.cancel_processing();
              }
            }
          </script>
        </body>
        </html>
      HTML
    end
  end
end