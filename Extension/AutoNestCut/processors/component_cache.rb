module AutoNestCut
  class ComponentCache
    
    @@cache = {}
    @@last_selection_hash = nil
    
    def self.get_selection_hash(selection)
      selection.map do |e|
        defn_id = e.respond_to?(:definition) && e.definition ? e.definition.entityID : 'group'
        nested_mat = get_nested_material_fingerprint(e)
        "#{e.entityID}_#{defn_id}_#{nested_mat}"
      end.sort.join('|')
    end

    # Recursively collects a lightweight fingerprint of all materials in nested entities.
    # Tracks face materials on leaf components — matching exactly what the analyzer reads.
    def self.get_nested_material_fingerprint(entity, depth = 0)
      return '' if depth > 5

      entities = nil
      if entity.respond_to?(:definition) && entity.definition.respond_to?(:entities)
        entities = entity.definition.entities
      elsif entity.respond_to?(:entities)
        entities = entity.entities
      end
      return '' unless entities

      parts = []
      entities.each do |e|
        if e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
          # Capture face material fingerprint for this child
          child_entities = e.is_a?(Sketchup::ComponentInstance) && e.definition ?
                             e.definition.entities : (e.respond_to?(:entities) ? e.entities : [])
          face_mats = child_entities.select { |f| f.is_a?(Sketchup::Face) && (f.material || f.back_material) }
                                    .map { |f| (f.material || f.back_material).name }
                                    .sort.join(',')
          parts << "#{e.entityID}:#{face_mats}"
          parts << get_nested_material_fingerprint(e, depth + 1)
        end
      end
      parts.join('|')
    end
    
    def self.get_cached_analysis(selection)
      hash = get_selection_hash(selection)
      return nil if hash != @@last_selection_hash
      @@cache[hash]
    end
    
    def self.cache_analysis(selection, parts_by_material, original_components, hierarchy_tree)
      hash = get_selection_hash(selection)
      @@last_selection_hash = hash
      @@cache[hash] = {
        parts_by_material: parts_by_material,
        original_components: original_components,
        hierarchy_tree: hierarchy_tree,
        timestamp: Time.now
      }
      
      # Keep only last 3 analyses
      if @@cache.size > 3
        oldest = @@cache.keys.first
        @@cache.delete(oldest)
      end
    end
    
    def self.clear_cache
      @@cache.clear
      @@last_selection_hash = nil
    end
  end
end