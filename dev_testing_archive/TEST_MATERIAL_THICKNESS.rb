#!/usr/bin/env ruby
# Unit test for material thickness support
# Tests the new array-based material storage system

require 'csv'
require 'fileutils'
require 'tmpdir'

# Mock the AutoNestCut module structure
module AutoNestCut
  class Config
    def self.get_cached_settings
      { 'default_currency' => 'USD' }
    end
  end
  
  class Util
    def self.debug(msg)
      puts "DEBUG: #{msg}"
    end
  end
  
  class MaterialsDatabase
    @test_db_file = nil
    
    def self.set_test_database(path)
      @test_db_file = path
    end
    
    def self.database_file
      @test_db_file || File.join(Dir.tmpdir, 'test_materials.csv')
    end
    
    def self.ensure_database_folder
      folder = File.dirname(database_file)
      FileUtils.mkdir_p(folder) unless Dir.exist?(folder)
    end
    
    def self.load_database
      ensure_database_folder
      return {} unless File.exist?(database_file)
      
      materials = {}
      row_count = 0
      error_count = 0
      
      begin
        CSV.foreach(database_file, headers: true) do |row|
          row_count += 1
          
          begin
            name = row['name'].to_s.strip
            next if name.empty?
            
            # Validate all numeric fields with defaults
            width = validate_float(row['width'], 2440)
            height = validate_float(row['height'], 1220)
            thickness = validate_float(row['thickness'], 18)
            price = validate_float(row['price'], 0)
            density = validate_float(row['density'], 600)
            
            material_data = {
              'width' => width,
              'height' => height,
              'thickness' => thickness,
              'price' => price,
              'currency' => row['currency'] || 'USD',
              'density' => density,
              'auto_generated' => row['auto_generated'] == 'true' || row['auto_generated'] == true,
              'created_at' => row['created_at'] || '',
              'original_sketchup_material' => row['original_sketchup_material'] || '',
              'is_favorite' => row['is_favorite'] == 'true' || row['is_favorite'] == true,
              'flagged_no_material' => row['flagged_no_material'] == 'true' || row['flagged_no_material'] == true
            }
            
            # CRITICAL: Support multiple thicknesses per material name
            # Store as array of thickness variations
            if materials.key?(name)
              # Material already exists - add this thickness if not duplicate
              existing_thicknesses = materials[name].map { |m| m['thickness'] }
              unless existing_thicknesses.any? { |t| (t - thickness).abs < 0.01 }
                materials[name] << material_data
              end
            else
              # New material - start array
              materials[name] = [material_data]
            end
          rescue => e
            error_count += 1
            Util.debug("Warning: Skipped malformed row #{row_count}: #{e.message}")
          end
        end
        
        total_entries = materials.values.sum(&:length)
        puts "✅ Materials database loaded: #{materials.length} materials (#{total_entries} thickness variations)" if error_count == 0
        puts "✅ Materials database loaded: #{materials.length} materials (#{total_entries} thickness variations, #{error_count} errors skipped)" if error_count > 0
        materials
        
      rescue => e
        Util.debug("Error loading materials database: #{e.message}")
        {}
      end
    end
    
    def self.save_database(materials)
      ensure_database_folder
      
      temp_file = "#{database_file}.tmp"
      
      begin
        CSV.open(temp_file, 'w') do |csv|
          csv << ['name', 'width', 'height', 'thickness', 'price', 'currency', 'density', 'auto_generated', 'created_at', 'original_sketchup_material', 'is_favorite', 'flagged_no_material']
          
          materials.each do |name, data|
            next if name.nil? || name.to_s.strip.empty?
            
            # CRITICAL: If data is an array (multiple thicknesses), save each one
            if data.is_a?(Array)
              data.each do |thickness_data|
                default_currency = Config.get_cached_settings['default_currency'] || 'USD'
                csv << [
                  name,
                  validate_float(thickness_data['width'], 2440),
                  validate_float(thickness_data['height'], 1220),
                  validate_float(thickness_data['thickness'], 18),
                  validate_float(thickness_data['price'], 0),
                  thickness_data['currency'] || default_currency,
                  validate_float(thickness_data['density'], 600),
                  thickness_data['auto_generated'] || false,
                  thickness_data['created_at'] || '',
                  thickness_data['original_sketchup_material'] || '',
                  thickness_data['is_favorite'] || false,
                  thickness_data['flagged_no_material'] || false
                ]
              end
            else
              # Single thickness entry
              default_currency = Config.get_cached_settings['default_currency'] || 'USD'
              csv << [
                name,
                validate_float(data['width'], 2440),
                validate_float(data['height'], 1220),
                validate_float(data['thickness'], 18),
                validate_float(data['price'], 0),
                data['currency'] || default_currency,
                validate_float(data['density'], 600),
                data['auto_generated'] || false,
                data['created_at'] || '',
                data['original_sketchup_material'] || '',
                data['is_favorite'] || false,
                data['flagged_no_material'] || false
              ]
            end
          end
        end
        
        File.rename(temp_file, database_file)
        
        total_count = materials.values.sum { |v| v.is_a?(Array) ? v.length : 1 }
        puts "✅ Materials database saved successfully (#{total_count} entries)"
        
      rescue => e
        File.delete(temp_file) if File.exist?(temp_file)
        Util.debug("Error saving materials database: #{e.message}")
        raise e
      end
    end
    
    def self.validate_float(value, default)
      return default if value.nil?
      float_val = value.to_f
      float_val.finite? ? float_val : default
    rescue
      default
    end
  end
