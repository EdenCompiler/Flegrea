(in-package #:flegrea.meta)

(defclass flegrea:scene-parameter ()
  ((nome :initarg :name :reader flegrea:parameter-name)
   (tipo :initarg :type :reader flegrea:parameter-type)
   (padrao :initarg :default :reader flegrea:parameter-default)
   (validador :initarg :validator :initform nil :reader flegrea:parameter-validator)))

(defclass flegrea:hot-reload-event ()
  ((tipo :initarg :kind :reader flegrea:event-kind)
   (detalhe :initarg :detail :reader flegrea:event-detail)))

(defclass %controle-de-hot-reload ()
  ((instancia :initarg :instance :reader %instancia-hot)
   (caminho :initarg :path :reader %caminho-hot)
   (intervalo :initarg :interval :reader %intervalo-hot)
   (callback :initarg :callback :initform nil :reader %callback-hot)
   (ativo :initform t :accessor %ativo-hot)
   (data :initform nil :accessor %data-hot)
   (pendente :initform nil :accessor %pendente-hot)
   (erro :initform nil :accessor %erro-hot)
   (trava :initform (bt:make-lock "hot reload Flegrea") :reader %trava-hot)
   (thread :initform nil :accessor %thread-hot)))

(defvar *funcoes-de-binding* (make-hash-table :test #'equal))
(defvar *hot-reloads* nil)
(defvar *trava-de-hot-reloads* (bt:make-lock "lista de hot reload Flegrea"))
(defparameter *parse-scene-base* #'%parse-scene-base-legacy)

(defun flegrea:register-binding-function (name function &key validator)
  "Registra uma função nomeada permitida pela AST de bindings."
  (unless (and (or (symbolp name) (stringp name)) (functionp function)
               (or (null validator) (functionp validator)))
    (error 'flegrea:validation-error :message "O registro da função de binding é inválido."))
  (setf (gethash (string-upcase (string name)) *funcoes-de-binding*)
        (list :function function :validator validator))
  name)

(defun %registro-de-binding (simbolo)
  (gethash (string-upcase (string simbolo)) *funcoes-de-binding*))

(defun %operador-permitido-p (simbolo)
  (not (null (%registro-de-binding simbolo))))

(defun %validar-expressao (forma)
  (cond
    ((realp forma) t)
    ((member forma '(:time :delta) :test #'eq) t)
    ((and (consp forma) (member (first forma) '(:state :parameter))
          (= (length forma) 2) (keywordp (second forma))) t)
    ((and (consp forma) (symbolp (first forma)) (%operador-permitido-p (first forma)))
     (let* ((registro (%registro-de-binding (first forma)))
            (argumentos (rest forma)) (validador (getf registro :validator)))
       (every #'%validar-expressao argumentos)
       (when validador (funcall validador argumentos))
       t))
    (t (error 'flegrea:validation-error
              :message "Um binding contém uma expressão fora da AST registrada."))))

(setf *validador-de-expressao* #'%validar-expressao)

(defvar *estado-do-binding* nil)
(defvar *parametros-do-binding* nil)

(defun %avaliar-expressao (forma tempo delta)
  (cond
    ((realp forma) (coerce forma 'single-float))
    ((eq forma :time) tempo)
    ((eq forma :delta) delta)
    ((and (consp forma) (eq (first forma) :state))
     (and *estado-do-binding* (gethash (second forma) *estado-do-binding*)))
    ((and (consp forma) (eq (first forma) :parameter))
     (if *parametros-do-binding* (gethash (second forma) *parametros-do-binding*) 0.0f0))
    (t
     (let ((registro (%registro-de-binding (first forma))))
       (unless registro
         (error 'flegrea:validation-error :message "A função do binding não está registrada."))
       (apply (getf registro :function)
              (mapcar (lambda (item) (%avaliar-expressao item tempo delta)) (rest forma)))))))

(defun %validar-aridade (minimo &optional maximo)
  (lambda (argumentos)
    (unless (and (>= (length argumentos) minimo)
                 (or (null maximo) (<= (length argumentos) maximo)))
      (error 'flegrea:validation-error :message "A aridade de uma função de binding é inválida."))))

(eval-when (:load-toplevel :execute)
  (flegrea:register-binding-function '+ #'+ :validator (%validar-aridade 0))
  (flegrea:register-binding-function '- #'- :validator (%validar-aridade 1))
  (flegrea:register-binding-function '* #'* :validator (%validar-aridade 0))
  (flegrea:register-binding-function '/ #'/ :validator (%validar-aridade 1))
  (flegrea:register-binding-function 'sin #'sin :validator (%validar-aridade 1 1))
  (flegrea:register-binding-function 'cos #'cos :validator (%validar-aridade 1 1))
  (flegrea:register-binding-function 'tan #'tan :validator (%validar-aridade 1 1))
  (flegrea:register-binding-function 'abs #'abs :validator (%validar-aridade 1 1))
  (flegrea:register-binding-function 'min #'min :validator (%validar-aridade 1))
  (flegrea:register-binding-function 'max #'max :validator (%validar-aridade 1))
  (flegrea:register-binding-function 'clamp
    (lambda (valor minimo maximo) (max minimo (min maximo valor)))
    :validator (%validar-aridade 3 3)))

(defun %criar-parametro (forma)
  (destructuring-bind (nome &key (type t) default validator) forma
    (unless (keywordp nome)
      (error 'flegrea:validation-error :message "O nome de parâmetro precisa ser keyword."))
    (when (and validator (not (%registro-de-binding validator)))
      (error 'flegrea:validation-error :message "O validador do parâmetro não está registrado."))
    (make-instance 'flegrea:scene-parameter :name nome :type type :default default
                   :validator validator)))

(defun %inicializar-estado (plist)
  (unless (evenp (length plist))
    (error 'flegrea:validation-error :message "O estado inicial precisa formar uma plist."))
  (let ((tabela (make-hash-table :test #'eq)))
    (loop for (chave valor) on plist by #'cddr do
      (unless (keywordp chave)
        (error 'flegrea:validation-error :message "Uma chave de estado precisa ser keyword."))
      (setf (gethash chave tabela) valor))
    tabela))

(defun %registrar-descricao-15 (nome forma parametros estado)
  (let ((descricao (funcall *parse-scene-base* forma)))
    (setf (%parametros-meta descricao) (mapcar #'%criar-parametro parametros)
          (%estado-inicial-meta descricao) estado
          (%versao-meta descricao) 1
          (gethash nome *descricoes-de-cena*) descricao)
    descricao))

(defmacro flegrea:define-scene (name &body clauses)
  "Define uma factory tipada e registra seu metagrafo canônico."
  (let ((parametros nil) (estado nil) (forma nil))
    (dolist (clausula clauses)
      (cond ((and (consp clausula) (eq (first clausula) :parameters))
             (setf parametros (rest clausula)))
            ((and (consp clausula) (eq (first clausula) :state))
             (setf estado (rest clausula)))
            ((null forma) (setf forma clausula))
            (t (error "Define-scene recebeu mais de uma raiz."))))
    (unless forma (error "Define-scene requer uma raiz scene."))
    `(progn
       (eval-when (:compile-toplevel :load-toplevel :execute)
         (%registrar-descricao-15 ',name ',forma ',parametros ',estado))
       (defun ,name (&rest argumentos)
         (let ((instancia (instantiate-scene (scene-description ',name))))
           (%aplicar-parametros instancia argumentos)
           instancia)))))

(defun %aplicar-parametros (instancia argumentos)
  (unless (evenp (length argumentos))
    (error 'flegrea:validation-error :message "Os parâmetros da cena precisam formar uma plist."))
  (let ((descritor (%descricao-instancia instancia)))
    (dolist (parametro (%parametros-meta descritor))
      (let* ((nome (flegrea:parameter-name parametro))
             (ausente (gensym)) (valor (getf argumentos nome ausente)))
        (when (eq valor ausente) (setf valor (flegrea:parameter-default parametro)))
        (unless (typep valor (flegrea:parameter-type parametro))
          (error 'flegrea:validation-error :message
                 (format nil "O parâmetro ~A não corresponde ao tipo declarado." nome)))
        (let ((validador (flegrea:parameter-validator parametro)))
          (when (and validador (not (funcall (getf (%registro-de-binding validador) :function) valor)))
            (error 'flegrea:validation-error :message
                   (format nil "O parâmetro ~A falhou na validação." nome))))
        (setf (gethash nome (%valores-de-parametro instancia)) valor)))
    (loop for (chave valor) on argumentos by #'cddr do
      (unless (find chave (%parametros-meta descritor) :key #'flegrea:parameter-name)
        (error 'flegrea:validation-error :message (format nil "O parâmetro ~A não foi declarado." chave))))
    (setf (flegrea:scene-state instancia) (%inicializar-estado (%estado-inicial-meta descritor))))
  instancia)

(defun parse-scene (forma)
  "Converte uma forma canônica versionada ou uma raiz legada em metagrafo validado."
  (if (and (consp forma) (eq (first forma) :flegrea-scene))
      (let* ((plist (rest forma)) (versao (getf plist :version))
             (raiz (getf plist :root)) (parametros (getf plist :parameters))
             (estado (getf plist :state)))
        (unless (= versao 1)
          (error 'flegrea:metagraph-error :message "A versão do arquivo .fscene não é suportada."
                 :stage :parse))
        (let ((descricao (funcall *parse-scene-base* raiz)))
          (setf (%parametros-meta descricao) (mapcar #'%criar-parametro parametros)
                (%estado-inicial-meta descricao) estado (%versao-meta descricao) versao)
          descricao))
      (funcall *parse-scene-base* forma)))

(defun scene-description (nome)
  "Obtém uma cópia editável de uma descrição registrada."
  (let ((descricao (gethash nome *descricoes-de-cena*)))
    (unless descricao
      (error 'flegrea:validation-error :message (format nil "A cena ~A não está registrada." nome)))
    (let ((copia (funcall *parse-scene-base* (%node->form (%raiz-meta descricao)))))
      (setf (%parametros-meta copia)
            (mapcar (lambda (p)
                      (make-instance 'flegrea:scene-parameter
                                     :name (flegrea:parameter-name p) :type (flegrea:parameter-type p)
                                     :default (flegrea:parameter-default p)
                                     :validator (flegrea:parameter-validator p)))
                    (%parametros-meta descricao))
            (%estado-inicial-meta copia) (copy-list (%estado-inicial-meta descricao))
            (%versao-meta copia) (%versao-meta descricao))
      copia)))

(defun %parametro->forma (parametro)
  (list (flegrea:parameter-name parametro) :type (flegrea:parameter-type parametro)
        :default (flegrea:parameter-default parametro)
        :validator (flegrea:parameter-validator parametro)))

(defun write-scene (description destination &key (if-exists :supersede))
  "Grava uma descrição canônica versionada em caminho ou stream."
  (labels ((gravar (fluxo)
             (let ((*print-readably* t) (*package* (find-package :flegrea)))
               (write (list :flegrea-scene :version (%versao-meta description)
                            :parameters (mapcar #'%parametro->forma (%parametros-meta description))
                            :state (%estado-inicial-meta description)
                            :root (%node->form (%raiz-meta description)))
                      :stream fluxo :pretty t)
               (terpri fluxo))))
    (if (streamp destination) (gravar destination)
        (with-open-file (fluxo destination :direction :output :if-exists if-exists
                               :if-does-not-exist :create)
          (gravar fluxo))))
  destination)

(defun update-scene (instance time delta)
  "Avalia bindings contra tempo, parâmetros e estado da instância."
  (let ((*estado-do-binding* (flegrea:scene-state instance))
        (*parametros-do-binding* (%valores-de-parametro instance))
        (tempo (coerce time 'single-float)) (passo (coerce delta 'single-float)))
    (maphash (lambda (id no)
               (let ((objeto (gethash id (%objetos-instancia instance))))
                 (when objeto (%atualizar-propriedades-dinamicas no objeto tempo passo))))
             (%nos-meta (%descricao-instancia instance))))
  instance)

(defun %despachar-hot (controle tipo detalhe)
  (let ((callback (%callback-hot controle)))
    (when callback
      (funcall callback (make-instance 'flegrea:hot-reload-event :kind tipo :detail detalhe)))))

(defun %thread-de-hot-reload (controle)
  (loop while (%ativo-hot controle) do
    (handler-case
        (let ((data (file-write-date (%caminho-hot controle))))
          (when (and data (%data-hot controle) (> data (%data-hot controle)))
            (handler-case
                (let ((descricao (read-scene (%caminho-hot controle))))
                  (bt:with-lock-held ((%trava-hot controle))
                    (setf (%pendente-hot controle) descricao (%erro-hot controle) nil)))
              (error (condicao)
                (bt:with-lock-held ((%trava-hot controle))
                  (setf (%erro-hot controle) condicao (%pendente-hot controle) nil)))))
          (setf (%data-hot controle) data))
      (error (condicao)
        (bt:with-lock-held ((%trava-hot controle)) (setf (%erro-hot controle) condicao))))
    (sleep (%intervalo-hot controle))))

(defun flegrea:start-hot-reload (instance path &key (interval 0.25f0) callback)
  "Observa um .fscene e prepara commits transacionais no thread de renderização."
  (let ((controle (make-instance '%controle-de-hot-reload :instance instance
                                 :path (uiop:ensure-pathname path :want-existing t)
                                 :interval interval :callback callback)))
    (setf (%data-hot controle) (file-write-date (%caminho-hot controle))
          (%thread-hot controle) (bt:make-thread (lambda () (%thread-de-hot-reload controle))
                                                 :name "Flegrea hot reload"))
    (bt:with-lock-held (*trava-de-hot-reloads*) (push controle *hot-reloads*))
    controle))

(defun flegrea:stop-hot-reload (handle)
  "Para um observador de hot reload."
  (setf (%ativo-hot handle) nil)
  (when (%thread-hot handle) (bt:join-thread (%thread-hot handle)))
  (bt:with-lock-held (*trava-de-hot-reloads*)
    (setf *hot-reloads* (remove handle *hot-reloads*)))
  handle)

(defun %drenar-hot-reloads ()
  (let ((controles nil))
    (bt:with-lock-held (*trava-de-hot-reloads*) (setf controles (copy-list *hot-reloads*)))
    (dolist (controle controles)
      (let ((descricao nil) (erro nil))
        (bt:with-lock-held ((%trava-hot controle))
          (setf descricao (%pendente-hot controle) erro (%erro-hot controle)
                (%pendente-hot controle) nil (%erro-hot controle) nil))
        (when erro (%despachar-hot controle :error erro))
        (when descricao
          (handler-case
              (progn (commit-scene (%instancia-hot controle) descricao)
                     (%despachar-hot controle :committed descricao))
            (error (condicao) (%despachar-hot controle :error condicao))))))))
