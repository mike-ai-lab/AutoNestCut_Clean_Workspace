# frozen_string_literal: true
# MaterialChecker: Scans the selected assembly and reports exactly what face
# materials AutoNestCut will read for each leaf part. No fallbacks, no guessing.
# Face material on the deepest component = what the report will use. Period.

module AutoNestCut
  class MaterialChecker

    # Scans the selection and returns a structured result:
    # {
    #   parts: [
    #     {
    #       name:          String,
    #       thickness:     Float (mm),
    #       dimensions:    String "WxHxT mm",
    #       face_material: String or nil,
    #       status:        :ok | :no_material,
    #       depth_path:    String  (e.g. "Cabinet > Body > Side_L")
    #     }, ...
    #   ],
    #   summary: {
    #     total:       Integer,
    #     ok:          Integer,
    #     no_material: Integer
    #   }
    # }
    def self.scan(selection)
      parts = []
      selection.each do |entity|
        collect_leaf_parts(entity, [], parts)
      end

      ok_count          = parts.count { |p| p[:status] == :ok }
      no_material_count = parts.count { |p| p[:status] == :no_material }

      {
        parts: parts,
        summary: {
          total:       parts.length,
          ok:          ok_count,
          no_material: no_material_count
        }
      }
    end

    private

    def self.collect_leaf_parts(entity, path, results)
      return unless entity.is_a?(Sketchup::ComponentInstance) ||
                    entity.is_a?(Sketchup::Group)

      # Determine the display name and child entities
      if entity.is_a?(Sketchup::ComponentInstance)
        name     = entity.definition.name
        children = entity.definition.entities
      else
        name     = entity.name.to_s.empty? ? "Group_#{entity.entityID}" : entity.name
        children = entity.entities
      end

      current_path = path + [name]

      # Find nested components/groups
      nested = children.select do |e|
        e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      end

      if nested.empty?
        # This is a leaf — check if it qualifies as a sheet good
        bounds = entity.is_a?(Sketchup::ComponentInstance) ?
                   entity.definition.bounds : entity.bounds

        return unless Util.is_sheet_good?(bounds)

        # Read ONLY face materials — this is the single source of truth
        face_material = dominant_face_material(children)

        dims_mm = Util.get_dimensions(bounds).sort
        thickness = dims_mm[0].round(1)
        width     = dims_mm[1].round(1)
        height    = dims_mm[2].round(1)

        results << {
          name:          name,
          thickness:     thickness,
          dimensions:    "#{width} x #{height} x #{thickness}",
          face_material: face_material,
          status:        face_material ? :ok : :no_material,
          depth_path:    current_path.join(' > ')
        }
      else
        # Not a leaf — recurse into children
        nested.each { |child| collect_leaf_parts(child, current_path, results) }
      end
    end

    # Returns the name of the most-used face material, or nil if none found.
    def self.dominant_face_material(entities)
      counts = Hash.new(0)
      entities.each do |e|
        next unless e.is_a?(Sketchup::Face)
        mat = e.material || e.back_material
        counts[mat.display_name || mat.name] += 1 if mat
      end
      counts.empty? ? nil : counts.max_by { |_, c| c }.first
    end
  end
end
