(in-package #:flegrea.math)

(define-condition flegrea-error (error)
  ((mensagem :initarg :message :reader mensagem-do-erro))
  (:report (lambda (condicao fluxo)
             (write-string (mensagem-do-erro condicao) fluxo))))

(define-condition validation-error (flegrea-error) ())

(declaim (inline %real-simples))
(defun %real-simples (valor)
  (unless (realp valor)
    (error 'validation-error :message "Era esperado um número real."))
  (coerce valor 'single-float))

(defclass vector2 ()
  ((x :initarg :x :initform 0.0f0 :accessor x)
   (y :initarg :y :initform 0.0f0 :accessor y)))

(defclass vector3 ()
  ((x :initarg :x :initform 0.0f0 :accessor x)
   (y :initarg :y :initform 0.0f0 :accessor y)
   (z :initarg :z :initform 0.0f0 :accessor z)))

(defclass vector4 ()
  ((x :initarg :x :initform 0.0f0 :accessor x)
   (y :initarg :y :initform 0.0f0 :accessor y)
   (z :initarg :z :initform 0.0f0 :accessor z)
   (w :initarg :w :initform 0.0f0 :accessor w)))

(defclass quaternion (vector4) ()
  (:default-initargs :w 1.0f0))

(defclass euler (vector3)
  ((order :initarg :order :initform :xyz :accessor order)))

(defclass matrix3 ()
  ((elements :initarg :elements :accessor elements)))

(defclass matrix4 ()
  ((elements :initarg :elements :accessor elements)))

(defmethod initialize-instance :after ((valor vector2) &key)
  (setf (x valor) (%real-simples (x valor)) (y valor) (%real-simples (y valor))))
(defmethod initialize-instance :after ((valor vector3) &key)
  (setf (x valor) (%real-simples (x valor)) (y valor) (%real-simples (y valor))
        (z valor) (%real-simples (z valor))))
(defmethod initialize-instance :after ((valor vector4) &key)
  (setf (x valor) (%real-simples (x valor)) (y valor) (%real-simples (y valor))
        (z valor) (%real-simples (z valor)) (w valor) (%real-simples (w valor))))
(defmethod initialize-instance :after ((valor euler) &key)
  (unless (member (order valor) '(:xyz :yxz :zxy :zyx :yzx :xzy))
    (error 'validation-error :message "A ordem de Euler informada não é suportada.")))

(defun %identidade3 ()
  (make-array 9 :element-type 'single-float
                :initial-contents '(1.0f0 0.0f0 0.0f0 0.0f0 1.0f0 0.0f0 0.0f0 0.0f0 1.0f0)))
(defun %identidade4 ()
  (make-array 16 :element-type 'single-float
                 :initial-contents '(1.0f0 0.0f0 0.0f0 0.0f0
                                     0.0f0 1.0f0 0.0f0 0.0f0
                                     0.0f0 0.0f0 1.0f0 0.0f0
                                     0.0f0 0.0f0 0.0f0 1.0f0)))

(defmethod initialize-instance :after ((valor matrix3) &key)
  (unless (slot-boundp valor 'elements) (setf (elements valor) (%identidade3)))
  (unless (= (length (elements valor)) 9)
    (error 'validation-error :message "Uma matrix3 precisa de nove elementos."))
  (setf (elements valor) (map '(simple-array single-float (9)) #'%real-simples (elements valor))))
(defmethod initialize-instance :after ((valor matrix4) &key)
  (unless (slot-boundp valor 'elements) (setf (elements valor) (%identidade4)))
  (unless (= (length (elements valor)) 16)
    (error 'validation-error :message "Uma matrix4 precisa de dezesseis elementos."))
  (setf (elements valor) (map '(simple-array single-float (16)) #'%real-simples (elements valor))))

(defun make-vector2 (&optional (x 0.0f0) (y 0.0f0)) (make-instance 'vector2 :x x :y y))
(defun make-vector3 (&optional (x 0.0f0) (y 0.0f0) (z 0.0f0)) (make-instance 'vector3 :x x :y y :z z))
(defun make-vector4 (&optional (x 0.0f0) (y 0.0f0) (z 0.0f0) (w 0.0f0)) (make-instance 'vector4 :x x :y y :z z :w w))
(defun make-quaternion (&optional (x 0.0f0) (y 0.0f0) (z 0.0f0) (w 1.0f0)) (make-instance 'quaternion :x x :y y :z z :w w))
(defun make-euler (&optional (x 0.0f0) (y 0.0f0) (z 0.0f0) (order :xyz)) (make-instance 'euler :x x :y y :z z :order order))
(defun make-matrix3 (&optional elementos) (make-instance 'matrix3 :elements (or elementos (%identidade3))))
(defun make-matrix4 (&optional elementos) (make-instance 'matrix4 :elements (or elementos (%identidade4))))

(defgeneric set-vector2 (valor x y))
(defgeneric set-vector3 (valor x y z))
(defgeneric set-vector4 (valor x y z w))
(defgeneric set-quaternion (valor x y z w))
(defgeneric set-euler (valor x y z &optional order))
(defgeneric clone (valor))
(defgeneric copy-from (destino origem))
(defgeneric equals (a b &optional tolerancia))
(defgeneric add (destino outro))
(defgeneric subtract (destino outro))
(defgeneric multiply-scalar (destino escalar))
(defgeneric divide-scalar (destino escalar))
(defgeneric dot (a b))
(defgeneric normalize (valor))
(defgeneric length-squared (valor))
(defgeneric vector-length (valor))

(defmethod set-vector2 ((valor vector2) a b) (setf (x valor) (%real-simples a) (y valor) (%real-simples b)) valor)
(defmethod set-vector3 ((valor vector3) a b c) (setf (x valor) (%real-simples a) (y valor) (%real-simples b) (z valor) (%real-simples c)) valor)
(defmethod set-vector4 ((valor vector4) a b c d) (setf (x valor) (%real-simples a) (y valor) (%real-simples b) (z valor) (%real-simples c) (w valor) (%real-simples d)) valor)
(defmethod set-quaternion ((valor quaternion) a b c d) (set-vector4 valor a b c d))
(defmethod set-euler ((valor euler) a b c &optional (ordem (order valor)))
  (unless (member ordem '(:xyz :yxz :zxy :zyx :yzx :xzy))
    (error 'validation-error :message "A ordem de Euler informada não é suportada."))
  (set-vector3 valor a b c) (setf (order valor) ordem) valor)

(defmethod clone ((valor vector2)) (make-vector2 (x valor) (y valor)))
(defmethod clone ((valor vector3)) (make-vector3 (x valor) (y valor) (z valor)))
(defmethod clone ((valor vector4)) (make-vector4 (x valor) (y valor) (z valor) (w valor)))
(defmethod clone ((valor quaternion)) (make-quaternion (x valor) (y valor) (z valor) (w valor)))
(defmethod clone ((valor euler)) (make-euler (x valor) (y valor) (z valor) (order valor)))
(defmethod clone ((valor matrix3)) (make-matrix3 (copy-seq (elements valor))))
(defmethod clone ((valor matrix4)) (make-matrix4 (copy-seq (elements valor))))

(defmethod copy-from ((destino vector2) (origem vector2)) (set-vector2 destino (x origem) (y origem)))
(defmethod copy-from ((destino vector3) (origem vector3)) (set-vector3 destino (x origem) (y origem) (z origem)))
(defmethod copy-from ((destino vector4) (origem vector4)) (set-vector4 destino (x origem) (y origem) (z origem) (w origem)))
(defmethod copy-from ((destino quaternion) (origem quaternion)) (set-quaternion destino (x origem) (y origem) (z origem) (w origem)))
(defmethod copy-from ((destino euler) (origem euler)) (set-euler destino (x origem) (y origem) (z origem) (order origem)))
(defmethod copy-from ((destino matrix3) (origem matrix3)) (replace (elements destino) (elements origem)) destino)
(defmethod copy-from ((destino matrix4) (origem matrix4)) (replace (elements destino) (elements origem)) destino)

(defun %perto (a b tolerancia) (<= (abs (- a b)) tolerancia))
(defmethod equals ((a vector2) (b vector2) &optional (tolerancia 1.0e-6)) (and (%perto (x a) (x b) tolerancia) (%perto (y a) (y b) tolerancia)))
(defmethod equals ((a vector3) (b vector3) &optional (tolerancia 1.0e-6)) (and (%perto (x a) (x b) tolerancia) (%perto (y a) (y b) tolerancia) (%perto (z a) (z b) tolerancia)))
(defmethod equals ((a vector4) (b vector4) &optional (tolerancia 1.0e-6)) (and (%perto (x a) (x b) tolerancia) (%perto (y a) (y b) tolerancia) (%perto (z a) (z b) tolerancia) (%perto (w a) (w b) tolerancia)))
(defmethod equals ((a matrix3) (b matrix3) &optional (tolerancia 1.0e-6)) (every (lambda (u v) (%perto u v tolerancia)) (elements a) (elements b)))
(defmethod equals ((a matrix4) (b matrix4) &optional (tolerancia 1.0e-6)) (every (lambda (u v) (%perto u v tolerancia)) (elements a) (elements b)))

(defmacro %definir-operacoes-vetor (classe componentes)
  `(progn
     (defmethod add ((destino ,classe) (outro ,classe))
       ,@(mapcar (lambda (componente) `(incf (,componente destino) (,componente outro))) componentes) destino)
     (defmethod subtract ((destino ,classe) (outro ,classe))
       ,@(mapcar (lambda (componente) `(decf (,componente destino) (,componente outro))) componentes) destino)
     (defmethod multiply-scalar ((destino ,classe) escalar)
       (let ((fator (%real-simples escalar)))
         ,@(mapcar (lambda (componente) `(setf (,componente destino) (* (,componente destino) fator))) componentes)) destino)
     (defmethod divide-scalar ((destino ,classe) escalar)
       (let ((divisor (%real-simples escalar)))
         (when (zerop divisor) (error 'validation-error :message "Não é possível dividir um vetor por zero."))
         (multiply-scalar destino (/ 1.0f0 divisor))))
     (defmethod dot ((a ,classe) (b ,classe))
       (+ ,@(mapcar (lambda (componente) `(* (,componente a) (,componente b))) componentes)))
     (defmethod length-squared ((valor ,classe)) (dot valor valor))
     (defmethod vector-length ((valor ,classe)) (sqrt (length-squared valor)))
     (defmethod normalize ((valor ,classe))
       (let ((comprimento (vector-length valor)))
         (unless (zerop comprimento) (divide-scalar valor comprimento))) valor)))

(%definir-operacoes-vetor vector2 (x y))
(%definir-operacoes-vetor vector3 (x y z))
(%definir-operacoes-vetor vector4 (x y z w))

(defun cross (destino outro)
  "Calcula o produto vetorial, altera o primeiro vetor e o devolve."
  (let ((ax (x destino)) (ay (y destino)) (az (z destino))
        (bx (x outro)) (by (y outro)) (bz (z outro)))
    (set-vector3 destino (- (* ay bz) (* az by))
                 (- (* az bx) (* ax bz))
                 (- (* ax by) (* ay bx)))))

(defun apply-matrix3 (vetor matriz)
  "Aplica uma matrix3 ao vetor informado."
  (let* ((dados (elements matriz)) (vx (x vetor)) (vy (y vetor)) (vz (z vetor)))
    (set-vector3 vetor
                 (+ (* (aref dados 0) vx) (* (aref dados 3) vy) (* (aref dados 6) vz))
                 (+ (* (aref dados 1) vx) (* (aref dados 4) vy) (* (aref dados 7) vz))
                 (+ (* (aref dados 2) vx) (* (aref dados 5) vy) (* (aref dados 8) vz)))))

(defun apply-matrix4 (vetor matriz)
  "Aplica uma matrix4 ao vetor, incluindo divisão homogênea para vector3."
  (let ((dados (elements matriz)) (vx (x vetor)) (vy (y vetor)) (vz (z vetor)))
    (etypecase vetor
      (vector4
       (let ((vw (w vetor)))
         (set-vector4 vetor
                      (+ (* (aref dados 0) vx) (* (aref dados 4) vy) (* (aref dados 8) vz) (* (aref dados 12) vw))
                      (+ (* (aref dados 1) vx) (* (aref dados 5) vy) (* (aref dados 9) vz) (* (aref dados 13) vw))
                      (+ (* (aref dados 2) vx) (* (aref dados 6) vy) (* (aref dados 10) vz) (* (aref dados 14) vw))
                      (+ (* (aref dados 3) vx) (* (aref dados 7) vy) (* (aref dados 11) vz) (* (aref dados 15) vw)))))
      (vector3
       (let ((divisor (+ (* (aref dados 3) vx) (* (aref dados 7) vy) (* (aref dados 11) vz) (aref dados 15))))
         (when (zerop divisor) (error 'validation-error :message "A transformação homogênea produziu divisor zero."))
         (set-vector3 vetor
                      (/ (+ (* (aref dados 0) vx) (* (aref dados 4) vy) (* (aref dados 8) vz) (aref dados 12)) divisor)
                      (/ (+ (* (aref dados 1) vx) (* (aref dados 5) vy) (* (aref dados 9) vz) (aref dados 13)) divisor)
                      (/ (+ (* (aref dados 2) vx) (* (aref dados 6) vy) (* (aref dados 10) vz) (aref dados 14)) divisor)))))))

(defun apply-quaternion (vetor giro)
  "Aplica um quaternion a um vector3."
  (let* ((vx (x vetor)) (vy (y vetor)) (vz (z vetor))
         (qx (x giro)) (qy (y giro)) (qz (z giro)) (qw (w giro))
         (ix (+ (* qw vx) (* qy vz) (- (* qz vy))))
         (iy (+ (* qw vy) (* qz vx) (- (* qx vz))))
         (iz (+ (* qw vz) (* qx vy) (- (* qy vx))))
         (iw (- (+ (* qx vx) (* qy vy) (* qz vz)))))
    (set-vector3 vetor
                 (+ (* ix qw) (* iw (- qx)) (* iy (- qz)) (- (* iz (- qy))))
                 (+ (* iy qw) (* iw (- qy)) (* iz (- qx)) (- (* ix (- qz))))
                 (+ (* iz qw) (* iw (- qz)) (* ix (- qy)) (- (* iy (- qx)))))))

(defun set-identity (matriz)
  "Restaura a matriz para a identidade."
  (replace (elements matriz) (etypecase matriz (matrix3 (%identidade3)) (matrix4 (%identidade4)))) matriz)

(defun matrix-multiply (destino outro)
  "Multiplica a matriz destino por outra matriz."
  (let* ((ordem (etypecase destino (matrix3 3) (matrix4 4)))
         (a (copy-seq (elements destino))) (b (elements outro)) (saida (elements destino)))
    (dotimes (coluna ordem)
      (dotimes (linha ordem)
        (setf (aref saida (+ linha (* coluna ordem)))
              (loop for indice below ordem
                    sum (* (aref a (+ linha (* indice ordem)))
                           (aref b (+ indice (* coluna ordem)))) into soma
                    finally (return (%real-simples soma)))))) destino))

(defun matrix-premultiply (destino outra)
  "Multiplica outra matriz pela matriz destino."
  (let ((copia (clone outra))) (matrix-multiply copia destino) (copy-from destino copia)))

(defun matrix-transpose (matriz)
  "Transpõe a matriz no local."
  (let* ((ordem (etypecase matriz (matrix3 3) (matrix4 4))) (dados (elements matriz)))
    (dotimes (linha ordem)
      (loop for coluna from (1+ linha) below ordem do
        (rotatef (aref dados (+ linha (* coluna ordem)))
                 (aref dados (+ coluna (* linha ordem)))))) matriz))

(defun matrix-determinant (matriz)
  "Calcula o determinante da matriz."
  (etypecase matriz
    (matrix3
     (let ((m (elements matriz)))
       (+ (* (aref m 0) (- (* (aref m 4) (aref m 8)) (* (aref m 7) (aref m 5))))
          (- (* (aref m 3) (- (* (aref m 1) (aref m 8)) (* (aref m 7) (aref m 2)))))
          (* (aref m 6) (- (* (aref m 1) (aref m 5)) (* (aref m 4) (aref m 2)))))))
    (matrix4
     (let ((m (elements matriz)))
       (labels ((a (linha coluna) (aref m (+ linha (* coluna 4))))
                (det3 (l0 l1 l2 c0 c1 c2)
                  (+ (* (a l0 c0) (- (* (a l1 c1) (a l2 c2)) (* (a l1 c2) (a l2 c1))))
                     (- (* (a l0 c1) (- (* (a l1 c0) (a l2 c2)) (* (a l1 c2) (a l2 c0)))))
                     (* (a l0 c2) (- (* (a l1 c0) (a l2 c1)) (* (a l1 c1) (a l2 c0)))))))
         (+ (* (a 0 0) (det3 1 2 3 1 2 3))
            (- (* (a 0 1) (det3 1 2 3 0 2 3)))
            (* (a 0 2) (det3 1 2 3 0 1 3))
            (- (* (a 0 3) (det3 1 2 3 0 1 2)))))))))

(defun matrix-invert (matriz)
  "Inverte a matriz pelo método de Gauss-Jordan."
  (let* ((ordem (etypecase matriz (matrix3 3) (matrix4 4)))
         (largura (* 2 ordem))
         (tabela (make-array (list ordem largura) :element-type 'single-float :initial-element 0.0f0))
         (dados (elements matriz)))
    (dotimes (linha ordem)
      (dotimes (coluna ordem)
        (setf (aref tabela linha coluna) (aref dados (+ linha (* coluna ordem)))))
      (setf (aref tabela linha (+ ordem linha)) 1.0f0))
    (dotimes (coluna ordem)
      (let ((pivo coluna))
        (loop for linha from (1+ coluna) below ordem
              when (> (abs (aref tabela linha coluna)) (abs (aref tabela pivo coluna))) do (setf pivo linha))
        (when (< (abs (aref tabela pivo coluna)) 1.0e-8)
          (error 'validation-error :message "A matriz singular não pode ser invertida."))
        (unless (= pivo coluna)
          (dotimes (indice largura) (rotatef (aref tabela pivo indice) (aref tabela coluna indice))))
        (let ((divisor (aref tabela coluna coluna)))
          (dotimes (indice largura) (setf (aref tabela coluna indice) (/ (aref tabela coluna indice) divisor))))
        (dotimes (linha ordem)
          (unless (= linha coluna)
            (let ((fator (aref tabela linha coluna)))
              (dotimes (indice largura)
                (decf (aref tabela linha indice) (* fator (aref tabela coluna indice)))))))))
    (dotimes (linha ordem)
      (dotimes (coluna ordem)
        (setf (aref dados (+ linha (* coluna ordem))) (aref tabela linha (+ ordem coluna))))) matriz))

(defun set-translation-matrix4 (matriz tx ty tz)
  "Define uma matriz de translação."
  (set-identity matriz)
  (setf (aref (elements matriz) 12) (%real-simples tx)
        (aref (elements matriz) 13) (%real-simples ty)
        (aref (elements matriz) 14) (%real-simples tz)) matriz)
(defun set-scale-matrix4 (matriz sx sy sz)
  "Define uma matriz de escala."
  (set-identity matriz)
  (setf (aref (elements matriz) 0) (%real-simples sx)
        (aref (elements matriz) 5) (%real-simples sy)
        (aref (elements matriz) 10) (%real-simples sz)) matriz)

(defmacro %definir-rotacao (nome indices sinais)
  `(defun ,nome (matriz angulo)
     "Define uma matriz de rotação em um eixo principal."
     (let ((cosseno (cos (%real-simples angulo))) (seno (sin (%real-simples angulo))) (dados (elements matriz)))
       (set-identity matriz)
       ,@(loop for indice in indices for sinal in sinais collect
               `(setf (aref dados ,indice) (* ,sinal ,(if (member indice '(5 10 0)) 'cosseno 'seno))))
       matriz)))

(defun set-rotation-x-matrix4 (matriz angulo)
  "Define rotação no eixo X."
  (let ((c (cos (%real-simples angulo))) (s (sin (%real-simples angulo))) (m (elements matriz)))
    (set-identity matriz) (setf (aref m 5) c (aref m 6) s (aref m 9) (- s) (aref m 10) c) matriz))
(defun set-rotation-y-matrix4 (matriz angulo)
  "Define rotação no eixo Y."
  (let ((c (cos (%real-simples angulo))) (s (sin (%real-simples angulo))) (m (elements matriz)))
    (set-identity matriz) (setf (aref m 0) c (aref m 2) (- s) (aref m 8) s (aref m 10) c) matriz))
(defun set-rotation-z-matrix4 (matriz angulo)
  "Define rotação no eixo Z."
  (let ((c (cos (%real-simples angulo))) (s (sin (%real-simples angulo))) (m (elements matriz)))
    (set-identity matriz) (setf (aref m 0) c (aref m 1) s (aref m 4) (- s) (aref m 5) c) matriz))

(defun set-from-euler (giro angulos)
  "Define um quaternion a partir de ângulos Euler."
  (let* ((c1 (cos (/ (x angulos) 2.0f0))) (c2 (cos (/ (y angulos) 2.0f0))) (c3 (cos (/ (z angulos) 2.0f0)))
         (s1 (sin (/ (x angulos) 2.0f0))) (s2 (sin (/ (y angulos) 2.0f0))) (s3 (sin (/ (z angulos) 2.0f0))))
    (ecase (order angulos)
      (:xyz (set-quaternion giro (+ (* s1 c2 c3) (* c1 s2 s3)) (+ (* c1 s2 c3) (- (* s1 c2 s3))) (+ (* c1 c2 s3) (* s1 s2 c3)) (- (* c1 c2 c3) (* s1 s2 s3))))
      (:yxz (set-quaternion giro (+ (* s1 c2 c3) (* c1 s2 s3)) (+ (* c1 s2 c3) (- (* s1 c2 s3))) (+ (* c1 c2 s3) (- (* s1 s2 c3))) (+ (* c1 c2 c3) (* s1 s2 s3))))
      (:zxy (set-quaternion giro (+ (* s1 c2 c3) (- (* c1 s2 s3))) (+ (* c1 s2 c3) (* s1 c2 s3)) (+ (* c1 c2 s3) (* s1 s2 c3)) (- (* c1 c2 c3) (* s1 s2 s3))))
      (:zyx (set-quaternion giro (+ (* s1 c2 c3) (- (* c1 s2 s3))) (+ (* c1 s2 c3) (* s1 c2 s3)) (+ (* c1 c2 s3) (- (* s1 s2 c3))) (+ (* c1 c2 c3) (* s1 s2 s3))))
      (:yzx (set-quaternion giro (+ (* s1 c2 c3) (* c1 s2 s3)) (+ (* c1 s2 c3) (* s1 c2 s3)) (+ (* c1 c2 s3) (- (* s1 s2 c3))) (- (* c1 c2 c3) (* s1 s2 s3))))
      (:xzy (set-quaternion giro (+ (* s1 c2 c3) (- (* c1 s2 s3))) (+ (* c1 s2 c3) (- (* s1 c2 s3))) (+ (* c1 c2 s3) (* s1 s2 c3)) (+ (* c1 c2 c3) (* s1 s2 s3)))))))

(defmethod normalize ((valor quaternion))
  (let ((comprimento (vector-length valor)))
    (if (zerop comprimento) (set-quaternion valor 0 0 0 1) (divide-scalar valor comprimento))))

(defun quaternion-multiply (destino outro)
  "Multiplica o quaternion destino pelo outro."
  (let ((ax (x destino)) (ay (y destino)) (az (z destino)) (aw (w destino))
        (bx (x outro)) (by (y outro)) (bz (z outro)) (bw (w outro)))
    (set-quaternion destino
                    (+ (* ax bw) (* aw bx) (* ay bz) (- (* az by)))
                    (+ (* ay bw) (* aw by) (* az bx) (- (* ax bz)))
                    (+ (* az bw) (* aw bz) (* ax by) (- (* ay bx)))
                    (- (* aw bw) (* ax bx) (* ay by) (* az bz)))))

(defun slerp (destino outro fator)
  "Interpola esfericamente o quaternion destino em direção ao outro."
  (let* ((tamanho (%real-simples fator)) (coseno (dot destino outro)) (alvo (clone outro)))
    (when (< coseno 0.0f0) (setf coseno (- coseno)) (multiply-scalar alvo -1.0f0))
    (if (> coseno 0.9995f0)
        (progn (multiply-scalar destino (- 1.0f0 tamanho))
               (multiply-scalar alvo tamanho) (add destino alvo) (normalize destino))
        (let* ((angulo (acos (min 1.0f0 coseno))) (seno (sin angulo))
               (peso-a (/ (sin (* (- 1.0f0 tamanho) angulo)) seno))
               (peso-b (/ (sin (* tamanho angulo)) seno)))
          (multiply-scalar destino peso-a) (multiply-scalar alvo peso-b) (add destino alvo)))))

(defun compose-matrix4 (matriz posicao giro escala)
  "Compõe uma matrix4 com posição, quaternion e escala."
  (let* ((m (elements matriz)) (qx (x giro)) (qy (y giro)) (qz (z giro)) (qw (w giro))
         (x2 (+ qx qx)) (y2 (+ qy qy)) (z2 (+ qz qz))
         (xx (* qx x2)) (xy (* qx y2)) (xz (* qx z2))
         (yy (* qy y2)) (yz (* qy z2)) (zz (* qz z2))
         (wx (* qw x2)) (wy (* qw y2)) (wz (* qw z2))
         (sx (x escala)) (sy (y escala)) (sz (z escala)))
    (setf (aref m 0) (* (- 1.0f0 (+ yy zz)) sx) (aref m 1) (* (+ xy wz) sx) (aref m 2) (* (- xz wy) sx) (aref m 3) 0.0f0
          (aref m 4) (* (- xy wz) sy) (aref m 5) (* (- 1.0f0 (+ xx zz)) sy) (aref m 6) (* (+ yz wx) sy) (aref m 7) 0.0f0
          (aref m 8) (* (+ xz wy) sz) (aref m 9) (* (- yz wx) sz) (aref m 10) (* (- 1.0f0 (+ xx yy)) sz) (aref m 11) 0.0f0
          (aref m 12) (x posicao) (aref m 13) (y posicao) (aref m 14) (z posicao) (aref m 15) 1.0f0) matriz))

(defun set-from-quaternion (angulos giro &optional (ordem (order angulos)))
  "Define ângulos Euler a partir de um quaternion."
  (let ((m (make-matrix4)))
    (compose-matrix4 m (make-vector3) giro (make-vector3 1 1 1))
    (let* ((e (elements m)) (m11 (aref e 0)) (m12 (aref e 4)) (m13 (aref e 8))
           (m21 (aref e 1)) (m22 (aref e 5)) (m23 (aref e 9))
           (m31 (aref e 2)) (m32 (aref e 6)) (m33 (aref e 10))
           (limitar (lambda (v) (max -1.0f0 (min 1.0f0 v)))))
      (ecase ordem
        (:xyz (set-euler angulos (atan (- m23) m33) (asin (funcall limitar m13)) (atan (- m12) m11) ordem))
        (:yxz (set-euler angulos (asin (- (funcall limitar m23))) (atan m13 m33) (atan m21 m22) ordem))
        (:zxy (set-euler angulos (asin (funcall limitar m32)) (atan (- m31) m33) (atan (- m12) m22) ordem))
        (:zyx (set-euler angulos (atan m32 m33) (asin (- (funcall limitar m31))) (atan m21 m11) ordem))
        (:yzx (set-euler angulos (atan (- m23) m22) (atan (- m31) m11) (asin (funcall limitar m21)) ordem))
        (:xzy (set-euler angulos (atan m32 m22) (atan m13 m11) (asin (- (funcall limitar m12))) ordem))))))

(defun decompose-matrix4 (matriz posicao giro escala)
  "Decompõe uma matriz afim em posição, quaternion e escala."
  (let* ((m (elements matriz))
         (sx (sqrt (+ (expt (aref m 0) 2) (expt (aref m 1) 2) (expt (aref m 2) 2))))
         (sy (sqrt (+ (expt (aref m 4) 2) (expt (aref m 5) 2) (expt (aref m 6) 2))))
         (sz (sqrt (+ (expt (aref m 8) 2) (expt (aref m 9) 2) (expt (aref m 10) 2))))
         (rotacao (clone matriz)))
    (when (minusp (matrix-determinant matriz)) (setf sx (- sx)))
    (when (or (zerop sx) (zerop sy) (zerop sz))
      (error 'validation-error :message "Não é possível decompor uma matriz com escala zero."))
    (set-vector3 posicao (aref m 12) (aref m 13) (aref m 14))
    (dotimes (linha 3) (setf (aref (elements rotacao) linha) (/ (aref (elements rotacao) linha) sx)
                              (aref (elements rotacao) (+ 4 linha)) (/ (aref (elements rotacao) (+ 4 linha)) sy)
                              (aref (elements rotacao) (+ 8 linha)) (/ (aref (elements rotacao) (+ 8 linha)) sz)))
    (let* ((r (elements rotacao)) (traco (+ (aref r 0) (aref r 5) (aref r 10))))
      (cond
        ((plusp traco)
         (let ((s (* 2.0f0 (sqrt (+ traco 1.0f0)))))
           (set-quaternion giro (/ (- (aref r 6) (aref r 9)) s) (/ (- (aref r 8) (aref r 2)) s)
                           (/ (- (aref r 1) (aref r 4)) s) (/ s 4.0f0))))
        ((and (> (aref r 0) (aref r 5)) (> (aref r 0) (aref r 10)))
         (let ((s (* 2.0f0 (sqrt (+ 1.0f0 (aref r 0) (- (aref r 5)) (- (aref r 10)))))))
           (set-quaternion giro (/ s 4.0f0) (/ (+ (aref r 4) (aref r 1)) s) (/ (+ (aref r 8) (aref r 2)) s) (/ (- (aref r 6) (aref r 9)) s))))
        ((> (aref r 5) (aref r 10))
         (let ((s (* 2.0f0 (sqrt (+ 1.0f0 (aref r 5) (- (aref r 0)) (- (aref r 10)))))))
           (set-quaternion giro (/ (+ (aref r 4) (aref r 1)) s) (/ s 4.0f0) (/ (+ (aref r 9) (aref r 6)) s) (/ (- (aref r 8) (aref r 2)) s))))
        (t
         (let ((s (* 2.0f0 (sqrt (+ 1.0f0 (aref r 10) (- (aref r 0)) (- (aref r 5)))))))
           (set-quaternion giro (/ (+ (aref r 8) (aref r 2)) s) (/ (+ (aref r 9) (aref r 6)) s) (/ s 4.0f0) (/ (- (aref r 1) (aref r 4)) s))))))
    (normalize giro) (set-vector3 escala sx sy sz) (values posicao giro escala)))

(defun set-normal-matrix3 (destino matriz4)
  "Calcula a matriz normal inversa-transposta."
  (let ((origem (elements matriz4)) (dados (elements destino)))
    (setf (aref dados 0) (aref origem 0) (aref dados 1) (aref origem 1) (aref dados 2) (aref origem 2)
          (aref dados 3) (aref origem 4) (aref dados 4) (aref origem 5) (aref dados 5) (aref origem 6)
          (aref dados 6) (aref origem 8) (aref dados 7) (aref origem 9) (aref dados 8) (aref origem 10))
    (matrix-transpose (matrix-invert destino))))

(defun set-perspective-matrix4 (matriz campo-visao aspecto proximo distante)
  "Define uma projeção perspectiva em graus."
  (let* ((pi-simples (coerce pi 'single-float))
         (topo (* proximo (tan (* 0.5f0 campo-visao (/ pi-simples 180.0f0)))))
         (altura (* 2.0f0 topo)) (largura (* aspecto altura)) (esquerda (/ largura -2.0f0))
         (direita (- esquerda)) (base (- topo)) (m (elements matriz)))
    (fill m 0.0f0)
    (setf (aref m 0) (/ (* 2.0f0 proximo) (- direita esquerda))
          (aref m 5) (/ (* 2.0f0 proximo) (- topo base))
          (aref m 8) (/ (+ direita esquerda) (- direita esquerda))
          (aref m 9) (/ (+ topo base) (- topo base))
          (aref m 10) (/ (- (+ distante proximo)) (- distante proximo))
          (aref m 11) -1.0f0
          (aref m 14) (/ (- (* 2.0f0 distante proximo)) (- distante proximo))) matriz))

(defun set-orthographic-matrix4 (matriz esquerda direita topo base proximo distante)
  "Define uma projeção ortográfica."
  (let ((m (elements matriz)) (lr (/ 1.0f0 (- esquerda direita)))
        (bt (/ 1.0f0 (- base topo))) (nf (/ 1.0f0 (- proximo distante))))
    (fill m 0.0f0)
    (setf (aref m 0) (* -2.0f0 lr) (aref m 5) (* -2.0f0 bt) (aref m 10) (* 2.0f0 nf)
          (aref m 12) (* (+ esquerda direita) lr) (aref m 13) (* (+ topo base) bt)
          (aref m 14) (* (+ distante proximo) nf) (aref m 15) 1.0f0) matriz))

(defun look-at-matrix4 (matriz olho alvo acima)
  "Define a parte rotacional de uma matriz que olha para um alvo."
  (let ((eixo-z (subtract (clone olho) alvo)) (eixo-x nil) (eixo-y nil) (m (elements matriz)))
    (when (zerop (length-squared eixo-z)) (setf (z eixo-z) 1.0f0))
    (normalize eixo-z)
    (setf eixo-x (cross (clone acima) eixo-z))
    (when (zerop (length-squared eixo-x))
      (incf (x eixo-z) 1.0e-4) (normalize eixo-z) (setf eixo-x (cross (clone acima) eixo-z)))
    (normalize eixo-x) (setf eixo-y (cross (clone eixo-z) eixo-x))
    (set-identity matriz)
    (setf (aref m 0) (x eixo-x) (aref m 1) (x eixo-y) (aref m 2) (x eixo-z)
          (aref m 4) (y eixo-x) (aref m 5) (y eixo-y) (aref m 6) (y eixo-z)
          (aref m 8) (z eixo-x) (aref m 9) (z eixo-y) (aref m 10) (z eixo-z)) matriz))
