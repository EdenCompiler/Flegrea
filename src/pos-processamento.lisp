(in-package #:flegrea)

(defclass render-target (resource)
  ((largura :initarg :width :accessor target-width)
   (altura :initarg :height :accessor target-height)
   (textura-de-cor :initarg :color-texture :accessor target-color-texture)
   (textura-de-profundidade :initarg :depth-texture :accessor target-depth-texture)
   (framebuffer :initform nil :accessor %framebuffer-do-alvo)
   (textura-gl :initform nil :accessor %textura-gl-do-alvo)
   (profundidade-gl :initform nil :accessor %profundidade-gl-do-alvo)
   (thread-dono :initform nil :accessor %thread-dono-do-alvo)))

(defclass %effect-pass ()
  ((habilitado :initarg :enabled :initform t :accessor pass-enabled)
   (precisa-trocar :initarg :needs-swap :initform t :accessor pass-needs-swap)))

(defclass render-pass (%effect-pass)
  ((cena :initarg :scene :reader %cena-do-passe)
   (camera :initarg :camera :reader %camera-do-passe)))

(defclass shader-pass (%effect-pass)
  ((material :initarg :material :reader %material-do-passe)))

(defclass effect-composer (resource)
  ((renderizador :initarg :renderer :reader %renderizador-do-compositor)
   (leitura :initarg :read-buffer :accessor %leitura-do-compositor)
   (escrita :initarg :write-buffer :accessor %escrita-do-compositor)
   (passes :initform nil :accessor %passes-do-compositor)
   (vao-de-tela :initform nil :accessor %vao-de-tela)
   (buffer-de-tela :initform nil :accessor %buffer-de-tela)))

(defun make-render-target (width height &key (color-space :linear) (depth t))
  "Cria um alvo de renderização redimensionável."
  (unless (and (integerp width) (plusp width) (integerp height) (plusp height))
    (error 'validation-error :message "As dimensões do render-target são inválidas."))
  (make-instance 'render-target :width width :height height
                 :color-texture (make-data-texture width height #() :color-space color-space)
                 :depth-texture (and depth (make-data-texture width height #()
                                                             :color-space :none :format :depth))))

(defun %criar-alvo-gl (alvo)
  (unless (%framebuffer-do-alvo alvo)
    (let ((framebuffer (gl:gen-framebuffer)) (textura (gl:gen-texture))
          (profundidade (and (target-depth-texture alvo) (gl:gen-renderbuffer))))
      (gl:bind-framebuffer :framebuffer framebuffer)
      (gl:bind-texture :texture-2d textura)
      (gl:tex-parameter :texture-2d :texture-min-filter :linear)
      (gl:tex-parameter :texture-2d :texture-mag-filter :linear)
      (gl:tex-image-2d :texture-2d 0 :rgba16f (target-width alvo) (target-height alvo) 0
                       :rgba :float (cffi:null-pointer))
      (gl:framebuffer-texture-2d :framebuffer :color-attachment0 :texture-2d textura 0)
      (when profundidade
        (gl:bind-renderbuffer :renderbuffer profundidade)
        (gl:renderbuffer-storage :renderbuffer :depth-component24
                                 (target-width alvo) (target-height alvo))
        (gl:framebuffer-renderbuffer :framebuffer :depth-attachment :renderbuffer profundidade))
      (unless (gl::enum= (gl:check-framebuffer-status :framebuffer) :framebuffer-complete)
        (error 'renderer-error :message "O framebuffer de pós-processamento está incompleto."))
      (gl:bind-framebuffer :framebuffer 0)
      (setf (%framebuffer-do-alvo alvo) framebuffer (%textura-gl-do-alvo alvo) textura
            (%profundidade-gl-do-alvo alvo) profundidade
            (%thread-dono-do-alvo alvo) (bt:current-thread))))
  alvo)

(defun resize-render-target (target width height)
  "Redimensiona um alvo; os objetos de textura preservam identidade."
  (setf (target-width target) width (target-height target) height
        (image-width (target-color-texture target)) width
        (image-height (target-color-texture target)) height)
  (when (target-depth-texture target)
    (setf (image-width (target-depth-texture target)) width
          (image-height (target-depth-texture target)) height))
  (when (%framebuffer-do-alvo target)
    (gl:bind-texture :texture-2d (%textura-gl-do-alvo target))
    (gl:tex-image-2d :texture-2d 0 :rgba16f width height 0 :rgba :float (cffi:null-pointer))
    (when (%profundidade-gl-do-alvo target)
      (gl:bind-renderbuffer :renderbuffer (%profundidade-gl-do-alvo target))
      (gl:renderbuffer-storage :renderbuffer :depth-component24 width height)))
  target)

(defun read-render-target-pixels (target &key (x 0) (y 0)
                                         (width (target-width target))
                                         (height (target-height target)))
  "Lê pixels RGBA de um alvo já inicializado no contexto atual."
  (%criar-alvo-gl target)
  (gl:bind-framebuffer :framebuffer (%framebuffer-do-alvo target))
  (gl:read-pixels x y width height :rgba :unsigned-byte))

(defmethod dispose ((alvo render-target))
  (unless (disposed-p alvo)
    (when (and (%thread-dono-do-alvo alvo)
               (not (eq (%thread-dono-do-alvo alvo) (bt:current-thread))))
      (error 'renderer-error :message "O render-target precisa ser descartado no thread proprietário."))
    (when (%textura-gl-do-alvo alvo) (gl:delete-texture (%textura-gl-do-alvo alvo)))
    (when (%profundidade-gl-do-alvo alvo) (gl:delete-renderbuffer (%profundidade-gl-do-alvo alvo)))
    (when (%framebuffer-do-alvo alvo) (gl:delete-framebuffer (%framebuffer-do-alvo alvo)))
    (dispose (target-color-texture alvo))
    (when (target-depth-texture alvo) (dispose (target-depth-texture alvo))))
  (call-next-method))

(defun make-render-pass (scene camera)
  "Cria um passe que renderiza uma cena."
  (make-instance 'render-pass :scene scene :camera camera :needs-swap t))

(defun make-shader-pass (material &key (needs-swap t))
  "Cria um passe de tela baseado em shader-material."
  (unless (typep material 'shader-material)
    (error 'validation-error :message "Shader-pass requer shader-material."))
  (make-instance 'shader-pass :material material :needs-swap needs-swap))

(defun make-effect-composer (renderer &key width height)
  "Cria um compositor com dois alvos para ping-pong."
  (let ((largura (or width (renderer-width renderer)))
        (altura (or height (renderer-height renderer))))
    (make-instance 'effect-composer :renderer renderer
                   :read-buffer (make-render-target largura altura)
                   :write-buffer (make-render-target largura altura))))

(defun add-pass (composer pass)
  "Adiciona um passe ao compositor."
  (setf (%passes-do-compositor composer) (append (%passes-do-compositor composer) (list pass))) composer)
(defun remove-pass (composer pass)
  "Remove um passe do compositor."
  (setf (%passes-do-compositor composer) (remove pass (%passes-do-compositor composer))) composer)

(defun %trocar-alvos (compositor)
  (rotatef (%leitura-do-compositor compositor) (%escrita-do-compositor compositor)))

(defun %garantir-triangulo-de-tela (compositor)
  (unless (%vao-de-tela compositor)
    (let ((vao (gl:gen-vertex-array)) (buffer (gl:gen-buffer))
          (dados (make-array 9 :element-type 'single-float
                               :initial-contents '(-1.0f0 -1.0f0 0.0f0
                                                   3.0f0 -1.0f0 0.0f0
                                                   -1.0f0 3.0f0 0.0f0))))
      (gl:bind-vertex-array vao)
      (gl:bind-buffer :array-buffer buffer)
      (flegrea.renderer::%enviar-array :array-buffer :float dados :static-draw)
      (gl:enable-vertex-attrib-array 0)
      (gl:vertex-attrib-pointer 0 3 :float nil 0 (cffi:null-pointer))
      (gl:bind-vertex-array 0)
      (setf (%vao-de-tela compositor) vao (%buffer-de-tela compositor) buffer)))
  compositor)

(defun %desenhar-passe-de-shader (compositor passe destino)
  (%garantir-triangulo-de-tela compositor)
  (let* ((renderizador (%renderizador-do-compositor compositor))
         (material (%material-do-passe passe))
         (programa (flegrea.renderer::%programa-personalizado renderizador material))
         (entrada (%leitura-do-compositor compositor)))
    (if destino
        (progn (%criar-alvo-gl destino)
               (gl:bind-framebuffer :framebuffer (%framebuffer-do-alvo destino))
               (gl:viewport 0 0 (target-width destino) (target-height destino)))
        (progn (gl:bind-framebuffer :framebuffer 0)
               (gl:viewport 0 0 (renderer-width renderizador) (renderer-height renderizador))))
    (gl:disable :depth-test)
    (gl:disable :blend)
    (gl:use-program programa)
    (gl:active-texture :texture0)
    (gl:bind-texture :texture-2d (%textura-gl-do-alvo entrada))
    (gl:uniformi (gl:get-uniform-location programa "inputTexture") 0)
    (let ((resolucao (uniform material "inverseResolution")))
      (when (typep resolucao 'vector2)
        (set-vector2 resolucao (/ 1.0f0 (target-width entrada))
                     (/ 1.0f0 (target-height entrada)))))
    (let ((flegrea.renderer::*unidade-de-textura* 1))
      (maphash (lambda (nome valor)
                 (unless (string= nome "inputTexture")
                   (flegrea.renderer::%enviar-uniforme-personalizado
                    renderizador programa nome valor)))
               (uniforms material)))
    (gl:bind-vertex-array (%vao-de-tela compositor))
    (gl:draw-arrays :triangles 0 3)
    (gl:bind-vertex-array 0)
    (gl:enable :depth-test)))

(defun composer-render (composer &optional delta)
  "Executa os passes habilitados em ordem."
  (declare (ignore delta))
  (let* ((ativos (remove-if-not #'pass-enabled (%passes-do-compositor composer)))
         (ultimo (car (last ativos))))
    (dolist (passe ativos)
      (let ((destino (unless (eq passe ultimo) (%escrita-do-compositor composer))))
        (typecase passe
          (render-pass
           (if destino
               (progn (%criar-alvo-gl destino)
                      (gl:bind-framebuffer :framebuffer (%framebuffer-do-alvo destino)))
               (gl:bind-framebuffer :framebuffer 0))
           (let ((flegrea.renderer::*largura-do-alvo*
                   (and destino (target-width destino)))
                 (flegrea.renderer::*altura-do-alvo*
                   (and destino (target-height destino))))
             (render (%renderizador-do-compositor composer)
                     (%cena-do-passe passe) (%camera-do-passe passe)))
           (gl:bind-framebuffer :framebuffer 0))
          (shader-pass
           (%desenhar-passe-de-shader composer passe destino)))
        (when (and destino (pass-needs-swap passe)) (%trocar-alvos composer)))))
  composer)

(defmethod dispose ((compositor effect-composer))
  (unless (disposed-p compositor)
    (when (%buffer-de-tela compositor)
      (gl:delete-buffers (vector (%buffer-de-tela compositor))))
    (when (%vao-de-tela compositor) (gl:delete-vertex-array (%vao-de-tela compositor)))
    (dispose (%leitura-do-compositor compositor))
    (dispose (%escrita-do-compositor compositor)))
  (call-next-method))

(defun make-fxaa-pass ()
  "Cria um passe FXAA compatível com OpenGL 3.3."
  (make-shader-pass
   (make-shader-material
    :vertex-shader "#version 330 core
layout(location=0) in vec3 posicao;
out vec2 coordenada;
void main(){coordenada=posicao.xy*0.5+0.5;gl_Position=vec4(posicao,1.0);}"
    :fragment-shader "#version 330 core
in vec2 coordenada;
out vec4 corSaida;
uniform sampler2D inputTexture;
uniform vec2 inverseResolution;
void main(){
  vec3 centro=texture(inputTexture,coordenada).rgb;
  vec3 norte=texture(inputTexture,coordenada+vec2(0,inverseResolution.y)).rgb;
  vec3 sul=texture(inputTexture,coordenada-vec2(0,inverseResolution.y)).rgb;
  vec3 leste=texture(inputTexture,coordenada+vec2(inverseResolution.x,0)).rgb;
  vec3 oeste=texture(inputTexture,coordenada-vec2(inverseResolution.x,0)).rgb;
  corSaida=vec4((centro*4+norte+sul+leste+oeste)/8,1);
}"
    :uniforms (list "inverseResolution" (make-vector2 1.0f0 1.0f0)))))
