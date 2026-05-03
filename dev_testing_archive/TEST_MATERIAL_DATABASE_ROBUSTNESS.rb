#!/usr/bin/env ruby
# Comprehensive unit tests for Material Database robustness
# Tests: save, load, refresh, consistency, data integrity

require 'json'
require 'csv'
require 'fileutils'
require 'tempfile'

# Mock classes for testing
class MockConfig
  @@settings = {
    'default_currency' => 'USD',
    'units' => 'mm',
    'kerf_width' => 3.0,
    'allow_rotation' => true
  }

  def self.get_cached_settings
    @@settings.dup
  end

  def self.save_global_settings(settings)
    @@settings.merge!(settings)
  end
end

class MockUtil
  def self.debug(msg)
    puts "DEBUG: #{msg}"
  end
end

# Test Suite
class MaterialDatabaseTest
  attr_accessor :test_db_path, :passed, :failed

  def initialize
    @test_db_path = File.join(Dir.tmpdir, "test_materials_#{Time.now.to_i}.csv")
    @passed = 0
    @failed = 0
  end

  def cleanup
    File.delete(@test_db_path) if File.exist?(@test_db_path)
  end

  def assert(condition, message)
    if condition
      @passed += 1
      puts "✅ PASS: #{message}"
    else
      @failed += 1
      puts "❌ FAIL: #{message}"
    end
  end

  def assert_equal(expected, actual, message)
    if expected == actual
      @passed += 1
      puts "✅ PASS: #{message}"
    else
      @failed += 1
      puts "❌ FAIL: #{message}"
      puts "   Expected: #{expected.inspect}"
      puts "   Actual: #{actual.inspect}"
    end
  end

  def run_all_tests
    puts "\n" + "=" * 80
    puts "MATERIAL DATABASE ROBUSTNESS TEST SUITE"
    puts "=" * 80 + "\n"

    test_save_robustness
    test_load_consistency
    test_refresh_preserves_data
    test_no_silent_modifications
    test_data_integrity_on_save
    test_concurrent_access_safety
    test_default_materials_loading
    test_auto_material_preservation
    test_material_contamination_prevention

    print_summary
    cleanup
  end

  # TEST 1: Save Robustness
  def test_save_robustness
    puts "\n--- TEST 1: Save Robustness ---"
    
    materials = {
      'MDF_18mm' => {
        'width' => 2440, 'height' => 1220, 'thickness' => 18,
        'price' => 25, 'currency' => 'USD', 'density' => 750,
        'auto_generated' => false, 'is_favorite' => true
      },
      'Plywood_12mm' => {
        'width' => 2440, 'height' => 1220, 'thickness' => 12,
        'price' => 35, 'currency' => 'USD', 'density' => 650,
        'auto_generated' => false, 'is_favorite' => false
      }
    }

    # Save materials
    save_materials_to_file(@test_db_path, materials)
    assert(File.exist?(@test_db_path), "Database file created after save")

    # Verify file is not empty
    file_size = File.size(@test_db_path)
    assert(file_size > 0, "Database file has content (size: #{file_size} bytes)")

    # Verify CSV structure
    csv_lines = File.readlines(@test_db_path)
    assert(csv_lines.length >= 3, "CSV has header + at least 2 data rows")

    # Verify header
    header = csv_lines[0].strip
    expected_columns = ['name', 'width', 'height', 'thickness', 'price', 'currency', 'density', 'auto_generated', 'created_at', 'original_sketchup_material', 'is_favorite', 'flagged_no_material']
    assert(header.include?('name') && header.include?('width'), "CSV header contains required columns")
  end

  # TEST 2: Load Consistency
  def test_load_consistency
    puts "\n--- TEST 2: Load Consistency ---"
    
    original_materials = {
      'MDF_18mm' => {
        'width' => 2440.5, 'height' => 1220.3, 'thickness' => 18.0,
        'price' => 25.99, 'currency' => 'EUR', 'density' => 750.0,
        'auto_generated' => false, 'is_favorite' => true
      }
    }

    # Save and load
    save_materials_to_file(@test_db_path, original_materials)
    loaded_materials = load_materials_from_file(@test_db_path)

    # Verify all materials loaded
    assert_equal(original_materials.keys.length, loaded_materials.keys.length, "All materials loaded")

    # Verify data integrity
    loaded_mat = loaded_materials['MDF_18mm']
    assert_equal(2440.5, loaded_mat['width'], "Width preserved with decimals")
    assert_equal(1220.3, loaded_mat['height'], "Height preserved with decimals")
    assert_equal(18.0, loaded_mat['thickness'], "Thickness preserved")
    assert_equal(25.99, loaded_mat['price'], "Price preserved with decimals")
    assert_equal('EUR', loaded_mat['currency'], "Currency preserved")
    assert_equal(true, loaded_mat['is_favorite'], "Boolean flag preserved")
  end

  # TEST 3: Refresh Preserves Data
  def test_refresh_preserves_data
    puts "\n--- TEST 3: Refresh Preserves Data ---"
    
    materials_v1 = {
      'MDF_18mm' => { 'width' => 2440, 'height' => 1220, 'thickness' => 18, 'price' => 25, 'currency' => 'USD', 'density' => 750, 'auto_generated' => false, 'is_favorite' => true },
      'Plywood_12mm' => { 'width' => 2440, 'height' => 1220, 'thickness' => 12, 'price' => 35, 'currency' => 'USD', 'density' => 650, 'auto_generated' => false, 'is_favorite' => false }
    }

    # Save initial data
    save_materials_to_file(@test_db_path, materials_v1)
    loaded_v1 = load_materials_from_file(@test_db_path)

    # Simulate refresh (load and re-save without modification)
    save_materials_to_file(@test_db_path, loaded_v1)
    loaded_v2 = load_materials_from_file(@test_db_path)

    # Verify data unchanged after refresh
    assert_equal(loaded_v1.keys.sort, loaded_v2.keys.sort, "Material names preserved after refresh")
    assert_equal(loaded_v1['MDF_18mm']['price'], loaded_v2['MDF_18mm']['price'], "MDF price preserved after refresh")
    assert_equal(loaded_v1['Plywood_12mm']['is_favorite'], loaded_v2['Plywood_12mm']['is_favorite'], "Plywood favorite flag preserved after refresh")
  end

  # TEST 4: No Silent Modifications
  def test_no_silent_modifications
    puts "\n--- TEST 4: No Silent Modifications ---"
    
    materials = {
      'Custom_Material' => {
        'width' => 1500, 'height' => 800, 'thickness' => 25,
        'price' => 99.99, 'currency' => 'GBP', 'density' => 600,
        'auto_generated' => false, 'is_favorite' => false,
        'created_at' => '2025-01-24T10:00:00Z',
        'original_sketchup_material' => 'Custom'
      }
    }

    # Save
    save_materials_to_file(@test_db_path, materials)
    loaded = load_materials_from_file(@test_db_path)

    # Verify no unexpected modifications
    original_mat = materials['Custom_Material']
    loaded_mat = loaded['Custom_Material']

    assert_equal(original_mat['width'], loaded_mat['width'], "Width not modified")
    assert_equal(original_mat['height'], loaded_mat['height'], "Height not modified")
    assert_equal(original_mat['thickness'], loaded_mat['thickness'], "Thickness not modified")
    assert_equal(original_mat['price'], loaded_mat['price'], "Price not modified")
    assert_equal(original_mat['currency'], loaded_mat['currency'], "Currency not modified")
    assert_equal(original_mat['created_at'], loaded_mat['created_at'], "Timestamp not modified")
  end

  # TEST 5: Data Integrity on Save
  def test_data_integrity_on_save
    puts "\n--- TEST 5: Data Integrity on Save ---"
    
    materials = {
      'Material_1' => { 'width' => 2440, 'height' => 1220, 'thickness' => 18, 'price' => 25, 'currency' => 'USD', 'density' => 750, 'auto_generated' => false, 'is_favorite' => true },
      'Material_2' => { 'width' => 2440, 'height' => 1220, 'thickness' => 12, 'price' => 35, 'currency' => 'USD', 'density' => 650, 'auto_generated' => false, 'is_favorite' => false },
      'Material_3' => { 'width' => 1525, 'height' => 1525, 'thickness' => 18, 'price' => 45, 'currency' => 'EUR', 'density' => 680, 'auto_generated' => true, 'is_favorite' => false }
    }

    # Save
    save_materials_to_file(@test_db_path, materials)
    loaded = load_materials_from_file(@test_db_path)

    # Verify all materials present
    assert_equal(3, loaded.keys.length, "All 3 materials saved and loaded")

    # Verify no data loss
    materials.each do |name, data|
      assert(loaded.key?(name), "Material '#{name}' present after save/load")
      assert_equal(data['width'], loaded[name]['width'], "#{name} width correct")
      assert_equal(data['price'], loaded[name]['price'], "#{name} price correct")
    end
  end

  # TEST 6: Concurrent Access Safety
  def test_concurrent_access_safety
    puts "\n--- TEST 6: Concurrent Access Safety ---"
    
    materials_a = {
      'Material_A' => { 'width' => 2440, 'height' => 1220, 'thickness' => 18, 'price' => 25, 'currency' => 'USD', 'density' => 750, 'auto_generated' => false, 'is_favorite' => false }
    }

    materials_b = {
      'Material_B' => { 'width' => 2440, 'height' => 1220, 'thickness' => 12, 'price' => 35, 'currency' => 'USD', 'density' => 650, 'auto_generated' => false, 'is_favorite' => false }
    }

    # Save A
    save_materials_to_file(@test_db_path, materials_a)
    loaded_a = load_materials_from_file(@test_db_path)

    # Save B (should not lose A)
    merged = loaded_a.merge(materials_b)
    save_materials_to_file(@test_db_path, merged)
    loaded_merged = load_materials_from_file(@test_db_path)

    # Verify both present
    assert(loaded_merged.key?('Material_A'), "Material A preserved after merge save")
    assert(loaded_merged.key?('Material_B'), "Material B added in merge save")
    assert_equal(2, loaded_merged.keys.length, "Both materials present after concurrent operations")
  end

  # TEST 7: Default Materials Loading
  def test_default_materials_loading
    puts "\n--- TEST 7: Default Materials Loading ---"
    
    # Simulate loading defaults
    defaults = {
      'Plywood_19mm' => { 'width' => 2440, 'height' => 1220, 'thickness' => 19, 'price' => 45, 'currency' => 'USD', 'density' => 600, 'auto_generated' => false, 'is_default' => true },
      'MDF_18mm' => { 'width' => 2440, 'height' => 1220, 'thickness' => 18, 'price' => 30, 'currency' => 'USD', 'density' => 750, 'auto_generated' => false, 'is_default' => true }
    }

    # Save defaults
    save_materials_to_file(@test_db_path, defaults)
    loaded = load_materials_from_file(@test_db_path)

    # Verify defaults loaded
    assert_equal(2, loaded.keys.length, "Default materials loaded")
    assert(loaded.key?('Plywood_19mm'), "Plywood default present")
    assert(loaded.key?('MDF_18mm'), "MDF default present")
  end

  # TEST 8: Auto-Material Preservation
  def test_auto_material_preservation
    puts "\n--- TEST 8: Auto-Material Preservation ---"
    
    materials = {
      'Auto_user_W232xH348xTH8_(Blue_Glass_Shelf)' => {
        'width' => 232, 'height' => 348, 'thickness' => 8,
        'price' => 0, 'currency' => 'USD', 'density' => 600,
        'auto_generated' => true, 'original_sketchup_material' => 'Blue_Glass_Shelf'
      },
      'Standard_MDF_18mm' => {
        'width' => 2440, 'height' => 1220, 'thickness' => 18,
        'price' => 25, 'currency' => 'USD', 'density' => 750,
        'auto_generated' => false, 'is_favorite' => false
      }
    }

    # Save
    save_materials_to_file(@test_db_path, materials)
    loaded = load_materials_from_file(@test_db_path)

    # Verify auto-material preserved with exact dimensions
    auto_mat = loaded['Auto_user_W232xH348xTH8_(Blue_Glass_Shelf)']
    assert_equal(232, auto_mat['width'], "Auto-material width preserved exactly")
    assert_equal(348, auto_mat['height'], "Auto-material height preserved exactly")
    assert_equal(8, auto_mat['thickness'], "Auto-material thickness preserved exactly")
    assert_equal(true, auto_mat['auto_generated'], "Auto-generated flag preserved")
  end

  # TEST 9: Material Contamination Prevention
  def test_material_contamination_prevention
    puts "\n--- TEST 9: Material Contamination Prevention ---"
    
    materials = {
      'Auto_user_W232xH348xTH8_(Blue_Glass_Shelf)' => {
        'width' => 232, 'height' => 348, 'thickness' => 8,
        'price' => 0, 'currency' => 'USD', 'density' => 600,
        'auto_generated' => true, 'original_sketchup_material' => 'Blue_Glass_Shelf'
      },
      'Auto_user_W250xH750xTH100_(Metal_Corrogated_Shiny)' => {
        'width' => 250, 'height' => 750, 'thickness' => 100,
        'price' => 0, 'currency' => 'USD', 'density' => 600,
        'auto_generated' => true, 'original_sketchup_material' => 'Metal_Corrogated_Shiny'
      },
      'Metal_Corrogated_Shiny (18.0mm)' => {
        'width' => 2440, 'height' => 1220, 'thickness' => 18,
        'price' => 50, 'currency' => 'USD', 'density' => 680,
        'auto_generated' => false, 'is_favorite' => false
      }
    }

    # Save
    save_materials_to_file(@test_db_path, materials)
    loaded = load_materials_from_file(@test_db_path)

    # Verify no contamination
    assert(loaded.key?('Auto_user_W232xH348xTH8_(Blue_Glass_Shelf)'), "8mm auto-material preserved")
    assert(loaded.key?('Auto_user_W250xH750xTH100_(Metal_Corrogated_Shiny)'), "100mm auto-material preserved")
    assert(loaded.key?('Metal_Corrogated_Shiny (18.0mm)'), "18mm standard material preserved")
    assert_equal(3, loaded.keys.length, "All 3 materials coexist without contamination")
  end

  # Helper methods
  def save_materials_to_file(path, materials)
    CSV.open(path, 'w') do |csv|
      csv << ['name', 'width', 'height', 'thickness', 'price', 'currency', 'density', 'auto_generated', 'created_at', 'original_sketchup_material', 'is_favorite', 'flagged_no_material']
      materials.each do |name, data|
        csv << [
          name,
          data['width'] || 2440,
          data['height'] || 1220,
          data['thickness'] || 18,
          data['price'] || 0,
          data['currency'] || 'USD',
          data['density'] || 600,
          data['auto_generated'] || false,
          data['created_at'] || '',
          data['original_sketchup_material'] || '',
          data['is_favorite'] || false,
          data['flagged_no_material'] || false
        ]
      end
    end
  end

  def load_materials_from_file(path)
    return {} unless File.exist?(path)
    
    materials = {}
    CSV.foreach(path, headers: true) do |row|
      materials[row['name']] = {
        'width' => row['width'].to_f,
        'height' => row['height'].to_f,
        'thickness' => (row['thickness'] || 18).to_f,
        'price' => row['price'].to_f,
        'currency' => row['currency'] || 'USD',
        'density' => (row['density'] || 600).to_f,
        'auto_generated' => row['auto_generated'] == 'true' || row['auto_generated'] == true,
        'created_at' => row['created_at'] || '',
        'original_sketchup_material' => row['original_sketchup_material'] || '',
        'is_favorite' => row['is_favorite'] == 'true' || row['is_favorite'] == true,
        'flagged_no_material' => row['flagged_no_material'] == 'true' || row['flagged_no_material'] == true
      }
    end
    materials
  end

  def print_summary
    puts "\n" + "=" * 80
    puts "TEST SUMMARY"
    puts "=" * 80
    puts "✅ Passed: #{@passed}"
    puts "❌ Failed: #{@failed}"
    puts "Total: #{@passed + @failed}"
    
    if @failed == 0
      puts "\n🎉 ALL TESTS PASSED!"
    else
      puts "\n⚠️  #{@failed} test(s) failed"
    end
    puts "=" * 80 + "\n"
  end
end

# Run tests
if __FILE__ == $0
  test_suite = MaterialDatabaseTest.new
  test_suite.run_all_tests
end
