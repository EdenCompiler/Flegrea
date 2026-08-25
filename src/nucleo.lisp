(in-package #:flegrea.core)

(defclass object-3d ()
  ((position :initarg :position :initform (make-vector3) :accessor position)
   (rotation :initarg :rotation :initform (make-euler) :accessor rotation)
   (scale :initarg :scale :initform (make-vector3 1 1 1) :accessor scale)
   (parent :initform nil :accessor parent)
   (children :initform nil :accessor children)
   (matrix :initform (make-matrix4) :accessor matrix)
   (matrix-world :initform (make-matrix4) :accessor matrix-world)
   (visible :initarg :visible :initform t :accessor visible)
   (name :initarg :name :initform "" :accessor name)))

(defclass scene (object-3d) ())
(defclass group (object-3d) ())
(defclass mesh (object-3d)
  ((geometry :initarg :geometry :accessor geometry)
   (material :initarg :material :accessor material)))

(defclass camera (object-3d)
  ((projection-matrix :initform (make-matrix4) :accessor projection-matrix)
   (view-matrix :initform (make-matrix4) :accessor view-matrix)))

(defclass perspective-camera (camera)
  ((fov :initarg :fov :initform 50.0f0 :accessor fov)
   (aspect :initarg :aspect :initform 1.0f0 :accessor aspect)
   (near :initarg :near :initform 0.1f0 :accessor near)
   (far :initarg :far :initform 2000.0f0 :accessor far)
   (zoom :initarg :zoom :initform 1.0f0 :accessor zoom)))

(defclass orthographic-camera (camera)
  ((left :initarg :left :initform -1.0f0 :accessor left)
   (right :initarg :right :initform 1.0f0 :accessor right)
   (top :initarg :top :initform 1.0f0 :accessor top)
   (bottom :initarg :bottom :initform -1.0f0 :accessor bottom)
   (near :initarg :near :initform 0.1f0 :accessor near)
   (far :initarg :far :initform 2000.0f0 :accessor far)
   (zoom :initarg :zoom :initform 1.0f0 :accessor zoom)))

(defgeneric update-projection-matrix (camera))

(defmethod initialize-instance :after ((objeto perspective-camera) &key)
  (update-projection-matrix objeto))
(defmethod initialize-instance :after ((objeto orthographic-camera) &key)
  (update-projection-matrix objeto))

(defun make-object-3d (&key (name "") (visible t))
  "Cria um objeto base do grafo de cena."
  (make-instance 'object-3d :name name :visible visible))
(defun make-scene (&key (name "") (visible t))
  "Cria uma cena."
  (make-instance 'scene :name name :visible visible))
(defun make-group (&key (name "") (visible t))
  "Cria um grupo."
  (make-instance 'group :name name :visible visible))
(defun make-mesh (geometry material &key (name "") (visible t))
  "Cria uma malha com geometria e material."
  (make-instance 'mesh :geometry geometry :material material :name name :visible visible))
(defun make-perspective-camera (&key (fov 50.0f0) (aspect 1.0f0) (near 0.1f0) (far 2000.0f0) (zoom 1.0f0) (name ""))
  "Cria uma câmera perspectiva."
  (make-instance 'perspective-camera :fov fov :aspect aspect :near near :far far :zoom zoom :name name))
(defun make-orthographic-camera (&key (left -1.0f0) (right 1.0f0) (top 1.0f0) (bottom -1.0f0)
                                      (near 0.1f0) (far 2000.0f0) (zoom 1.0f0) (name ""))
  "Cria uma câmera ortográfica."
  (make-instance 'orthographic-camera :left left :right right :top top :bottom bottom
                                      :near near :far far :zoom zoom :name name))

(defun %ancestral-p (possivel-ancestral objeto)
  (loop for atual = objeto then (parent atual)
        while atual thereis (eq atual possivel-ancestral)))

(defun remove-child (objeto filho)
  "Remove um filho do objeto."
  (when (member filho (children objeto) :test #'eq)
    (setf (children objeto) (remove filho (children objeto) :test #'eq)
          (parent filho) nil))
  objeto)

(defun add-child (objeto filho)
  "Adiciona um filho, preservando uma única relação de parentesco."
  (when (or (eq objeto filho) (%ancestral-p filho objeto))
    (error 'validation-error :message "O grafo de cena não aceita ciclos de parentesco."))
  (unless (eq (parent filho) objeto)
    (when (parent filho) (remove-child (parent filho) filho))
    (setf (children objeto) (append (children objeto) (list filho))
          (parent filho) objeto))
  objeto)

(defun traverse (objeto funcao)
  "Percorre o objeto e seus descendentes em pré-ordem."
  (funcall funcao objeto)
  (dolist (filho (children objeto)) (traverse filho funcao))
  objeto)

(defun set-position (objeto x y z)
  "Altera a posição local do objeto."
  (set-vector3 (position objeto) x y z) objeto)
(defun set-rotation (objeto x y z &optional (order (order (rotation objeto))))
  "Altera a rotação Euler local do objeto."
  (set-euler (rotation objeto) x y z order) objeto)
(defun set-scale (objeto x y z)
  "Altera a escala local do objeto."
  (set-vector3 (scale objeto) x y z) objeto)

(defun update-matrix (objeto)
  "Atualiza a matriz local a partir das propriedades do objeto."
  (let ((giro (set-from-euler (make-quaternion) (rotation objeto))))
    (compose-matrix4 (matrix objeto) (position objeto) giro (scale objeto)))
  objeto)

(defun update-matrix-world (objeto &optional (atualizar-filhos t))
  "Atualiza a matriz mundial do objeto e, opcionalmente, dos descendentes."
  (update-matrix objeto)
  (if (parent objeto)
      (progn (copy-from (matrix-world objeto) (matrix-world (parent objeto)))
             (matrix-multiply (matrix-world objeto) (matrix objeto)))
      (copy-from (matrix-world objeto) (matrix objeto)))
  (when (typep objeto 'camera)
    (copy-from (view-matrix objeto) (matrix-world objeto))
    (matrix-invert (view-matrix objeto)))
  (when atualizar-filhos
    (dolist (filho (children objeto)) (update-matrix-world filho t)))
  objeto)

(defun look-at (objeto alvo &optional (acima (make-vector3 0 1 0)))
  "Orienta um objeto para um ponto no espaço mundial."
  (let ((orientacao (make-matrix4)) (giro (make-quaternion))
        (posicao-temporaria (make-vector3)) (escala-temporaria (make-vector3)))
    (look-at-matrix4 orientacao (position objeto) alvo acima)
    (flegrea:decompose-matrix4 orientacao posicao-temporaria giro escala-temporaria)
    (flegrea:set-from-quaternion (rotation objeto) giro))
  objeto)

(defmethod update-projection-matrix ((camera perspective-camera))
  (when (or (<= (near camera) 0) (<= (far camera) (near camera)) (<= (aspect camera) 0) (<= (zoom camera) 0))
    (error 'validation-error :message "Os parâmetros da câmera perspectiva são inválidos."))
  (set-perspective-matrix4 (projection-matrix camera) (/ (fov camera) (zoom camera))
                           (aspect camera) (near camera) (far camera))
  camera)
(defmethod update-projection-matrix ((camera orthographic-camera))
  (when (or (<= (far camera) (near camera)) (<= (zoom camera) 0))
    (error 'validation-error :message "Os parâmetros da câmera ortográfica são inválidos."))
  (let* ((meio-x (/ (+ (left camera) (right camera)) 2.0f0))
         (meio-y (/ (+ (top camera) (bottom camera)) 2.0f0))
         (metade-x (/ (- (right camera) (left camera)) (* 2.0f0 (zoom camera))))
         (metade-y (/ (- (top camera) (bottom camera)) (* 2.0f0 (zoom camera)))))
    (set-orthographic-matrix4 (projection-matrix camera)
                              (- meio-x metade-x) (+ meio-x metade-x)
                              (+ meio-y metade-y) (- meio-y metade-y)
                              (near camera) (far camera))) camera)
