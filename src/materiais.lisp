(in-package #:flegrea.materials)

(defun %cor-copiada (valor)
  (unless (and (typep valor 'vector3)
               (<= 0 (flegrea:x valor) 1) (<= 0 (flegrea:y valor) 1) (<= 0 (flegrea:z valor) 1))
    (error 'validation-error :message "A cor deve ser vector3 sRGB com componentes entre zero e um."))
  (clone valor))

(defclass material-base ()
  ((color :initarg :color :initform (make-vector3 1 1 1) :accessor color)
   (vertex-colors :initarg :vertex-colors :initform nil :accessor vertex-colors)))
(defclass mesh-basic-material (material-base) ())
(defclass mesh-standard-material (material-base)
  ((roughness :initarg :roughness :initform 0.5f0 :accessor roughness)
   (metalness :initarg :metalness :initform 0.0f0 :accessor metalness)
   (emissive :initarg :emissive :initform (make-vector3) :accessor emissive)))
(defclass shader-material (material-base)
  ((vertex-shader :initarg :vertex-shader :accessor vertex-shader)
   (fragment-shader :initarg :fragment-shader :accessor fragment-shader)
   (uniforms :initarg :uniforms :reader uniforms)
   (side :initarg :side :initform :front :accessor side)
   (depth-write :initarg :depth-write :initform t :accessor depth-write)))

(defmethod initialize-instance :after ((valor material-base) &key)
  (setf (color valor) (%cor-copiada (color valor))))
(defmethod initialize-instance :after ((valor mesh-standard-material) &key)
  (unless (and (realp (roughness valor)) (<= 0 (roughness valor) 1)
               (realp (metalness valor)) (<= 0 (metalness valor) 1))
    (error 'validation-error :message "Roughness e metalness precisam estar entre zero e um."))
  (setf (roughness valor) (coerce (roughness valor) 'single-float)
        (metalness valor) (coerce (metalness valor) 'single-float)
        (emissive valor) (%cor-copiada (emissive valor))))

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

(defun make-mesh-basic-material (&key (color (make-vector3 1 1 1)) (vertex-colors nil))
  "Cria um material sem iluminação."
  (make-instance 'mesh-basic-material :color color :vertex-colors vertex-colors))
(defun make-mesh-standard-material (&key (color (make-vector3 1 1 1)) (roughness 0.5f0)
                                         (metalness 0.0f0) (emissive (make-vector3)) (vertex-colors nil))
  "Cria um material PBR metálico-rugoso."
  (make-instance 'mesh-standard-material :color color :roughness roughness :metalness metalness
                                          :emissive emissive :vertex-colors vertex-colors))

(defun make-shader-material (&key ((:vertex-shader fonte-vertice))
                                  ((:fragment-shader fonte-fragmento))
                                  ((:uniforms valores-uniformes) nil)
                                  ((:side lado) :front)
                                  ((:depth-write grava-profundidade) t))
  "Cria um material programável com fontes GLSL e uniformes próprios."
  (make-instance 'shader-material
                 :vertex-shader fonte-vertice :fragment-shader fonte-fragmento
                 :uniforms (%tabela-uniformes valores-uniformes)
                 :side lado :depth-write grava-profundidade))

(defun uniform (material name &optional default)
  "Obtém o valor de um uniforme do material programável."
  (gethash (string name) (uniforms material) default))

(defun set-uniform (material name value)
  "Define o valor de um uniforme do material programável."
  (setf (gethash (string name) (uniforms material)) value)
  material)

(defclass light (object-3d)
  ((color :initarg :color :initform (make-vector3 1 1 1) :accessor color)
   (intensity :initarg :intensity :initform 1.0f0 :accessor intensity)))
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

(defun make-ambient-light (&key (color (make-vector3 1 1 1)) (intensity 1.0f0) (name ""))
  "Cria uma luz ambiente."
  (make-instance 'ambient-light :color color :intensity intensity :name name))
(defun make-directional-light (&key (color (make-vector3 1 1 1)) (intensity 1.0f0)
                                    (target (flegrea:make-object-3d)) (name ""))
  "Cria uma luz direcional."
  (make-instance 'directional-light :color color :intensity intensity :target target :name name))
(defun make-point-light (&key (color (make-vector3 1 1 1)) (intensity 1.0f0)
                              (distance 0.0f0) (decay 2.0f0) (name ""))
  "Cria uma luz pontual."
  (make-instance 'point-light :color color :intensity intensity :distance distance :decay decay :name name))
