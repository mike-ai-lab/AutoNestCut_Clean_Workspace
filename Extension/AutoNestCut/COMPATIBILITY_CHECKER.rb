# AutoNestCut Compatibility Checker
# Run this script BEFORE processing components to identify compatibility issues
# Usage: In SketchUp Ruby Console, paste this entire script and run it

module AutoNestCut
  class CompatibilityChecker
    
    # Validation limits
    HARD_LIMIT_WIDTH = 4500
    HARD_LIMIT_HEIGHT = 5500
    MIN_DIMENSION = 1
    MIN_THICKNESS = 0.1
    MAX_THICKNESS = 500
    
    def initialize
      @compatible = []
      @incompatible = []
      @materials_db = load_materials_database
    end
    
    def check_selection
      model = Sketchup.active_model
      selection = model.selection
      
      if selection.empty?
        puts "\n❌ ERROR: No components selected. Please select components first."
        return
      end
      
      puts "\n" + "="*80
      puts "🔍 AUTONESTCUT COMPATIBILITY CHECKER"
      puts "="*80
      puts "Checking #{selection.length} selected entities...\n"
      
      selection.each do |entity|
        check_entity(entity)
      end
      
      print_report
    end
    
    private
    
    def check_entity(entity)
      case entity
      when Sketchup::ComponentInstance
        check_component(entity)
      when Sketchup::Group
        check_group(entity)
      else
        @incompatible << {
          name: entity.class.to_s,
          reason: "Not a component or group",
          details: "Only components and groups are supported"
        }
      end
    end
    
    def check_component(component)
      definition = component.definition
      name = definition.name
      
      # Get dimensions
      bounds = definition.bounds
      dimensions = get_dimensions(bounds).sort
      thickness = dimensions[0]
      width = dimensions[1]
      height = dimensions[2]
      
      # Get material
      material = component.material&.display_name || component.material&.name
      material = definition.material&.display_name || definition.material&.name if !material
      
      # Check for issues
      issues = []
      
      # Check 1: Material assigned (CRITICAL)
      if !material || material == 'No Material' || material.nil?
        issues << "❌ CRITICAL: No material assigned - component will be rejected"
      end
      
      # Check 2: Dimensions within hard limits
      if width > HARD_LIMIT_WIDTH
        issues << "Width #{width.round(1)}mm exceeds hard limit (#{HARD_LIMIT_WIDTH}mm)"
      end
      if height > HARD_LIMIT_HEIGHT
        issues << "Height #{height.round(1)}mm exceeds hard limit (#{HARD_LIMIT_HEIGHT}mm)"
      end
      
      # Check 3: Minimum dimensions
      if width < MIN_DIMENSION
        issues << "Width #{width.round(1)}mm below minimum (#{MIN_DIMENSION}mm)"
      end
      if height < MIN_DIMENSION
        issues << "Height #{height.round(1)}mm below minimum (#{MIN_DIMENSION}mm)"
      end
      
      # Check 4: Thickness valid
      if thickness > MAX_THICKNESS
        issues << "Thickness #{thickness.round(0)}mm exceeds maximum (#{MAX_THICKNESS}mm) - not a sheet material"
      end
      if thickness < MIN_THICKNESS
        issues << "Thickness #{thickness.round(2)}mm below minimum (#{MIN_THICKNESS}mm)"
      end
      
      # Check 5: Material in database (if assigned)
      if material && material != 'No Material'
        unless @materials_db.key?(material)
          issues << "⚠️  Material '#{material}' not in database (will be auto-created)"
        end
      end
      
      # Store result
      result = {
        name: name,
        width: width.round(1),
        height: height.round(1),
        thickness: thickness.round(2),
        material: material || "NONE",
        issues: issues
      }
      
      if issues.empty?
        @compatible << result
      else
        @incompatible << result
      end
    end
    
    def check_group(group)
      name = group.name.empty? ? "Group_#{group.entityID}" : group.name
      
      # Get dimensions
      bounds = group.bounds
      dimensions = get_dimensions(bounds).sort
      thickness = dimensions[0]
      width = dimensions[1]
      height = dimensions[2]
      
      # Get material
      material = group.material&.display_name || group.material&.name
      
      # Check for issues
      issues = []
      
      # Check 1: Material assigned (CRITICAL)
      if !material || material == 'No Material' || material.nil?
        issues << "❌ CRITICAL: No material assigned - component will be rejected"
      end
      
      # Check 2: Dimensions within hard limits
      if width > HARD_LIMIT_WIDTH
        issues << "Width #{width.round(1)}mm exceeds hard limit (#{HARD_LIMIT_WIDTH}mm)"
      end
      if height > HARD_LIMIT_HEIGHT
        issues << "Height #{height.round(1)}mm exceeds hard limit (#{HARD_LIMIT_HEIGHT}mm)"
      end
      
      # Check 3: Minimum dimensions
      if width < MIN_DIMENSION
        issues << "Width #{width.round(1)}mm below minimum (#{MIN_DIMENSION}mm)"
      end
      if height < MIN_DIMENSION
        issues << "Height #{height.round(1)}mm below minimum (#{MIN_DIMENSION}mm)"
      end
      
      # Check 4: Thickness valid
      if thickness > MAX_THICKNESS
        issues << "Thickness #{thickness.round(0)}mm exceeds maximum (#{MAX_THICKNESS}mm) - not a sheet material"
      end
      if thickness < MIN_THICKNESS
        issues << "Thickness #{thickness.round(2)}mm below minimum (#{MIN_THICKNESS}mm)"
      end
      
      # Check 5: Material in database (if assigned)
      if material && material != 'No Material'
        unless @materials_db.key?(material)
          issues << "⚠️  Material '#{material}' not in database (will be auto-created)"
        end
      end
      
      # Store result
      result = {
        name: name,
        width: width.round(1),
        height: height.round(1),
        thickness: thickness.round(2),
        material: material || "NONE",
        issues: issues
      }
      
      if issues.empty?
        @compatible << result
      else
        @incompatible << result
      end
    end
    
    def print_report
      puts "\n" + "="*80
      puts "✅ COMPATIBLE COMPONENTS (#{@compatible.length})"
      puts "="*80
      
      if @compatible.empty?
        puts "No compatible components found.\n"
      else
        @compatible.each_with_index do |comp, idx|
          puts "\n#{idx + 1}. #{comp[:name]}"
          puts "   Dimensions: #{comp[:width]} x #{comp[:height]} x #{comp[:thickness]}mm"
          puts "   Material: #{comp[:material]}"
          puts "   Status: ✓ READY FOR PROCESSING"
        end
      end
      
      puts "\n" + "="*80
      puts "❌ INCOMPATIBLE COMPONENTS (#{@incompatible.length})"
      puts "="*80
      
      if @incompatible.empty?
        puts "No incompatible components found.\n"
      else
        @incompatible.each_with_index do |comp, idx|
          puts "\n#{idx + 1}. #{comp[:name]}"
          puts "   Dimensions: #{comp[:width]} x #{comp[:height]} x #{comp[:thickness]}mm"
          puts "   Material: #{comp[:material]}"
          puts "   Issues:"
          comp[:issues].each do |issue|
            puts "     • #{issue}"
          end
        end
      end
      
      puts "\n" + "="*80
      puts "📊 SUMMARY"
      puts "="*80
      puts "Total Selected: #{@compatible.length + @incompatible.length}"
      puts "Compatible: #{@compatible.length} ✓"
      puts "Incompatible: #{@incompatible.length} ❌"
      puts "Success Rate: #{((@compatible.length.to_f / (@compatible.length + @incompatible.length)) * 100).round(1)}%"
      puts "="*80 + "\n"
      
      if @incompatible.any?
        puts "⚠️  ACTION REQUIRED:"
        puts "   Fix the incompatible components above before running AutoNestCut"
        puts "   Common fixes:"
        puts "   • Assign a material to components without materials"
        puts "   • Ensure dimensions are within limits (1mm - 4500x5500mm)"
        puts "   • Verify thickness is between 0.1mm and 500mm"
        puts "   • Check that materials exist in the database\n"
      else
        puts "✅ All components are compatible! Ready to run AutoNestCut.\n"
      end
    end
    
    def get_dimensions(bounds)
      width = (bounds.max.x - bounds.min.x).abs
      height = (bounds.max.y - bounds.min.y).abs
      depth = (bounds.max.z - bounds.min.z).abs
      [width, height, depth]
    end
    
    def load_materials_database
      # Try to load from AutoNestCut materials database
      materials = {}
      
      # Check if materials database file exists
      db_path = File.join(Sketchup.find_support_file('Plugins'), 'AutoNestCut', 'materials_database.json')
      
      if File.exist?(db_path)
        begin
          require 'json'
          content = File.read(db_path)
          materials = JSON.parse(content)
        rescue => e
          puts "⚠️  Could not load materials database: #{e.message}"
        end
      end
      
      materials
    end
  end
end

# Run the checker
checker = AutoNestCut::CompatibilityChecker.new
checker.check_selection
