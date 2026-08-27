(in-package #:flegrea)

(defgeneric before-update (object delta time))
(defgeneric update (object delta time))
(defgeneric after-update (object delta time))
(defgeneric before-render (object renderer scene camera))
(defgeneric after-render (object renderer scene camera))

(defmethod before-update ((objeto t) delta tempo)
  (declare (ignore delta tempo)) objeto)
(defmethod update ((objeto t) delta tempo)
  (declare (ignore delta tempo)) objeto)
(defmethod after-update ((objeto t) delta tempo)
  (declare (ignore delta tempo)) objeto)
(defmethod before-render ((objeto t) renderizador cena camera)
  (declare (ignore renderizador cena camera)) objeto)
(defmethod after-render ((objeto t) renderizador cena camera)
  (declare (ignore renderizador cena camera)) objeto)

(defun %indice-de-camada (camada)
  (unless (and (integerp camada) (<= 0 camada 31))
    (error 'validation-error :message "A camada precisa estar entre zero e trinta e um."))
  camada)

(defun enable-layer (objeto camada)
  "Habilita uma camada de visibilidade."
  (setf (layers objeto) (logior (layers objeto) (ash 1 (%indice-de-camada camada))))
  objeto)

(defun disable-layer (objeto camada)
  "Desabilita uma camada de visibilidade."
  (setf (layers objeto) (logandc2 (layers objeto) (ash 1 (%indice-de-camada camada))))
  objeto)

(defun toggle-layer (objeto camada)
  "Alterna uma camada de visibilidade."
  (setf (layers objeto) (logxor (layers objeto) (ash 1 (%indice-de-camada camada))))
  objeto)

(defun layer-enabled-p (objeto camada)
  "Informa se uma camada está habilitada."
  (logbitp (%indice-de-camada camada) (layers objeto)))

(defun layers-match-p (a b)
  "Informa se dois objetos compartilham ao menos uma camada."
  (not (zerop (logand (layers a) (layers b)))))

(defclass line (object-3d)
  ((geometria :initarg :geometry :accessor geometry)
   (material-da-linha :initarg :material :accessor material)))

(defclass line-segments (line) ())

(defclass points (object-3d)
  ((geometria :initarg :geometry :accessor geometry)
   (material-dos-pontos :initarg :material :accessor material)))

(defclass sprite (object-3d)
  ((material-do-sprite :initarg :material :accessor material)))

(defclass instanced-mesh (mesh)
  ((quantidade-de-instancias :initarg :count :accessor instance-count)
   (matrizes-de-instancia :initarg :matrices :accessor instance-matrices)
   (cores-de-instancia :initarg :colors :initform nil :accessor instance-colors)))

(defun make-line (geometry material &key (name "") (visible t))
  "Cria uma linha contínua."
  (make-instance 'line :geometry geometry :material material :name name :visible visible))

(defun make-line-segments (geometry material &key (name "") (visible t))
  "Cria segmentos de linha independentes."
  (make-instance 'line-segments :geometry geometry :material material :name name :visible visible))

(defun make-points (geometry material &key (name "") (visible t))
  "Cria um conjunto de pontos."
  (make-instance 'points :geometry geometry :material material :name name :visible visible))

(defun make-sprite (material &key (name "") (visible t))
  "Cria um sprite orientado à câmera."
  (make-instance 'sprite :material material :name name :visible visible))

(defun make-instanced-mesh (geometry material count &key (name "") (visible t))
  "Cria uma malha instanciada com matrizes identidade."
  (unless (and (integerp count) (plusp count))
    (error 'validation-error :message "A quantidade de instâncias precisa ser positiva."))
  (make-instance 'instanced-mesh :geometry geometry :material material :count count
                 :matrices (make-array count :initial-contents
                                       (loop repeat count collect (make-matrix4)))
                 :name name :visible visible))

(defun set-instance-matrix (mesh index matrix)
  "Define a matriz de uma instância."
  (unless (and (typep mesh 'instanced-mesh) (<= 0 index) (< index (instance-count mesh))
               (typep matrix 'matrix4))
    (error 'validation-error :message "Índice ou matriz de instância inválido."))
  (setf (aref (instance-matrices mesh) index) (clone matrix))
  mesh)

(defun set-instance-color (mesh index color)
  "Define a cor de uma instância."
  (unless (and (typep mesh 'instanced-mesh) (<= 0 index) (< index (instance-count mesh))
               (typep color 'color))
    (error 'validation-error :message "Índice ou cor de instância inválido."))
  (unless (instance-colors mesh)
    (setf (instance-colors mesh) (make-array (instance-count mesh) :initial-element nil)))
  (setf (aref (instance-colors mesh) index) (clone color))
  mesh)