end

# Test Suite
class MaterialThicknessTest
  def initialize
    @test_db = File.join(Dir.tmpdir, "test_materials_#{Time.now.to_i}.csv")
    AutoNestCut::MaterialsDatabase.set_test_database(@test_db)
    @passed = 0
    @failed = 0
    @tests = []
  end
  
  def run_all_tests
    puts "=" * 80
    puts "MATERIAL THICKNESS UNIT TESTS"
    puts "=" * 80
    puts "Test database: #{@test_db}"
    puts ""
    
    # Clean start
    cleanup_test_db
    
    # Run tests
    test_single_material_single_thickness
    test_single_material_multiple_thicknesses
    test_multiple_materials_multiple_thicknesses
    test_duplicate_thickness_prevention
    test_floating_point_tolerance
    test_save_and_reload_consistency
    test_empty_database
    test_malformed_data
    test_edge_case_thicknesses
    test_backward_compatibility
    
    # Cleanup
    cleanup_test_db
    
    # Summary
    puts ""
    puts "=" * 80
    puts "TEST SUMMARY"
    puts "=" * 80
    puts "Total tests: #{@tests.length}"
    puts "Passed: #{@passed} ✅"
    puts "Failed: #{@failed} ❌"
    puts ""
    
    if @failed > 0
      puts "FAILED TESTS:"
      @tests.select { |t| !t[:passed] }.each do |t|
        puts "  ❌ #{t[:name]}: #{t[:error]}"
      end
    else
      puts "🎉 ALL TESTS PASSED!"
    end
    puts "=" * 80
    
    @failed == 0
  end
  
  def assert(condition, test_name, error_msg = "Assertion failed")
    if condition
      puts "  ✅ #{test_name}"
      @passed += 1
      @tests << { name: test_name, passed: true }
    else
      puts "  ❌ #{test_name}: #{error_msg}"
      @failed += 1
      @tests << { name: test_name, passed: false, error: error_msg }
    end
  end
  
  def cleanup_test_db
    File.delete(@test_db) if File.exist?(@test_db)
  end
  
  # TEST 1: Single material, single thickness
  def test_single_material_single_thickness
    puts "\n📋 Test 1: Single material, single thickness"
    
    materials = {
      'Plywood' => [{
        'width' => 2440,
        'height' => 1220,
        'thickness' => 18,
        'price' => 45,
        'currency' => 'USD',
        'density' => 600,
        'auto_generated' => false
      }]
    }
    
    AutoNestCut::MaterialsDatabase.save_database(materials)
    loaded = AutoNestCut::MaterialsDatabase.load_database
    
    assert(loaded.key?('Plywood'), "Material exists")
    assert(loaded['Plywood'].is_a?(Array), "Material is array")
    assert(loaded['Plywood'].length == 1, "Has 1 thickness", "Expected 1, got #{loaded['Plywood'].length}")
    assert(loaded['Plywood'][0]['thickness'] == 18, "Thickness is 18mm")
  end
  
  # TEST 2: Single material, multiple thicknesses
  def test_single_material_multiple_thicknesses
    puts "\n📋 Test 2: Single material, multiple thicknesses"
    
    materials = {
      'Blue_Glass_Shelf' => [
        { 'width' => 2440, 'height' => 1220, 'thickness' => 8, 'price' => 30, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false },
        { 'width' => 2440, 'height' => 1220, 'thickness' => 18, 'price' => 45, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false },
        { 'width' => 2440, 'height' => 1220, 'thickness' => 100, 'price' => 200, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false }
      ]
    }
    
    AutoNestCut::MaterialsDatabase.save_database(materials)
    loaded = AutoNestCut::MaterialsDatabase.load_database
    
    assert(loaded.key?('Blue_Glass_Shelf'), "Material exists")
    assert(loaded['Blue_Glass_Shelf'].length == 3, "Has 3 thicknesses", "Expected 3, got #{loaded['Blue_Glass_Shelf'].length}")
    
    thicknesses = loaded['Blue_Glass_Shelf'].map { |m| m['thickness'] }.sort
    assert(thicknesses == [8, 18, 100], "All thicknesses present", "Expected [8, 18, 100], got #{thicknesses}")
  end
  
  # TEST 3: Multiple materials, multiple thicknesses each
  def test_multiple_materials_multiple_thicknesses
    puts "\n📋 Test 3: Multiple materials, multiple thicknesses each"
    
    materials = {
      'Plywood' => [
        { 'width' => 2440, 'height' => 1220, 'thickness' => 12, 'price' => 35, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false },
        { 'width' => 2440, 'height' => 1220, 'thickness' => 18, 'price' => 45, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false }
      ],
      'MDF' => [
        { 'width' => 2440, 'height' => 1220, 'thickness' => 16, 'price' => 25, 'currency' => 'USD', 'density' => 750, 'auto_generated' => false },
        { 'width' => 2440, 'height' => 1220, 'thickness' => 19, 'price' => 30, 'currency' => 'USD', 'density' => 750, 'auto_generated' => false }
      ]
    }
    
    AutoNestCut::MaterialsDatabase.save_database(materials)
    loaded = AutoNestCut::MaterialsDatabase.load_database
    
    assert(loaded.keys.length == 2, "2 materials exist", "Expected 2, got #{loaded.keys.length}")
    assert(loaded['Plywood'].length == 2, "Plywood has 2 thicknesses")
    assert(loaded['MDF'].length == 2, "MDF has 2 thicknesses")
  end
  
  # TEST 4: Duplicate thickness prevention
  def test_duplicate_thickness_prevention
    puts "\n📋 Test 4: Duplicate thickness prevention"
    
    # Save initial
    materials = {
      'Plywood' => [
        { 'width' => 2440, 'height' => 1220, 'thickness' => 18, 'price' => 45, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false }
      ]
    }
    AutoNestCut::MaterialsDatabase.save_database(materials)
    
    # Try to add duplicate
    loaded = AutoNestCut::MaterialsDatabase.load_database
    loaded['Plywood'] << { 'width' => 2440, 'height' => 1220, 'thickness' => 18.0, 'price' => 50, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false }
    AutoNestCut::MaterialsDatabase.save_database(loaded)
    
    # Reload and check
    final = AutoNestCut::MaterialsDatabase.load_database
    assert(final['Plywood'].length == 1, "Duplicate not added", "Expected 1, got #{final['Plywood'].length}")
  end
  
  # TEST 5: Floating point tolerance
  def test_floating_point_tolerance
    puts "\n📋 Test 5: Floating point tolerance (0.01mm)"
    
    materials = {
      'Test_Material' => [
        { 'width' => 2440, 'height' => 1220, 'thickness' => 18.0, 'price' => 45, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false }
      ]
    }
    AutoNestCut::MaterialsDatabase.save_database(materials)
    
    loaded = AutoNestCut::MaterialsDatabase.load_database
    
    # Try to add 18.005mm (within tolerance)
    loaded['Test_Material'] << { 'width' => 2440, 'height' => 1220, 'thickness' => 18.005, 'price' => 50, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false }
    AutoNestCut::MaterialsDatabase.save_database(loaded)
    
    final = AutoNestCut::MaterialsDatabase.load_database
    assert(final['Test_Material'].length == 1, "Within tolerance treated as duplicate")
    
    # Try to add 18.02mm (outside tolerance)
    final['Test_Material'] << { 'width' => 2440, 'height' => 1220, 'thickness' => 18.02, 'price' => 50, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false }
    AutoNestCut::MaterialsDatabase.save_database(final)
    
    final2 = AutoNestCut::MaterialsDatabase.load_database
    assert(final2['Test_Material'].length == 2, "Outside tolerance treated as new", "Expected 2, got #{final2['Test_Material'].length}")
  end
  
  # TEST 6: Save and reload consistency
  def test_save_and_reload_consistency
    puts "\n📋 Test 6: Save and reload consistency"
    
    original = {
      'Material_A' => [
        { 'width' => 2440, 'height' => 1220, 'thickness' => 8, 'price' => 30, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false },
        { 'width' => 2440, 'height' => 1220, 'thickness' => 18, 'price' => 45, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false }
      ],
      'Material_B' => [
        { 'width' => 2440, 'height' => 1220, 'thickness' => 12, 'price' => 35, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false }
      ]
    }
    
    AutoNestCut::MaterialsDatabase.save_database(original)
    loaded = AutoNestCut::MaterialsDatabase.load_database
    
    assert(loaded.keys.sort == original.keys.sort, "Same material names")
    assert(loaded['Material_A'].length == original['Material_A'].length, "Material_A thickness count matches")
    assert(loaded['Material_B'].length == original['Material_B'].length, "Material_B thickness count matches")
    
    # Check all thicknesses
    original_thicknesses_a = original['Material_A'].map { |m| m['thickness'] }.sort
    loaded_thicknesses_a = loaded['Material_A'].map { |m| m['thickness'] }.sort
    assert(loaded_thicknesses_a == original_thicknesses_a, "Material_A thicknesses match")
  end
  
  # TEST 7: Empty database
  def test_empty_database
    puts "\n📋 Test 7: Empty database"
    
    cleanup_test_db
    loaded = AutoNestCut::MaterialsDatabase.load_database
    
    assert(loaded.is_a?(Hash), "Returns hash")
    assert(loaded.empty?, "Empty hash for non-existent database")
  end
  
  # TEST 8: Malformed data handling
  def test_malformed_data
    puts "\n📋 Test 8: Malformed data handling"
    
    # Create CSV with malformed row
    CSV.open(@test_db, 'w') do |csv|
      csv << ['name', 'width', 'height', 'thickness', 'price', 'currency', 'density', 'auto_generated', 'created_at', 'original_sketchup_material', 'is_favorite', 'flagged_no_material']
      csv << ['Good_Material', 2440, 1220, 18, 45, 'USD', 600, false, '', '', false, false]
      csv << ['Bad_Material', 'invalid', 'invalid', 'invalid', 'invalid', 'USD', 'invalid', false, '', '', false, false]
      csv << ['Another_Good', 2440, 1220, 12, 35, 'USD', 600, false, '', '', false, false]
    end
    
    loaded = AutoNestCut::MaterialsDatabase.load_database
    
    assert(loaded.key?('Good_Material'), "Good material loaded")
    assert(loaded.key?('Another_Good'), "Another good material loaded")
    assert(loaded.key?('Bad_Material'), "Bad material loaded with defaults")
    assert(loaded['Bad_Material'][0]['width'] == 2440, "Bad material has default width")
  end
  
  # TEST 9: Edge case thicknesses
  def test_edge_case_thicknesses
    puts "\n📋 Test 9: Edge case thicknesses"
    
    materials = {
      'Edge_Cases' => [
        { 'width' => 2440, 'height' => 1220, 'thickness' => 0.1, 'price' => 10, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false },  # Very thin
        { 'width' => 2440, 'height' => 1220, 'thickness' => 500, 'price' => 500, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false },  # Very thick
        { 'width' => 2440, 'height' => 1220, 'thickness' => 18.123456, 'price' => 45, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false }  # Many decimals
      ]
    }
    
    AutoNestCut::MaterialsDatabase.save_database(materials)
    loaded = AutoNestCut::MaterialsDatabase.load_database
    
    assert(loaded['Edge_Cases'].length == 3, "All edge cases saved")
    thicknesses = loaded['Edge_Cases'].map { |m| m['thickness'] }.sort
    assert(thicknesses[0] == 0.1, "Very thin thickness preserved")
    assert(thicknesses[2] == 500, "Very thick thickness preserved")
  end
  
  # TEST 10: Backward compatibility (single hash format)
  def test_backward_compatibility
    puts "\n📋 Test 10: Backward compatibility with single hash format"
    
    # Simulate old format (single hash, not array)
    materials = {
      'Old_Format_Material' => {
        'width' => 2440,
        'height' => 1220,
        'thickness' => 18,
        'price' => 45,
        'currency' => 'USD',
        'density' => 600,
        'auto_generated' => false
      }
    }
    
    AutoNestCut::MaterialsDatabase.save_database(materials)
    loaded = AutoNestCut::MaterialsDatabase.load_database
    
    assert(loaded.key?('Old_Format_Material'), "Old format material loaded")
    assert(loaded['Old_Format_Material'].is_a?(Array), "Converted to array format")
    assert(loaded['Old_Format_Material'].length == 1, "Has 1 entry")
    assert(loaded['Old_Format_Material'][0]['thickness'] == 18, "Thickness preserved")
  end
end

# Run tests
if __FILE__ == $0
  tester = MaterialThicknessTest.new
  success = tester.run_all_tests
  exit(success ? 0 : 1)
end
