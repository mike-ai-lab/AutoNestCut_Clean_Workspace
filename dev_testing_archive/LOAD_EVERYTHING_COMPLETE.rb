# Load EVERYTHING including UI classes
# Run this in SketchUp Ruby Console

puts "\n🚀 LOADING COMPLETE AUTONESTCUT EXTENSION"
puts "="*80

workspace = 'C:/Users/Administrator/Desktop/AUTOMATION/cutlist/AutoNestCut/AutoNestCut_Clean_Workspace'
base_path = File.join(workspace, 'Extension', 'AutoNestCut')

# Check if AutoNestCut module exists
unless defined?(AutoNestCut)
  puts "❌ AutoNestCut module not loaded!"
  puts "   The extension should auto-load when SketchUp starts"
  puts "   If not, run: load '#{File.join(workspace, 'Extension', 'autonestcut.rb')}'"
  exit
end

puts "✓ AutoNestCut module exists"
puts "\n📦 Loading ALL classes (models, processors, UI, exporters)..."

# Complete list of all files in correct dependency order
files = [
  # Core utilities
  'compatibility.rb',
  'util.rb',
  'materials_database.rb',
  'config.rb',
  
  # Models
  'models/part.rb',
  'models/board.rb',
  'models/facade_surface.rb',
  'models/cladding_preset.rb',
  
  # Processors
  'processors/model_analyzer.rb',
  'processors/nester.rb',
  'processors/facade_analyzer.rb',
  'processors/component_cache.rb',
  'processors/component_validator.rb',
  'processors/async_processor.rb',
  'processors/label_generator.rb',
  
  # UI
  'ui/dialog_manager.rb',
  'ui/missing_materials_ui.rb',
  'ui/progress_dialog.rb',
  'ui/view_export_ui.rb',
  'ui/material_database_ui.rb',
  'ui/svg_export_ui.rb',
  
  # Exporters
  'exporters/diagram_generator.rb',
  'exporters/report_generator.rb',
  'exporters/pdf_generator.rb',
  'exporters/report_pdf_exporter.rb',
  'exporters/facade_reporter.rb',
  'exporters/assembly_exporter.rb',
  'exporters/svg_vector_exporter.rb',
  'exporters/view_export_handler.rb',
  
  # Other
  'scheduler.rb',
  'supabase_client.rb'
]

loaded_count = 0
failed_count = 0
failed_files = []

files.each do |file|
  file_path = File.join(base_path, file)
  
  # Skip if file doesn't exist
  unless File.exist?(file_path)
    puts "⚠️  #{file} (not found, skipping)"
    next
  end
  
  begin
    load file_path
    puts "✅ #{file}"
    loaded_count += 1
  rescue => e
    puts "❌ #{file}"
    puts "   ERROR: #{e.message}"
    failed_count += 1
    failed_files << file
  end
end

puts "\n" + "="*80
puts "📊 LOADING SUMMARY"
puts "="*80
puts "✅ Loaded: #{loaded_count}"
puts "❌ Failed: #{failed_count}"

if failed_count > 0
  puts "\n⚠️  Failed files:"
  failed_files.each { |f| puts "   - #{f}" }
end

# Check ALL critical classes
puts "\n🔍 CRITICAL CLASSES CHECK:"

critical_classes = [
  # Core
  'Config',
  'MaterialsDatabase',
  'Compatibility',
  
  # Models
  'Part',
  'Board',
  'FacadeSurface',
  'CladdingPreset',
  
  # Processors
  'ModelAnalyzer',
  'Nester',
  'FacadeAnalyzer',
  'ComponentCache',
  'ComponentValidator',
  'LabelGenerator',
  
  # UI
  'UIDialogManager',
  'MissingMaterialsUI',
  'ProgressDialog',
  'ViewExportUI',
  'MaterialDatabaseUI',
  'SvgExportUI',
  
  # Exporters
  'DiagramGenerator',
  'ReportGenerator',
  'PdfGenerator',
  'ReportPdfExporter',
  'FacadeReporter',
  'AssemblyExporter',
  'SvgVectorExporter',
  'ViewExportHandler'
]

all_ok = true
missing_classes = []

critical_classes.each do |class_name|
  begin
    const = AutoNestCut.const_get(class_name)
    puts "✅ #{class_name}"
  rescue NameError
    puts "❌ #{class_name} NOT FOUND"
    all_ok = false
    missing_classes << class_name
  end
end

if all_ok
  puts "\n" + "="*80
  puts "✅ ALL CLASSES LOADED SUCCESSFULLY!"
  puts "="*80
  
  # Enable QR labels feature
  begin
    AutoNestCut::Config.save_global_settings({'enable_part_labels' => true})
    settings = AutoNestCut::Config.get_cached_settings
    puts "✅ enable_part_labels: #{settings['enable_part_labels']}"
  rescue => e
    puts "⚠️  Could not configure: #{e.message}"
  end
  
  # Clear cache
  begin
    AutoNestCut::ComponentCache.clear_cache
    puts "✅ Cache cleared"
  rescue => e
    puts "⚠️  Could not clear cache: #{e.message}"
  end
  
  puts "\n" + "="*80
  puts "🎉 EXTENSION FULLY LOADED - READY TO USE!"
  puts "="*80
  puts "\n📋 NOW YOU CAN:"
  puts "   1. Select components in SketchUp"
  puts "   2. Extensions → Auto Nest Cut → Generate Cut List"
  puts "   3. Click 'Process' button (MUST run fresh nesting!)"
  puts "   4. Watch console for:"
  puts "      🏷️ LABEL GENERATION CHECK:"
  puts "      🏷️ Calling LabelGenerator.generate_labels..."
  puts "      ✅ Label generation complete - X parts labeled"
  puts "      UID: \"ANC-XXXX-XXX\""
  puts "   5. Export PDF"
  puts "   6. Verify Part Code + QR columns appear"
  puts "\n⚠️  CRITICAL: Click 'Process' to run fresh nesting!"
  puts "   Do NOT use cached results!"
  puts "="*80
else
  puts "\n" + "="*80
  puts "❌ SOME CLASSES MISSING"
  puts "="*80
  puts "\nMissing classes (#{missing_classes.length}):"
  missing_classes.each { |c| puts "   - #{c}" }
  
  puts "\n   Available constants (#{AutoNestCut.constants.length}):"
  AutoNestCut.constants.sort.each do |const|
    puts "      - #{const}"
  end
  
  puts "\n⚠️  The extension may not work correctly!"
end

