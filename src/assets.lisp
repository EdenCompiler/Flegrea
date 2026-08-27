(in-package #:flegrea)

(defclass texture (resource)
  ((largura :initarg :width :accessor image-width)
   (altura :initarg :height :accessor image-height)
   (dados :initarg :data :accessor image-data)
   (espaco-de-cor :initarg :color-space :initform :srgb :accessor texture-color-space)
   (gera-mipmaps :initarg :generate-mipmaps :initform t :accessor generate-mipmaps)
   (filtro-minimo :initarg :min-filter :initform :linear-mipmap-linear :accessor min-filter)
   (filtro-maximo :initarg :mag-filter :initform :linear :accessor mag-filter)
   (envolvimento-s :initarg :wrap-s :initform :repeat :accessor wrap-s)
   (envolvimento-t :initarg :wrap-t :initform :repeat :accessor wrap-t)
   (repeticao :initarg :repeat :initform (make-vector2 1 1) :accessor repeat)
   (deslocamento :initarg :offset :initform (make-vector2) :accessor offset)
   (rotacao-da-textura :initarg :rotation :initform 0.0f0 :accessor texture-rotation)
   (centro-da-textura :initarg :center :initform (make-vector2) :accessor texture-center)
   (anisotropia :initarg :anisotropy :initform 1.0f0 :accessor anisotropy)
   (inverte-y :initarg :flip-y :initform t :accessor flip-y)
   (canal-uv :initarg :uv-channel :initform 0 :accessor uv-channel)
   (precisa-atualizar :initarg :needs-update :initform t :accessor needs-update)
   (formato :initarg :format :initform :rgba :reader %formato-da-textura)))

(defclass data-texture (texture) ())

(eval-when (:load-toplevel :execute)
  (register-node-class :data-texture 'meta-node
                       :properties '(:width :height :data :color-space :generate-mipmaps
                                     :min-filter :mag-filter :wrap-s :wrap-t :repeat :offset
                                     :texture-rotation :texture-center :anisotropy :flip-y
                                     :uv-channel :name)
                       :bindable-properties nil :child-policy :none :resource-p t))

