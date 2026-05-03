# ============================================================================
# VISUAL TEST: See QR Features in Action
# ============================================================================
# Run this in SketchUp Ruby Console to see:
# 1. Labels ON the nesting diagram (with QR codes)
# 2. Separate label sheet PDF (printable stickers)
# ============================================================================

puts "\n" + "="*80
puts "🎯 VISUAL TEST: QR Features Demo"
puts "="*80

# Load required files
require_relative 'Extension/AutoNestCut/exporters/qr_code_generator'
require_relative 'Extension/AutoNestCut/exporters/label_generator'
require_relative 'Extension/AutoNestCut/exporters/label_sheet_generator'

# Create test part data
test_parts = [
  {
    part_id: 'SIDE-001',
    name: 'Cabinet Side Panel',
    material: '18mm Plywood',
    width: 600,
    height: 800,
    thickness: 18,
    board_number: 1
  },
  {
    part_id: 'SHELF-001',
    name: 'Adjustable Shelf',
    material: '18mm Plywood',
    width: 580,
    height: 400,
    thickness: 18,
    board_number: 1
  },
  {
    part_id: 'BACK-001',
    name: 'Cabinet Back',
    material: '6mm MDF',
    width: 600,
    height: 800,
    thickness: 6,
    board_number: 2
  }
]

puts "\n📦 Test Parts Created: #{test_parts.length} parts"

# ============================================================================
# FEATURE 1: Labels ON Nesting Diagram
# ============================================================================
puts "\n" + "-"*80
puts "FEATURE 1: Labels ON Nesting Diagram"
puts "-"*80
puts "These labels appear ON each part in the nesting diagram SVG/HTML"

label_gen = AutoNestCut::LabelGenerator.new(
  qr_enabled: true,
  qr_size: 20,
  label_style: 'compact'
)

# Generate a sample label for the first part
part_dimensions = { width: 600, height: 800 }
label_svg = label_gen.generate_label(test_parts[0], part_dimensions)

# Save to file so you can see it
File.write('test_diagram_label.svg', %{
<svg xmlns="http://www.w3.org/2000/svg" width="600" height="800" viewBox="0 0 600 800">
  <!-- This is what appears ON the part in the diagram -->
  <rect width="600" height="800" fill="#f0f0f0" stroke="#333" stroke-width="2"/>
  #{label_svg}
</svg>
})

puts "✅ Generated label that goes ON the diagram"
puts "   📄 Saved to: test_diagram_label.svg"
puts "   👁️  Open this file to see what appears ON each part"
puts ""
puts "   This label contains:"
puts "   • QR code with part data"
puts "   • Part ID and name"
puts "   • Dimensions"
puts "   • Positioned on the part itself"

# ============================================================================
# FEATURE 2: Separate Label Sheet (Printable Stickers)
# ============================================================================
puts "\n" + "-"*80
puts "FEATURE 2: Separate Label Sheet PDF"
puts "-"*80
puts "This is a SEPARATE PDF you can print as sticker labels"

sheet_gen = AutoNestCut::LabelSheetGenerator.new('custom')
pdf_path = sheet_gen.generate_label_sheet(test_parts, nil, false)

puts "✅ Generated printable label sheet"
puts "   📄 Saved to: #{pdf_path}"
puts "   👁️  Open this PDF to see printable sticker labels"
puts ""
puts "   This PDF contains:"
puts "   • One label per part"
puts "   • Arranged in a grid (like sticker sheets)"
puts "   • Print and stick on physical parts"
puts "   • Each has a QR code you can scan"

# ============================================================================
# SUMMARY
# ============================================================================
puts "\n" + "="*80
puts "📊 SUMMARY: Two Different Features"
puts "="*80

puts "\n1️⃣  LABELS ON DIAGRAM (label_generator.rb)"
puts "   • Shows up: ON each part in the nesting diagram"
puts "   • File: test_diagram_label.svg"
puts "   • Purpose: Visual identification in digital diagrams"
puts "   • When: Automatically added when you export nesting diagrams"

puts "\n2️⃣  LABEL SHEET PDF (label_sheet_generator.rb)"
puts "   • Shows up: Separate PDF file"
puts "   • File: #{File.basename(pdf_path)}"
puts "   • Purpose: Print and physically stick on cut parts"
puts "   • When: Menu → Extensions → AutoNestCut → 🏷️ Generate QR Label Sheet"

puts "\n" + "="*80
puts "✅ TEST COMPLETE - Check the files above!"
puts "="*80

# Open the files automatically
UI.openURL("file:///#{File.expand_path('test_diagram_label.svg')}")
UI.openURL("file:///#{pdf_path}")

puts "\n💡 TIP: Both files should have opened in your browser/PDF viewer"
puts "    Compare them to see the difference!"
