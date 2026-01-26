require 'base64'
require 'json'
require_relative '../config'
require_relative '../util'

module AutoNestCut
  class AssemblyExporter
    
    def self.safe_set(options, key, value)
      return unless options
      begin
        if options.keys.include?(key)
          options[key] = value
        end
      rescue => e
        puts "AssemblyExporter Warning: Could not set '#{key}'. #{e.message}"
      end
    end
    

    def self.capture_assembly_views(entity, style = "0", selected_views = {}, include_svg = false)
      return nil unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
      
      model = Sketchup.active_model
      view = model.active_view
      camera = view.camera
      rendering_options = model.rendering_options
      
      # Store original settings
      original_eye = camera.eye
      original_target = camera.target
      original_up = camera.up
      original_render_mode = rendering_options['RenderMode']
      original_texture = rendering_options['Texture']
      original_inactive_hidden = rendering_options['InactiveHidden']
      original_instance_hidden = rendering_options['InstanceHidden']
      
      # Get bounds in GLOBAL coordinates first
      global_bounds = entity.bounds
      global_center = global_bounds.center
      
      # Open entity
      entity.locked = false
      model.active_path = [entity]
      
      # HIDE EVERYTHING ELSE & SET WHITE BACKGROUND
      safe_set(rendering_options, 'InactiveHidden', true)
      safe_set(rendering_options, 'InstanceHidden', true)
      safe_set(rendering_options, 'DrawGround', false)
      safe_set(rendering_options, 'DrawHorizon', false)
      safe_set(rendering_options, 'DrawSky', false)
      safe_set(rendering_options, 'BackgroundColor', 0xFFFFFF)
      view.invalidate
      
      # Get bounds in local context
      bounds = Geom::BoundingBox.new
      model.active_entities.each { |e| bounds.add(e.bounds) }
      center = global_center
      
      views = {}
      svg_views = {} if include_svg
      
      directions = {
        'Front' => [Geom::Vector3d.new(0, -1, 0), Geom::Vector3d.new(0, 0, 1)],
        'Back' => [Geom::Vector3d.new(0, 1, 0), Geom::Vector3d.new(0, 0, 1)],
        'Left' => [Geom::Vector3d.new(-1, 0, 0), Geom::Vector3d.new(0, 0, 1)],
        'Right' => [Geom::Vector3d.new(1, 0, 0), Geom::Vector3d.new(0, 0, 1)],
        'Top' => [Geom::Vector3d.new(0, 0, 1), Geom::Vector3d.new(0, 1, 0)],
        'Bottom' => [Geom::Vector3d.new(0, 0, -1), Geom::Vector3d.new(0, -1, 0)]
      }
      
      directions.each do |name, (direction, up)|
        # Skip if view not selected
        next unless selected_views[name]
        
        size = [global_bounds.width, global_bounds.height, global_bounds.depth].max
        eye = center.offset(direction, size * 3.5)
        
        camera.set(eye, center, up)
        camera.perspective = false
        
        # Calculate proper height based on global bounds
        if name == 'Top' || name == 'Bottom'
          camera.height = [global_bounds.width, global_bounds.height].max * 1.3
        elsif name == 'Left' || name == 'Right'
          camera.height = [global_bounds.height, global_bounds.depth].max * 1.3
        else # Front/Back
          camera.height = [global_bounds.width, global_bounds.depth].max * 1.3
        end
        
        case style.to_i
        when 0 # Hidden Line
          safe_set(rendering_options, 'RenderMode', 1)
          safe_set(rendering_options, 'Texture', false)
        when 1 # Shaded
          safe_set(rendering_options, 'RenderMode', 2)
          safe_set(rendering_options, 'Texture', false)
        when 2 # Shaded with Textures
          safe_set(rendering_options, 'RenderMode', 2)
          safe_set(rendering_options, 'Texture', true)
        when 3 # Wireframe
          safe_set(rendering_options, 'RenderMode', 0)
        end
        
        view.invalidate
        sleep(0.2)
        
        temp_file = File.join(Dir.tmpdir, "assembly_view_#{name}_#{Time.now.to_i}.jpg")
        # Export at 1024x768 resolution with quality 0.75 for optimized file size
        # JPEG compression reduces file size from 14-15MB to ~300-400KB while maintaining visual quality
        # The 4th parameter (false) disables transparency, 5th parameter (0.75) sets JPEG quality to 75%
        # This achieves target of < 500 KB per image while preserving assembly view clarity
        view.write_image(temp_file, 1024, 768, false, 0.75)
        
        # Further optimize the JPEG if needed
        optimized_file = Util.optimize_image_to_jpeg(temp_file, 0.75, 500)
        views[name] = optimized_file
      end
      
      # Validate captured images
      views.each do |name, path|
        if File.exist?(path)
          validation = Util.validate_image_compression(path, 500)
          entity_display_name = entity.is_a?(Sketchup::ComponentInstance) ? entity.definition.name : entity.name
          Util.log_compression_result("Assembly_#{entity_display_name}_#{name}", validation)
          
          if !validation[:valid]
            puts "WARNING: Assembly image #{name} exceeds size limit: #{validation[:file_size_kb]}KB"
          end
        end
      end
      
      # Restore
      model.active_path = nil
      camera.set(original_eye, original_target, original_up)
      safe_set(rendering_options, 'RenderMode', original_render_mode)
      safe_set(rendering_options, 'Texture', original_texture)
      safe_set(rendering_options, 'InactiveHidden', original_inactive_hidden)
      safe_set(rendering_options, 'InstanceHidden', original_instance_hidden)
      safe_set(rendering_options, 'DrawGround', true)
      safe_set(rendering_options, 'DrawHorizon', true)
      safe_set(rendering_options, 'DrawSky', true)
      view.invalidate
      
      views
    end
    
    def self.extract_geometry_data(entity)
      faces = []
      collect_faces(entity, entity.transformation, faces)
      { faces: faces }
    end
    
    def self.collect_faces(entity, transformation, faces)
      entities = entity.is_a?(Sketchup::Group) ? entity.entities : entity.definition.entities
      current_transform = transformation
      
      entities.each do |e|
        if e.is_a?(Sketchup::Face)
          vertices = []
          e.outer_loop.vertices.each do |v|
            pt = v.position.transform(current_transform)
            vertices << {
              x: pt.x.to_mm / 100.0,
              y: pt.y.to_mm / 100.0,
              z: pt.z.to_mm / 100.0
            }
          end
          
          color = e.material ? (e.material.color.to_i & 0xFFFFFF) : 0x74b9ff
          faces << { vertices: vertices, color: color }
          
        elsif e.is_a?(Sketchup::Group)
          collect_faces(e, current_transform * e.transformation, faces)
        elsif e.is_a?(Sketchup::ComponentInstance)
          collect_faces(e, current_transform * e.transformation, faces)
        end
      end
    end
    
    def self.generate_assembly_html_section(views, geometry_data, entity_name)
      views_html = views.map do |name, path|
        next unless File.exist?(path)
        begin
          base64 = Base64.strict_encode64(File.binread(path))
          # Use JPEG MIME type for optimized assembly view images
          img_src = "data:image/jpeg;base64,#{base64}"
          "<div class='assembly-view-item' onclick='openAssemblyView(\"#{img_src}\")'>
            <h4>#{name}</h4>
            <img src='#{img_src}' />
          </div>"
        rescue => e
          puts "AssemblyExporter: Could not encode image #{name}: #{e.message}"
          nil
        end
      end.compact.join("\n")
      
      geometry_json = geometry_data.to_json rescue '{}'
      
      <<-HTML
      <div class="assembly-section" style="margin-top: 40px; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
        <h2 style="color: #00A5E3; border-bottom: 3px solid #00A5E3; padding-bottom: 10px;">Assembly: #{entity_name}</h2>
        
        <h3 style="color: #555; margin-top: 20px;">Standard Views</h3>
        <div class="assembly-views-grid" style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 20px; margin-bottom: 30px;">
          #{views_html}
        </div>
        
        <h3 style="color: #555; margin-top: 30px;">3D Interactive Model</h3>
        <div id="assemblyViewer" style="width: 100%; height: 500px; border: 1px solid #ddd; background: #ffffff; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);"></div>
      </div>
      
      <div id="assemblyModal" class="assembly-modal" onclick="this.style.display='none'">
        <img id="modalImg" style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); max-width: 90%; max-height: 90%;">
      </div>
      
      <style>
        .assembly-view-item { background: #f9f9f9; padding: 12px; border-radius: 6px; border: 1px solid #ddd; cursor: pointer; transition: transform 0.2s; }
        .assembly-view-item:hover { transform: scale(1.02); box-shadow: 0 4px 12px rgba(0,0,0,0.15); }
        .assembly-view-item h4 { margin: 0 0 8px 0; color: #555; text-align: center; font-size: 13px; }
        .assembly-view-item img { width: 100%; height: auto; border: 1px solid #ddd; border-radius: 4px; }
        .assembly-modal { display: none; position: fixed; z-index: 9999; left: 0; top: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.9); cursor: pointer; }
      </style>
      
      <script>
        function openAssemblyView(src) {
          document.getElementById('modalImg').src = src;
          document.getElementById('assemblyModal').style.display = 'block';
        }
        
        const assemblyGeometryData = #{geometry_json};
        
        function initAssemblyViewer() {
          const container = document.getElementById('assemblyViewer');
          if (!container || !window.THREE) {
            console.warn('Assembly viewer container or THREE.js not available');
            return;
          }
          
          try {
            const scene = new THREE.Scene();
            scene.background = new THREE.Color(0xf0f0f0);
            scene.fog = new THREE.Fog(0xf0f0f0, 1000, 5000);
            
            const camera = new THREE.PerspectiveCamera(75, container.clientWidth / container.clientHeight, 0.1, 10000);
            
            const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
            renderer.setSize(container.clientWidth, container.clientHeight);
            renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
            renderer.shadowMap.enabled = true;
            renderer.shadowMap.type = THREE.PCFSoftShadowMap;
            container.appendChild(renderer.domElement);
            
            const controls = new THREE.OrbitControls(camera, renderer.domElement);
            controls.enableDamping = true;
            controls.dampingFactor = 0.1;
            controls.rotateSpeed = 1.0;
            controls.zoomSpeed = 1.5;
            controls.panSpeed = 1.0;
            
            const ambientLight = new THREE.AmbientLight(0xffffff, 1.2);
            scene.add(ambientLight);
            
            const keyLight = new THREE.DirectionalLight(0xffffff, 1.0);
            keyLight.position.set(5, 10, 7);
            keyLight.castShadow = true;
            scene.add(keyLight);
            
            const fillLight = new THREE.DirectionalLight(0xffffff, 0.6);
            fillLight.position.set(-5, 5, -5);
            scene.add(fillLight);
            
            const backLight = new THREE.DirectionalLight(0xffffff, 0.4);
            backLight.position.set(0, 5, -10);
            scene.add(backLight);
            
            const group = new THREE.Group();
            const mergedGeometry = new THREE.BufferGeometry();
            const positions = [];
            
            if (assemblyGeometryData && assemblyGeometryData.faces) {
              assemblyGeometryData.faces.forEach(face => {
                const vertices = face.vertices;
                if (vertices.length < 3) return;
                
                for (let i = 1; i < vertices.length - 1; i++) {
                  positions.push(vertices[0].x, vertices[0].z, -vertices[0].y);
                  positions.push(vertices[i].x, vertices[i].z, -vertices[i].y);
                  positions.push(vertices[i + 1].x, vertices[i + 1].z, -vertices[i + 1].y);
                }
              });
            }
            
            if (positions.length > 0) {
              mergedGeometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
              mergedGeometry.computeVertexNormals();
              
              const material = new THREE.MeshStandardMaterial({ 
                color: 0xcccccc,
                metalness: 0.1,
                roughness: 0.6,
                side: THREE.DoubleSide
              });
              const mesh = new THREE.Mesh(mergedGeometry, material);
              mesh.castShadow = true;
              mesh.receiveShadow = true;
              
              const edges = new THREE.EdgesGeometry(mergedGeometry, 15);
              const edgeMaterial = new THREE.LineBasicMaterial({ color: 0x666666 });
              const wireframe = new THREE.LineSegments(edges, edgeMaterial);
              
              group.add(mesh);
              group.add(wireframe);
            }
            
            scene.add(group);
            
            const box = new THREE.Box3().setFromObject(group);
            const center = box.getCenter(new THREE.Vector3());
            const size = box.getSize(new THREE.Vector3());
            const maxDim = Math.max(size.x, size.y, size.z);
            
            group.position.sub(center);
            
            const planeGeometry = new THREE.PlaneGeometry(maxDim * 5, maxDim * 5);
            const planeMaterial = new THREE.ShadowMaterial({ opacity: 0.1 });
            const plane = new THREE.Mesh(planeGeometry, planeMaterial);
            plane.rotation.x = -Math.PI / 2;
            plane.position.y = -size.y / 2;
            plane.receiveShadow = true;
            scene.add(plane);
            
            const distance = maxDim * 2.5;
            camera.position.set(distance * 0.7, distance * 0.5, distance * 0.7);
            camera.lookAt(0, 0, 0);
            controls.target.set(0, 0, 0);
            controls.update();
            
            function animate() {
              requestAnimationFrame(animate);
              controls.update();
              renderer.render(scene, camera);
            }
            animate();
            
          } catch (error) {
            console.error('Error initializing assembly viewer:', error);
          }
        }
        
        if (document.readyState === 'loading') {
          document.addEventListener('DOMContentLoaded', initAssemblyViewer);
        } else {
          setTimeout(initAssemblyViewer, 500);
        }
      </script>
      HTML
    end
    
  end
end
