(in-package #:flegrea.materials)

(defun %cor-copiada (valor)
  (cond ((typep valor 'flegrea:color) (clone valor))
        ((typep valor 'vector3)
         (flegrea:make-color (flegrea:x valor) (flegrea:y valor) (flegrea:z valor)))
        (t (error 'validation-error :message "A cor deve ser uma instância de color."))))

(defclass material-base (flegrea:resource)
  ((color :initarg :color :initform (flegrea:make-color) :accessor color)
   (vertex-colors :initarg :vertex-colors :initform nil :accessor vertex-colors)
   (lado :initarg :side :initform :front :accessor side)
   (grava-profundidade :initarg :depth-write :initform t :accessor depth-write)
   (testa-profundidade :initarg :depth-test :initform t :accessor flegrea:depth-test)
   (transparente :initarg :transparent :initform nil :accessor flegrea:transparent)
   (opacidade :initarg :opacity :initform 1.0f0 :accessor flegrea:opacity)
   (modo-alfa :initarg :alpha-mode :initform :opaque :accessor flegrea:alpha-mode)
   (teste-alfa :initarg :alpha-test :initform 0.0f0 :accessor flegrea:alpha-test)
   (mistura :initarg :blending :initform :normal :accessor flegrea:blending)
   (mapa-de-cor :initarg :base-color-map :initform nil :accessor flegrea:base-color-map)
   (mapa-de-opacidade :initarg :opacity-map :initform nil :accessor flegrea:opacity-map)))
(defclass mesh-basic-material (material-base) ())
(defclass mesh-standard-material (material-base)
  ((roughness :initarg :roughness :initform 0.5f0 :accessor roughness)
   (metalness :initarg :metalness :initform 0.0f0 :accessor metalness)
   (emissive :initarg :emissive :initform (flegrea:make-color 0 0 0 :color-space :linear)
             :accessor emissive)
   (intensidade-emissiva :initarg :emissive-intensity :initform 1.0f0
                         :accessor flegrea:emissive-intensity)
   (escala-normal :initarg :normal-scale :initform (flegrea:make-vector2 1 1)
                  :accessor flegrea:normal-scale)
   (forca-da-oclusao :initarg :occlusion-strength :initform 1.0f0
                     :accessor flegrea:occlusion-strength)
   (mapa-normal :initarg :normal-map :initform nil :accessor flegrea:normal-map)
   (mapa-metalico-rugoso :initarg :metallic-roughness-map :initform nil
                         :accessor flegrea:metallic-roughness-map)
   (mapa-emissivo :initarg :emissive-map :initform nil :accessor flegrea:emissive-map)
   (mapa-oclusao :initarg :occlusion-map :initform nil :accessor flegrea:occlusion-map)))
(defclass shader-material (material-base)
  ((vertex-shader :initarg :vertex-shader :accessor vertex-shader)
   (fragment-shader :initarg :fragment-shader :accessor fragment-shader)
   (uniforms :initarg :uniforms :reader uniforms)
   ))

(defmethod initialize-instance :after ((valor material-base) &key)
  (setf (color valor) (%cor-copiada (color valor)))
  (unless (member (side valor) '(:front :back :double))
    (error 'validation-error :message "Side precisa ser :front, :back ou :double."))
  (unless (and (realp (flegrea:opacity valor)) (<= 0 (flegrea:opacity valor) 1))
    (error 'validation-error :message "Opacity precisa estar entre zero e um.")))
(defmethod initialize-instance :after ((valor mesh-standard-material) &key)
  (unless (and (realp (roughness valor)) (<= 0 (roughness valor) 1)
               (realp (metalness valor)) (<= 0 (metalness valor) 1))
    (error 'validation-error :message "Roughness e metalness precisam estar entre zero e um."))
  (setf (roughness valor) (coerce (roughness valor) 'single-float)
        (metalness valor) (coerce (metalness valor) 'single-float)
        (emissive valor) (%cor-copiada (emissive valor))
        (flegrea:normal-scale valor) (clone (flegrea:normal-scale valor)))
  (unless (and (realp (flegrea:emissive-intensity valor))
               (not (minusp (flegrea:emissive-intensity valor)))
               (realp (flegrea:occlusion-strength valor))
               (<= 0 (flegrea:occlusion-strength valor) 1))
    (error 'validation-error
           :message "Emissive-intensity ou occlusion-strength inválido."))
  (setf (flegrea:emissive-intensity valor)
        (coerce (flegrea:emissive-intensity valor) 'single-float)
        (flegrea:occlusion-strength valor)
        (coerce (flegrea:occlusion-strength valor) 'single-float)))

(defun %tabela-uniformes (valores)
  (let ((tabela (make-hash-table :test #'equal)))
    (cond
      ((hash-table-p valores)
       (maphash (lambda (nome valor) (setf (gethash (string nome) tabela) valor)) valores))
      ((null valores) nil)
      ((and (listp valores) (evenp (length valores)))
       (loop for (nome valor) on valores by #'cddr do
         (unless (or (stringp nome) (symbolp nome))
           (error 'validation-error :message "O nome de um uniforme precisa ser string ou símbolo."))
         (setf (gethash (string nome) tabela) valor)))
      (t (error 'validation-error :message "A coleção de uniformes precisa ser uma plist de nomes e valores.")))
    tabela))

(defmethod initialize-instance :after ((valor shader-material) &key)
  (unless (and (stringp (vertex-shader valor)) (plusp (length (vertex-shader valor)))
               (stringp (fragment-shader valor)) (plusp (length (fragment-shader valor))))
    (error 'validation-error :message "As fontes dos shaders precisam ser strings não vazias."))
  (unless (member (side valor) '(:front :back :double))
    (error 'validation-error :message "Side precisa ser :front, :back ou :double.")))

(defun make-mesh-basic-material (&key (color (flegrea:make-color)) (vertex-colors nil)
                                      base-color-map opacity-map (opacity 1.0f0)
                                      (transparent nil) (alpha-mode :opaque) (alpha-test 0.0f0)
                                      (blending :normal) (side :front)
                                      (depth-write t) (depth-test t))
  "Cria um material sem iluminação."
  (make-instance 'mesh-basic-material :color color :vertex-colors vertex-colors
                 :base-color-map base-color-map :opacity-map opacity-map
                 :opacity opacity :transparent transparent :alpha-mode alpha-mode
                 :alpha-test alpha-test :blending blending :side side
                 :depth-write depth-write :depth-test depth-test))
(defun make-mesh-standard-material (&key (color (flegrea:make-color)) (roughness 0.5f0)
                                         (metalness 0.0f0)
                                         (emissive (flegrea:make-color 0 0 0 :color-space :linear))
                                         (emissive-intensity 1.0f0)
                                         (normal-scale (flegrea:make-vector2 1 1))
                                         (occlusion-strength 1.0f0)
                                         (vertex-colors nil) base-color-map normal-map
                                         metallic-roughness-map emissive-map occlusion-map opacity-map
                                         (opacity 1.0f0) (transparent nil) (alpha-mode :opaque)
                                         (alpha-test 0.0f0) (blending :normal) (side :front)
                                         (depth-write t) (depth-test t))
  "Cria um material PBR metálico-rugoso."
  (make-instance 'mesh-standard-material :color color :roughness roughness :metalness metalness
                  :emissive emissive :emissive-intensity emissive-intensity
                  :normal-scale normal-scale :occlusion-strength occlusion-strength
                  :vertex-colors vertex-colors :base-color-map base-color-map
                  :normal-map normal-map :metallic-roughness-map metallic-roughness-map
                  :emissive-map emissive-map :occlusion-map occlusion-map :opacity-map opacity-map
                  :opacity opacity :transparent transparent :alpha-mode alpha-mode
                  :alpha-test alpha-test :blending blending :side side
                  :depth-write depth-write :depth-test depth-test))

(defun make-shader-material (&key ((:vertex-shader fonte-vertice))
                                  ((:fragment-shader fonte-fragmento))
                                  ((:uniforms valores-uniformes) nil)
                                  ((:side lado) :front)
                                  ((:depth-write grava-profundidade) t)
                                  ((:depth-test testa-profundidade) t)
                                  ((:transparent transparente) nil)
                                  ((:opacity opacidade) 1.0f0)
                                  ((:blending mistura) :normal))
  "Cria um material programável com fontes GLSL e uniformes próprios."
  (make-instance 'shader-material
                 :vertex-shader fonte-vertice :fragment-shader fonte-fragmento
                 :uniforms (%tabela-uniformes valores-uniformes)
                 :side lado :depth-write grava-profundidade :depth-test testa-profundidade
                 :transparent transparente :opacity opacidade :blending mistura))

(defun uniform (material name &optional default)
  "Obtém o valor de um uniforme do material programável."
  (gethash (string name) (uniforms material) default))

(defun set-uniform (material name value)
  "Define o valor de um uniforme do material programável."
  (setf (gethash (string name) (uniforms material)) value)
  material)

(defclass light (object-3d)
  ((color :initarg :color :initform (flegrea:make-color) :accessor color)
   (intensity :initarg :intensity :initform 1.0f0 :accessor intensity)
   (sombra :initarg :shadow :initform nil :accessor flegrea:shadow)))
(defclass ambient-light (light) ())
(defclass directional-light (light)
  ((target :initarg :target :initform (flegrea:make-object-3d) :accessor target)))
(defclass point-light (light)
  ((distance :initarg :distance :initform 0.0f0 :accessor distance)
   (decay :initarg :decay :initform 2.0f0 :accessor decay)))

(defmethod initialize-instance :after ((valor light) &key)
  (when (minusp (intensity valor))
    (error 'validation-error :message "A intensidade de uma luz não pode ser negativa."))
  (setf (color valor) (%cor-copiada (color valor))
        (intensity valor) (coerce (intensity valor) 'single-float)))
(defmethod initialize-instance :after ((valor point-light) &key)
  (when (or (minusp (distance valor)) (minusp (decay valor)))
    (error 'validation-error :message "Distance e decay de uma luz pontual não podem ser negativos."))
  (setf (distance valor) (coerce (distance valor) 'single-float)
        (decay valor) (coerce (decay valor) 'single-float)))

(defun make-ambient-light (&key (color (flegrea:make-color)) (intensity 1.0f0) (name ""))
  "Cria uma luz ambiente."
  (make-instance 'ambient-light :color color :intensity intensity :name name))
(defun make-directional-light (&key (color (flegrea:make-color)) (intensity 1.0f0)
                                    (target (flegrea:make-object-3d)) shadow (name ""))
  "Cria uma luz direcional."
  (make-instance 'directional-light :color color :intensity intensity :target target
                 :shadow shadow :name name))
(defun make-point-light (&key (color (flegrea:make-color)) (intensity 1.0f0)
                              (distance 0.0f0) (decay 2.0f0) shadow (name ""))
  "Cria uma luz pontual."
  (make-instance 'point-light :color color :intensity intensity :distance distance :decay decay
                 :shadow shadow :name name))
