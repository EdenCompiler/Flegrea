(in-package #:flegrea)

(defclass scene-asset (resource)
  ((cenas :initarg :scenes :reader asset-scenes)
   (cameras :initarg :cameras :reader asset-cameras)
   (variantes :initarg :variants :reader asset-variants)
   (metagrafo :initarg :metagraph :reader asset-metagraph)
   (metadados :initarg :metadata :reader asset-metadata)
   (recursos :initarg :resources :initform nil :reader %recursos-do-asset)
   (fabrica :initarg :factory :reader %fabrica-do-asset)))

(defmethod dispose ((asset scene-asset))
  (unless (disposed-p asset)
    (dolist (recurso (%recursos-do-asset asset))
      (when (typep recurso 'resource) (dispose recurso))))
  (call-next-method))

(defun instantiate-asset (asset &key scene variant)
  "Instancia uma cena de um asset sem compartilhar o grafo de objetos."
  (%verificar-recurso-vivo asset :instantiate)
  (funcall (%fabrica-do-asset asset) scene variant))

(defun %json (objeto chave &optional padrao)
  (if (hash-table-p objeto) (gethash chave objeto padrao) padrao))

(defun %vetor-json (objeto chave)
  (or (%json objeto chave) #()))

(defun %u32-pequeno (dados inicio)
  (logior (aref dados inicio) (ash (aref dados (+ inicio 1)) 8)
          (ash (aref dados (+ inicio 2)) 16) (ash (aref dados (+ inicio 3)) 24)))

(defun %texto-utf8 (dados &optional (inicio 0) (fim (length dados)))
  (string-right-trim '(#\Null #\Space #\Tab #\Newline #\Return)
                     (babel:octets-to-string dados :start inicio :end fim :encoding :utf-8)))

(defun %ler-glb (dados caminho)
  (unless (and (>= (length dados) 20) (= (%u32-pequeno dados 0) #x46546c67)
               (= (%u32-pequeno dados 4) 2) (= (%u32-pequeno dados 8) (length dados)))
    (error 'gltf-error :message "O cabeçalho GLB 2.0 é inválido." :path caminho :stage :parse))
  (let ((cursor 12) (json nil) (binario nil))
    (loop while (< cursor (length dados)) do
      (let* ((tamanho (%u32-pequeno dados cursor)) (tipo (%u32-pequeno dados (+ cursor 4)))
             (inicio (+ cursor 8)) (fim (+ inicio tamanho)))
        (when (> fim (length dados))
          (error 'gltf-error :message "Um chunk GLB ultrapassa o arquivo." :path caminho :stage :parse))
        (case tipo
          (#x4e4f534a (setf json (%texto-utf8 dados inicio fim)))
          (#x004e4942 (setf binario (subseq dados inicio fim))))
        (setf cursor fim)))
    (unless json (error 'gltf-error :message "O GLB não contém chunk JSON." :path caminho :stage :parse))
    (values (com.inuoe.jzon:parse json) binario)))

(defparameter +extensoes-gltf+
  '("KHR_materials_unlit" "KHR_texture_transform" "KHR_lights_punctual"
    "KHR_materials_variants" "KHR_materials_emissive_strength" "KHR_materials_clearcoat"
    "KHR_materials_transmission" "KHR_materials_ior" "KHR_materials_volume"
    "EXT_mesh_gpu_instancing"))

(defvar *recursos-gltf* nil)

(defun %validar-extensoes-gltf (documento caminho)
  (loop for extensao across (%vetor-json documento "extensionsRequired") do
    (unless (member extensao +extensoes-gltf+ :test #'string=)
      (error 'gltf-error :message (format nil "A extensão glTF obrigatória ~A não é suportada." extensao)
             :path caminho :stage :validate :extension extensao)))
  (loop for extensao across (%vetor-json documento "extensionsUsed")
        unless (member extensao +extensoes-gltf+ :test #'string=)
          collect extensao))

(defun %uri-com-esquema (uri)
  (let ((posicao (cl:position #\: uri)))
    (and posicao (subseq uri 0 posicao))))

(defun %caminho-seguro (raiz uri)
  (let* ((base (uiop:ensure-directory-pathname raiz))
         (candidato (merge-pathnames uri base))
         (base-nomes (pathname-directory (truename base)))
         (candidato-nomes (pathname-directory (truename candidato))))
    (unless (and (>= (length candidato-nomes) (length base-nomes))
                 (equal base-nomes (subseq candidato-nomes 0 (length base-nomes))))
      (error 'gltf-error :message "Uma URI glTF tenta escapar da raiz do asset."
             :path candidato :stage :resolve))
    candidato))

(defun %resolver-uri-gltf (uri raiz manager)
  (cond
    ((uiop:string-prefix-p "data:" uri)
     (let ((virgula (cl:position #\, uri)))
       (unless (and virgula (search ";base64" uri :end2 virgula))
         (error 'gltf-error :message "A data URI glTF precisa usar base64." :stage :resolve))
       (qbase64:decode-string (subseq uri (1+ virgula)))))
    ((%uri-com-esquema uri)
     (let ((resolvedor (gethash (string-downcase (%uri-com-esquema uri)) (%resolvedores manager))))
       (unless resolvedor
         (error 'gltf-error :message "Não há resolvedor registrado para a URI glTF." :stage :resolve))
       (funcall resolvedor uri)))
    (t (%ler-octetos (%caminho-seguro raiz uri)))))

(defun %carregar-buffers-gltf (documento binario raiz manager)
  (let ((buffers (%vetor-json documento "buffers")))
    (map 'vector
         (lambda (descritor)
           (let ((uri (%json descritor "uri")))
             (cond (uri (%resolver-uri-gltf uri raiz manager))
                   (binario binario)
                   (t (error 'gltf-error :message "Um buffer glTF não possui fonte."
                             :stage :resolve)))))
         buffers)))

(defun %float32-de-bits (bits)
  (let ((sinal (if (logbitp 31 bits) -1.0d0 1.0d0))
        (expoente (ldb (byte 8 23) bits)) (fracao (ldb (byte 23 0) bits)))
    (coerce (cond ((zerop expoente) (* sinal (expt 2.0d0 -126) (/ fracao (expt 2.0d0 23))))
                  ((= expoente 255) (error 'gltf-error :message "O accessor contém float não finito." :stage :decode))
                  (t (* sinal (expt 2.0d0 (- expoente 127))
                        (+ 1.0d0 (/ fracao (expt 2.0d0 23))))))
            'single-float)))

(defun %ler-componente (dados inicio tipo normalizado)
  (labels ((u16 () (logior (aref dados inicio) (ash (aref dados (1+ inicio)) 8)))
           (u32 () (%u32-pequeno dados inicio)))
    (let ((valor (ecase tipo
                   (5120 (let ((v (aref dados inicio))) (if (> v 127) (- v 256) v)))
                   (5121 (aref dados inicio))
                   (5122 (let ((v (u16))) (if (> v 32767) (- v 65536) v)))
                   (5123 (u16)) (5125 (u32)) (5126 (%float32-de-bits (u32))))))
      (if (or (not normalizado) (= tipo 5126)) valor
          (case tipo
            (5120 (max -1.0f0 (/ valor 127.0f0))) (5121 (/ valor 255.0f0))
            (5122 (max -1.0f0 (/ valor 32767.0f0))) (5123 (/ valor 65535.0f0))
            (5125 (/ valor 4294967295.0f0)))))))

(defun %componentes-do-tipo (tipo)
  (or (cdr (assoc tipo '(("SCALAR" . 1) ("VEC2" . 2) ("VEC3" . 3) ("VEC4" . 4)
                         ("MAT2" . 4) ("MAT3" . 9) ("MAT4" . 16)) :test #'string=))
      (error 'gltf-error :message "O tipo de accessor glTF é inválido." :stage :decode)))

(defun %bytes-do-componente (tipo)
  (ecase tipo ((5120 5121) 1) ((5122 5123) 2) ((5125 5126) 4)))

(defun %decodificar-accessor (documento buffers indice)
  (let* ((accessor (aref (%vetor-json documento "accessors") indice))
         (tipo (%json accessor "componentType")) (componentes (%componentes-do-tipo (%json accessor "type")))
         (bytes (%bytes-do-componente tipo)) (quantidade (%json accessor "count"))
         (normalizado (%json accessor "normalized" nil)) (vista-indice (%json accessor "bufferView" nil))
         (saida (make-array (* quantidade componentes)
                            :element-type (if (or normalizado (= tipo 5126)) 'single-float
                                              '(unsigned-byte 32))
                            :initial-element (if (or normalizado (= tipo 5126)) 0.0f0 0))))
    (when vista-indice
      (let* ((vista (aref (%vetor-json documento "bufferViews") vista-indice))
             (dados (aref buffers (%json vista "buffer")))
             (inicio (+ (%json vista "byteOffset" 0) (%json accessor "byteOffset" 0)))
             (passo (%json vista "byteStride" (* bytes componentes))))
        (dotimes (elemento quantidade)
          (dotimes (componente componentes)
            (setf (aref saida (+ (* elemento componentes) componente))
                  (%ler-componente dados (+ inicio (* elemento passo) (* componente bytes))
                                   tipo normalizado))))))
    (let ((esparso (%json accessor "sparse")))
      (when esparso
        (let* ((q (%json esparso "count")) (indices (%json esparso "indices"))
               (valores (%json esparso "values"))
               (vista-i (aref (%vetor-json documento "bufferViews") (%json indices "bufferView")))
               (vista-v (aref (%vetor-json documento "bufferViews") (%json valores "bufferView")))
               (dados-i (aref buffers (%json vista-i "buffer")))
               (dados-v (aref buffers (%json vista-v "buffer")))
               (tipo-i (%json indices "componentType")) (bytes-i (%bytes-do-componente tipo-i))
               (inicio-i (+ (%json vista-i "byteOffset" 0) (%json indices "byteOffset" 0)))
               (inicio-v (+ (%json vista-v "byteOffset" 0) (%json valores "byteOffset" 0))))
          (dotimes (i q)
            (let ((destino (%ler-componente dados-i (+ inicio-i (* i bytes-i)) tipo-i nil)))
              (dotimes (c componentes)
                (setf (aref saida (+ (* destino componentes) c))
                      (%ler-componente dados-v (+ inicio-v (* (+ (* i componentes) c) bytes))
                                       tipo normalizado))))))))
    (values saida componentes)))

(defun %modo-gltf (valor)
  (svref #(:points :lines :line-loop :line-strip :triangles :triangle-strip :triangle-fan)
         (or valor 4)))

(defun %geometria-gltf (documento buffers primitiva)
  (let ((geometria (make-buffer-geometry)) (atributos (%json primitiva "attributes")))
    (maphash
     (lambda (semantica indice)
       (let ((nome (cdr (assoc semantica '(("POSITION" . :position) ("NORMAL" . :normal)
                                            ("TANGENT" . :tangent) ("TEXCOORD_0" . :uv)
                                            ("TEXCOORD_1" . :uv1) ("COLOR_0" . :color))
                               :test #'string=))))
         (when nome
           (multiple-value-bind (dados tamanho) (%decodificar-accessor documento buffers indice)
             (set-attribute geometria nome (make-buffer-attribute dados tamanho))))))
     atributos)
    (when (%json primitiva "indices")
      (multiple-value-bind (dados tamanho)
          (%decodificar-accessor documento buffers (%json primitiva "indices"))
        (declare (ignore tamanho)) (set-index geometria dados)))
    (setf (primitive-mode geometria) (%modo-gltf (%json primitiva "mode" 4)))
    (when (and (eq (primitive-mode geometria) :triangles)
               (null (get-attribute geometria :normal)))
      (compute-vertex-normals geometria))
    (push geometria *recursos-gltf*)
    geometria))

(defun %cor-json (vetor &optional (padrao (make-color)))
  (if vetor (make-color (aref vetor 0) (aref vetor 1) (aref vetor 2)) padrao))

(defun %octetos-da-vista-gltf (documento buffers indice)
  (let* ((vista (aref (%vetor-json documento "bufferViews") indice))
         (dados (aref buffers (%json vista "buffer")))
         (inicio (%json vista "byteOffset" 0))
         (fim (+ inicio (%json vista "byteLength"))))
    (when (> fim (length dados))
      (error 'gltf-error :message "Uma bufferView de imagem ultrapassa seu buffer."
             :stage :decode))
    (subseq dados inicio fim)))

(defun %tipo-da-uri-de-imagem (uri)
  (cond ((uiop:string-prefix-p "data:" uri)
         (let ((fim (or (cl:position #\; uri) (cl:position #\, uri))))
           (and fim (subseq uri 5 fim))))
        (t (string-downcase (or (pathname-type (pathname uri)) "")))))

(defun %imagem-gltf (documento buffers raiz manager indice cache)
  (or (aref cache indice)
      (let* ((descritor (aref (%vetor-json documento "images") indice))
             (uri (%json descritor "uri"))
             (tipo (or (%json descritor "mimeType")
                       (and uri (%tipo-da-uri-de-imagem uri))))
             (octetos (cond (uri (%resolver-uri-gltf uri raiz manager))
                            ((%json descritor "bufferView")
                             (%octetos-da-vista-gltf documento buffers
                                                    (%json descritor "bufferView")))
                            (t (error 'gltf-error :message "Uma imagem glTF não possui fonte."
                                      :stage :resolve)))))
        (unless (typep octetos '(vector (unsigned-byte 8)))
          (error 'gltf-error :message "O resolvedor de imagem glTF não retornou octetos."
                 :stage :resolve))
        (multiple-value-bind (dados largura altura)
            (%decodificar-imagem-octetos octetos tipo)
          (setf (aref cache indice) (list dados largura altura))))))

(defun %filtro-minimo-gltf (valor)
  (case valor (9728 :nearest) (9729 :linear) (9984 :nearest-mipmap-nearest)
        (9985 :linear-mipmap-nearest) (9986 :nearest-mipmap-linear)
        (otherwise :linear-mipmap-linear)))

(defun %filtro-maximo-gltf (valor)
  (if (= (or valor 9729) 9728) :nearest :linear))

(defun %envolvimento-gltf (valor)
  (case valor (33071 :clamp-to-edge) (33648 :mirrored-repeat) (otherwise :repeat)))

(defun %textura-gltf (documento buffers raiz manager informacao espaco cache)
  (when informacao
    (let* ((indice (%json informacao "index"))
           (descritor (aref (%vetor-json documento "textures") indice))
           (fonte (%json descritor "source"))
           (amostrador-i (%json descritor "sampler"))
           (amostrador (and amostrador-i
                            (aref (%vetor-json documento "samplers") amostrador-i)))
           (transformacao (%json (%json informacao "extensions") "KHR_texture_transform"))
           (escala (%json transformacao "scale" #(1 1)))
           (deslocamento (%json transformacao "offset" #(0 0)))
           (canal (%json transformacao "texCoord" (%json informacao "texCoord" 0)))
           (minimo (%json amostrador "minFilter" 9987)))
      (unless fonte
        (error 'gltf-error :message "Uma textura glTF não referencia uma imagem."
               :stage :resolve))
      (destructuring-bind (dados largura altura)
          (%imagem-gltf documento buffers raiz manager fonte cache)
        (let ((textura
                (make-texture largura altura dados
                              :color-space espaco :flip-y nil :uv-channel canal
                              :repeat (make-vector2 (aref escala 0) (aref escala 1))
                              :offset (make-vector2 (aref deslocamento 0) (aref deslocamento 1))
                              :rotation (%json transformacao "rotation" 0.0f0)
                              :min-filter (%filtro-minimo-gltf minimo)
                              :mag-filter (%filtro-maximo-gltf (%json amostrador "magFilter" 9729))
                              :wrap-s (%envolvimento-gltf (%json amostrador "wrapS" 10497))
                              :wrap-t (%envolvimento-gltf (%json amostrador "wrapT" 10497))
                              :generate-mipmaps (member minimo '(9984 9985 9986 9987)))))
          (push textura *recursos-gltf*)
          textura)))))

(defun %material-gltf (descritor documento buffers raiz manager cache)
  (let* ((pbr (%json descritor "pbrMetallicRoughness"))
         (extensoes (%json descritor "extensions"))
         (sem-luz (%json extensoes "KHR_materials_unlit"))
         (fisico (or (%json extensoes "KHR_materials_clearcoat")
                     (%json extensoes "KHR_materials_transmission")
                     (%json extensoes "KHR_materials_volume")))
         (fator (%json pbr "baseColorFactor"))
         (modo-alfa (intern (string-upcase (%json descritor "alphaMode" "OPAQUE")) :keyword))
         (comuns (list :color (%cor-json fator)
                       :base-color-map (%textura-gltf documento buffers raiz manager
                                                      (%json pbr "baseColorTexture") :srgb cache)
                       :opacity (if fator (aref fator 3) 1.0f0)
                       :transparent (eq modo-alfa :blend) :alpha-mode modo-alfa
                       :alpha-test (%json descritor "alphaCutoff" 0.5f0)
                       :side (if (%json descritor "doubleSided" nil) :double :front)))
         (material
           (if sem-luz
               (apply #'make-mesh-basic-material comuns)
               (apply #'make-instance (if fisico 'mesh-physical-material
                                          'mesh-standard-material)
                      :roughness (%json pbr "roughnessFactor" 1.0f0)
                      :metalness (%json pbr "metallicFactor" 1.0f0)
                      :emissive (%cor-json (%json descritor "emissiveFactor")
                                             (make-color 0 0 0 :color-space :linear))
                      :emissive-intensity
                      (%json (%json extensoes "KHR_materials_emissive_strength")
                             "emissiveStrength" 1.0f0)
                      :metallic-roughness-map
                      (%textura-gltf documento buffers raiz manager
                                     (%json pbr "metallicRoughnessTexture") :none cache)
                      :normal-map
                      (%textura-gltf documento buffers raiz manager
                                     (%json descritor "normalTexture") :none cache)
                      :normal-scale
                      (let ((escala (%json (%json descritor "normalTexture") "scale" 1.0f0)))
                        (make-vector2 escala escala))
                      :emissive-map
                      (%textura-gltf documento buffers raiz manager
                                     (%json descritor "emissiveTexture") :srgb cache)
                      :occlusion-map
                      (%textura-gltf documento buffers raiz manager
                                     (%json descritor "occlusionTexture") :none cache)
                      :occlusion-strength
                      (%json (%json descritor "occlusionTexture") "strength" 1.0f0)
                      comuns))))
    (when (typep material 'mesh-physical-material)
      (let ((cc (%json extensoes "KHR_materials_clearcoat"))
            (tr (%json extensoes "KHR_materials_transmission"))
            (io (%json extensoes "KHR_materials_ior"))
            (vo (%json extensoes "KHR_materials_volume")))
        (when cc (setf (clearcoat material) (%json cc "clearcoatFactor" 0.0f0)
                       (clearcoat-roughness material) (%json cc "clearcoatRoughnessFactor" 0.0f0)
                       (clearcoat-map material)
                       (%textura-gltf documento buffers raiz manager
                                      (%json cc "clearcoatTexture") :none cache)
                       (clearcoat-roughness-map material)
                       (%textura-gltf documento buffers raiz manager
                                      (%json cc "clearcoatRoughnessTexture") :none cache)
                       (clearcoat-normal-map material)
                       (%textura-gltf documento buffers raiz manager
                                      (%json cc "clearcoatNormalTexture") :none cache)))
        (when tr (setf (transmission material) (%json tr "transmissionFactor" 0.0f0)
                       (transmission-map material)
                       (%textura-gltf documento buffers raiz manager
                                      (%json tr "transmissionTexture") :none cache)))
        (when io (setf (ior material) (%json io "ior" 1.5f0)))
        (when vo (setf (thickness material) (%json vo "thicknessFactor" 0.0f0)
                       (thickness-map material)
                       (%textura-gltf documento buffers raiz manager
                                      (%json vo "thicknessTexture") :none cache)
                       (attenuation-distance material) (%json vo "attenuationDistance" most-positive-single-float)
                       (attenuation-color material) (%cor-json (%json vo "attenuationColor"))))))
    (push material *recursos-gltf*)
    material))

(defun %indice-de-variante (selecao variantes)
  (cond ((null selecao) nil)
        ((integerp selecao) (and (<= 0 selecao) (< selecao (length variantes)) selecao))
        ((stringp selecao) (cl:position selecao variantes :test #'equal))
        (t nil)))

(defun %material-da-primitiva (primitiva materiais variante)
  (let ((indice (or (%json primitiva "material") 0)))
    (when variante
      (let ((extensao (%json (%json primitiva "extensions") "KHR_materials_variants")))
        (loop for mapeamento across (%vetor-json extensao "mappings")
              when (cl:position variante (%vetor-json mapeamento "variants")) do
                (setf indice (%json mapeamento "material")) (return))))
    (aref materiais (min indice (1- (length materiais))))))

(defun %matriz-de-instancia-gltf (translacoes rotacoes escalas indice)
  (let ((posicao (if translacoes
                     (make-vector3 (aref translacoes (* indice 3))
                                   (aref translacoes (+ (* indice 3) 1))
                                   (aref translacoes (+ (* indice 3) 2)))
                     (make-vector3)))
        (giro (if rotacoes
                  (make-quaternion (aref rotacoes (* indice 4))
                                   (aref rotacoes (+ (* indice 4) 1))
                                   (aref rotacoes (+ (* indice 4) 2))
                                   (aref rotacoes (+ (* indice 4) 3)))
                  (make-quaternion)))
        (escala (if escalas
                    (make-vector3 (aref escalas (* indice 3))
                                  (aref escalas (+ (* indice 3) 1))
                                  (aref escalas (+ (* indice 3) 2)))
                    (make-vector3 1 1 1))))
    (compose-matrix4 (make-matrix4) posicao giro escala)))

(defun %dados-de-instancias-gltf (documento buffers no)
  (let* ((extensao (%json (%json no "extensions") "EXT_mesh_gpu_instancing"))
         (atributos (%json extensao "attributes")))
    (when atributos
      (labels ((ler (nome)
                 (let ((indice (%json atributos nome)))
                   (and indice (nth-value 0 (%decodificar-accessor documento buffers indice))))))
        (let* ((translacoes (ler "TRANSLATION")) (rotacoes (ler "ROTATION"))
               (escalas (ler "SCALE"))
               (quantidade (cond (translacoes (/ (length translacoes) 3))
                                 (rotacoes (/ (length rotacoes) 4))
                                 (escalas (/ (length escalas) 3))
                                 (t 0))))
          (when (plusp quantidade)
            (values quantidade
                    (loop for indice below quantidade
                          collect (%matriz-de-instancia-gltf translacoes rotacoes escalas indice)))))))))

(defun %camera-gltf (descritor)
  (let ((perspectiva (%json descritor "perspective")))
    (if perspectiva
        (make-perspective-camera
         :fov (* 180.0f0 (/ (%json perspectiva "yfov") pi))
         :aspect (%json perspectiva "aspectRatio" 1.0f0)
         :near (%json perspectiva "znear" 0.1f0)
         :far (%json perspectiva "zfar" 2000.0f0))
        (let ((orto (%json descritor "orthographic")))
          (make-orthographic-camera
           :left (- (%json orto "xmag")) :right (%json orto "xmag")
           :top (%json orto "ymag") :bottom (- (%json orto "ymag"))
           :near (%json orto "znear") :far (%json orto "zfar"))))))

(defun %luz-gltf (descritor)
  (let ((tipo (%json descritor "type")) (cor (%cor-json (%json descritor "color")))
        (potencia (%json descritor "intensity" 1.0f0))
        (alcance (%json descritor "range" 0.0f0)) (nome (%json descritor "name" "")))
    (cond ((string= tipo "point")
           (make-point-light :color cor :intensity potencia :distance alcance :name nome))
          ((string= tipo "directional")
           (make-directional-light :color cor :intensity potencia :name nome))
          ((string= tipo "spot")
           (let* ((spot (%json descritor "spot"))
                  (externo (%json spot "outerConeAngle" (/ pi 4)))
                  (interno (%json spot "innerConeAngle" 0.0f0)))
             (make-spot-light :color cor :intensity potencia :distance alcance
                              :angle externo :penumbra (if (plusp externo)
                                                           (max 0.0f0 (min 1.0f0 (- 1 (/ interno externo))))
                                                           0.0f0)
                              :name nome)))
          (t (error 'gltf-error :message "O tipo de luz punctual é inválido."
                    :stage :decode)))))

(defun %aplicar-transformacao-gltf (objeto no)
  (let ((matriz (%json no "matrix")) (translacao (%json no "translation"))
        (giro (%json no "rotation")) (escala (%json no "scale")))
    (cond (matriz
           (copy-from (matrix objeto) (make-matrix4 matriz))
           (decompose-matrix4 (matrix objeto) (position objeto) (quaternion objeto) (scale objeto))
           (set-from-quaternion (rotation objeto) (quaternion objeto)))
          (t
           (when translacao (apply #'set-position objeto (coerce translacao 'list)))
           (when giro (apply #'set-object-quaternion objeto (coerce giro 'list)))
           (when escala (apply #'set-scale objeto (coerce escala 'list)))))
    (setf (name objeto) (%json no "name" "")))
  objeto)

(defun %construir-asset-gltf (documento buffers caminho avisos manager)
  (let* ((*recursos-gltf* nil)
         (raiz (uiop:pathname-directory-pathname caminho))
         (cache-imagens (make-array (length (%vetor-json documento "images"))
                                    :initial-element nil))
         (materiais-json (%vetor-json documento "materials"))
         (materiais (map 'vector (lambda (descritor)
                                   (%material-gltf descritor documento buffers raiz manager
                                                   cache-imagens))
                         materiais-json))
         (materiais (if (plusp (length materiais)) materiais
                        (let ((padrao (make-mesh-standard-material)))
                          (push padrao *recursos-gltf*) (vector padrao))))
         (malhas-json (%vetor-json documento "meshes"))
         (geometrias
           (map 'vector
                (lambda (malha)
                  (map 'vector
                       (lambda (primitiva)
                         (cons (%geometria-gltf documento buffers primitiva) primitiva))
                       (%vetor-json malha "primitives")))
                malhas-json))
         (nos-json (%vetor-json documento "nodes"))
         (cenas-json (%vetor-json documento "scenes"))
         (cameras-json (%vetor-json documento "cameras"))
         (luzes-json (%vetor-json (%json (%json documento "extensions")
                                        "KHR_lights_punctual") "lights"))
         (nomes-cameras (make-hash-table :test #'equal)))
    (let* ((variantes (let* ((ext (%json documento "extensions"))
                             (kmv (%json ext "KHR_materials_variants")))
                        (loop for v across (%vetor-json kmv "variants") collect (%json v "name")))))
      (labels ((construir-no (indice variante)
               (let* ((no (aref nos-json indice)) (malha-i (%json no "mesh"))
                      (objeto (make-group)))
                 (%aplicar-transformacao-gltf objeto no)
                 (when malha-i
                   (multiple-value-bind (quantidade matrizes)
                       (%dados-de-instancias-gltf documento buffers no)
                     (loop for p across (aref geometrias malha-i) do
                       (let* ((geometria (car p)) (primitiva (cdr p))
                              (material (%material-da-primitiva primitiva materiais variante))
                              (malha (if quantidade
                                        (make-instanced-mesh geometria material quantidade)
                                        (make-mesh geometria material))))
                         (when quantidade
                           (loop for matriz in matrizes for i from 0 do
                             (set-instance-matrix malha i matriz)))
                         (add-child objeto malha)))))
                 (loop for filho across (%vetor-json no "children") do
                   (add-child objeto (construir-no filho variante)))
                 (let ((camera-i (%json no "camera")))
                   (when camera-i
                     (let ((camera (%camera-gltf (aref cameras-json camera-i))))
                       (setf (gethash (%json no "name" (format nil "camera-~D" camera-i)) nomes-cameras) camera)
                       (add-child objeto camera))))
                 (let* ((extensao (%json (%json no "extensions") "KHR_lights_punctual"))
                        (luz-i (%json extensao "light")))
                   (when luz-i
                     (let ((luz (%luz-gltf (aref luzes-json luz-i))))
                       (add-child objeto luz)
                       (when (or (typep luz 'directional-light) (typep luz 'spot-light))
                         (set-position (target luz) 0 0 -1)
                         (add-child objeto (target luz))))))
                 objeto))
             (construir-cena (indice variante)
               (let* ((descritor (aref cenas-json indice))
                      (cena (make-scene :name (%json descritor "name" ""))))
                 (loop for no across (%vetor-json descritor "nodes") do
                   (add-child cena (construir-no no variante)))
                 cena)))
      (let* ((nomes (loop for cena across cenas-json for indice from 0
                          collect (or (%json cena "name") indice)))
             (padrao (%json documento "scene" 0))
             (metagrafo (list :format :gltf-2.0 :source (namestring caminho)
                              :scene-count (length cenas-json) :default-scene padrao)))
        (make-instance 'scene-asset :scenes nomes :cameras nomes-cameras :variants variantes
                       :metagraph metagrafo :resources *recursos-gltf*
                       :metadata (list :warnings avisos :document documento)
                       :factory (lambda (selecao variante)
                                  (let ((indice (cond ((integerp selecao) selecao)
                                                      ((stringp selecao) (cl:position selecao nomes :test #'equal))
                                                      (t padrao)))
                                        (variante-i (%indice-de-variante variante variantes)))
                                    (when (and variante (null variante-i))
                                      (error 'gltf-error :message "A variante glTF solicitada não existe."
                                             :path caminho :stage :instantiate))
                                    (construir-cena (or indice padrao) variante-i)))))))))

(defun load-gltf (path &key (manager (default-loading-manager)))
  "Carrega e valida um arquivo glTF 2.0 ou GLB local."
  (let* ((caminho (uiop:ensure-pathname path :want-existing t))
         (tipo (string-downcase (or (pathname-type caminho) "")))
         (dados (%ler-octetos caminho)) (documento nil) (binario nil))
    (handler-case
        (progn
          (if (string= tipo "glb")
              (multiple-value-setq (documento binario) (%ler-glb dados caminho))
              (setf documento (com.inuoe.jzon:parse (%texto-utf8 dados))))
          (unless (string= (%json (%json documento "asset") "version") "2.0")
            (error 'gltf-error :message "O asset não declara glTF 2.0." :path caminho :stage :validate))
          (let ((avisos (%validar-extensoes-gltf documento caminho))
                (buffers (%carregar-buffers-gltf documento binario
                                                 (uiop:pathname-directory-pathname caminho) manager)))
            (%construir-asset-gltf documento buffers caminho avisos manager)))
      (gltf-error (condicao) (error condicao))
      (error (condicao)
        (error 'gltf-error :message (format nil "Falha ao carregar glTF: ~A" condicao)
               :path caminho :stage :parse :cause condicao)))))

(defun load-gltf-async (path &key (manager (default-loading-manager)))
  "Inicia leitura e parsing glTF fora do thread de renderização."
  (let ((chave (namestring (uiop:ensure-pathname path :want-existing t))))
    (or (let ((valor (gethash chave (%cache-de-assets manager))))
          (when valor
            (let ((job (make-instance 'load-job)))
              (setf (job-status job) :completed (job-stage job) :complete
                    (job-progress job) 1.0f0 (job-result job) valor)
              job)))
        (%iniciar-job manager chave
                      (lambda (job)
                        (setf (job-stage job) :parse (job-progress job) 0.35f0)
                        (load-gltf path :manager manager))))))
