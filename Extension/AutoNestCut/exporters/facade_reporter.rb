require 'csv'

module AutoNestCut
  class FacadeReporter
    
    def generate_facade_report(quantities, surface_breakdown, settings = {})
      units = settings['units'] || 'mm'
      currency = settings['currency'] || 'USD'
      
      report_data = {
        project_summary: generate_project_summary(quantities, units),
        material_specifications: generate_material_specs(quantities[:preset_info]),
        quantity_breakdown: generate_quantity_breakdown(quantities, currency),
        surface_analysis: generate_surface_analysis(surface_breakdown, units),
        cost_estimation: generate_cost_estimation(quantities, settings),
        generated_at: Time.now.strftime("%Y-%m-%d %H:%M:%S")
      }
      
      report_data
    end
    
    def export_facade_csv(filename, report_data)
      CSV.open(filename, 'w') do |csv|
        csv << ["FACADE MATERIALS REPORT"]
        csv << ["Generated:", report_data[:generated_at]]
        csv << []
        
        # Project Summary
        csv << ["PROJECT SUMMARY"]
        summary = report_data[:project_summary]
        csv << ["Total Area (m²)", summary[:total_area]]
        csv << ["Total Pieces Required", summary[:total_pieces]]
        csv << ["Waste Allowance (%)", summary[:waste_factor]]
        csv << ["Joint Material Volume (m³)", summary[:joint_volume]]
        csv << []
        
        # Material Specifications
        csv << ["MATERIAL SPECIFICATIONS"]
        specs = report_data[:material_specifications]
        csv << ["Material Type", specs[:material_name]]
        csv << ["Piece Dimensions", specs[:piece_dimensions]]
        csv << ["Joint Size", specs[:joint_size]]
        csv << ["Pattern Type", specs[:pattern_type]]
        csv << ["Coverage (pieces/m²)", specs[:pieces_per_m2]]
        csv << []
        
        # Surface Breakdown
        csv << ["SURFACE BREAKDOWN"]
        csv << ["Surface Type", "Count", "Total Area (m²)"]
        breakdown = report_data[:surface_analysis]
        csv << ["Vertical Surfaces", breakdown[:vertical_count], breakdown[:vertical_area]]
        csv << ["Horizontal Surfaces", breakdown[:horizontal_count], breakdown[:horizontal_area]]
        csv << ["Sloped Surfaces", breakdown[:sloped_count], breakdown[:sloped_area]]
      end
    end
    
    private
    
    def generate_project_summary(quantities, units)
      {
        total_area: quantities[:total_area_m2],
        total_pieces: quantities[:total_pieces],
        waste_pieces: quantities[:waste_pieces],
        waste_factor: quantities[:waste_factor],
        joint_volume: quantities[:joint_volume_m3],
        surfaces_count: quantities[:surfaces_count],
        units: units
      }
    end
    
    def generate_material_specs(preset_info)
      {
        material_name: preset_info[:material],
        piece_dimensions: preset_info[:piece_dimensions],
        joint_size: preset_info[:joint_size],
        pattern_type: preset_info[:pattern],
        pieces_per_m2: preset_info[:pieces_per_m2],
        joint_ratio: preset_info[:joint_ratio]
      }
    end
    
    def generate_quantity_breakdown(quantities, currency)
      {
        base_pieces: quantities[:total_pieces] - quantities[:waste_pieces],
        waste_pieces: quantities[:waste_pieces],
        total_pieces: quantities[:total_pieces],
        joint_volume: quantities[:joint_volume_m3],
        currency: currency
      }
    end
    
    def generate_surface_analysis(surface_breakdown, units)
      vertical_area = surface_breakdown[:vertical_surfaces].sum { |s| s[:area_m2] }
      horizontal_area = surface_breakdown[:horizontal_surfaces].sum { |s| s[:area_m2] }
      sloped_area = surface_breakdown[:sloped_surfaces].sum { |s| s[:area_m2] }
      
      {
        vertical_count: surface_breakdown[:vertical_surfaces].length,
        vertical_area: vertical_area.round(2),
        horizontal_count: surface_breakdown[:horizontal_surfaces].length,
        horizontal_area: horizontal_area.round(2),
        sloped_count: surface_breakdown[:sloped_surfaces].length,
        sloped_area: sloped_area.round(2),
        units: units
      }
    end
    
    def generate_cost_estimation(quantities, settings)
      material_cost_per_piece = settings['material_cost_per_piece'] || 0
      joint_cost_per_m3 = settings['joint_cost_per_m3'] || 0
      
      material_cost = quantities[:total_pieces] * material_cost_per_piece
      joint_cost = quantities[:joint_volume_m3] * joint_cost_per_m3
      total_cost = material_cost + joint_cost
      
      {
        material_cost: material_cost.round(2),
        joint_cost: joint_cost.round(2),
        total_cost: total_cost.round(2),
        currency: settings['currency'] || 'USD'
      }
    end
  end
end