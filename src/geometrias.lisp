(in-package #:flegrea.geometry)

(defclass buffer-attribute ()
  ((attribute-array :initarg :array :accessor attribute-array)
   (item-size :initarg :item-size :accessor item-size)
   (normalized :initarg :normalized :initform nil :accessor normalized)
   (usage :initarg :usage :initform :static-draw :accessor usage)
   (needs-update :initarg :needs-update :initform t :accessor needs-update)))

(defclass buffer-geometry ()
  ((attributes :initform (make-hash-table :test #'eq) :accessor attributes)
   (index :initform nil :accessor index)))
(defclass box-geometry (buffer-geometry) ())
(defclass sphere-geometry (buffer-geometry) ())
(defclass plane-geometry (buffer-geometry) ())

(defun %vetor-float (dados)
  (let ((saida (make-array (length dados) :element-type 'single-float)))
    (loop for valor across (coerce dados 'vector) for indice from 0 do
      (unless (realp valor) (error 'validation-error :message "Um atributo de vértice contém valor não numérico."))
      (setf (aref saida indice) (coerce valor 'single-float)))
    saida))

(defun %vetor-indice (dados)
  (let ((saida (make-array (length dados) :element-type '(unsigned-byte 32))))
    (loop for valor across (coerce dados 'vector) for indice from 0 do
      (unless (and (integerp valor) (not (minusp valor)))
        (error 'validation-error :message "Um índice de geometria precisa ser inteiro e não negativo."))
      (setf (aref saida indice) valor))
    saida))

(defun make-buffer-attribute (data item-size &key (normalized nil) (usage :static-draw) (index-data nil))
  "Cria um atributo copiando e especializando a sequência recebida."
  (unless (and (integerp item-size) (<= 1 item-size 4))
    (error 'validation-error :message "O tamanho de item precisa estar entre um e quatro."))
  (unless (zerop (mod (length data) item-size))
    (error 'validation-error :message "O comprimento do atributo não é divisível pelo tamanho de item."))
  (make-instance 'buffer-attribute :array (if index-data (%vetor-indice data) (%vetor-float data))
                                   :item-size item-size :normalized normalized :usage usage))

(defun make-buffer-geometry ()
  "Cria uma geometria de buffers vazia."
  (make-instance 'buffer-geometry))

(defun set-attribute (geometry name attribute)
  "Associa um atributo a uma geometria."
  (unless (and (keywordp name) (typep attribute 'buffer-attribute))
    (error 'validation-error :message "O nome do atributo deve ser keyword e o valor deve ser buffer-attribute."))
  (setf (gethash name (attributes geometry)) attribute) geometry)
(defun get-attribute (geometry name)
  "Obtém um atributo ou NIL."
  (gethash name (attributes geometry)))
(defun delete-attribute (geometry name)
  "Remove um atributo."
  (remhash name (attributes geometry)) geometry)
(defun set-index (geometry data)
  "Define o índice da geometria a partir de uma sequência ou atributo."
  (setf (index geometry)
        (cond ((null data) nil)
              ((typep data 'buffer-attribute) data)
              (t (make-buffer-attribute data 1 :index-data t))))
  geometry)

(defun %validar-cor (cor)
  (unless (and (typep cor 'vector3) (<= 0 (x cor) 1) (<= 0 (y cor) 1) (<= 0 (z cor) 1))
    (error 'validation-error :message "Cada cor deve ser vector3 sRGB com componentes entre zero e um."))
  cor)

(defun make-box-geometry (&key (width 1.0f0) (height 1.0f0) (depth 1.0f0) face-colors)
  "Cria uma caixa com vinte e quatro vértices e normais por face."
  (when (or (<= width 0) (<= height 0) (<= depth 0))
    (error 'validation-error :message "As dimensões da caixa precisam ser positivas."))
  (when (and face-colors (/= (length face-colors) 6))
    (error 'validation-error :message "A caixa precisa receber exatamente seis cores de face."))
  (let* ((hx (/ width 2.0f0)) (hy (/ height 2.0f0)) (hz (/ depth 2.0f0))
         (posicoes (vector
                    (- hx) (- hy) hz  hx (- hy) hz  hx hy hz  (- hx) hy hz
                    hx (- hy) (- hz)  (- hx) (- hy) (- hz)  (- hx) hy (- hz)  hx hy (- hz)
                    hx (- hy) hz  hx (- hy) (- hz)  hx hy (- hz)  hx hy hz
                    (- hx) (- hy) (- hz)  (- hx) (- hy) hz  (- hx) hy hz  (- hx) hy (- hz)
                    (- hx) hy hz  hx hy hz  hx hy (- hz)  (- hx) hy (- hz)
                    (- hx) (- hy) (- hz)  hx (- hy) (- hz)  hx (- hy) hz  (- hx) (- hy) hz))
         (normais (vector
                   0 0 1  0 0 1  0 0 1  0 0 1
                   0 0 -1  0 0 -1  0 0 -1  0 0 -1
                   1 0 0  1 0 0  1 0 0  1 0 0
                   -1 0 0  -1 0 0  -1 0 0  -1 0 0
                   0 1 0  0 1 0  0 1 0  0 1 0
                   0 -1 0  0 -1 0  0 -1 0  0 -1 0))
         (indices (loop for face below 6 append
                    (let ((base (* face 4))) (list base (1+ base) (+ base 2) base (+ base 2) (+ base 3)))))
         (geometria (make-instance 'box-geometry)))
    (set-attribute geometria :position (make-buffer-attribute posicoes 3))
    (set-attribute geometria :normal (make-buffer-attribute normais 3))
    (set-index geometria indices)
    (when face-colors
      (let ((cores (make-array 72 :element-type 'single-float)) (cursor 0))
        (dolist (cor face-colors)
          (%validar-cor cor)
          (loop repeat 4 do
            (setf (aref cores cursor) (x cor) (aref cores (1+ cursor)) (y cor)
                  (aref cores (+ cursor 2)) (z cor))
            (incf cursor 3)))
        (set-attribute geometria :color (make-buffer-attribute cores 3))))
    geometria))

(defun make-plane-geometry (&key (width 1.0f0) (height 1.0f0) (width-segments 1) (height-segments 1))
  "Cria um plano no eixo XY voltado para Z positivo."
  (unless (and (> width 0) (> height 0) (plusp width-segments) (plusp height-segments)
               (integerp width-segments) (integerp height-segments))
    (error 'validation-error :message "Os parâmetros do plano são inválidos."))
  (let ((posicoes nil) (normais nil) (indices nil) (geometria (make-instance 'plane-geometry)))
    (dotimes (linha (1+ height-segments))
      (dotimes (coluna (1+ width-segments))
        (let ((px (- (* width (/ coluna width-segments)) (/ width 2.0f0)))
              (py (- (/ height 2.0f0) (* height (/ linha height-segments)))))
          (setf posicoes (nconc posicoes (list px py 0.0f0))
                normais (nconc normais (list 0.0f0 0.0f0 1.0f0))))))
    (dotimes (linha height-segments)
      (dotimes (coluna width-segments)
        (let* ((a (+ coluna (* linha (1+ width-segments)))) (b (+ a (1+ width-segments)))
               (c (1+ b)) (d (1+ a)))
          (setf indices (nconc indices (list a b d b c d))))))
    (set-attribute geometria :position (make-buffer-attribute posicoes 3))
    (set-attribute geometria :normal (make-buffer-attribute normais 3))
    (set-index geometria indices) geometria))

(defun make-sphere-geometry (&key (radius 1.0f0) (width-segments 32) (height-segments 16))
  "Cria uma esfera UV indexada."
  (unless (and (> radius 0) (integerp width-segments) (>= width-segments 3)
               (integerp height-segments) (>= height-segments 2))
    (error 'validation-error :message "Os parâmetros da esfera são inválidos."))
  (let ((posicoes nil) (normais nil) (indices nil) (geometria (make-instance 'sphere-geometry)))
    (dotimes (linha (1+ height-segments))
      (let ((v (/ linha height-segments)))
        (dotimes (coluna (1+ width-segments))
          (let* ((u (/ coluna width-segments)) (phi (* u 2 pi)) (theta (* v pi))
                 (nx (* -1 (cos phi) (sin theta))) (ny (cos theta)) (nz (* (sin phi) (sin theta))))
            (setf posicoes (nconc posicoes (list (* radius nx) (* radius ny) (* radius nz)))
                  normais (nconc normais (list nx ny nz)))))))
    (dotimes (linha height-segments)
      (dotimes (coluna width-segments)
        (let* ((a (+ coluna (* linha (1+ width-segments)))) (b (+ a (1+ width-segments)))
               (c (1+ b)) (d (1+ a)))
          (unless (zerop linha) (setf indices (nconc indices (list a b d))))
          (unless (= linha (1- height-segments)) (setf indices (nconc indices (list b c d)))))))
    (set-attribute geometria :position (make-buffer-attribute posicoes 3))
    (set-attribute geometria :normal (make-buffer-attribute normais 3))
    (set-index geometria indices) geometria))

(defun compute-vertex-normals (geometry)
  "Calcula normais suaves para triângulos indexados ou sequenciais."
  (let* ((posicao (get-attribute geometry :position))
         (dados-posicao (and posicao (attribute-array posicao))))
    (unless (and posicao (= (item-size posicao) 3))
      (error 'validation-error :message "A geometria precisa de posições tridimensionais para calcular normais."))
    (let* ((quantidade (/ (length dados-posicao) 3))
           (dados-normal (make-array (* quantidade 3) :element-type 'single-float :initial-element 0.0f0))
           (dados-indice (and (index geometry) (attribute-array (index geometry))))
           (total (if dados-indice (length dados-indice) quantidade)))
      (unless (zerop (mod total 3))
        (error 'validation-error :message "A geometria não forma uma lista completa de triângulos."))
      (labels ((indice (posicao) (if dados-indice (aref dados-indice posicao) posicao))
               (somar-face (ia ib ic)
                 (let* ((a (* ia 3)) (b (* ib 3)) (c (* ic 3))
                        (abx (- (aref dados-posicao b) (aref dados-posicao a)))
                        (aby (- (aref dados-posicao (1+ b)) (aref dados-posicao (1+ a))))
                        (abz (- (aref dados-posicao (+ b 2)) (aref dados-posicao (+ a 2))))
                        (acx (- (aref dados-posicao c) (aref dados-posicao a)))
                        (acy (- (aref dados-posicao (1+ c)) (aref dados-posicao (1+ a))))
                        (acz (- (aref dados-posicao (+ c 2)) (aref dados-posicao (+ a 2))))
                        (nx (- (* aby acz) (* abz acy)))
                        (ny (- (* abz acx) (* abx acz)))
                        (nz (- (* abx acy) (* aby acx))))
                   (dolist (vertice (list a b c))
                     (incf (aref dados-normal vertice) nx)
                     (incf (aref dados-normal (1+ vertice)) ny)
                     (incf (aref dados-normal (+ vertice 2)) nz)))))
        (loop for cursor from 0 below total by 3 do
          (somar-face (indice cursor) (indice (1+ cursor)) (indice (+ cursor 2)))))
      (dotimes (vertice quantidade)
        (let* ((base (* vertice 3))
               (normal (make-vector3 (aref dados-normal base) (aref dados-normal (1+ base)) (aref dados-normal (+ base 2)))))
          (normalize normal)
          (setf (aref dados-normal base) (x normal) (aref dados-normal (1+ base)) (y normal)
                (aref dados-normal (+ base 2)) (z normal))))
      (set-attribute geometry :normal (make-buffer-attribute dados-normal 3)))))
