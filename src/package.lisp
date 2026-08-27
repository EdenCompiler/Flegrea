(defpackage #:flegrea
  (:use #:cl)
  (:shadow #:position #:shadow #:intersection)
  (:export
   ;; Condições e recursos
   #:flegrea-error #:validation-error #:renderer-error #:shader-error
   #:asset-error #:gltf-error #:disposed-resource-error #:metagraph-error
   #:error-operation #:error-path #:error-stage #:error-node #:error-extension #:error-cause
   #:resource #:resource-id #:resource-name #:disposed-p #:dispose
   ;; Matemática
   #:vector2 #:vector3 #:vector4 #:matrix3 #:matrix4 #:quaternion #:euler
   #:make-vector2 #:make-vector3 #:make-vector4 #:make-matrix3 #:make-matrix4
   #:make-quaternion #:make-euler #:x #:y #:z #:w #:elements #:order
   #:set-vector2 #:set-vector3 #:set-vector4 #:set-quaternion #:set-euler
   #:clone #:copy-from #:equals #:add #:subtract #:multiply-scalar
   #:divide-scalar #:dot #:cross #:normalize #:vector-length #:length-squared
   #:apply-matrix3 #:apply-matrix4 #:apply-quaternion
   #:matrix-multiply #:matrix-premultiply #:matrix-transpose
   #:matrix-determinant #:matrix-invert #:set-identity
   #:set-translation-matrix4 #:set-scale-matrix4 #:set-rotation-x-matrix4
   #:set-rotation-y-matrix4 #:set-rotation-z-matrix4
   #:set-from-euler #:set-from-quaternion #:quaternion-multiply #:slerp
   #:compose-matrix4 #:decompose-matrix4 #:set-normal-matrix3
   #:set-perspective-matrix4 #:set-orthographic-matrix4 #:look-at-matrix4
   #:color #:make-color #:color-r #:color-g #:color-b #:color-space
   #:set-color #:set-color-hex #:color-hex #:convert-color #:srgb-to-linear #:linear-to-srgb
   #:box3 #:sphere #:ray #:plane #:triangle #:frustum
   #:make-box3 #:make-sphere #:make-ray #:make-plane #:make-triangle #:make-frustum
   #:min-point #:max-point #:center #:radius #:origin #:direction #:normal #:constant
   #:point-a #:point-b #:point-c #:planes #:empty-p #:expand-by-point #:contains-point-p
   #:intersects-box-p #:intersects-sphere-p #:distance-to-point #:ray-at
   #:intersect-ray-plane #:intersect-ray-triangle #:set-from-projection-matrix
   ;; Núcleo
   #:object-3d #:scene #:group #:mesh #:camera #:perspective-camera
   #:orthographic-camera #:make-object-3d #:make-scene #:make-group #:make-mesh
   #:make-perspective-camera #:make-orthographic-camera
   #:position #:rotation #:quaternion #:scale #:parent #:children #:matrix #:matrix-world
   #:visible #:name #:geometry #:material #:projection-matrix #:view-matrix
   #:fov #:aspect #:near #:far #:left #:right #:top #:bottom #:zoom
   #:layers #:render-order #:frustum-culled #:cast-shadow #:receive-shadow #:user-data
   #:bounding-box #:bounding-sphere #:enable-layer #:disable-layer #:toggle-layer
   #:layer-enabled-p #:layers-match-p #:set-object-quaternion
   #:add-child #:remove-child #:traverse #:set-position #:set-rotation
   #:set-scale #:look-at #:update-matrix #:update-matrix-world #:update-projection-matrix
   #:before-update #:update #:after-update #:before-render #:after-render
   ;; Geometrias
   #:buffer-attribute #:buffer-geometry #:box-geometry #:sphere-geometry
   #:plane-geometry #:make-buffer-attribute #:make-buffer-geometry
   #:make-box-geometry #:make-sphere-geometry #:make-plane-geometry
   #:attribute-array #:item-size #:normalized #:usage #:needs-update
   #:attributes #:index #:set-attribute #:get-attribute #:delete-attribute
   #:set-index #:compute-vertex-normals #:geometry-groups #:draw-range #:primitive-mode
   #:add-group #:clear-groups #:set-draw-range #:compute-bounding-box #:compute-bounding-sphere
   #:circle-geometry #:ring-geometry #:cylinder-geometry #:cone-geometry #:torus-geometry
   #:capsule-geometry #:edges-geometry #:wireframe-geometry
   #:make-circle-geometry #:make-ring-geometry #:make-cylinder-geometry #:make-cone-geometry
   #:make-torus-geometry #:make-capsule-geometry #:make-edges-geometry #:make-wireframe-geometry
   ;; Materiais e texturas
   #:material-base #:mesh-basic-material #:mesh-standard-material #:mesh-physical-material
   #:mesh-normal-material #:mesh-depth-material #:line-material #:points-material
   #:sprite-material #:shader-material
   #:make-mesh-basic-material #:make-mesh-standard-material #:make-mesh-physical-material
   #:make-mesh-normal-material #:make-mesh-depth-material #:make-line-material
   #:make-points-material #:make-sprite-material #:make-shader-material
   #:color #:vertex-colors #:roughness #:metalness #:emissive
   #:emissive-intensity #:normal-scale #:occlusion-strength
   #:vertex-shader #:fragment-shader #:uniforms #:uniform #:set-uniform
   #:side #:depth-write #:depth-test #:transparent #:opacity #:alpha-mode #:alpha-test
   #:blending #:base-color-map #:normal-map #:metallic-roughness-map #:emissive-map
   #:occlusion-map #:opacity-map #:clearcoat-map #:clearcoat-normal-map
   #:clearcoat-roughness-map #:transmission-map #:thickness-map
   #:clearcoat #:clearcoat-roughness #:transmission #:thickness #:ior
   #:attenuation-color #:attenuation-distance #:line-width #:point-size #:size-attenuation
   #:texture #:data-texture #:make-texture #:make-data-texture #:load-texture #:load-texture-async
   #:image-width #:image-height #:image-data #:texture-color-space #:generate-mipmaps
   #:min-filter #:mag-filter #:wrap-s #:wrap-t #:repeat #:offset #:texture-rotation
   #:texture-center #:anisotropy #:flip-y #:uv-channel
   ;; Luzes e objetos desenháveis
   #:light #:ambient-light #:directional-light #:point-light #:spot-light #:hemisphere-light
   #:make-ambient-light #:make-directional-light #:make-point-light
   #:make-spot-light #:make-hemisphere-light
   #:intensity #:target #:distance #:decay #:angle #:penumbra #:ground-color
   #:shadow #:light-shadow #:shadow-map-size #:shadow-bias #:shadow-normal-bias #:shadow-camera
   #:line #:line-segments #:points #:sprite #:instanced-mesh
   #:make-line #:make-line-segments #:make-points #:make-sprite #:make-instanced-mesh
   #:instance-count #:instance-matrices #:instance-colors #:set-instance-matrix #:set-instance-color
   ;; Metagrafo
   #:meta-node #:meta-scene #:scene-instance #:binding
   #:node-id #:node-type #:node-properties #:node-property #:node-children
   #:instance-scene #:instance-camera #:define-scene #:bind #:ref
   #:scene-description #:parse-scene #:instantiate-scene #:commit-scene
   #:update-scene #:find-node #:find-object #:walk-scene #:transform-scene
   #:read-scene #:write-scene #:register-node-class
   #:validate-node #:instantiate-node #:update-node #:dispose-node
   #:scene-parameter #:parameter-name #:parameter-type #:parameter-default #:parameter-validator
   #:scene-state #:register-binding-function #:register-track-target
   #:start-hot-reload #:stop-hot-reload #:hot-reload-event #:event-kind #:event-detail
   ;; Renderização
   #:renderer #:make-renderer #:render #:render-scene #:animate #:animate-scene
   #:animation-loop #:stop-animation #:renderer-should-close-p
   #:add-animation-mixer #:remove-animation-mixer #:add-controls #:remove-controls
   #:renderer-width #:renderer-height #:renderer-title #:renderer-input #:key-down-p #:request-close
   #:renderer-quality #:renderer-stats #:renderer-antialias #:output-color-space
   #:exposure #:tone-mapping #:pixel-ratio #:set-quality #:render-list #:render-item
   #:opaque-items #:transparent-items #:build-render-list
   #:draw-calls #:triangles-rendered #:objects-rendered #:objects-culled
   ;; Assets e glTF
   #:loading-manager #:load-job #:make-loading-manager #:default-loading-manager
   #:job-status #:job-stage #:job-progress #:job-result #:job-error
   #:cancel-job #:add-job-listener #:drain-loading-manager #:evict-asset #:clear-asset-cache
   #:register-uri-resolver #:scene-asset #:load-gltf #:load-gltf-async #:instantiate-asset
   #:asset-scenes #:asset-cameras #:asset-variants #:asset-metagraph #:asset-metadata
   ;; Animação
   #:animation-clip #:keyframe-track #:animation-mixer #:animation-action
   #:make-animation-clip #:make-keyframe-track #:make-animation-mixer #:clip-action
   #:play #:pause #:stop #:seek #:cross-fade #:mixer-update
   #:track-times #:track-values #:track-target #:duration #:loop-mode #:time-scale
   #:weight #:clamp-when-finished #:action-time
   ;; Entrada, picking e controles
   #:input-state #:make-input-state #:poll-input #:key-pressed-p #:key-released-p
   #:mouse-down-p #:mouse-pressed-p #:mouse-released-p #:cursor-position #:cursor-delta
   #:wheel-delta #:modifiers #:add-input-listener #:remove-input-listener
   #:raycaster #:intersection #:make-raycaster #:set-ray-from-camera #:intersect-object
   #:intersection-distance #:intersection-point #:intersection-normal #:intersection-uv
   #:intersection-object #:intersection-face #:intersection-instance
   #:orbit-controls #:make-orbit-controls #:controls-update #:controls-enabled
   #:controls-target #:enable-damping #:damping-factor #:min-distance #:max-distance
   #:min-polar-angle #:max-polar-angle
   ;; Pós-processamento
   #:render-target #:make-render-target #:target-width #:target-height #:target-color-texture
   #:target-depth-texture #:resize-render-target #:read-render-target-pixels
   #:effect-composer #:render-pass #:shader-pass #:make-effect-composer
   #:make-render-pass #:make-shader-pass #:add-pass #:remove-pass #:composer-render
   #:pass-enabled #:pass-needs-swap #:make-fxaa-pass))

(defpackage #:flegrea.math
  (:use #:cl)
  (:import-from #:flegrea
                #:flegrea-error #:validation-error
                #:vector2 #:vector3 #:vector4 #:matrix3 #:matrix4 #:quaternion #:euler
                #:make-vector2 #:make-vector3 #:make-vector4 #:make-matrix3 #:make-matrix4
                #:make-quaternion #:make-euler #:x #:y #:z #:w #:elements #:order
                #:set-vector2 #:set-vector3 #:set-vector4 #:set-quaternion #:set-euler
                #:clone #:copy-from #:equals #:add #:subtract #:multiply-scalar
                #:divide-scalar #:dot #:cross #:normalize #:vector-length #:length-squared
                #:apply-matrix3 #:apply-matrix4 #:apply-quaternion
                #:matrix-multiply #:matrix-premultiply #:matrix-transpose
                #:matrix-determinant #:matrix-invert #:set-identity
                #:set-translation-matrix4 #:set-scale-matrix4
                #:set-rotation-x-matrix4 #:set-rotation-y-matrix4 #:set-rotation-z-matrix4
                #:set-from-euler #:set-from-quaternion #:quaternion-multiply #:slerp
                #:compose-matrix4 #:decompose-matrix4 #:set-normal-matrix3
                #:set-perspective-matrix4 #:set-orthographic-matrix4 #:look-at-matrix4))

(defpackage #:flegrea.core
  (:use #:cl)
  (:shadowing-import-from #:flegrea #:position)
  (:import-from #:flegrea
                #:validation-error #:vector3 #:matrix4 #:quaternion #:euler
                #:make-vector3 #:make-matrix4 #:make-quaternion #:make-euler
                #:x #:y #:z #:order #:set-vector3 #:set-euler #:set-from-euler
                #:compose-matrix4 #:matrix-multiply #:matrix-invert #:copy-from
                #:look-at-matrix4 #:set-perspective-matrix4 #:set-orthographic-matrix4
                #:object-3d #:scene #:group #:mesh #:camera #:perspective-camera
                #:orthographic-camera #:make-object-3d #:make-scene #:make-group #:make-mesh
                #:make-perspective-camera #:make-orthographic-camera
                #:rotation #:scale #:parent #:children #:matrix #:matrix-world
                #:visible #:name #:geometry #:material #:projection-matrix #:view-matrix
                #:fov #:aspect #:near #:far #:left #:right #:top #:bottom #:zoom
                #:add-child #:remove-child #:traverse #:set-position #:set-rotation
                #:set-scale #:look-at #:update-matrix #:update-matrix-world
                #:update-projection-matrix))

(defpackage #:flegrea.geometry
  (:use #:cl)
  (:import-from #:flegrea
                #:validation-error #:vector3 #:make-vector3 #:x #:y #:z #:normalize
                #:buffer-attribute #:buffer-geometry #:box-geometry #:sphere-geometry
                #:plane-geometry #:make-buffer-attribute #:make-buffer-geometry
                #:make-box-geometry #:make-sphere-geometry #:make-plane-geometry
                #:attribute-array #:item-size #:normalized #:usage #:needs-update
                #:attributes #:index #:set-attribute #:get-attribute #:delete-attribute
                #:set-index #:compute-vertex-normals))

(defpackage #:flegrea.materials
  (:use #:cl)
  (:import-from #:flegrea
                #:validation-error #:vector3 #:make-vector3 #:clone
                #:material-base #:mesh-basic-material #:mesh-standard-material #:shader-material
                #:make-mesh-basic-material #:make-mesh-standard-material #:make-shader-material
                #:color #:vertex-colors #:roughness #:metalness #:emissive
                #:vertex-shader #:fragment-shader #:uniforms #:uniform #:set-uniform
                #:side #:depth-write
                #:object-3d #:light #:ambient-light #:directional-light #:point-light
                #:make-ambient-light #:make-directional-light #:make-point-light
                #:intensity #:target #:distance #:decay))

(defpackage #:flegrea.meta
  (:use #:cl)
  (:import-from #:flegrea
                #:validation-error #:meta-node #:meta-scene #:scene-instance #:binding
                #:node-id #:node-type #:node-properties #:node-property #:node-children
                #:instance-scene #:instance-camera #:define-scene #:bind #:ref
                #:scene-description #:parse-scene #:instantiate-scene #:commit-scene
                #:update-scene #:find-node #:find-object #:walk-scene #:transform-scene
                #:read-scene #:write-scene #:register-node-class
                #:validate-node #:instantiate-node #:update-node #:dispose-node))

(defpackage #:flegrea.renderer
  (:use #:cl)
  (:import-from #:flegrea
                #:renderer-error #:shader-error #:renderer #:make-renderer
                #:render #:render-scene #:animate #:animate-scene #:animation-loop
                #:stop-animation #:renderer-should-close-p #:dispose
                #:renderer-width #:renderer-height #:renderer-title
                #:key-down-p #:request-close))
