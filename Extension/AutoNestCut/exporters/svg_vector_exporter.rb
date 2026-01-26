# frozen_string_literal: true

require 'base64'
require 'json'

module AutoNestCut
  class SvgVectorExporter
    
    # Export a specific face as SVG for CNC/Laser cutting
    def self.export_face_as_svg(entity, face_name = 'Front', output_path = nil)
      return nil unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      
      output_path ||= generate_default_svg_path(entity.name, face_name)
      
      # Get the geometry data
      geometry_data = extract_geometry_with_edges(entity)
      
      # Project geometry onto the specified plane
      projected_data = project_to_2d(geometry_data, face_name)
      
      # Generate SVG content
      svg_content = generate_svg(projected_data, entity.name, face_name)
      
      # Write to file
      File.write(output_path, svg_content)
      
      puts "SVG exported successfully: #{output_path}"
      output_path
    end
    
    # Extract geometry with edge information for accurate vector representation
    def self.extract_geometry_with_edges(entity)
      faces = []
      edges = []
      collect_geometry(entity, entity.transformation, faces, edges)
      { faces: faces, edges: edges }
    end
    
    private
    
    def self.collect_geometry(entity, transformation, faces, edges)
      entities = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
      current_transform = transformation
      
      entities.each do |e|
        if e.is_a?(Sketchup::Face)
          # Collect face vertices
          vertices = []
          e.outer_loop.vertices.each do |v|
            pt = v.position.transform(current_transform)
            vertices << {
              x: pt.x.to_mm,
              y: pt.y.to_mm,
              z: pt.z.to_mm
            }
          end
          
          faces << {
            vertices: vertices,
            normal: transform_vector(e.normal, current_transform),
            material: e.material ? (e.material.color.to_i & 0xFFFFFF) : 0x74b9ff
          }
          
          # Collect edges from this face
          e.outer_loop.edges.each do |edge|
            pt1 = edge.start.position.transform(current_transform)
            pt2 = edge.end.position.transform(current_transform)
            
            edges << {
              start: { x: pt1.x.to_mm, y: pt1.y.to_mm, z: pt1.z.to_mm },
              end: { x: pt2.x.to_mm, y: pt2.y.to_mm, z: pt2.z.to_mm },
              smooth: edge.smooth?
            }
          end
          
        elsif e.is_a?(Sketchup::Group)
          collect_geometry(e, current_transform * e.transformation, faces, edges)
        elsif e.is_a?(Sketchup::ComponentInstance)
          collect_geometry(e, current_transform * e.transformation, faces, edges)
        end
      end
    end
    
    def self.transform_vector(vector, transformation)
      # Transform a vector (direction) by a transformation matrix
      origin = Geom::Point3d.new(0, 0, 0)
      end_point = origin.offset(vector)
      transformed_end = end_point.transform(transformation)
      transformed_origin = origin.transform(transformation)
      transformed_end - transformed_origin
    end
    
    def self.project_to_2d(geometry_data, face_name)
      # Define projection planes for each view
      projections = {
        'Front' => { normal: [0, 1, 0], up: [0, 0, 1], right: [1, 0, 0] },
        'Back' => { normal: [0, -1, 0], up: [0, 0, 1], right: [-1, 0, 0] },
        'Left' => { normal: [-1, 0, 0], up: [0, 0, 1], right: [0, 1, 0] },
        'Right' => { normal: [1, 0, 0], up: [0, 0, 1], right: [0, -1, 0] },
        'Top' => { normal: [0, 0, 1], up: [0, 1, 0], right: [1, 0, 0] },
        'Bottom' => { normal: [0, 0, -1], up: [0, -1, 0], right: [1, 0, 0] }
      }
      
      projection = projections[face_name] || projections['Front']
      
      # Project all edges onto the 2D plane
      projected_edges = []
      geometry_data[:edges].each do |edge|
        pt1_2d = project_point(edge[:start], projection)
        pt2_2d = project_point(edge[:end], projection)
        
        projected_edges << {
          start: pt1_2d,
          end: pt2_2d,
          smooth: edge[:smooth]
        }
      end
      
      # Calculate bounds for scaling
      all_points = projected_edges.flat_map { |e| [e[:start], e[:end]] }
      min_x = all_points.map { |p| p[:x] }.min || 0
      max_x = all_points.map { |p| p[:x] }.max || 100
      min_y = all_points.map { |p| p[:y] }.min || 0
      max_y = all_points.map { |p| p[:y] }.max || 100
      
      {
        edges: projected_edges,
        bounds: {
          min_x: min_x,
          max_x: max_x,
          min_y: min_y,
          max_y: max_y,
          width: max_x - min_x,
          height: max_y - min_y
        }
      }
    end
    
    def self.project_point(point, projection)
      # Project a 3D point onto a 2D plane
      normal = projection[:normal]
      up = projection[:up]
      right = projection[:right]
      
      # Calculate 2D coordinates using dot product
      x = point[:x] * right[0] + point[:y] * right[1] + point[:z] * right[2]
      y = point[:x] * up[0] + point[:y] * up[1] + point[:z] * up[2]
      
      { x: x, y: y }
    end
    
    def self.generate_svg(projected_data, entity_name, face_name)
      bounds = projected_data[:bounds]
      edges = projected_data[:edges]
      
      # Add padding
      padding = 50
      width = bounds[:width] + (padding * 2)
      height = bounds[:height] + (padding * 2)
      
      # SVG header
      svg = <<~SVG
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" 
             xmlns:xlink="http://www.w3.org/1999/xlink"
             width="#{width.round(2)}mm" 
             height="#{height.round(2)}mm" 
             viewBox="0 0 #{width.round(2)} #{height.round(2)}"
             version="1.1">
          
          <!-- Generated by AutoNestCut SVG Vector Exporter -->
          <!-- Entity: #{entity_name} | Face: #{face_name} -->
          <!-- Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} -->
          
          <defs>
            <style type="text/css">
              .cut-line { stroke: #000000; stroke-width: 0.1mm; fill: none; }
              .smooth-line { stroke: #0066cc; stroke-width: 0.1mm; fill: none; stroke-dasharray: 2,2; }
              .dimension { stroke: #666666; stroke-width: 0.05mm; fill: none; }
            </style>
          </defs>
          
          <!-- Background -->
          <rect width="#{width.round(2)}" height="#{height.round(2)}" fill="#ffffff" stroke="#cccccc" stroke-width="0.1mm"/>
          
          <!-- Cutting Lines -->
          <g id="cutting-paths">
      SVG
      
      # Add edges as paths
      edges.each do |edge|
        x1 = edge[:start][:x] - bounds[:min_x] + padding
        y1 = edge[:start][:y] - bounds[:min_y] + padding
        x2 = edge[:end][:x] - bounds[:min_x] + padding
        y2 = edge[:end][:y] - bounds[:min_y] + padding
        
        line_class = edge[:smooth] ? 'smooth-line' : 'cut-line'
        svg += "    <line x1=\"#{x1.round(3)}\" y1=\"#{y1.round(3)}\" x2=\"#{x2.round(3)}\" y2=\"#{y2.round(3)}\" class=\"#{line_class}\"/>\n"
      end
      
      svg += <<~SVG
          </g>
          
          <!-- Dimensions -->
          <g id="dimensions" opacity="0.5">
            <text x="#{(padding + 5).round(2)}" y="#{(height - 10).round(2)}" font-size="3mm" fill="#666666">
              W: #{bounds[:width].round(1)}mm
            </text>
            <text x="#{(padding + 5).round(2)}" y="#{(height - 5).round(2)}" font-size="3mm" fill="#666666">
              H: #{bounds[:height].round(1)}mm
            </text>
          </g>
          
          <!-- Metadata -->
          <metadata>
            <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
              <rdf:Description rdf:about="">
                <dc:title xmlns:dc="http://purl.org/dc/elements/1.1/">#{entity_name} - #{face_name} View</dc:title>
                <dc:creator xmlns:dc="http://purl.org/dc/elements/1.1/">AutoNestCut</dc:creator>
                <dc:date xmlns:dc="http://purl.org/dc/elements/1.1/">#{Time.now.iso8601}</dc:date>
                <dc:description xmlns:dc="http://purl.org/dc/elements/1.1/">Vector export for CNC/Laser cutting</dc:description>
              </rdf:Description>
            </rdf:RDF>
          </metadata>
        </svg>
      SVG
      
      svg
    end
    
    def self.generate_default_svg_path(entity_name, face_name)
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      downloads_path = File.join(ENV['USERPROFILE'] || ENV['HOME'], 'Downloads')
      sanitized_name = entity_name.gsub(/[^\w\s-]/, '').gsub(/\s+/, '_')
      File.join(downloads_path, "#{sanitized_name}_#{face_name}_#{timestamp}.svg")
    end
  end
end
