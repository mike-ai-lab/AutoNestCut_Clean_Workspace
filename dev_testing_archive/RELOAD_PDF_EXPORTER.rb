# Force reload the PDF exporter to test changes
# Run this in SketchUp Ruby Console

puts "\n" + "="*80
puts "FORCE RELOADING PDF EXPORTER"
puts "="*80

# Unload the module if it exists
if defined?(AutoNestCut::ReportPdfExporter)
  puts "Removing existing ReportPdfExporter class..."
  AutoNestCut.send(:remove_const, :ReportPdfExporter)
end

# Reload the file
exporter_path = File.join(__dir__, 'Extension', 'AutoNestCut', 'exporters', 'report_pdf_exporter.rb')
puts "Loading: #{exporter_path}"
load exporter_path

puts "✓ ReportPdfExporter reloaded successfully"
puts "="*80

# Test that the class exists
if defined?(AutoNestCut::ReportPdfExporter)
  puts "✓ AutoNestCut::ReportPdfExporter is defined"
  exporter = AutoNestCut::ReportPdfExporter.new
  puts "✓ Can instantiate ReportPdfExporter"
else
  puts "✗ ERROR: ReportPdfExporter not found!"
end

puts "="*80
puts "Now try exporting PDF from the extension"
puts "="*80
