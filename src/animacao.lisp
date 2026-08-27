(in-package #:flegrea)

(defvar *alvos-de-trilha* (make-hash-table :test #'equal))

(defun register-track-target (name getter setter value-type interpolator &key blender)
  "Registra um alvo serializável para trilhas de animação."
  (unless (and (or (symbolp name) (stringp name)) (functionp getter) (functionp setter)
               (functionp interpolator) (or (null blender) (functionp blender)))
    (error 'validation-error :message "O contrato do alvo de trilha é inválido."))
  (setf (gethash (string-upcase (string name)) *alvos-de-trilha*)
        (list :getter getter :setter setter :value-type value-type
              :interpolator interpolator :blender blender))
  name)

(defclass keyframe-track ()
  ((alvo :initarg :target :reader track-target)
   (tempos :initarg :times :reader track-times)
   (valores :initarg :values :reader track-values)
   (interpolacao :initarg :interpolation :initform :linear :reader %interpolacao-da-trilha)))

(defclass animation-clip ()
  ((nome :initarg :name :initform "" :accessor name)
   (duracao :initarg :duration :accessor duration)
   (trilhas :initarg :tracks :initform nil :reader %trilhas-do-clipe)))

(defclass animation-mixer ()
  ((raiz :initarg :root :reader %raiz-do-mixer)
   (acoes :initform nil :accessor %acoes-do-mixer)
   (tempo :initform 0.0f0 :accessor %tempo-do-mixer)
   (ouvintes :initform nil :accessor %ouvintes-do-mixer)))

(defclass animation-action ()
  ((mixer :initarg :mixer :reader %mixer-da-acao)
   (clipe :initarg :clip :reader %clipe-da-acao)
   (estado :initform :stopped :accessor %estado-da-acao)
   (tempo :initform 0.0f0 :accessor action-time)
   (escala-de-tempo :initarg :time-scale :initform 1.0f0 :accessor time-scale)
   (peso :initarg :weight :initform 1.0f0 :accessor weight)
   (modo-de-loop :initarg :loop-mode :initform :repeat :accessor loop-mode)
   (repeticoes :initarg :repetitions :initform nil :accessor %repeticoes-da-acao)
   (ciclos :initform 0 :accessor %ciclos-da-acao)
   (fixa-ao-terminar :initarg :clamp-when-finished :initform nil :accessor clamp-when-finished)
   (direcao :initform 1.0f0 :accessor %direcao-da-acao)
   (transicao :initform nil :accessor %transicao-da-acao)))

(defun %vetor-float-animacao (sequencia)
  (let ((saida (make-array (length sequencia) :element-type 'single-float)))
    (loop for valor across (coerce sequencia 'vector) for indice from 0 do
      (unless (realp valor)
        (error 'validation-error :message "Um tempo de keyframe não é numérico."))
      (setf (aref saida indice) (coerce valor 'single-float)))
    saida))

(defun make-keyframe-track (target times values &key (interpolation :linear))
  "Cria uma trilha de keyframes para um alvo registrado."
  (let ((tempos (%vetor-float-animacao times)) (valores (coerce values 'vector)))
    (unless (and (= (length tempos) (length valores)) (plusp (length tempos))
                 (loop for indice from 1 below (length tempos)
                       always (< (aref tempos (1- indice)) (aref tempos indice))))
      (error 'validation-error :message "Tempos e valores da trilha são inconsistentes."))
    (unless (member interpolation '(:linear :step))
      (error 'validation-error :message "A interpolação precisa ser :linear ou :step."))
    (make-instance 'keyframe-track :target target :times tempos :values valores
                   :interpolation interpolation)))

(defun make-animation-clip (&key (name "") duration tracks)
  "Cria um clipe de animação."
  (let ((duracao (or duration
                     (loop for trilha in tracks maximize
                       (aref (track-times trilha) (1- (length (track-times trilha))))))))
    (unless (and (realp duracao) (not (minusp duracao)))
      (error 'validation-error :message "A duração do clipe é inválida."))
    (make-instance 'animation-clip :name name :duration (coerce duracao 'single-float)
                   :tracks tracks)))

(defun make-animation-mixer (root)
  "Cria um mixer ligado a uma raiz de objetos."
  (make-instance 'animation-mixer :root root))

(defun clip-action (mixer clip &key (loop-mode :repeat) repetitions (weight 1.0f0)
                                    (time-scale 1.0f0) clamp-when-finished)
  "Obtém ou cria uma ação para um clipe."
  (or (find clip (%acoes-do-mixer mixer) :key #'%clipe-da-acao :test #'eq)
      (let ((acao (make-instance 'animation-action :mixer mixer :clip clip
                                 :loop-mode loop-mode :repetitions repetitions
                                 :weight weight :time-scale time-scale
                                 :clamp-when-finished clamp-when-finished)))
        (push acao (%acoes-do-mixer mixer)) acao)))

(defun play (action)
  "Inicia ou retoma uma ação."
  (setf (%estado-da-acao action) :playing) action)
(defun pause (action)
  "Pausa uma ação."
  (setf (%estado-da-acao action) :paused) action)
(defun stop (action)
  "Para e rebobina uma ação."
  (setf (%estado-da-acao action) :stopped (action-time action) 0.0f0
        (%ciclos-da-acao action) 0 (%direcao-da-acao action) 1.0f0)
  action)
(defun seek (action time)
  "Posiciona uma ação no tempo do clipe."
  (setf (action-time action) (coerce (max 0 (min (duration (%clipe-da-acao action)) time))
                                     'single-float))
  action)

(defun cross-fade (from to duration)
  "Faz transição linear entre duas ações."
  (unless (plusp duration)
    (error 'validation-error :message "A duração do crossfade precisa ser positiva."))
  (setf (%transicao-da-acao from) (list :elapsed 0.0f0 :duration (coerce duration 'single-float)
                                        :from (weight from) :to 0.0f0)
        (%transicao-da-acao to) (list :elapsed 0.0f0 :duration (coerce duration 'single-float)
                                      :from 0.0f0 :to (weight to))
        (weight to) 0.0f0)
  (play to)
  to)

(defun %interpolar-linear (a b fator)
  (typecase a
    (number (+ a (* (- b a) fator)))
    (quaternion (slerp (clone a) b fator))
    (vector4 (add (multiply-scalar (clone a) (- 1 fator))
                  (multiply-scalar (clone b) fator)))
    (vector3 (add (multiply-scalar (clone a) (- 1 fator))
                  (multiply-scalar (clone b) fator)))
    (vector2 (add (multiply-scalar (clone a) (- 1 fator))
                  (multiply-scalar (clone b) fator)))
    (color
     (let ((ca (convert-color a :linear)) (cb (convert-color b :linear)))
       (make-color (+ (color-r ca) (* (- (color-r cb) (color-r ca)) fator))
                   (+ (color-g ca) (* (- (color-g cb) (color-g ca)) fator))
                   (+ (color-b ca) (* (- (color-b cb) (color-b ca)) fator))
                   :color-space :linear)))
    (t (if (< fator 0.5f0) a b))))

(defun %amostrar-trilha (trilha tempo)
  (let ((tempos (track-times trilha)) (valores (track-values trilha)))
    (cond ((<= tempo (aref tempos 0)) (aref valores 0))
          ((>= tempo (aref tempos (1- (length tempos)))) (aref valores (1- (length valores))))
          (t
           (loop for indice from 0 below (1- (length tempos))
                 when (<= (aref tempos indice) tempo (aref tempos (1+ indice))) do
                   (let ((fator (/ (- tempo (aref tempos indice))
                                   (- (aref tempos (1+ indice)) (aref tempos indice)))))
                     (return (if (eq (%interpolacao-da-trilha trilha) :step)
                                 (aref valores indice)
                                 (%interpolar-linear (aref valores indice)
                                                     (aref valores (1+ indice)) fator)))))))))

(defun %resolver-alvo-de-trilha (mixer alvo)
  (unless (and (consp alvo) (= (length alvo) 2))
    (error 'validation-error :message "Track-target precisa ser (nome objeto-ou-id)."))
  (let* ((registro (gethash (string-upcase (string (first alvo))) *alvos-de-trilha*))
         (identidade (second alvo))
         (objeto (if (keywordp identidade)
                     (if (typep (%raiz-do-mixer mixer) 'scene-instance)
                         (find-object (%raiz-do-mixer mixer) identidade)
                         (error 'validation-error :message "Um alvo por ID requer scene-instance."))
                     identidade)))
    (unless registro
      (error 'validation-error :message "O nome do alvo de trilha não está registrado."))
    (values registro objeto)))

(defun %avancar-loop (acao delta)
  (let* ((duracao (duration (%clipe-da-acao acao)))
         (novo (+ (action-time acao) (* delta (time-scale acao) (%direcao-da-acao acao)))))
    (cond
      ((zerop duracao) (setf novo 0.0f0))
      ((eq (loop-mode acao) :once)
       (when (or (> novo duracao) (< novo 0))
         (setf novo (max 0.0f0 (min duracao novo))
               (%estado-da-acao acao) (if (clamp-when-finished acao) :paused :stopped))))
      ((eq (loop-mode acao) :repeat)
       (loop while (>= novo duracao) do (decf novo duracao) (incf (%ciclos-da-acao acao)))
       (loop while (< novo 0) do (incf novo duracao) (incf (%ciclos-da-acao acao))))
      ((eq (loop-mode acao) :ping-pong)
       (when (or (> novo duracao) (< novo 0))
         (setf novo (if (> novo duracao) (- (* 2 duracao) novo) (- novo))
               (%direcao-da-acao acao) (- (%direcao-da-acao acao)))
         (incf (%ciclos-da-acao acao)))))
    (when (and (%repeticoes-da-acao acao)
               (>= (%ciclos-da-acao acao) (%repeticoes-da-acao acao)))
      (setf (%estado-da-acao acao) (if (clamp-when-finished acao) :paused :stopped)))
    (setf (action-time acao) novo)))

(defun %atualizar-transicao (acao delta)
  (when (%transicao-da-acao acao)
    (let* ((dados (%transicao-da-acao acao))
           (decorrido (+ (getf dados :elapsed) delta))
           (fator (min 1.0f0 (/ decorrido (getf dados :duration)))))
      (setf (getf dados :elapsed) decorrido
            (weight acao) (+ (getf dados :from)
                             (* (- (getf dados :to) (getf dados :from)) fator)))
      (when (= fator 1.0f0) (setf (%transicao-da-acao acao) nil)))))

(defun %misturar-amostras (amostras)
  (let* ((positivas (remove-if-not (lambda (amostra) (plusp (cdr amostra))) amostras))
         (total (reduce #'+ positivas :key #'cdr :initial-value 0.0f0)))
    (cond
      ((or (null positivas) (zerop total)) (car (car amostras)))
      ((numberp (car (first positivas)))
       (/ (reduce #'+ positivas
                  :key (lambda (amostra) (* (car amostra) (cdr amostra)))
                  :initial-value 0.0f0)
          total))
      ((typep (car (first positivas)) 'quaternion)
       (let ((resultado (clone (car (first positivas))))
             (acumulado (cdr (first positivas))))
         (dolist (amostra (rest positivas) resultado)
           (let ((novo-total (+ acumulado (cdr amostra))))
             (slerp resultado (car amostra) (/ (cdr amostra) novo-total))
             (setf acumulado novo-total)))))
      ((typep (car (first positivas)) 'color)
       (let ((r 0.0f0) (g 0.0f0) (b 0.0f0))
         (dolist (amostra positivas)
           (let ((cor (convert-color (car amostra) :linear)) (peso (/ (cdr amostra) total)))
             (incf r (* peso (color-r cor)))
             (incf g (* peso (color-g cor)))
             (incf b (* peso (color-b cor)))))
         (make-color r g b :color-space :linear)))
      ((or (typep (car (first positivas)) 'vector2)
           (typep (car (first positivas)) 'vector3)
           (typep (car (first positivas)) 'vector4))
       (let ((resultado (multiply-scalar (clone (car (first positivas)))
                                         (/ (cdr (first positivas)) total))))
         (dolist (amostra (rest positivas) resultado)
           (add resultado (multiply-scalar (clone (car amostra)) (/ (cdr amostra) total))))))
      (t (car (car (sort (copy-list positivas) #'> :key #'cdr)))))))

(defun mixer-update (mixer delta)
  "Avança ações e aplica valores combinados aos alvos."
  (incf (%tempo-do-mixer mixer) delta)
  (let ((acumulados (make-hash-table :test #'equal)))
    (dolist (acao (%acoes-do-mixer mixer))
      (when (eq (%estado-da-acao acao) :playing)
        (%avancar-loop acao delta)
        (%atualizar-transicao acao delta)
        (dolist (trilha (%trilhas-do-clipe (%clipe-da-acao acao)))
          (push (cons (%amostrar-trilha trilha (action-time acao)) (weight acao))
                (gethash (track-target trilha) acumulados)))))
    (maphash
     (lambda (alvo amostras)
       (multiple-value-bind (registro objeto) (%resolver-alvo-de-trilha mixer alvo)
         (let* ((setter (getf registro :setter)) (misturador (getf registro :blender))
                (valor (if misturador (funcall misturador amostras)
                           (%misturar-amostras amostras))))
           (funcall setter objeto valor))))
     acumulados))
  mixer)

(eval-when (:load-toplevel :execute)
  (register-track-target :position #'position
                         (lambda (objeto valor) (copy-from (position objeto) valor))
                         'vector3 #'%interpolar-linear)
  (register-track-target :rotation #'rotation
                         (lambda (objeto valor) (copy-from (rotation objeto) valor))
                         'euler #'%interpolar-linear)
  (register-track-target :scale #'scale
                         (lambda (objeto valor) (copy-from (scale objeto) valor))
                         'vector3 #'%interpolar-linear)
  (register-track-target :color #'color
                         (lambda (objeto valor) (setf (color objeto) (clone valor)))
                         'color #'%interpolar-linear)
  (register-track-target :intensity #'intensity
                         (lambda (objeto valor) (setf (intensity objeto) valor))
                         'real #'%interpolar-linear)
  (register-track-target :fov #'fov
                         (lambda (objeto valor) (setf (fov objeto) valor)
                           (update-projection-matrix objeto))
                         'real #'%interpolar-linear))
