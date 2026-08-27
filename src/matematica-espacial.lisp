(in-package #:flegrea)

(defclass box3 ()
  ((minimo :initarg :min :accessor min-point)
   (maximo :initarg :max :accessor max-point)))

(defclass sphere ()
  ((centro :initarg :center :accessor center)
   (raio :initarg :radius :accessor radius)))

(defclass ray ()
  ((origem :initarg :origin :accessor origin)
   (direcao :initarg :direction :accessor direction)))

(defclass plane ()
  ((normal-do-plano :initarg :normal :accessor normal)
   (constante :initarg :constant :accessor constant)))

(defclass triangle ()
  ((a :initarg :a :accessor point-a)
   (b :initarg :b :accessor point-b)
   (c :initarg :c :accessor point-c)))

(defclass frustum ()
  ((planos :initarg :planes :accessor planes)))

(defun make-box3 (&optional (min (make-vector3 most-positive-single-float
                                                most-positive-single-float
                                                most-positive-single-float))
                            (max (make-vector3 most-negative-single-float
                                              most-negative-single-float
                                              most-negative-single-float)))
  "Cria uma caixa alinhada aos eixos."
  (make-instance 'box3 :min (clone min) :max (clone max)))

(defun make-sphere (&optional (center (make-vector3)) (radius 0.0f0))
  "Cria um volume esférico."
  (make-instance 'sphere :center (clone center) :radius (coerce radius 'single-float)))

(defun make-ray (&optional (origin (make-vector3)) (direction (make-vector3 0 0 -1)))
  "Cria um raio com direção normalizada."
  (make-instance 'ray :origin (clone origin) :direction (normalize (clone direction))))

(defun make-plane (&optional (normal (make-vector3 1 0 0)) (constant 0.0f0))
  "Cria um plano pela equação normal ponto mais constante."
  (make-instance 'plane :normal (normalize (clone normal)) :constant (coerce constant 'single-float)))

(defun make-triangle (&optional (a (make-vector3)) (b (make-vector3)) (c (make-vector3)))
  "Cria um triângulo."
  (make-instance 'triangle :a (clone a) :b (clone b) :c (clone c)))

(defun make-frustum (&optional planos)
  "Cria um frustum com seis planos."
  (make-instance 'frustum :planes
                 (or planos (loop repeat 6 collect (make-plane)))))

(defun empty-p (caixa)
  "Informa se uma caixa não contém pontos."
  (or (> (x (min-point caixa)) (x (max-point caixa)))
      (> (y (min-point caixa)) (y (max-point caixa)))
      (> (z (min-point caixa)) (z (max-point caixa)))))

(defun expand-by-point (caixa ponto)
  "Expande uma caixa para incluir um ponto."
  (setf (x (min-point caixa)) (min (x (min-point caixa)) (x ponto))
        (y (min-point caixa)) (min (y (min-point caixa)) (y ponto))
        (z (min-point caixa)) (min (z (min-point caixa)) (z ponto))
        (x (max-point caixa)) (max (x (max-point caixa)) (x ponto))
        (y (max-point caixa)) (max (y (max-point caixa)) (y ponto))
        (z (max-point caixa)) (max (z (max-point caixa)) (z ponto)))
  caixa)

(defgeneric contains-point-p (volume point))
(defgeneric intersects-box-p (volume box))
(defgeneric intersects-sphere-p (volume sphere))
(defgeneric distance-to-point (object point))

(defmethod contains-point-p ((caixa box3) (ponto vector3))
  (and (<= (x (min-point caixa)) (x ponto) (x (max-point caixa)))
       (<= (y (min-point caixa)) (y ponto) (y (max-point caixa)))
       (<= (z (min-point caixa)) (z ponto) (z (max-point caixa)))))

(defmethod contains-point-p ((esfera sphere) (ponto vector3))
  (<= (length-squared (subtract (clone ponto) (center esfera)))
      (* (radius esfera) (radius esfera))))

(defmethod distance-to-point ((plano plane) (ponto vector3))
  (+ (dot (normal plano) ponto) (constant plano)))

(defmethod distance-to-point ((raio ray) (ponto vector3))
  (let* ((deslocamento (subtract (clone ponto) (origin raio)))
         (projecao (max 0.0f0 (dot deslocamento (direction raio))))
         (mais-proximo (add (clone (origin raio))
                            (multiply-scalar (clone (direction raio)) projecao))))
    (vector-length (subtract mais-proximo ponto))))

(defmethod intersects-box-p ((a box3) (b box3))
  (not (or (< (x (max-point a)) (x (min-point b)))
           (> (x (min-point a)) (x (max-point b)))
           (< (y (max-point a)) (y (min-point b)))
           (> (y (min-point a)) (y (max-point b)))
           (< (z (max-point a)) (z (min-point b)))
           (> (z (min-point a)) (z (max-point b))))))

(defmethod intersects-sphere-p ((caixa box3) (esfera sphere))
  (let* ((c (center esfera))
         (px (max (x (min-point caixa)) (min (x (max-point caixa)) (x c))))
         (py (max (y (min-point caixa)) (min (y (max-point caixa)) (y c))))
         (pz (max (z (min-point caixa)) (min (z (max-point caixa)) (z c))))
         (d (make-vector3 (- px (x c)) (- py (y c)) (- pz (z c)))))
    (<= (length-squared d) (* (radius esfera) (radius esfera)))))

(defmethod intersects-box-p ((frustum frustum) (caixa box3))
  (every (lambda (plano)
           (let ((vertice (make-vector3
                           (if (plusp (x (normal plano))) (x (max-point caixa)) (x (min-point caixa)))
                           (if (plusp (y (normal plano))) (y (max-point caixa)) (y (min-point caixa)))
                           (if (plusp (z (normal plano))) (z (max-point caixa)) (z (min-point caixa))))))
             (>= (distance-to-point plano vertice) 0.0f0)))
         (planes frustum)))

(defmethod intersects-sphere-p ((frustum frustum) (esfera sphere))
  (every (lambda (plano)
           (>= (distance-to-point plano (center esfera)) (- (radius esfera))))
         (planes frustum)))

(defun ray-at (raio distancia &optional (destino (make-vector3)))
  "Calcula um ponto ao longo de um raio."
  (copy-from destino (direction raio))
  (multiply-scalar destino distancia)
  (add destino (origin raio)))

(defun intersect-ray-plane (raio plano &optional (destino (make-vector3)))
  "Retorna a interseção de raio e plano, ou NIL."
  (let ((denominador (dot (normal plano) (direction raio))))
    (cond
      ((< (abs denominador) 1.0e-7)
       (when (< (abs (distance-to-point plano (origin raio))) 1.0e-7)
         (copy-from destino (origin raio))))
      (t
       (let ((distancia (/ (- (+ (dot (origin raio) (normal plano)) (constant plano))) denominador)))
         (when (>= distancia 0.0f0) (ray-at raio distancia destino)))))))

(defun intersect-ray-triangle (raio triangulo &key (backface-culling nil) (target (make-vector3)))
  "Retorna a interseção de um raio com um triângulo, ou NIL."
  (let* ((aresta1 (subtract (clone (point-b triangulo)) (point-a triangulo)))
         (aresta2 (subtract (clone (point-c triangulo)) (point-a triangulo)))
         (p (cross (clone (direction raio)) aresta2))
         (determinante (dot aresta1 p)))
    (when (if backface-culling (> determinante 1.0e-7) (> (abs determinante) 1.0e-7))
      (let* ((inverso (/ 1.0f0 determinante))
             (tvec (subtract (clone (origin raio)) (point-a triangulo)))
             (u (* (dot tvec p) inverso)))
        (when (<= 0.0f0 u 1.0f0)
          (let* ((q (cross tvec aresta1))
                 (v (* (dot (direction raio) q) inverso))
                 (distancia (* (dot aresta2 q) inverso)))
            (when (and (>= v 0.0f0) (<= (+ u v) 1.0f0) (>= distancia 0.0f0))
              (ray-at raio distancia target))))))))

(defun %normalizar-plano (plano)
  (let ((comprimento (vector-length (normal plano))))
    (unless (zerop comprimento)
      (divide-scalar (normal plano) comprimento)
      (setf (constant plano) (/ (constant plano) comprimento))))
  plano)

(defun set-from-projection-matrix (frustum matriz)
  "Extrai os seis planos de uma matriz de projeção composta."
  (let ((m (elements matriz)))
    (flet ((definir (indice a b c d)
             (let ((plano (nth indice (planes frustum))))
               (set-vector3 (normal plano) a b c)
               (setf (constant plano) (coerce d 'single-float))
               (%normalizar-plano plano))))
      (definir 0 (- (aref m 3) (aref m 0)) (- (aref m 7) (aref m 4))
               (- (aref m 11) (aref m 8)) (- (aref m 15) (aref m 12)))
      (definir 1 (+ (aref m 3) (aref m 0)) (+ (aref m 7) (aref m 4))
               (+ (aref m 11) (aref m 8)) (+ (aref m 15) (aref m 12)))
      (definir 2 (+ (aref m 3) (aref m 1)) (+ (aref m 7) (aref m 5))
               (+ (aref m 11) (aref m 9)) (+ (aref m 15) (aref m 13)))
      (definir 3 (- (aref m 3) (aref m 1)) (- (aref m 7) (aref m 5))
               (- (aref m 11) (aref m 9)) (- (aref m 15) (aref m 13)))
      (definir 4 (- (aref m 3) (aref m 2)) (- (aref m 7) (aref m 6))
               (- (aref m 11) (aref m 10)) (- (aref m 15) (aref m 14)))
      (definir 5 (+ (aref m 3) (aref m 2)) (+ (aref m 7) (aref m 6))
               (+ (aref m 11) (aref m 10)) (+ (aref m 15) (aref m 14)))))
  frustum)
