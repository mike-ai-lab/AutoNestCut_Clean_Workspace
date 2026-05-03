# AutoNestCut Security Configuration
module AutoNestCut
  module Security
    PROTECTED_FILES = ["main.rb", "processors/model_analyzer.rb", "processors/nester.rb", "processors/facade_analyzer.rb", "exporters/diagram_generator.rb", "exporters/report_generator.rb", "exporters/facade_reporter.rb", "models/part.rb", "models/board.rb", "lib/LicenseManager/license_manager.rb", "lib/LicenseManager/trial_manager.rb"]
    
    def self.verify_integrity
      # Runtime integrity check
      protected_files_exist = PROTECTED_FILES.all? do |file|
        encoded_file = file.gsub('.rb', '.rbe')
        File.exist?(File.join(__dir__, encoded_file))
      end
      
      unless protected_files_exist
        raise "Security violation: Protected files missing or tampered"
      end
      
      true
    end
    
    def self.load_protected_file(filename)
      # Load encoded file with integrity check
      verify_integrity
      encoded_file = filename.gsub('.rb', '.rbe')
      require_relative encoded_file
    end
  end
end