(defmethod flegrea.meta::%criar-recurso-estendido
    ((tag (eql :data-texture)) no contexto)
  (declare (ignore tag contexto))
  (flet ((p (chave padrao)
           (flegrea.meta::%propriedade-resolvida no chave 0.0f0 0.0f0 padrao)))
    (make-data-texture
     (p :width 1) (p :height 1)
     (coerce (p :data '(255 255 255 255)) '(vector (unsigned-byte 8)))
     :color-space (p :color-space :srgb)
     :generate-mipmaps (p :generate-mipmaps t)
     :min-filter (p :min-filter :linear-mipmap-linear)
     :mag-filter (p :mag-filter :linear) :wrap-s (p :wrap-s :repeat)
     :wrap-t (p :wrap-t :repeat) :repeat (p :repeat (make-vector2 1 1))
     :offset (p :offset (make-vector2))
     :rotation (p :texture-rotation 0.0f0)
     :center (p :texture-center (make-vector2))
     :anisotropy (p :anisotropy 1.0f0) :flip-y (p :flip-y t)
     :uv-channel (p :uv-channel 0) :name (p :name ""))))

(defmethod flegrea.meta::%copiar-recurso-estendido
    ((destino texture) (origem texture))
  (setf (image-width destino) (image-width origem)
        (image-height destino) (image-height origem)
        (image-data destino) (copy-seq (image-data origem))
        (texture-color-space destino) (texture-color-space origem)
        (generate-mipmaps destino) (generate-mipmaps origem)
        (min-filter destino) (min-filter origem)
        (mag-filter destino) (mag-filter origem)
        (wrap-s destino) (wrap-s origem) (wrap-t destino) (wrap-t origem)
        (repeat destino) (clone (repeat origem)) (offset destino) (clone (offset origem))
        (texture-rotation destino) (texture-rotation origem)
        (texture-center destino) (clone (texture-center origem))
        (anisotropy destino) (anisotropy origem) (flip-y destino) (flip-y origem)
        (uv-channel destino) (uv-channel origem)
        (needs-update destino) t)
  t)

(defmethod initialize-instance :after ((textura texture) &key)
  (unless (and (integerp (image-width textura)) (plusp (image-width textura))
               (integerp (image-height textura)) (plusp (image-height textura)))
    (error 'validation-error :message "As dimensões da textura precisam ser positivas."))
  (unless (member (texture-color-space textura) '(:srgb :linear :none))
    (error 'validation-error :message "O espaço de cor da textura é inválido."))
  (unless (member (uv-channel textura) '(0 1))
    (error 'validation-error :message "O canal UV da textura precisa ser zero ou um.")))

(defun make-texture (width height data &rest options &key &allow-other-keys)
  "Cria uma textura bidimensional a partir de octetos."
  (apply #'make-instance 'texture :width width :height height :data data options))

(defun make-data-texture (width height data &rest options &key &allow-other-keys)
  "Cria uma textura de dados bidimensional."
  (apply #'make-instance 'data-texture :width width :height height :data data options))

(defmethod dispose ((textura texture))
  (unless (disposed-p textura) (setf (image-data textura) #()))
  (call-next-method))

(defun %ler-octetos (caminho)
  (with-open-file (fluxo caminho :direction :input :element-type '(unsigned-byte 8))
    (let ((dados (make-array (file-length fluxo) :element-type '(unsigned-byte 8))))
      (read-sequence dados fluxo)
      dados)))

(defun %u32-grande (dados inicio)
  (logior (ash (aref dados inicio) 24) (ash (aref dados (+ inicio 1)) 16)
          (ash (aref dados (+ inicio 2)) 8) (aref dados (+ inicio 3))))

(defun %paeth (a b c)
  (let* ((p (- (+ a b) c)) (pa (abs (- p a))) (pb (abs (- p b))) (pc (abs (- p c))))
    (cond ((and (<= pa pb) (<= pa pc)) a) ((<= pb pc) b) (t c))))

(defun %decodificar-png-octetos (arquivo &optional caminho)
  (let* ((assinatura #(137 80 78 71 13 10 26 10))
         (cursor 8) (largura nil) (altura nil) (tipo nil) (profundidade nil)
         (comprimido (make-array 0 :element-type '(unsigned-byte 8)
                                 :adjustable t :fill-pointer 0)))
    (unless (and (>= (length arquivo) 8)
                 (loop for i below 8 always (= (aref arquivo i) (aref assinatura i))))
      (error 'asset-error :message "A assinatura PNG é inválida." :path caminho :stage :decode))
    (loop while (<= (+ cursor 12) (length arquivo)) do
      (let* ((tamanho (%u32-grande arquivo cursor))
             (nome (map 'string #'code-char (subseq arquivo (+ cursor 4) (+ cursor 8))))
             (inicio (+ cursor 8)) (fim (+ inicio tamanho)))
        (when (> (+ fim 4) (length arquivo))
          (error 'asset-error :message "Um chunk PNG ultrapassa o arquivo." :path caminho :stage :decode))
        (cond
          ((string= nome "IHDR")
           (setf largura (%u32-grande arquivo inicio) altura (%u32-grande arquivo (+ inicio 4))
                 profundidade (aref arquivo (+ inicio 8)) tipo (aref arquivo (+ inicio 9)))
           (unless (and (= profundidade 8) (member tipo '(0 2 6))
                        (zerop (aref arquivo (+ inicio 12))))
             (error 'asset-error :message "Flegrea aceita PNG 8-bit, não entrelaçado, gray/RGB/RGBA."
                    :path caminho :stage :decode)))
          ((string= nome "IDAT")
           (loop for i from inicio below fim do (vector-push-extend (aref arquivo i) comprimido)))
          ((string= nome "IEND") (return)))
        (setf cursor (+ fim 4))))
    (unless (and largura altura tipo)
      (error 'asset-error :message "O PNG não contém IHDR válido." :path caminho :stage :decode))
    (let* ((canais (ecase tipo (0 1) (2 3) (6 4)))
           (linha (* largura canais))
           ;; CHIPZ exige um vetor simples mesmo quando os chunks foram acumulados
           ;; em um vetor ajustável.
           (inflado (chipz:decompress nil 'chipz:zlib (subseq comprimido 0)))
           (bruto (make-array (* altura linha) :element-type '(unsigned-byte 8)))
           (rgba (make-array (* largura altura 4) :element-type '(unsigned-byte 8))))
      (unless (= (length inflado) (* altura (1+ linha)))
        (error 'asset-error :message "O tamanho descomprimido do PNG é inconsistente."
               :path caminho :stage :decode))
      (dotimes (y altura)
        (let ((filtro (aref inflado (* y (1+ linha)))))
          (dotimes (x linha)
            (let* ((origem (+ (* y (1+ linha)) 1 x)) (destino (+ (* y linha) x))
                   (valor (aref inflado origem))
                   (a (if (>= x canais) (aref bruto (- destino canais)) 0))
                   (b (if (plusp y) (aref bruto (- destino linha)) 0))
                   (c (if (and (plusp y) (>= x canais))
                          (aref bruto (- destino linha canais)) 0)))
              (setf (aref bruto destino)
                    (mod (+ valor (case filtro (0 0) (1 a) (2 b)
                                        (3 (floor (+ a b) 2)) (4 (%paeth a b c))
                                        (otherwise
                                         (error 'asset-error :message "O filtro PNG é inválido."
                                                :path caminho :stage :decode)))) 256))))))
      (dotimes (pixel (* largura altura))
        (let ((entrada (* pixel canais)) (saida (* pixel 4)))
          (ecase canais
            (1 (let ((v (aref bruto entrada)))
                 (setf (aref rgba saida) v (aref rgba (+ saida 1)) v
                       (aref rgba (+ saida 2)) v (aref rgba (+ saida 3)) 255)))
            (3 (setf (aref rgba saida) (aref bruto entrada)
                     (aref rgba (+ saida 1)) (aref bruto (+ entrada 1))
                     (aref rgba (+ saida 2)) (aref bruto (+ entrada 2))
                     (aref rgba (+ saida 3)) 255))
            (4 (replace rgba bruto :start1 saida :end1 (+ saida 4)
                        :start2 entrada :end2 (+ entrada 4))))))
      (values rgba largura altura))))

(defun %decodificar-png (caminho)
  (%decodificar-png-octetos (%ler-octetos caminho) caminho))

(defun %rgba-de-jpeg (dados altura largura canais)
  (let ((rgba (make-array (* largura altura 4) :element-type '(unsigned-byte 8))))
    (dotimes (pixel (* largura altura))
      (let ((entrada (* pixel canais)) (saida (* pixel 4)))
        (if (= canais 1)
            (let ((v (aref dados entrada)))
              (setf (aref rgba saida) v (aref rgba (+ saida 1)) v (aref rgba (+ saida 2)) v))
            (setf (aref rgba saida) (aref dados entrada)
                  (aref rgba (+ saida 1)) (aref dados (+ entrada 1))
                  (aref rgba (+ saida 2)) (aref dados (+ entrada 2))))
        (setf (aref rgba (+ saida 3)) 255)))
    (values rgba largura altura)))

(defun %decodificar-jpeg (caminho)
  (multiple-value-bind (dados altura largura canais) (jpeg:decode-image caminho)
    (%rgba-de-jpeg dados altura largura canais)))

(defun %decodificar-jpeg-octetos (octetos)
  (let ((fluxo (flexi-streams:make-in-memory-input-stream octetos)))
    (unwind-protect
         (multiple-value-bind (dados altura largura canais) (jpeg:decode-stream fluxo)
           (%rgba-de-jpeg dados altura largura canais))
      (close fluxo))))

(defun %decodificar-imagem-octetos (octetos tipo &optional caminho)
  (let ((tipo-normalizado (string-downcase (or tipo ""))))
    (cond
      ((or (search "png" tipo-normalizado)
           (and (>= (length octetos) 8)
                (= (aref octetos 0) 137) (= (aref octetos 1) 80)))
       (%decodificar-png-octetos octetos caminho))
      ((or (search "jpeg" tipo-normalizado) (search "jpg" tipo-normalizado)
           (and (>= (length octetos) 2)
                (= (aref octetos 0) #xff) (= (aref octetos 1) #xd8)))
       (%decodificar-jpeg-octetos octetos))
      (t
       (error 'asset-error :message "A imagem embutida não é PNG nem JPEG."
              :path caminho :stage :decode)))))

(defun load-texture (path &rest options &key &allow-other-keys)
  "Carrega uma textura PNG ou JPEG do sistema de arquivos."
  (let* ((caminho (uiop:ensure-pathname path :want-existing t))
         (tipo (string-downcase (or (pathname-type caminho) ""))))
    (multiple-value-bind (dados largura altura)
        (cond ((string= tipo "png") (%decodificar-png caminho))
              ((member tipo '("jpg" "jpeg") :test #'string=) (%decodificar-jpeg caminho))
              (t (error 'asset-error :message "O formato de imagem não é PNG nem JPEG."
                        :path caminho :stage :decode)))
      (apply #'make-texture largura altura dados options))))

(defun load-texture-async (path &rest options &key (manager (default-loading-manager))
                                             &allow-other-keys)
  "Inicia leitura e decodificação de uma textura fora do thread chamador."
  (let* ((caminho (namestring (uiop:ensure-pathname path :want-existing t)))
         (opcoes (alexandria:remove-from-plist options :manager))
         (chave (list :texture caminho opcoes)))
    (or (let ((valor (gethash chave (%cache-de-assets manager))))
          (when valor
            (let ((job (make-instance 'load-job)))
              (setf (job-status job) :completed (job-stage job) :complete
                    (job-progress job) 1.0f0 (job-result job) valor)
              job)))
        (%iniciar-job manager chave
                      (lambda (job)
                        (setf (job-stage job) :decode (job-progress job) 0.35f0)
                        (apply #'load-texture caminho opcoes))))))

(defclass load-job ()
  ((estado :initform :pending :accessor job-status)
   (etapa :initform :queued :accessor job-stage)
   (progresso :initform 0.0f0 :accessor job-progress)
   (resultado :initform nil :accessor job-result)
   (erro :initform nil :accessor job-error)
   (cancelado :initform nil :accessor %job-cancelado-p)
   (ouvintes :initform nil :accessor %ouvintes-do-job)
   (trava :initform (bt:make-lock "job Flegrea") :reader %trava-do-job)))

(defclass loading-manager ()
  ((cache :initform (make-hash-table :test #'equal) :reader %cache-de-assets)
   (em-voo :initform (make-hash-table :test #'equal) :reader %assets-em-voo)
   (resolvedores :initform (make-hash-table :test #'equal) :reader %resolvedores)
   (fila-principal :initform nil :accessor %fila-principal)
   (trava :initform (bt:make-lock "loading manager Flegrea") :reader %trava-do-manager)))

(defvar *default-loading-manager* nil)

(defun make-loading-manager ()
  "Cria um gerenciador isolado de assets."
  (make-instance 'loading-manager))

(defun default-loading-manager ()
  "Retorna o gerenciador global criado sob demanda."
  (or *default-loading-manager* (setf *default-loading-manager* (make-loading-manager))))

(defun cancel-job (job)
  "Solicita o cancelamento cooperativo de um job."
  (bt:with-lock-held ((%trava-do-job job))
    (setf (%job-cancelado-p job) t)
    (when (eq (job-status job) :pending) (setf (job-status job) :cancelled)))
  job)

(defun add-job-listener (job listener)
  "Adiciona uma função chamada no thread de renderização quando o job muda."
  (check-type listener function)
  (bt:with-lock-held ((%trava-do-job job)) (push listener (%ouvintes-do-job job)))
  job)

(defun %enfileirar-principal (manager function)
  (bt:with-lock-held ((%trava-do-manager manager))
    (setf (%fila-principal manager) (nconc (%fila-principal manager) (list function)))))

(defun drain-loading-manager (manager)
  "Executa uploads e callbacks pendentes no thread chamador."
  (let ((fila nil))
    (bt:with-lock-held ((%trava-do-manager manager))
      (setf fila (%fila-principal manager) (%fila-principal manager) nil))
    (dolist (funcao fila) (funcall funcao)))
  manager)

(defun register-uri-resolver (manager scheme resolver)
  "Registra um resolvedor explícito para um esquema de URI."
  (check-type resolver function)
  (setf (gethash (string-downcase (string scheme)) (%resolvedores manager)) resolver)
  manager)

(defun evict-asset (manager key &key dispose)
  "Remove uma entrada do cache e opcionalmente descarta seu recurso."
  (let ((valor (gethash key (%cache-de-assets manager))))
    (remhash key (%cache-de-assets manager))
    (when (and dispose valor (typep valor 'resource)) (flegrea:dispose valor))
    valor))

(defun clear-asset-cache (manager &key dispose)
  "Esvazia o cache de um gerenciador."
  (when dispose
    (maphash (lambda (chave valor) (declare (ignore chave))
               (when (typep valor 'resource) (flegrea:dispose valor)))
             (%cache-de-assets manager)))
  (clrhash (%cache-de-assets manager))
  manager)

(defun %notificar-job (manager job)
  (%enfileirar-principal
   manager
   (lambda ()
     (dolist (ouvinte (reverse (%ouvintes-do-job job))) (funcall ouvinte job)))))

(defun %iniciar-job (manager key worker)
  (bt:with-lock-held ((%trava-do-manager manager))
    (or (gethash key (%assets-em-voo manager))
        (let ((job (make-instance 'load-job)))
          (setf (gethash key (%assets-em-voo manager)) job)
          (bt:make-thread
           (lambda ()
             (handler-case
                 (progn
                   (setf (job-status job) :running (job-stage job) :loading
                         (job-progress job) 0.1f0)
                   (let ((resultado (unless (%job-cancelado-p job) (funcall worker job))))
                     (%enfileirar-principal
                      manager
                      (lambda ()
                        (bt:with-lock-held ((%trava-do-manager manager))
                          (remhash key (%assets-em-voo manager))
                          (unless (%job-cancelado-p job)
                            (setf (gethash key (%cache-de-assets manager)) resultado)))
                        (setf (job-result job) resultado
                              (job-status job) (if (%job-cancelado-p job) :cancelled :completed)
                              (job-stage job) :complete (job-progress job) 1.0f0)
                        (dolist (ouvinte (reverse (%ouvintes-do-job job)))
                          (funcall ouvinte job))))))
               (error (condicao)
                 (%enfileirar-principal
                  manager
                  (lambda ()
                    (bt:with-lock-held ((%trava-do-manager manager))
                      (remhash key (%assets-em-voo manager)))
                    (setf (job-error job) condicao (job-status job) :failed
                          (job-stage job) :failed)
                    (dolist (ouvinte (reverse (%ouvintes-do-job job)))
                      (funcall ouvinte job)))))))
           :name (format nil "Flegrea asset ~A" key))
          job))))
