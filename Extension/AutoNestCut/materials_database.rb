require 'csv'

module AutoNestCut
  class MaterialsDatabase
    
    def self.database_file
      File.join(ENV['APPDATA'] || ENV['HOME'], 'AutoNestCut', 'materials_database.csv')
    end
    
    def self.ensure_database_folder
      folder = File.dirname(database_file)
      Dir.mkdir(folder) unless Dir.exist?(folder)
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
      
      # Use atomic write: write to temp file, then rename
      # This prevents corruption if save is interrupted
      temp_file = "#{database_file}.tmp"
      
      begin
        CSV.open(temp_file, 'w') do |csv|
          csv << ['name', 'width', 'height', 'thickness', 'price', 'currency', 'density', 'auto_generated', 'created_at', 'original_sketchup_material', 'is_favorite', 'flagged_no_material']
          
          materials.each do |name, data|
            # Validate name
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
        
        # Atomic rename: temp file becomes the real database
        File.rename(temp_file, database_file)
        
        # Count total entries (including multiple thicknesses)
        total_count = materials.values.sum { |v| v.is_a?(Array) ? v.length : 1 }
        puts "✅ Materials database saved successfully (#{total_count} entries)"
        
      rescue => e
        # Clean up temp file on error
        File.delete(temp_file) if File.exist?(temp_file)
        Util.debug("Error saving materials database: #{e.message}")
        raise e
      end
    end
    
    def self.import_csv(file_path)
      return {} unless File.exist?(file_path)
      
      materials = {}
      CSV.foreach(file_path, headers: true) do |row|
        name = row['name'] || row['material'] || row['Material']
        next unless name
        
        default_currency = Config.get_cached_settings['default_currency'] || 'USD'
        materials[name] = {
          'width' => (row['width'] || row['Width'] || 2440).to_f,
          'height' => (row['height'] || row['Height'] || 1220).to_f,
          'thickness' => (row['thickness'] || row['Thickness'] || 18).to_f,
          'price' => (row['price'] || row['Price'] || 0).to_f,
          'currency' => row['currency'] || row['Currency'] || default_currency,
          'density' => (row['density'] || row['Density'] || 600).to_f,
          'supplier' => row['supplier'] || row['Supplier'] || '',
          'notes' => row['notes'] || row['Notes'] || '',
          'auto_generated' => (row['auto_generated'] || 'false') == 'true',
          'created_at' => row['created_at'] || '',
          'original_sketchup_material' => row['original_sketchup_material'] || ''
        }
      end
      materials
    rescue => e
      Util.debug("Error importing CSV: #{e.message}")
      {}
    end
    
    def self.get_default_materials
      default_currency = Config.get_cached_settings['default_currency'] || 'USD'
      
      # Try to load from JSON file first
      json_path = File.join(__dir__, 'default_materials_database.json')
      if File.exist?(json_path)
        begin
          json_content = File.read(json_path)
          defaults = JSON.parse(json_content)
          
          # Ensure all entries have currency set and mark as default
          defaults.each do |name, data|
            data['currency'] ||= default_currency
            data['auto_generated'] = false  # Mark as not auto-generated (they're from defaults)
            data['is_default'] = true       # Mark as default material
          end
          
          return defaults
        rescue => e
          puts "WARNING: Could not load default materials from JSON: #{e.message}"
          puts "Falling back to hardcoded defaults"
        end
      end
      
      # Fallback to basic defaults if JSON not found
      {
        'Plywood_19mm' => { 'width' => 2440, 'height' => 1220, 'thickness' => 19, 'price' => 45, 'currency' => default_currency, 'density' => 600, 'auto_generated' => false, 'is_default' => true },
        'Plywood_12mm' => { 'width' => 2440, 'height' => 1220, 'thickness' => 12, 'price' => 35, 'currency' => default_currency, 'density' => 600, 'auto_generated' => false, 'is_default' => true },
        'MDF_16mm' => { 'width' => 2440, 'height' => 1220, 'thickness' => 16, 'price' => 25, 'currency' => default_currency, 'density' => 750, 'auto_generated' => false, 'is_default' => true },
        'MDF_19mm' => { 'width' => 2440, 'height' => 1220, 'thickness' => 19, 'price' => 30, 'currency' => default_currency, 'density' => 750, 'auto_generated' => false, 'is_default' => true },
        'Oak_Veneer' => { 'width' => 2440, 'height' => 1220, 'thickness' => 18, 'price' => 85, 'currency' => default_currency, 'density' => 680, 'auto_generated' => false, 'is_default' => true },
        'Melamine_White' => { 'width' => 2440, 'height' => 1220, 'thickness' => 18, 'price' => 40, 'currency' => default_currency, 'density' => 680, 'auto_generated' => false, 'is_default' => true }
      }
    end
    
    # This method is for backend internal use. Frontend uses global currencySymbols.
    def self.get_supported_currencies
      # Keeping a comprehensive list, but UI only shows a subset.
      # This is useful for CSV import/export validation or future features.
      {
        'USD' => '$',
        'EUR' => '€',
        'GBP' => '£',
        'CAD' => 'C$',
        'AUD' => 'A$',
        'JPY' => '¥',
        'CNY' => '¥',
        'INR' => '₹',
        'BRL' => 'R$',
        'MXN' => '$',
        'CHF' => 'CHF',
        'SEK' => 'kr',
        'NOK' => 'kr',
        'DKK' => 'kr',
        'PLN' => 'zł',
        'CZK' => 'Kč',
        'HUF' => 'Ft',
        'RUB' => '₽',
        'TRY' => '₺',
        'ZAR' => 'R',
        'KRW' => '₩',
        'SGD' => 'S$',
        'HKD' => 'HK$',
        'NZD' => 'NZ$',
        'THB' => '฿',
        'MYR' => 'RM',
        'IDR' => 'Rp',
        'PHP' => '₱',
        'VND' => '₫',
        'ILS' => '₪',
        'AED' => 'د.إ',
        'SAR' => 'ر.س',
        'EGP' => 'ج.م',
        'QAR' => 'ر.ق',
        'KWD' => 'د.ك',
        'BHD' => 'د.ب',
        'OMR' => 'ر.ع.',
        'JOD' => 'د.ا',
        'LBP' => 'ل.ل',
        'MAD' => 'د.م.',
        'TND' => 'د.ت',
        'DZD' => 'د.ج',
        'LYD' => 'ل.د',
        'SDG' => 'ج.س.',
        'SOS' => 'S',
        'ETB' => 'Br',
        'KES' => 'KSh',
        'UGX' => 'USh',
        'TZS' => 'TSh',
        'RWF' => 'RF',
        'BIF' => 'FBu',
        'DJF' => 'Fdj',
        'ERN' => 'Nfk',
        'MGA' => 'Ar',
        'MUR' => '₨',
        'SCR' => '₨',
        'KMF' => 'CF',
        'MWK' => 'MK',
        'ZMW' => 'ZK',
        'BWP' => 'P',
        'SZL' => 'L',
        'LSL' => 'L',
        'NAD' => 'N$',
        'AOA' => 'Kz',
        'MZN' => 'MT',
        'ZWL' => 'Z$',
        'GMD' => 'D',
        'SLL' => 'Le',
        'LRD' => 'L$',
        'GHS' => '₵',
        'NGN' => '₦',
        'XOF' => 'CFA',
        'XAF' => 'FCFA',
        'CVE' => '$',
        'STD' => 'Db',
        'GNF' => 'FG',
        'CDF' => 'FC',
        'XPF' => '₣',
        'FJD' => 'FJ$',
        'SBD' => 'SI$',
        'VUV' => 'VT',
        'TOP' => 'T$',
        'WST' => 'WS$',
        'PGK' => 'K',
        'TVD' => '$',
        'NRU' => '$',
        'KID' => '$',
        'CKD' => '$',
        'NUD' => '$'
      }
    end
    
    def self.format_price(price, currency = 'USD')
      symbol = get_supported_currencies[currency] || currency
      "#{symbol}#{price.round(2)}"
    end
    
    # Helper: Validate and coerce float values with defaults
    # Prevents NaN, Infinity, and nil values from corrupting the database
    def self.validate_float(value, default)
      return default if value.nil?
      float_val = value.to_f
      float_val.finite? ? float_val : default
    rescue
      default
    end
    
  end
end
