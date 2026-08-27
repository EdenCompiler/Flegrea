(defpackage #:flegrea.tests
  (:use #:cl #:fiveam)
  (:shadowing-import-from #:flegrea #:position)
  (:export #:run-tests))

(in-package #:flegrea.tests)

(def-suite conjunto-flegrea
  :description "Testes da versão 1.5 de Flegrea.")
(in-suite conjunto-flegrea)

(defun perto-p (a b &optional (tolerancia 1.0e-5))
  (<= (abs (- a b)) tolerancia))

(test vetores-e-quaternion
  (let ((a (flegrea:make-vector3 1 2 3))
        (b (flegrea:make-vector3 3 2 1)))
    (is (eq a (flegrea:add a b)))
    (is (flegrea:equals a (flegrea:make-vector3 4 4 4)))
    (is (= 24.0f0 (flegrea:dot a b)))
    (is (flegrea:equals (flegrea:cross (flegrea:make-vector3 1 0 0)
                                      (flegrea:make-vector3 0 1 0))
                        (flegrea:make-vector3 0 0 1)))
    (is (flegrea:equals (flegrea:normalize (flegrea:make-vector3))
                        (flegrea:make-vector3))))
  (let* ((angulos (flegrea:make-euler 0.2 0.4 -0.1 :zyx))
         (giro (flegrea:set-from-euler (flegrea:make-quaternion) angulos))
         (retorno (flegrea:set-from-quaternion (flegrea:make-euler 0 0 0 :zyx) giro)))
    (is (flegrea:equals angulos retorno 1.0e-4))))

(test matrizes
  (let* ((matriz (flegrea:set-translation-matrix4 (flegrea:make-matrix4) 2 3 4))
         (inversa (flegrea:matrix-invert (flegrea:clone matriz)))
         (produto (flegrea:matrix-multiply (flegrea:clone matriz) inversa)))
    (is (flegrea:equals produto (flegrea:make-matrix4) 1.0e-5))
    (is (flegrea:equals (flegrea:apply-matrix4 (flegrea:make-vector3 1 1 1) matriz)
                        (flegrea:make-vector3 3 4 5))))
  (signals flegrea:validation-error
    (flegrea:matrix-invert (flegrea:make-matrix4 (make-array 16 :initial-element 0.0f0)))))

(test composicao
  (let* ((posicao (flegrea:make-vector3 1 2 3))
         (giro (flegrea:set-from-euler (flegrea:make-quaternion)
                                      (flegrea:make-euler 0.2 0.3 0.4)))
         (escala (flegrea:make-vector3 2 3 4))
         (matriz (flegrea:compose-matrix4 (flegrea:make-matrix4) posicao giro escala))
         (posicao-retorno (flegrea:make-vector3))
         (giro-retorno (flegrea:make-quaternion))
         (escala-retorno (flegrea:make-vector3)))
    (flegrea:decompose-matrix4 matriz posicao-retorno giro-retorno escala-retorno)
    (is (flegrea:equals posicao posicao-retorno))
    (is (flegrea:equals escala escala-retorno))
    (is (perto-p 1.0f0 (abs (flegrea:dot giro giro-retorno)) 1.0e-4))))

(test grafo-de-cena
  (let ((raiz (flegrea:make-scene)) (grupo (flegrea:make-group)) (filho (flegrea:make-object-3d)))
    (flegrea:add-child raiz grupo)
    (flegrea:add-child grupo filho)
    (signals flegrea:validation-error (flegrea:add-child filho raiz))
    (flegrea:set-position grupo 1 0 0)
    (flegrea:set-position filho 0 2 0)
    (flegrea:update-matrix-world raiz)
    (let ((dados (flegrea:elements (flegrea:matrix-world filho))))
      (is (perto-p 1.0f0 (aref dados 12)))
      (is (perto-p 2.0f0 (aref dados 13))))))

(test geometrias
  (let ((caixa (flegrea:make-box-geometry))
        (esfera (flegrea:make-sphere-geometry :width-segments 8 :height-segments 4))
        (plano (flegrea:make-plane-geometry :width-segments 2 :height-segments 3)))
    (is (= 72 (length (flegrea:attribute-array (flegrea:get-attribute caixa :position)))))
    (is (= 36 (length (flegrea:attribute-array (flegrea:index caixa)))))
    (is (= (* 9 5 3) (length (flegrea:attribute-array (flegrea:get-attribute esfera :position)))))
    (is (= (* 3 4 3) (length (flegrea:attribute-array (flegrea:get-attribute plano :position))))))
  (let ((customizada (flegrea:make-buffer-geometry)))
    (flegrea:set-attribute customizada :position
                           (flegrea:make-buffer-attribute '(0 0 0 1 0 0 0 1 0) 3))
    (flegrea:compute-vertex-normals customizada)
    (is (flegrea:get-attribute customizada :normal))))

(flegrea:define-scene criar-cena-de-teste
  (flegrea:scene
   :id :raiz
   :active-camera (flegrea:ref :camera)
   :resources
   ((flegrea:box-geometry :id :geometria)
    (flegrea:mesh-standard-material :id :material
                                    :color (flegrea:vector3 0.8 0.2 0.1)))
   :children
   ((flegrea:perspective-camera :id :camera
                                :position (flegrea:vector3 0 0 5))
    (flegrea:mesh :id :cubo
                  :geometry (flegrea:ref :geometria)
                  :material (flegrea:ref :material)
                  :rotation (flegrea:euler (flegrea:bind (* :time 0.5)) 0 0 :xyz)))))

(test metagrafo-e-bindings
  (let* ((instancia (criar-cena-de-teste))
         (cubo (flegrea:find-object instancia :cubo)))
    (flegrea:update-scene instancia 2.0 0.016)
    (is (perto-p 1.0f0 (flegrea:x (flegrea:rotation cubo))))
    (is (typep (flegrea:instance-camera instancia) 'flegrea:perspective-camera))))

(test commit-preserva-identidade
  (let* ((instancia (criar-cena-de-teste))
         (cubo (flegrea:find-object instancia :cubo))
         (descricao (flegrea:scene-description 'criar-cena-de-teste))
         (no (flegrea:find-node descricao :cubo)))
    (setf (flegrea:node-property no :position) '( :vector3 2 0 0))
    (flegrea:commit-scene instancia descricao)
    (is (eq cubo (flegrea:find-object instancia :cubo)))
    (is (perto-p 2.0f0 (flegrea:x (flegrea:position cubo))))))

(test persistencia
  (let* ((descricao (flegrea:scene-description 'criar-cena-de-teste))
         (texto (with-output-to-string (fluxo) (flegrea:write-scene descricao fluxo)))
         (retorno (with-input-from-string (fluxo texto) (flegrea:read-scene fluxo))))
    (is (flegrea:find-node retorno :cubo))
    (is (search "SCENE" texto))))

(test material-programavel
  (let ((material
          (flegrea:make-shader-material
           :vertex-shader "#version 330 core
void main(){gl_Position=vec4(0.0);}"
           :fragment-shader "#version 330 core
out vec4 corSaida;void main(){corSaida=vec4(1.0);}"
           :uniforms '("tempo" 0.0 "cor" nil)
           :side :double)))
    (is (typep material 'flegrea:shader-material))
    (is (zerop (flegrea:uniform material "tempo")))
    (is (eq material (flegrea:set-uniform material "tempo" 3.5f0)))
    (is (perto-p 3.5f0 (flegrea:uniform material "tempo")))
    (is (eq :double (flegrea:side material)))))

(test cores-e-volumes
  (let* ((srgb (flegrea:make-color 0.5 0.25 0.75))
         (linear (flegrea:convert-color srgb :linear))
         (retorno (flegrea:convert-color linear :srgb)))
    (is (typep srgb 'flegrea:color))
    (is (flegrea:equals srgb retorno 1.0e-5))
    (is (= #x8040bf (flegrea:color-hex srgb))))
  (let ((caixa (flegrea:make-box3))
        (esfera (flegrea:make-sphere (flegrea:make-vector3 1 1 1) 0.5)))
    (flegrea:expand-by-point caixa (flegrea:make-vector3 0 0 0))
    (flegrea:expand-by-point caixa (flegrea:make-vector3 2 2 2))
    (is (flegrea:contains-point-p caixa (flegrea:make-vector3 1 1 1)))
    (is (flegrea:intersects-sphere-p caixa esfera)))
  (signals flegrea:validation-error
    (flegrea:make-data-texture 1 1 #(255 255 255 255) :uv-channel 2)))

(test geometrias-15-e-descarte
  (dolist (geometria (list (flegrea:make-circle-geometry :segments 8)
                           (flegrea:make-ring-geometry :segments 8)
                           (flegrea:make-cylinder-geometry :radial-segments 8)
                           (flegrea:make-cone-geometry :radial-segments 8)
                           (flegrea:make-torus-geometry :radial-segments 4 :tubular-segments 8)
                           (flegrea:make-capsule-geometry :segments 4)))
    (is (flegrea:get-attribute geometria :position))
    (is (typep (flegrea:compute-bounding-sphere geometria) 'flegrea:sphere)))
  (let ((geometria (flegrea:make-box-geometry)))
    (flegrea:dispose geometria)
    (is (flegrea:disposed-p geometria))
    (is (eq geometria (flegrea:dispose geometria)))
    (signals flegrea:disposed-resource-error (flegrea:add-group geometria 0 3 0))))

(test camadas-listas-e-instancias
  (let* ((cena (flegrea:make-scene))
         (camera (flegrea:make-perspective-camera :aspect 1.0f0))
         (geometria (flegrea:make-box-geometry))
         (opaco (flegrea:make-mesh-basic-material :color (flegrea:make-color 1 0 0)))
         (transparente (flegrea:make-mesh-basic-material :color (flegrea:make-color 0 0 1)))
         (a (flegrea:make-mesh geometria opaco))
         (b (flegrea:make-mesh geometria transparente))
         (instancias (flegrea:make-instanced-mesh geometria opaco 3)))
    (setf (flegrea:transparent transparente) t (flegrea:opacity transparente) 0.5f0)
    (flegrea:set-position camera 0 0 6)
    (flegrea:set-position b 0 0 -1)
    (flegrea:add-child cena camera)
    (dolist (objeto (list a b instancias)) (flegrea:add-child cena objeto))
    (let ((lista (flegrea:build-render-list cena camera)))
      (is (= 2 (length (flegrea:opaque-items lista))))
      (is (= 1 (length (flegrea:transparent-items lista)))))
    (flegrea:disable-layer b 0)
    (is (not (flegrea:layers-match-p b camera)))
    (is (= 3 (flegrea:instance-count instancias)))
    (flegrea:set-instance-color instancias 1 (flegrea:make-color 0.25 0.5 0.75))
    (is (flegrea:equals (aref (flegrea:instance-colors instancias) 1)
                        (flegrea:make-color 0.25 0.5 0.75)))))

(test animacao-e-raycaster
  (let* ((objeto (flegrea:make-mesh (flegrea:make-box-geometry)
                                    (flegrea:make-mesh-basic-material)))
         (trilha (flegrea:make-keyframe-track
                  (list :position objeto) #(0 1)
                  (vector (flegrea:make-vector3 0 0 0) (flegrea:make-vector3 2 0 0))))
         (clipe (flegrea:make-animation-clip :tracks (list trilha)))
         (mixer (flegrea:make-animation-mixer objeto))
         (acao (flegrea:clip-action mixer clipe :loop-mode :once :clamp-when-finished t)))
    (flegrea:play acao)
    (flegrea:mixer-update mixer 0.5f0)
    (is (perto-p 1.0f0 (flegrea:x (flegrea:position objeto)))))
  (let* ((objeto (flegrea:make-object-3d))
         (trilha-a (flegrea:make-keyframe-track
                    (list :position objeto) #(0 1)
                    (vector (flegrea:make-vector3) (flegrea:make-vector3))))
         (trilha-b (flegrea:make-keyframe-track
                    (list :position objeto) #(0 1)
                    (vector (flegrea:make-vector3 10 0 0) (flegrea:make-vector3 10 0 0))))
         (mixer (flegrea:make-animation-mixer objeto))
         (a (flegrea:clip-action mixer (flegrea:make-animation-clip :tracks (list trilha-a))
                                 :weight 0.25f0))
         (b (flegrea:clip-action mixer (flegrea:make-animation-clip :tracks (list trilha-b))
                                 :weight 0.75f0)))
    (flegrea:play a) (flegrea:play b) (flegrea:mixer-update mixer 0.5f0)
    (is (perto-p 7.5f0 (flegrea:x (flegrea:position objeto)))))
  (let* ((objeto (flegrea:make-mesh (flegrea:make-box-geometry)
                                    (flegrea:make-mesh-basic-material)))
         (raycaster (flegrea:make-raycaster :origin (flegrea:make-vector3 0 0 3)
                                            :direction (flegrea:make-vector3 0 0 -1)))
         (intersecoes nil))
    (flegrea:update-matrix-world objeto)
    (setf intersecoes (flegrea:intersect-object raycaster objeto))
    (is (plusp (length intersecoes)))
    (is (typep (flegrea:intersection-uv (first intersecoes)) 'flegrea:vector2))
    (is (perto-p 1.0f0 (flegrea:vector-length
                        (flegrea:intersection-normal (first intersecoes))))))
  (let* ((geometria (flegrea:make-buffer-geometry))
         (linha nil)
         (sprite (flegrea:make-sprite (flegrea:make-sprite-material)))
         (raycaster (flegrea:make-raycaster :origin (flegrea:make-vector3 0 0 3)
                                            :direction (flegrea:make-vector3 0 0 -1))))
    (flegrea:set-attribute geometria :position
                           (flegrea:make-buffer-attribute '(-1 0 0 1 0 0) 3))
    (setf linha (flegrea:make-line-segments geometria (flegrea:make-line-material)))
    (flegrea:update-matrix-world linha)
    (flegrea:update-matrix-world sprite)
    (is (= 1 (length (flegrea:intersect-object raycaster linha))))
    (is (= 1 (length (flegrea:intersect-object raycaster sprite)))))
  (let* ((entrada (flegrea:make-input-state))
         (camera (flegrea:make-perspective-camera))
         (controles (flegrea:make-orbit-controls camera entrada)))
    (flegrea:set-position camera 0 0 10)
    (flegrea::%definir-botao entrada :right t)
    (flegrea:set-vector2 (flegrea:cursor-delta entrada) 10 0)
    (flegrea:controls-update controles 0.016f0)
    (is (< (flegrea:x (flegrea:controls-target controles)) 0.0f0))))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (flegrea:register-binding-function :positive (lambda (valor) (and (realp valor) (plusp valor)))))

(flegrea:define-scene criar-cena-tipada
  (:parameters (:speed :type real :default 2.0f0 :validator :positive))
  (:state :selected nil)
  (flegrea:scene
   :id :root :active-camera (flegrea:ref :camera)
   :resources ((flegrea:box-geometry :id :geometry)
               (flegrea:mesh-basic-material :id :material
                                             :color (flegrea:color 0.2 0.4 0.8)))
   :children ((flegrea:perspective-camera :id :camera :position (flegrea:vector3 0 0 5))
              (flegrea:mesh :id :box :geometry (flegrea:ref :geometry)
                            :material (flegrea:ref :material)
                            :rotation (flegrea:euler
                                       (flegrea:bind (* :time (:parameter :speed))) 0 0 :xyz)))))

(test metagrafo-tipado-versionado
  (let* ((instancia (criar-cena-tipada :speed 3.0f0))
         (caixa (flegrea:find-object instancia :box)))
    (flegrea:update-scene instancia 2.0f0 0.016f0)
    (is (perto-p 6.0f0 (flegrea:x (flegrea:rotation caixa))))
    (is (null (gethash :selected (flegrea:scene-state instancia))))
    (let* ((descricao (flegrea:scene-description 'criar-cena-tipada))
           (texto (with-output-to-string (fluxo) (flegrea:write-scene descricao fluxo)))
           (copia (with-input-from-string (fluxo texto) (flegrea:read-scene fluxo))))
      (is (search "FLEGREA-SCENE" texto))
      (is (flegrea:find-node copia :box)))))

(flegrea:define-scene criar-cena-recursos-15
  (flegrea:scene
   :id :root :active-camera (flegrea:ref :camera)
   :resources ((flegrea:data-texture :id :texture :width 1 :height 1
                                    :data (255 64 32 255) :generate-mipmaps nil
                                    :repeat (flegrea:vector2 2 3) :uv-channel 1)
               (flegrea:mesh-physical-material
                :id :physical :base-color-map (flegrea:ref :texture)
                :clearcoat 0.4 :transmission 0.2)
               (flegrea:torus-geometry :id :torus :radius 1.0 :tube 0.25
                                       :radial-segments 8 :tubular-segments 12))
   :children ((flegrea:perspective-camera :id :camera :position (flegrea:vector3 0 0 5))
              (flegrea:instanced-mesh
               :id :object :geometry (flegrea:ref :torus)
               :material (flegrea:ref :physical) :count 2
               :colors ((flegrea:color 1 0 0) nil)))))

(test metagrafo-recursos-15
  (let* ((instancia (criar-cena-recursos-15))
         (textura (flegrea:find-object instancia :texture))
         (material (flegrea:find-object instancia :physical))
         (objeto (flegrea:find-object instancia :object))
         (descricao (flegrea:scene-description 'criar-cena-recursos-15)))
    (is (typep textura 'flegrea:data-texture))
    (is (typep material 'flegrea:mesh-physical-material))
    (is (typep objeto 'flegrea:instanced-mesh))
    (is (flegrea:equals (aref (flegrea:instance-colors objeto) 0)
                        (flegrea:make-color 1 0 0)))
    (is (= 1 (flegrea:uv-channel textura)))
    (is (flegrea:equals (flegrea:repeat textura) (flegrea:make-vector2 2 3)))
    (is (eq textura (flegrea:base-color-map material)))
    (setf (flegrea:node-property (flegrea:find-node descricao :texture) :data)
          '(0 255 64 255)
          (flegrea:node-property (flegrea:find-node descricao :texture) :offset)
          '(:vector2 0.25 0.5)
          (flegrea:node-property (flegrea:find-node descricao :object) :colors)
          '((:color 0 1 0) nil))
    (flegrea:commit-scene instancia descricao)
    (is (eq textura (flegrea:find-object instancia :texture)))
    (is (= 255 (aref (flegrea:image-data textura) 1)))
    (is (flegrea:needs-update textura))
    (is (flegrea:equals (flegrea:offset textura) (flegrea:make-vector2 0.25 0.5)))
    (is (eq objeto (flegrea:find-object instancia :object)))
    (is (flegrea:equals (aref (flegrea:instance-colors objeto) 0)
                        (flegrea:make-color 0 1 0)))
    (is (eq textura (flegrea:base-color-map
                     (flegrea:find-object instancia :physical))))
    (setf (flegrea:node-property (flegrea:find-node descricao :object) :count) 3)
    (flegrea:commit-scene instancia descricao)
    (is (= 3 (flegrea:instance-count (flegrea:find-object instancia :object))))
    (is (not (eq objeto (flegrea:find-object instancia :object))))))

(test assets-assincronos
  (uiop:with-temporary-file (:pathname caminho :stream fluxo :type "png"
                             :element-type '(unsigned-byte 8) :keep nil :direction :output)
    (write-sequence
     (qbase64:decode-string
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAAGYktHRAD/AP8A/6C9p5MAAAANSURBVAjXY/jPwPAfAAUAAf9ynFJnAAAAAElFTkSuQmCC")
     fluxo)
    (finish-output fluxo)
    (let* ((manager (flegrea:make-loading-manager))
           (job (flegrea:load-texture-async caminho :manager manager))
           (notificado nil))
      (flegrea:add-job-listener job (lambda (estado) (declare (ignore estado))
                                      (setf notificado t)))
      (loop repeat 400
            until (member (flegrea:job-status job) '(:completed :failed :cancelled))
            do (sleep 0.005) (flegrea:drain-loading-manager manager))
      (flegrea:drain-loading-manager manager)
      (is (eq :completed (flegrea:job-status job)))
      (is (not (null notificado)))
      (is (typep (flegrea:job-result job) 'flegrea:texture))
      (is (= 1 (flegrea:image-width (flegrea:job-result job))))
      (is (eq (flegrea:job-result job)
              (flegrea:job-result
               (flegrea:load-texture-async caminho :manager manager)))))))

(test gltf-proprio
  (uiop:with-temporary-file (:pathname caminho :stream fluxo :type "gltf"
                             :keep nil :direction :output)
    (write-string
     "{\"asset\":{\"version\":\"2.0\"},\"buffers\":[{\"byteLength\":42,\"uri\":\"data:application/octet-stream;base64,AACAvwAAgL8AAAAAAACAPwAAgL8AAAAAAAAAAAAAgD8AAAAAAAABAAIA\"}],\"bufferViews\":[{\"buffer\":0,\"byteOffset\":0,\"byteLength\":36},{\"buffer\":0,\"byteOffset\":36,\"byteLength\":6}],\"accessors\":[{\"bufferView\":0,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\"},{\"bufferView\":1,\"componentType\":5123,\"count\":3,\"type\":\"SCALAR\"}],\"meshes\":[{\"primitives\":[{\"attributes\":{\"POSITION\":0},\"indices\":1}]}],\"nodes\":[{\"mesh\":0}],\"scenes\":[{\"name\":\"Principal\",\"nodes\":[0]}],\"scene\":0}"
     fluxo)
    (finish-output fluxo)
    (let ((asset (flegrea:load-gltf caminho)))
      (is (typep asset 'flegrea:scene-asset))
      (is (typep (flegrea:instantiate-asset asset) 'flegrea:scene))
      (is (equal '("Principal") (flegrea:asset-scenes asset))))))

(test gltf-texturas-variantes-e-luzes
  (uiop:with-temporary-file (:pathname caminho :stream fluxo :type "gltf"
                             :keep nil :direction :output)
    (write-string
     "{\"asset\":{\"version\":\"2.0\"},\"extensionsUsed\":[\"KHR_materials_unlit\",\"KHR_materials_variants\",\"KHR_lights_punctual\",\"KHR_texture_transform\",\"KHR_materials_emissive_strength\"],\"extensions\":{\"KHR_materials_variants\":{\"variants\":[{\"name\":\"Vermelho\"}]},\"KHR_lights_punctual\":{\"lights\":[{\"name\":\"Luz\",\"type\":\"point\",\"color\":[1,0.5,0.25],\"intensity\":2,\"range\":8}]}},\"buffers\":[{\"byteLength\":42,\"uri\":\"data:application/octet-stream;base64,AACAvwAAgL8AAAAAAACAPwAAgL8AAAAAAAAAAAAAgD8AAAAAAAABAAIA\"}],\"bufferViews\":[{\"buffer\":0,\"byteOffset\":0,\"byteLength\":36},{\"buffer\":0,\"byteOffset\":36,\"byteLength\":6}],\"accessors\":[{\"bufferView\":0,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\"},{\"bufferView\":1,\"componentType\":5123,\"count\":3,\"type\":\"SCALAR\"}],\"images\":[{\"uri\":\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAIGNIUk0AAHomAACAhAAA+gAAAIDoAAB1MAAA6mAAADqYAAAXcJy6UTwAAAAGYktHRAD/AP8A/6C9p5MAAAANSURBVAjXY/jPwPAfAAUAAf9ynFJnAAAAAElFTkSuQmCC\"}],\"samplers\":[{\"magFilter\":9728,\"minFilter\":9728,\"wrapS\":33071,\"wrapT\":33648}],\"textures\":[{\"source\":0,\"sampler\":0}],\"materials\":[{\"extensions\":{\"KHR_materials_unlit\":{}},\"pbrMetallicRoughness\":{\"baseColorTexture\":{\"index\":0,\"extensions\":{\"KHR_texture_transform\":{\"offset\":[0.25,0.5],\"scale\":[2,3],\"rotation\":0.2}}}}},{\"emissiveFactor\":[1,0,0],\"extensions\":{\"KHR_materials_emissive_strength\":{\"emissiveStrength\":3}}}],\"meshes\":[{\"primitives\":[{\"attributes\":{\"POSITION\":0},\"indices\":1,\"material\":0,\"extensions\":{\"KHR_materials_variants\":{\"mappings\":[{\"material\":1,\"variants\":[0]}]}}}]}],\"nodes\":[{\"mesh\":0,\"extensions\":{\"KHR_lights_punctual\":{\"light\":0}}}],\"scenes\":[{\"nodes\":[0]}],\"scene\":0}"
     fluxo)
    (finish-output fluxo)
    (let* ((asset (flegrea:load-gltf caminho))
           (padrao (flegrea:instantiate-asset asset))
           (variante (flegrea:instantiate-asset asset :variant "Vermelho"))
           (malha-padrao nil) (malha-variante nil) (luz nil))
      (flegrea:traverse padrao
                        (lambda (objeto)
                          (when (typep objeto 'flegrea:mesh) (setf malha-padrao objeto))
                          (when (typep objeto 'flegrea:point-light) (setf luz objeto))))
      (flegrea:traverse variante
                        (lambda (objeto)
                          (when (typep objeto 'flegrea:mesh) (setf malha-variante objeto))))
      (is (equal '("Vermelho") (flegrea:asset-variants asset)))
      (is (typep (flegrea:material malha-padrao) 'flegrea:mesh-basic-material))
      (is (typep (flegrea:base-color-map (flegrea:material malha-padrao)) 'flegrea:texture))
      (is (eq :nearest (flegrea:min-filter
                        (flegrea:base-color-map (flegrea:material malha-padrao)))))
      (is (typep (flegrea:material malha-variante) 'flegrea:mesh-standard-material))
      (is (perto-p 3.0f0 (flegrea:emissive-intensity
                          (flegrea:material malha-variante))))
      (is (typep luz 'flegrea:point-light))
      (is (perto-p 8.0f0 (flegrea:distance luz))))))

(test gltf-fisico-e-instancias
  (uiop:with-temporary-file (:pathname caminho :stream fluxo :type "gltf"
                             :keep nil :direction :output)
    (write-string
     "{\"asset\":{\"version\":\"2.0\"},\"extensionsUsed\":[\"KHR_materials_clearcoat\",\"KHR_materials_transmission\",\"KHR_materials_ior\",\"KHR_materials_volume\",\"EXT_mesh_gpu_instancing\"],\"buffers\":[{\"byteLength\":42,\"uri\":\"data:application/octet-stream;base64,AACAvwAAgL8AAAAAAACAPwAAgL8AAAAAAAAAAAAAgD8AAAAAAAABAAIA\"},{\"byteLength\":24,\"uri\":\"data:application/octet-stream;base64,AAAAAAAAAAAAAAAAAACAPwAAAAAAAAAA\"}],\"bufferViews\":[{\"buffer\":0,\"byteOffset\":0,\"byteLength\":36},{\"buffer\":0,\"byteOffset\":36,\"byteLength\":6},{\"buffer\":1,\"byteLength\":24}],\"accessors\":[{\"bufferView\":0,\"componentType\":5126,\"count\":3,\"type\":\"VEC3\"},{\"bufferView\":1,\"componentType\":5123,\"count\":3,\"type\":\"SCALAR\"},{\"bufferView\":2,\"componentType\":5126,\"count\":2,\"type\":\"VEC3\"}],\"materials\":[{\"extensions\":{\"KHR_materials_clearcoat\":{\"clearcoatFactor\":0.6,\"clearcoatRoughnessFactor\":0.2},\"KHR_materials_transmission\":{\"transmissionFactor\":0.7},\"KHR_materials_ior\":{\"ior\":1.4},\"KHR_materials_volume\":{\"thicknessFactor\":0.5,\"attenuationDistance\":4,\"attenuationColor\":[0.8,0.9,1]}}}],\"meshes\":[{\"primitives\":[{\"attributes\":{\"POSITION\":0},\"indices\":1,\"material\":0}]}],\"nodes\":[{\"mesh\":0,\"extensions\":{\"EXT_mesh_gpu_instancing\":{\"attributes\":{\"TRANSLATION\":2}}}}],\"scenes\":[{\"nodes\":[0]}],\"scene\":0}"
     fluxo)
    (finish-output fluxo)
    (let* ((asset (flegrea:load-gltf caminho))
           (cena (flegrea:instantiate-asset asset)) (instancias nil))
      (flegrea:traverse cena
                        (lambda (objeto)
                          (when (typep objeto 'flegrea:instanced-mesh)
                            (setf instancias objeto))))
      (is (typep instancias 'flegrea:instanced-mesh))
      (is (= 2 (flegrea:instance-count instancias)))
      (is (perto-p 1.0f0 (aref (flegrea:elements
                                (aref (flegrea:instance-matrices instancias) 1)) 12)))
      (let ((material (flegrea:material instancias)))
        (is (typep material 'flegrea:mesh-physical-material))
        (is (perto-p 0.6f0 (flegrea:clearcoat material)))
        (is (perto-p 0.7f0 (flegrea:transmission material)))
        (is (perto-p 1.4f0 (flegrea:ior material)))
        (is (perto-p 0.5f0 (flegrea:thickness material)))))))

(test renderer-opcional
  (when (string= (or (uiop:getenv "FLEGREA_RUN_GL_TESTS") "") "1")
    (let ((renderizador (flegrea:make-renderer :width 64 :height 64 :visible nil))
          (instancia (criar-cena-de-teste)))
      (unwind-protect
           (progn
             (flegrea:render-scene renderizador instancia)
             (let* ((cena (flegrea:make-scene))
                    (camera (flegrea:make-perspective-camera :aspect 1.0f0))
                    (geometria (flegrea:make-buffer-geometry))
                    (material
                      (flegrea:make-shader-material
                       :vertex-shader
                       "#version 330 core
layout(location=0)in vec3 posicao;uniform mat4 matrizModelo;uniform mat4 matrizVisao;uniform mat4 matrizProjecao;void main(){gl_Position=matrizProjecao*matrizVisao*matrizModelo*vec4(posicao,1.0);}"
                       :fragment-shader
                       "#version 330 core
out vec4 corSaida;uniform vec3 corTeste;void main(){corSaida=vec4(corTeste,1.0);}"
                       :uniforms (list "corTeste" (flegrea:make-vector3 0.2 0.5 0.9)))))
               (flegrea:set-attribute geometria :position
                                      (flegrea:make-buffer-attribute '(-1 -1 0 1 -1 0 0 1 0) 3))
               (flegrea:set-position camera 0 0 3)
               (flegrea:add-child cena (flegrea:make-mesh geometria material))
               (flegrea:render renderizador cena camera))
             (let* ((cena (flegrea:make-scene))
                    (camera (flegrea:make-perspective-camera :aspect 1.0f0))
                    (dados (make-array 16 :element-type '(unsigned-byte 8)
                                          :initial-contents
                                          '(255 40 20 255 20 255 40 255
                                            40 20 255 255 255 255 255 255)))
                    (textura (flegrea:make-data-texture 2 2 dados :generate-mipmaps nil
                                                       :min-filter :nearest :mag-filter :nearest))
                    (material (flegrea:make-mesh-basic-material :color (flegrea:make-color)
                                                                :base-color-map textura))
                    (instancias (flegrea:make-instanced-mesh
                                 (flegrea:make-box-geometry) material 2)))
               (setf (flegrea:uv-channel textura) 1)
               (let ((uv (flegrea:get-attribute (flegrea:geometry instancias) :uv)))
                 (flegrea:set-attribute
                  (flegrea:geometry instancias) :uv1
                  (flegrea:make-buffer-attribute
                   (copy-seq (flegrea:attribute-array uv)) 2)))
               (flegrea:set-position camera 0 0 5)
               (flegrea:set-instance-matrix
                instancias 0
                (flegrea:set-translation-matrix4 (flegrea:make-matrix4) -0.75 0 0))
               (flegrea:set-instance-matrix
                instancias 1
                (flegrea:set-translation-matrix4 (flegrea:make-matrix4) 0.75 0 0))
               (flegrea:set-instance-color instancias 0 (flegrea:make-color 1 0.5 0.5))
               (flegrea:set-instance-color instancias 1 (flegrea:make-color 0.5 0.5 1))
               (setf (flegrea:cast-shadow instancias) t (flegrea:receive-shadow instancias) t)
               (flegrea:add-child cena instancias)
               (let ((vidro (flegrea:make-mesh
                             (flegrea:make-sphere-geometry :radius 0.4 :width-segments 12
                                                           :height-segments 8)
                             (flegrea:make-mesh-physical-material
                              :color (flegrea:make-color 0.5 0.8 1.0)
                              :transmission 0.8 :thickness 0.25 :roughness 0.15))))
                 (flegrea:set-position vidro 0 0 1)
                 (flegrea:add-child cena vidro))
               (let ((luz (flegrea:make-spot-light
                           :color (flegrea:make-color) :intensity 4.0f0
                           :shadow (make-instance 'flegrea:light-shadow :map-size
                                                  (flegrea:make-vector2 64 64)))))
                 (flegrea:set-position luz 0 3 4)
                 (flegrea:add-child cena luz))
               (let ((sprite (flegrea:make-sprite
                              (flegrea:make-sprite-material
                               :base-color-map textura :transparent t))))
                 (flegrea:set-position sprite 0 1 0)
                 (flegrea:add-child cena sprite))
               (let ((normal (flegrea:make-mesh (flegrea:make-box-geometry)
                                                 (flegrea:make-mesh-normal-material)))
                     (profundidade (flegrea:make-mesh (flegrea:make-box-geometry)
                                                      (flegrea:make-mesh-depth-material))))
                 (flegrea:set-position normal -2 0 0)
                 (flegrea:set-position profundidade 2 0 0)
                 (flegrea:add-child cena normal)
                 (flegrea:add-child cena profundidade))
               (flegrea:render renderizador cena camera)
               (let ((compositor (flegrea:make-effect-composer renderizador :width 64 :height 64)))
                 (unwind-protect
                      (progn
                        (flegrea:add-pass compositor (flegrea:make-render-pass cena camera))
                        (flegrea:add-pass compositor (flegrea:make-fxaa-pass))
                        (flegrea:composer-render compositor))
                   (flegrea:dispose compositor))))
             (pass))
        (flegrea:dispose renderizador)))))

(defun run-tests ()
  "Executa os testes automatizados e sinaliza falha para o ASDF."
  (let ((resultado (run 'conjunto-flegrea)))
    (unless (results-status resultado)
      (error "Os testes de Flegrea falharam."))
    resultado))
