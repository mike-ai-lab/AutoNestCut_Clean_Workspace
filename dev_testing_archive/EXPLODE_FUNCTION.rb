require 'sketchup.rb'

require 'json'



module ExplodeExporter



  # Main method to call on a selected Component

  def self.generate_3d_data(parent_entity)

    parts_data = []

    parent_center = parent_entity.bounds.center

    

    # 1. Identify Sub-Parts (Groups/Components)

    # If the user selects a component, we look inside its definition.

    entities = parent_entity.is_a?(Sketchup::ComponentInstance) ? parent_entity.definition.entities : parent_entity.entities

    sub_parts = entities.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }

    

    # 2. Process each part

    sub_parts.each do |part|

      

      # --- A. Smart Axis Logic (The Explode Calculation) ---

      # Calculates which direction this specific part should move

      center = part.bounds.center

      raw_vector = center - parent_center

      

      # Handle parts exactly at center

      raw_vector = Geom::Vector3d.new(0,0,1) if raw_vector.length == 0

      

      # Find dominant axis (X, Y, or Z) to create a clean "technical" explosion

      abs_x, abs_y, abs_z = raw_vector.x.abs, raw_vector.y.abs, raw_vector.z.abs

      axis_vector = Geom::Vector3d.new(0,0,0)

      

      if abs_x >= abs_y && abs_x >= abs_z

        axis_vector.x = raw_vector.x # Keep direction (+/-)

      elsif abs_y >= abs_x && abs_y >= abs_z

        axis_vector.y = raw_vector.y

      else

        axis_vector.z = raw_vector.z

      end

      axis_vector.normalize!



      # --- B. Geometry & Style Extraction ---

      # Extracts Mesh (Shape), Normals (Shading), UVs (Textures)

      mesh_data = get_geometry_data(part)

      

      parts_data << {

        name: part.name.empty? ? "Part" : part.name,

        # Vector: The direction this part will move when slider is dragged

        explode_vector: [axis_vector.x, axis_vector.z, -axis_vector.y], # Swap Y/Z for WebGL

        vertices: mesh_data[:vertices],

        normals: mesh_data[:normals],

        uvs: mesh_data[:uvs],      # Needed for Texture Style

        colors: mesh_data[:colors], # Needed for Shaded Style

        texture: mesh_data[:texture_name] # Reference to texture file if exists

      }

    end

    

    # Return JSON string ready for the web viewer

    return parts_data.to_json

  end



  # Helper: Extracts geometry from a part

  def self.get_geometry_data(entity)

    vertices = []

    normals = []

    uvs = []

    colors = []

    texture_name = nil

    

    # Get the definition entities if it's a component/group

    entities = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities

    transformation = entity.transformation

    

    entities.each do |e|

      if e.is_a?(Sketchup::Face)

        # Flag 7 = Points (1) + Normals (2) + UVs (4)

        mesh = e.mesh(7) 

        

        # --- Style: Shaded (Color) ---

        mat = e.material

        if mat

          col = mat.color

          # Convert SketchUp Color to Hex Integer

          hex_color = (col.red << 16) | (col.green << 8) | col.blue

          

          # --- Style: Texture ---

          if mat.texture

            texture_name = mat.texture.filename # Dev needs to handle the actual file export separately

          end

        else

          hex_color = 0xcccccc # Default Grey

        end



        polys = mesh.polygons

        points = mesh.points

        

        # Triangulate and extract

        polys.each do |poly|

          (0..poly.length-3).each do |i|

            [0, i+1, i+2].each do |idx|

              # SketchUp Mesh indices are 1-based

              index = poly[idx].abs

              

              # 1. Vertex Position

              pt = points[index - 1].transform(transformation)

              vertices.concat([pt.x.to_f, pt.z.to_f, -pt.y.to_f]) # Swap Y/Z for WebGL

              

              # 2. Normal (for smooth shading)

              # .normal_at is the safe method for all SU versions

              norm = mesh.normal_at(index).transform(transformation).normalize

              normals.concat([norm.x.to_f, norm.z.to_f, -norm.y.to_f])

              

              # 3. UV Coordinates (for Texture mapping)

              # These are essential for the "Texture" style

              uv = mesh.uv_at(index, true) # true = front face

              uvs.concat([uv.x.to_f, uv.y.to_f])

              

              colors << hex_color

            end

          end

        end

      elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)

        # Recursive extraction for nested parts (simplified)

        sub_data = get_geometry_data(e)

        vertices.concat(sub_data[:vertices])

        normals.concat(sub_data[:normals])

        uvs.concat(sub_data[:uvs])

        colors.concat(sub_data[:colors])

      end

    end

    

    { vertices: vertices, normals: normals, uvs: uvs, colors: colors, texture_name: texture_name }

  end

end