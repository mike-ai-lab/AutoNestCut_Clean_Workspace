module AutoNestCut
  class ComponentCache
    
    @@cache = {}
    @@last_selection_hash = nil
    
    def self.get_selection_hash(selection)
      selection.map { |e| "#{e.entityID}_#{e.definition ? e.definition.entityID : 'group'}" }.sort.join('|')
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