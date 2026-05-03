# TEST SCRIPT - Check material prices in database
require 'json'

# Load the database
db_path = File.join(ENV['APPDATA'], 'AutoNestCut', 'materials_database.json')
puts "Database path: #{db_path}"
puts "File exists: #{File.exist?(db_path)}"

if File.exist?(db_path)
  content = File.read(db_path)
  materials = JSON.parse(content)
  
  puts "\n" + "="*80
  puts "MATERIALS IN DATABASE:"
  puts "="*80
  
  materials.each do |name, data|
    if data.is_a?(Array)
      puts "\n#{name} (ARRAY with #{data.length} thickness variations):"
      data.each_with_index do |mat, idx|
        price = mat['price'] || 0
        thickness = mat['thickness'] || 0
        puts "  [#{idx}] Thickness: #{thickness}mm, Price: #{price}"
      end
    else
      price = data['price'] || 0
      thickness = data['thickness'] || 0
      puts "\n#{name} (HASH):"
      puts "  Thickness: #{thickness}mm, Price: #{price}"
    end
  end
  
  puts "\n" + "="*80
  puts "SUMMARY:"
  puts "  Total materials: #{materials.length}"
  puts "  Materials with price > 0: #{materials.count { |n, d| (d.is_a?(Array) ? d.first['price'] : d['price']).to_f > 0 }}"
  puts "  Materials with price = 0: #{materials.count { |n, d| (d.is_a?(Array) ? d.first['price'] : d['price']).to_f == 0 }}"
  puts "="*80
else
  puts "ERROR: Database file not found!"
end
