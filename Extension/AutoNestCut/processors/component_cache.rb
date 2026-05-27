module AutoNestCut
  class ComponentCache
    
    @@cache = {}
    @@last_selection_hash = nil
    
    def self.get_selection_hash(selection)
      selection.map do |e|
        mat = e.respond_to?(:material) ? (e.material ? e.material.name : 'nil') : 'nil'
        defn_id = e.respond_to?(:definition) && e.definition ? e.definition.entityID : 'group'
        # Include a recursive material fingerprint for nested entities
        nested_mat = get_nested_material_fingerprint(e)
        "#{e.entityID}_#{defn_id}_#{mat}_#{nested_mat}"
      end.sort.join('|')
    end

    # Recursively collects a lightweight fingerprint of all materials in nested entities
    def self.get_nested_material_fingerprint(entity, depth = 0)
      return '' if depth > 5 # Limit recursion depth for performance
      
      entities = nil
      if entity.respond_to?(:definition) && entity.definition.respond_to?(:entities)
        entities = entity.definition.entities
      elsif entity.respond_to?(:entities)
        entities = entity.entities
      end
      return '' unless entities
      
      parts = []
      entities.each do |e|
        next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
        mat = e.respond_to?(:material) ? (e.material ? e.material.name : 'nil') : 'nil'
        parts << "#{e.entityID}:#{mat}"
        parts << get_nested_material_fingerprint(e, depth + 1) if depth < 5
      end
      parts.join(',')
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