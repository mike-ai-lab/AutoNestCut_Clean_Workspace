# TEST: Material Binding for Auto-Created Materials
# This script tests if components with empty material names are correctly bound
# to their corresponding no_material_* auto-created materials

# Simulate the binding logic
module TestMaterialBinding
  
  # Simulate loaded materials database (what validator creates)
  def self.create_test_materials_database
    {
      # Standard materials
      'Plywood_18mm' => {
        'width' => 2440.0,
        'height' => 1220.0,
        'thickness' => 18.0,
        'price' => 50.0,
        'currency' => 'USD'
      },
      
      # Auto-created materials (from validator)
      'Auto_user_W364xH450xTH21_(A04_Scarlet_Glow)' => {
        'width' => 364.0,
        'height' => 450.0,
        'thickness' => 21.0,
        'price' => 25.0,
        'currency' => 'USD',
        'auto_generated' => true
      },
      
      'Auto_user_W380xH2040xTH18_(A04_Scarlet_Glow)' => {
        'width' => 380.0,
        'height' => 2040.0,
        'thickness' => 18.0,
        'price' => 45.0,
        'currency' => 'USD',
        'auto_generated' => true
      },
      
      # Flagged materials (components with no material assigned)
      'no_material_W321xH486xTH45_(unnamed)' => {
        'width' => 320.8,
        'height' => 486.3,
        'thickness' => 45.4,
        'price' => 30.0,
        'currency' => 'USD',
        'auto_generated' => true,
        'flagged_no_material' => true
      },
      
      'no_material_W40xH3355xTH18_(unnamed)' => {
        'width' => 40.0,
        'height' => 3354.5,
        'thickness' => 18.0,
        'price' => 80.0,
        'currency' => 'USD',
        'auto_generated' => true,
        'flagged_no_material' => true
      }
    }
  end
  
  # Mock Part class
  MockPart = Struct.new(:name, :width, :height, :thickness, :material)
  
  # Simulate parts_by_material (what ModelAnalyzer creates)
  def self.create_test_parts_by_material
    
    {
      'A04_Scarlet_Glow' => [
        MockPart.new('Panel#1', 364.0, 450.0, 21.0, 'A04_Scarlet_Glow'),
        MockPart.new('Panel - bottom', 380.0, 2040.0, 18.0, 'A04_Scarlet_Glow')
      ],
      '' => [  # Empty material name - the problematic case
        MockPart.new('', 320.8, 486.3, 45.4, ''),
        MockPart.new('', 40.0, 3354.5, 18.0, '')  # The oversized component
      ]
    }
  end
  
  # OLD binding logic (buggy - only checks Auto_user_)
  def self.bind_components_OLD(parts_by_material, loaded_materials)
    puts "\n" + "="*80
    puts "OLD BINDING LOGIC (BUGGY)"
    puts "="*80
    
    auto_materials = loaded_materials.select { |name, _| name.start_with?('Auto_user_') }
    puts "\nAuto-materials found: #{auto_materials.keys.length}"
    auto_materials.keys.each { |k| puts "  - #{k}" }
    
    remapped = {}
    
    parts_by_material.each do |original_material_name, parts|
      parts.each do |part|
        target_material = nil
        
        auto_materials.each do |auto_mat_name, auto_mat_data|
          if (part.width - auto_mat_data['width']).abs < 0.1 &&
             (part.height - auto_mat_data['height']).abs < 0.1 &&
             (part.thickness - auto_mat_data['thickness']).abs < 0.1
            target_material = auto_mat_name
            break
          end
        end
        
        target_material = original_material_name if target_material.nil?
        remapped[target_material] ||= []
        remapped[target_material] << part
      end
    end
    
    puts "\nBinding result:"
    remapped.each do |material, parts|
      puts "  Material: '#{material}' => #{parts.length} parts"
      parts.each do |p|
        puts "    - #{p.name.empty? ? '(unnamed)' : p.name}: #{p.width}x#{p.height}x#{p.thickness}mm"
      end
    end
    
    remapped
  end
  
  # NEW binding logic (fixed - checks both Auto_user_ and no_material_)
  def self.bind_components_NEW(parts_by_material, loaded_materials)
    puts "\n" + "="*80
    puts "NEW BINDING LOGIC (FIXED)"
    puts "="*80
    
    auto_materials = loaded_materials.select { |name, _| name.start_with?('Auto_user_') || name.start_with?('no_material_') }
    puts "\nAuto-materials found: #{auto_materials.keys.length}"
    auto_materials.keys.each { |k| puts "  - #{k}" }
    
    remapped = {}
    
    parts_by_material.each do |original_material_name, parts|
      parts.each do |part|
        target_material = nil
        
        auto_materials.each do |auto_mat_name, auto_mat_data|
          if (part.width - auto_mat_data['width']).abs < 0.1 &&
             (part.height - auto_mat_data['height']).abs < 0.1 &&
             (part.thickness - auto_mat_data['thickness']).abs < 0.1
            target_material = auto_mat_name
            break
          end
        end
        
        target_material = original_material_name if target_material.nil?
        remapped[target_material] ||= []
        remapped[target_material] << part
      end
    end
    
    puts "\nBinding result:"
    remapped.each do |material, parts|
      puts "  Material: '#{material}' => #{parts.length} parts"
      parts.each do |p|
        puts "    - #{p.name.empty? ? '(unnamed)' : p.name}: #{p.width}x#{p.height}x#{p.thickness}mm"
      end
    end
    
    remapped
  end
  
  # Simulate nester lookup
  def self.test_nester_lookup(remapped_materials, stock_materials_config)
    puts "\n" + "="*80
    puts "NESTER LOOKUP TEST"
    puts "="*80
    
    remapped_materials.each do |material_name, parts|
      puts "\nProcessing material: '#{material_name}'"
      
      stock_dims = stock_materials_config[material_name]
      if stock_dims.nil?
        puts "  ❌ NOT FOUND in stock_materials - defaulting to 2440x1220mm"
        stock_width, stock_height = 2440.0, 1220.0
      else
        stock_width = stock_dims['width'].to_f
        stock_height = stock_dims['height'].to_f
        puts "  ✓ FOUND in stock_materials - using #{stock_width}x#{stock_height}mm"
      end
      
      # Check if parts can fit
      parts.each do |part|
        can_fit = (part.width <= stock_width && part.height <= stock_height) ||
                  (part.height <= stock_width && part.width <= stock_height)
        
        if can_fit
          puts "    ✓ Part #{part.width}x#{part.height}mm CAN fit on #{stock_width}x#{stock_height}mm"
        else
          puts "    ❌ Part #{part.width}x#{part.height}mm CANNOT fit on #{stock_width}x#{stock_height}mm"
        end
      end
    end
  end
  
  # Run the full test
  def self.run_test
    puts "\n" + "="*80
    puts "MATERIAL BINDING TEST"
    puts "Testing fix for oversized components with empty material names"
    puts "="*80
    
    materials_db = create_test_materials_database
    parts_by_material = create_test_parts_by_material
    
    puts "\nTest scenario:"
    puts "  - 2 components with material 'A04_Scarlet_Glow'"
    puts "  - 2 components with EMPTY material name (including 40x3355mm oversized)"
    puts "  - Validator created 4 auto-materials (2 Auto_user_, 2 no_material_)"
    
    # Test OLD logic
    old_result = bind_components_OLD(parts_by_material, materials_db)
    test_nester_lookup(old_result, materials_db)
    
    # Test NEW logic
    new_result = bind_components_NEW(parts_by_material, materials_db)
    test_nester_lookup(new_result, materials_db)
    
    # Summary
    puts "\n" + "="*80
    puts "TEST SUMMARY"
    puts "="*80
    
    # Check if oversized component is properly bound in new logic
    oversized_bound_correctly = new_result.any? do |material, parts|
      material.start_with?('no_material_W40xH3355') && 
      parts.any? { |p| p.width == 40.0 && p.height == 3354.5 }
    end
    
    if oversized_bound_correctly
      puts "✅ SUCCESS: Oversized component (40x3355mm) is correctly bound to custom material"
      puts "   The nester will use the correct sheet dimensions and won't fail"
    else
      puts "❌ FAILURE: Oversized component is still bound to empty material name"
      puts "   The nester will default to 2440x1220mm and fail"
    end
    
    puts "="*80
  end
end

# Run the test
TestMaterialBinding.run_test
