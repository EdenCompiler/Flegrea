(in-package #:flegrea)

(define-condition asset-error (flegrea-error)
  ((operacao :initarg :operation :initform nil :reader error-operation)
   (caminho :initarg :path :initform nil :reader error-path)
   (etapa :initarg :stage :initform nil :reader error-stage)
   (no :initarg :node :initform nil :reader error-node)
   (extensao :initarg :extension :initform nil :reader error-extension)
   (causa :initarg :cause :initform nil :reader error-cause)))

(define-condition gltf-error (asset-error) ())
(define-condition metagraph-error (flegrea-error)
  ((operacao :initarg :operation :initform nil :reader error-operation)
   (caminho :initarg :path :initform nil :reader error-path)
   (etapa :initarg :stage :initform nil :reader error-stage)
   (no :initarg :node :initform nil :reader error-node)
   (extensao :initarg :extension :initform nil :reader error-extension)
   (causa :initarg :cause :initform nil :reader error-cause)))

(define-condition disposed-resource-error (flegrea-error)
  ((operacao :initarg :operation :initform nil :reader error-operation)
   (recurso :initarg :resource :reader %recurso-descartado)))

(defvar *contador-de-recursos* 0)
(defvar *trava-de-recursos* (bt:make-lock "contador de recursos Flegrea"))

(defun %proximo-id-de-recurso ()
  (bt:with-lock-held (*trava-de-recursos*)
    (incf *contador-de-recursos*)))

(defclass resource ()
  ((resource-id :initform (%proximo-id-de-recurso) :reader resource-id)
   (resource-name :initarg :name :initform "" :accessor resource-name)
   (descartado-p :initform nil :accessor disposed-p)))

(defgeneric dispose (resource)
  (:documentation "Libera um recurso de forma idempotente."))

(defmethod dispose ((recurso resource))
  (setf (disposed-p recurso) t)
  recurso)

(defun %verificar-recurso-vivo (recurso operacao)
  (when (and (typep recurso 'resource) (disposed-p recurso))
    (error 'disposed-resource-error
           :message (format nil "O recurso ~A já foi descartado." (resource-id recurso))
           :operation operacao :resource recurso))
  recurso)

(defclass color ()
  ((vermelho :initarg :r :initform 1.0f0 :accessor color-r)
   (verde :initarg :g :initform 1.0f0 :accessor color-g)
   (azul :initarg :b :initform 1.0f0 :accessor color-b)
   (espaco :initarg :color-space :initform :srgb :accessor color-space)))

(defun %componente-de-cor (valor)
  (unless (and (realp valor) (<= 0 valor 1))
    (error 'validation-error :message "Um componente de cor precisa estar entre zero e um."))
  (coerce valor 'single-float))

(defmethod initialize-instance :after ((cor color) &key)
  (setf (color-r cor) (%componente-de-cor (color-r cor))
        (color-g cor) (%componente-de-cor (color-g cor))
        (color-b cor) (%componente-de-cor (color-b cor)))
  (unless (member (color-space cor) '(:srgb :linear))
    (error 'validation-error :message "Color-space precisa ser :srgb ou :linear.")))

(defun make-color (&optional (r 1.0f0) (g 1.0f0) (b 1.0f0) &rest options)
  "Cria uma cor no espaço sRGB ou linear."
  (unless (and (evenp (length options))
               (loop for restante on options by #'cddr
                     always (eq (first restante) :color-space)))
    (error 'validation-error :message "As opções de color são inválidas."))
  (make-instance 'color :r r :g g :b b
                 :color-space (getf options :color-space :srgb)))

(defun set-color (cor r g b &optional (espaco (color-space cor)))
  "Altera componentes e espaço de uma cor."
  (setf (color-r cor) (%componente-de-cor r)
        (color-g cor) (%componente-de-cor g)
        (color-b cor) (%componente-de-cor b)
        (color-space cor) espaco)
  cor)

(defun set-color-hex (cor valor)
  "Altera uma cor sRGB a partir de um inteiro hexadecimal de 24 bits."
  (unless (and (integerp valor) (<= 0 valor #xffffff))
    (error 'validation-error :message "A cor hexadecimal precisa ter 24 bits."))
  (set-color cor (/ (ldb (byte 8 16) valor) 255.0f0)
             (/ (ldb (byte 8 8) valor) 255.0f0)
             (/ (ldb (byte 8 0) valor) 255.0f0) :srgb))

(defun color-hex (cor)
  "Retorna a aproximação sRGB de uma cor como inteiro hexadecimal."
  (let ((srgb (convert-color cor :srgb)))
    (logior (ash (round (* 255 (color-r srgb))) 16)
            (ash (round (* 255 (color-g srgb))) 8)
            (round (* 255 (color-b srgb))))))

(defun srgb-to-linear (valor)
  "Converte um componente sRGB para linear."
  (let ((v (%componente-de-cor valor)))
    (if (<= v 0.04045f0) (/ v 12.92f0)
        (expt (/ (+ v 0.055f0) 1.055f0) 2.4f0))))

(defun linear-to-srgb (valor)
  "Converte um componente linear para sRGB."
  (let ((v (%componente-de-cor valor)))
    (if (<= v 0.0031308f0) (* 12.92f0 v)
        (- (* 1.055f0 (expt v (/ 1.0f0 2.4f0))) 0.055f0))))

(defun convert-color (cor espaco)
  "Cria uma cópia da cor no espaço solicitado."
  (unless (typep cor 'color)
    (error 'validation-error :message "Era esperada uma instância de color."))
  (cond
    ((eq espaco (color-space cor))
     (make-color (color-r cor) (color-g cor) (color-b cor) :color-space espaco))
    ((and (eq (color-space cor) :srgb) (eq espaco :linear))
     (make-color (srgb-to-linear (color-r cor)) (srgb-to-linear (color-g cor))
                 (srgb-to-linear (color-b cor)) :color-space :linear))
    ((and (eq (color-space cor) :linear) (eq espaco :srgb))
     (make-color (linear-to-srgb (color-r cor)) (linear-to-srgb (color-g cor))
                 (linear-to-srgb (color-b cor)) :color-space :srgb))
    (t (error 'validation-error :message "O espaço de cor solicitado não é suportado."))))

(defmethod clone ((cor color))
  (make-color (color-r cor) (color-g cor) (color-b cor) :color-space (color-space cor)))

(defmethod copy-from ((destino color) (origem color))
  (set-color destino (color-r origem) (color-g origem) (color-b origem) (color-space origem)))

(defmethod copy-from ((destino color) (origem vector3))
  (set-color destino (x origem) (y origem) (z origem) :srgb))

(defmethod equals ((a color) (b color) &optional (tolerancia 1.0e-6))
  (and (eq (color-space a) (color-space b))
       (<= (abs (- (color-r a) (color-r b))) tolerancia)
       (<= (abs (- (color-g a) (color-g b))) tolerancia)
       (<= (abs (- (color-b a) (color-b b))) tolerancia)))
