(in-package #:flegrea)

(defclass mesh-physical-material (mesh-standard-material)
  ((verniz :initarg :clearcoat :initform 0.0f0 :accessor clearcoat)
   (rugosidade-do-verniz :initarg :clearcoat-roughness :initform 0.0f0
                         :accessor clearcoat-roughness)
   (transmissao :initarg :transmission :initform 0.0f0 :accessor transmission)
   (espessura :initarg :thickness :initform 0.0f0 :accessor thickness)
   (indice-de-refracao :initarg :ior :initform 1.5f0 :accessor ior)
   (cor-de-atenuacao :initarg :attenuation-color :initform (make-color)
                     :accessor attenuation-color)
   (distancia-de-atenuacao :initarg :attenuation-distance :initform most-positive-single-float
                           :accessor attenuation-distance)
   (mapa-de-verniz :initarg :clearcoat-map :initform nil :accessor clearcoat-map)
   (mapa-normal-do-verniz :initarg :clearcoat-normal-map :initform nil
                          :accessor clearcoat-normal-map)
   (mapa-rugosidade-do-verniz :initarg :clearcoat-roughness-map :initform nil
                              :accessor clearcoat-roughness-map)
   (mapa-de-transmissao :initarg :transmission-map :initform nil :accessor transmission-map)
   (mapa-de-espessura :initarg :thickness-map :initform nil :accessor thickness-map)))

(defclass mesh-normal-material (material-base) ())
(defclass mesh-depth-material (material-base) ())
(defclass line-material (material-base)
  ((largura :initarg :line-width :initform 1.0f0 :accessor line-width)))
(defclass points-material (material-base)
  ((tamanho :initarg :point-size :initform 1.0f0 :accessor point-size)
   (atenua-tamanho :initarg :size-attenuation :initform t :accessor size-attenuation)))
(defclass sprite-material (material-base) ())

(defun %fracao-unitaria (valor nome)
  (unless (and (realp valor) (<= 0 valor 1))
    (error 'validation-error :message (format nil "~A precisa estar entre zero e um." nome)))
  (coerce valor 'single-float))

(defmethod initialize-instance :after ((material mesh-physical-material) &key)
  (setf (clearcoat material) (%fracao-unitaria (clearcoat material) "Clearcoat")
        (clearcoat-roughness material)
        (%fracao-unitaria (clearcoat-roughness material) "Clearcoat-roughness")
        (transmission material) (%fracao-unitaria (transmission material) "Transmission"))
  (unless (and (realp (thickness material)) (not (minusp (thickness material)))
               (realp (ior material)) (<= 1.0 (ior material) 2.333))
    (error 'validation-error :message "Thickness ou IOR inválido."))
  (setf (attenuation-color material) (clone (attenuation-color material))))

(defun make-mesh-physical-material (&rest argumentos &key &allow-other-keys)
  "Cria um material físico com verniz e transmissão."
  (apply #'make-instance 'mesh-physical-material argumentos))

(defun make-mesh-normal-material (&rest argumentos &key &allow-other-keys)
  "Cria um material que visualiza normais."
  (apply #'make-instance 'mesh-normal-material argumentos))

(defun make-mesh-depth-material (&rest argumentos &key &allow-other-keys)
  "Cria um material que visualiza profundidade."
  (apply #'make-instance 'mesh-depth-material argumentos))

(defun make-line-material (&rest argumentos &key &allow-other-keys)
  "Cria um material de linhas."
  (apply #'make-instance 'line-material argumentos))

(defun make-points-material (&rest argumentos &key &allow-other-keys)
  "Cria um material de pontos."
  (apply #'make-instance 'points-material argumentos))

(defun make-sprite-material (&rest argumentos &key &allow-other-keys)
  "Cria um material de sprite."
  (apply #'make-instance 'sprite-material argumentos))

(defmethod dispose ((material material-base))
  (unless (disposed-p material)
    (setf (base-color-map material) nil (opacity-map material) nil))
  (call-next-method))

(defclass light-shadow ()
  ((tamanho-do-mapa :initarg :map-size :initform (make-vector2 1024 1024)
                    :accessor shadow-map-size)
   (deslocamento :initarg :bias :initform 0.0f0 :accessor shadow-bias)
   (deslocamento-normal :initarg :normal-bias :initform 0.0f0 :accessor shadow-normal-bias)
   (camera-da-sombra :initarg :camera :initform nil :accessor shadow-camera)))

(defclass spot-light (point-light)
  ((alvo :initarg :target :initform (make-object-3d) :accessor target)
   (angulo :initarg :angle :initform (/ pi 3) :accessor angle)
   (penumbra-da-luz :initarg :penumbra :initform 0.0f0 :accessor penumbra)))

(defclass hemisphere-light (light)
  ((cor-do-solo :initarg :ground-color :initform (make-color 0.25 0.25 0.25)
                :accessor ground-color)))

(defmethod initialize-instance :after ((luz spot-light) &key)
  (unless (and (> (angle luz) 0) (<= (angle luz) (/ pi 2))
               (<= 0 (penumbra luz) 1))
    (error 'validation-error :message "Angle ou penumbra da luz spot é inválido.")))

(defmethod initialize-instance :after ((luz hemisphere-light) &key)
  (setf (ground-color luz) (clone (ground-color luz))))

(defun make-spot-light (&key (color (make-color)) (intensity 1.0f0) (distance 0.0f0)
                             (decay 2.0f0) (angle (/ pi 3)) (penumbra 0.0f0)
                             (target (make-object-3d)) shadow (name ""))
  "Cria uma luz cônica."
  (make-instance 'spot-light :color color :intensity intensity :distance distance :decay decay
                 :angle angle :penumbra penumbra :target target :shadow shadow :name name))

(defun make-hemisphere-light (&key (color (make-color))
                                   (ground-color (make-color 0.25 0.25 0.25))
                                   (intensity 1.0f0) (name ""))
  "Cria uma luz hemisférica de céu e solo."
  (make-instance 'hemisphere-light :color color :ground-color ground-color
                 :intensity intensity :name name))
