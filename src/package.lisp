(defpackage #:flegrea
  (:use #:cl)
  (:shadow #:position)
  (:export
   ;; Condições
   #:flegrea-error #:validation-error #:renderer-error #:shader-error
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
   ;; Núcleo
   #:object-3d #:scene #:group #:mesh #:camera #:perspective-camera
   #:orthographic-camera #:make-object-3d #:make-scene #:make-group #:make-mesh
   #:make-perspective-camera #:make-orthographic-camera
   #:position #:rotation #:scale #:parent #:children #:matrix #:matrix-world
   #:visible #:name #:geometry #:material #:projection-matrix #:view-matrix
   #:fov #:aspect #:near #:far #:left #:right #:top #:bottom #:zoom
   #:add-child #:remove-child #:traverse #:set-position #:set-rotation
   #:set-scale #:look-at #:update-matrix #:update-matrix-world
   #:update-projection-matrix
   ;; Geometrias
   #:buffer-attribute #:buffer-geometry #:box-geometry #:sphere-geometry
   #:plane-geometry #:make-buffer-attribute #:make-buffer-geometry
   #:make-box-geometry #:make-sphere-geometry #:make-plane-geometry
   #:attribute-array #:item-size #:normalized #:usage #:needs-update
   #:attributes #:index #:set-attribute #:get-attribute #:delete-attribute
   #:set-index #:compute-vertex-normals
   ;; Materiais
   #:material-base #:mesh-basic-material #:mesh-standard-material #:shader-material
   #:make-mesh-basic-material #:make-mesh-standard-material #:make-shader-material
   #:color #:vertex-colors #:roughness #:metalness #:emissive
   #:vertex-shader #:fragment-shader #:uniforms #:uniform #:set-uniform
   #:side #:depth-write
   ;; Luzes
   #:light #:ambient-light #:directional-light #:point-light
   #:make-ambient-light #:make-directional-light #:make-point-light
   #:intensity #:target #:distance #:decay
   ;; Metagrafo
   #:meta-node #:meta-scene #:scene-instance #:binding
   #:node-id #:node-type #:node-properties #:node-property #:node-children
   #:instance-scene #:instance-camera #:define-scene #:bind #:ref
   #:scene-description #:parse-scene #:instantiate-scene #:commit-scene
   #:update-scene #:find-node #:find-object #:walk-scene #:transform-scene
   #:read-scene #:write-scene #:register-node-class
   #:validate-node #:instantiate-node #:update-node #:dispose-node
   ;; Renderização
   #:renderer #:make-renderer #:render #:render-scene #:animate #:animate-scene
   #:animation-loop #:stop-animation #:renderer-should-close-p #:dispose
   #:renderer-width #:renderer-height #:renderer-title
   #:key-down-p #:request-close))

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
