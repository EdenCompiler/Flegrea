(in-package #:flegrea.renderer)

(defvar *renderizadores-por-janela* (make-hash-table :test #'eql))

(defun %ignorar-argumentos-de-callback (&rest valores)
  (declare (ignore valores))
  nil)

(defun %chave-da-janela (janela)
  (cffi:pointer-address janela))

(defun %renderizador-da-janela (janela)
  (gethash (%chave-da-janela janela) *renderizadores-por-janela*))

(glfw:def-key-callback %callback-de-tecla (janela tecla codigo acao modificadores)
  (%ignorar-argumentos-de-callback codigo)
  (let ((renderizador (%renderizador-da-janela janela)))
    (when renderizador
      (setf (flegrea:modifiers (flegrea:renderer-input renderizador)) modificadores)
      (flegrea::%definir-tecla (flegrea:renderer-input renderizador) tecla
                               (member acao '(:press :repeat))))))

(glfw:def-mouse-button-callback %callback-de-botao (janela botao acao modificadores)
  (let ((renderizador (%renderizador-da-janela janela)))
    (when renderizador
      (setf (flegrea:modifiers (flegrea:renderer-input renderizador)) modificadores)
      (flegrea::%definir-botao (flegrea:renderer-input renderizador) botao (eq acao :press)))))

(glfw:def-cursor-pos-callback %callback-de-cursor (janela x y)
  (let ((renderizador (%renderizador-da-janela janela)))
    (when renderizador
      (flegrea::%definir-cursor (flegrea:renderer-input renderizador) x y))))

(glfw:def-scroll-callback %callback-de-roda (janela x y)
  (%ignorar-argumentos-de-callback x)
  (let ((renderizador (%renderizador-da-janela janela)))
    (when renderizador
      (flegrea::%adicionar-roda (flegrea:renderer-input renderizador) y))))

(defun %instalar-entrada (renderizador)
  (let ((janela (%janela-renderizador renderizador)))
    (setf (gethash (%chave-da-janela janela) *renderizadores-por-janela*) renderizador)
    (glfw:set-key-callback '%callback-de-tecla janela)
    (glfw:set-mouse-button-callback '%callback-de-botao janela)
    (glfw:set-cursor-position-callback '%callback-de-cursor janela)
    (glfw:set-scroll-callback '%callback-de-roda janela))
  renderizador)

(defmethod flegrea:dispose :before ((renderizador renderer))
  (remhash (%chave-da-janela (%janela-renderizador renderizador)) *renderizadores-por-janela*))

(defun flegrea:set-quality (renderizador qualidade)
  "Altera o perfil de qualidade do renderer."
  (unless (member qualidade '(:low :medium :high))
    (error 'renderer-error :message "Quality precisa ser :low, :medium ou :high."))
  (setf (flegrea:renderer-quality renderizador) qualidade)
  renderizador)
