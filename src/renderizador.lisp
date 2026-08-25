(in-package #:flegrea.renderer)

(define-condition renderer-error (flegrea:flegrea-error) ())
(define-condition shader-error (renderer-error) ())

(defparameter *trava-glfw* (bt:make-lock "trava global do GLFW"))
(defparameter *usuarios-glfw* 0)

(defclass %geometria-gpu ()
  ((vao :initarg :vao :reader %vao-gpu)
   (buffers :initarg :buffers :reader %buffers-gpu)
   (buffer-indice :initarg :index-buffer :accessor %buffer-indice-gpu)
   (quantidade :initarg :count :accessor %quantidade-gpu)
   (indexada :initarg :indexed :accessor %indexada-gpu)))

(defclass renderer ()
  ((janela :initarg :window :reader %janela-renderizador)
   (dono :initarg :owner :reader %dono-renderizador)
   (renderer-width :initarg :width :accessor renderer-width)
   (renderer-height :initarg :height :accessor renderer-height)
   (renderer-title :initarg :title :reader renderer-title)
   (cor-limpeza :initarg :clear-color :reader %cor-limpeza)
   (programa-basico :initarg :basic-program :reader %programa-basico)
   (programa-padrao :initarg :standard-program :reader %programa-padrao)
   (cache-geometrias :initform (make-hash-table :test #'eq) :reader %cache-geometrias)
   (cache-programas :initform (make-hash-table :test #'eq) :reader %cache-programas)
   (executando :initform nil :accessor %executando)
   (descartado :initform nil :accessor %descartado)))

(defparameter +vertice-basico+
  "#version 330 core
layout(location = 0) in vec3 posicao;
layout(location = 1) in vec3 normalIgnorada;
layout(location = 2) in vec3 corVerticeEntrada;
uniform mat4 matrizModelo;
uniform mat4 matrizVisao;
uniform mat4 matrizProjecao;
out vec3 corVertice;
void main() {
  corVertice = corVerticeEntrada;
  gl_Position = matrizProjecao * matrizVisao * matrizModelo * vec4(posicao, 1.0);
}")

(defparameter +fragmento-basico+
  "#version 330 core
in vec3 corVertice;
uniform vec3 corMaterial;
uniform int usaCores;
out vec4 corSaida;
void main() {
  vec3 corFinal = corMaterial;
  if (usaCores == 1) corFinal *= corVertice;
  corSaida = vec4(corFinal, 1.0);
}")

(defparameter +vertice-padrao+
  "#version 330 core
layout(location = 0) in vec3 posicao;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 corVerticeEntrada;
uniform mat4 matrizModelo;
uniform mat4 matrizVisao;
uniform mat4 matrizProjecao;
uniform mat3 matrizNormal;
out vec3 posicaoMundial;
out vec3 normalMundial;
out vec3 corVertice;
void main() {
  vec4 mundial = matrizModelo * vec4(posicao, 1.0);
  posicaoMundial = mundial.xyz;
  normalMundial = normalize(matrizNormal * normal);
  corVertice = corVerticeEntrada;
  gl_Position = matrizProjecao * matrizVisao * mundial;
}")

(defparameter +fragmento-padrao+
  "#version 330 core
#define MAX_LUZES 8
const float PI_FLEGREA = 3.14159265359;
in vec3 posicaoMundial;
in vec3 normalMundial;
in vec3 corVertice;
uniform vec3 corMaterial;
uniform vec3 corEmissiva;
uniform float rugosidade;
uniform float metalicidade;
uniform int usaCores;
uniform vec3 posicaoCamera;
uniform vec3 luzAmbiente;
uniform int quantidadeDirecionais;
uniform vec3 direcoesDirecionais[MAX_LUZES];
uniform vec3 coresDirecionais[MAX_LUZES];
uniform int quantidadePontuais;
uniform vec3 posicoesPontuais[MAX_LUZES];
uniform vec3 coresPontuais[MAX_LUZES];
uniform float distanciasPontuais[MAX_LUZES];
uniform float decaimentosPontuais[MAX_LUZES];
out vec4 corSaida;

vec3 paraLinear(vec3 cor) {
  return pow(max(cor, vec3(0.0)), vec3(2.2));
}
vec3 paraSRGB(vec3 cor) {
  return pow(max(cor, vec3(0.0)), vec3(1.0 / 2.2));
}
float distribuicaoGGX(vec3 normal, vec3 meio, float rugoso) {
  float a = rugoso * rugoso;
  float a2 = a * a;
  float nh = max(dot(normal, meio), 0.0);
  float denominador = nh * nh * (a2 - 1.0) + 1.0;
  return a2 / max(PI_FLEGREA * denominador * denominador, 0.000001);
}
float geometriaSchlick(float nv, float rugoso) {
  float r = rugoso + 1.0;
  float k = (r * r) / 8.0;
  return nv / max(nv * (1.0 - k) + k, 0.000001);
}
float geometriaSmith(vec3 normal, vec3 vista, vec3 luz, float rugoso) {
  return geometriaSchlick(max(dot(normal, vista), 0.0), rugoso) *
         geometriaSchlick(max(dot(normal, luz), 0.0), rugoso);
}
vec3 fresnelSchlick(float hv, vec3 f0) {
  return f0 + (1.0 - f0) * pow(clamp(1.0 - hv, 0.0, 1.0), 5.0);
}
vec3 contribuicao(vec3 normal, vec3 vista, vec3 luz, vec3 radiancia,
                  vec3 base, vec3 f0, float rugoso, float metalico) {
  vec3 meio = normalize(vista + luz);
  float ndl = max(dot(normal, luz), 0.0);
  float ndv = max(dot(normal, vista), 0.0);
  vec3 fresnel = fresnelSchlick(max(dot(meio, vista), 0.0), f0);
  float distribuicao = distribuicaoGGX(normal, meio, rugoso);
  float geometria = geometriaSmith(normal, vista, luz, rugoso);
  vec3 especular = (distribuicao * geometria * fresnel) / max(4.0 * ndv * ndl, 0.0001);
  vec3 difusa = (vec3(1.0) - fresnel) * (1.0 - metalico) * base / PI_FLEGREA;
  return (difusa + especular) * radiancia * ndl;
}
void main() {
  vec3 base = paraLinear(corMaterial);
  if (usaCores == 1) base *= paraLinear(corVertice);
  vec3 emissiva = paraLinear(corEmissiva);
  vec3 normal = normalize(normalMundial);
  vec3 vista = normalize(posicaoCamera - posicaoMundial);
  float rugoso = clamp(rugosidade, 0.04, 1.0);
  vec3 f0 = mix(vec3(0.04), base, metalicidade);
  vec3 resultado = luzAmbiente * base * (1.0 - metalicidade) + emissiva;
  if (quantidadeDirecionais > 0) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[0]), coresDirecionais[0], base, f0, rugoso, metalicidade);
  if (quantidadeDirecionais > 1) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[1]), coresDirecionais[1], base, f0, rugoso, metalicidade);
  if (quantidadeDirecionais > 2) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[2]), coresDirecionais[2], base, f0, rugoso, metalicidade);
  if (quantidadeDirecionais > 3) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[3]), coresDirecionais[3], base, f0, rugoso, metalicidade);
  if (quantidadeDirecionais > 4) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[4]), coresDirecionais[4], base, f0, rugoso, metalicidade);
  if (quantidadeDirecionais > 5) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[5]), coresDirecionais[5], base, f0, rugoso, metalicidade);
  if (quantidadeDirecionais > 6) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[6]), coresDirecionais[6], base, f0, rugoso, metalicidade);
  if (quantidadeDirecionais > 7) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[7]), coresDirecionais[7], base, f0, rugoso, metalicidade);
  for (int indice = 0; indice < MAX_LUZES; ++indice) {
    if (indice >= quantidadePontuais) break;
    vec3 deslocamento = posicoesPontuais[indice] - posicaoMundial;
    float distancia = length(deslocamento);
    float atenuacao = 1.0 / max(pow(max(distancia, 0.01), decaimentosPontuais[indice]), 0.01);
    if (distanciasPontuais[indice] > 0.0) {
      float faixa = clamp(1.0 - distancia / distanciasPontuais[indice], 0.0, 1.0);
      atenuacao *= faixa * faixa;
    }
    resultado += contribuicao(normal, vista, normalize(deslocamento),
                              coresPontuais[indice] * atenuacao, base, f0, rugoso, metalicidade);
  }
  resultado = resultado / (resultado + vec3(1.0));
  corSaida = vec4(paraSRGB(max(resultado, vec3(0.0))), 1.0);
}")

(defun %assertar-thread (renderizador)
  (unless (eq (bt:current-thread) (%dono-renderizador renderizador))
    (error 'renderer-error :message "O renderer foi usado fora da thread proprietária do contexto OpenGL."))
  (when (%descartado renderizador)
    (error 'renderer-error :message "O renderer já foi descartado.")))

(defun %compilar-shader (tipo fonte)
  (let ((shader (gl:create-shader tipo)))
    (gl:shader-source shader fonte)
    (gl:compile-shader shader)
    (unless (gl:get-shader shader :compile-status)
      (let ((registro (gl:get-shader-info-log shader)))
        (gl:delete-shader shader)
        (error 'shader-error :message (format nil "Falha ao compilar shader.~%Registro do driver:~%~A" registro))))
    shader))

(defun %criar-programa (fonte-vertice fonte-fragmento)
  (let ((vertice (%compilar-shader :vertex-shader fonte-vertice))
        (fragmento (%compilar-shader :fragment-shader fonte-fragmento))
        (programa nil))
    (unwind-protect
         (progn
           (setf programa (gl:create-program))
           (gl:attach-shader programa vertice)
           (gl:attach-shader programa fragmento)
           (gl:link-program programa)
           (unless (gl:get-program programa :link-status)
             (let ((registro (gl:get-program-info-log programa)))
               (gl:delete-program programa)
               (setf programa nil)
               (error 'shader-error :message (format nil "Falha ao ligar programa de shader.~%Registro do driver:~%~A" registro))))
           programa)
      (gl:delete-shader vertice)
      (gl:delete-shader fragmento))))

(defun %validar-cor (cor)
  (unless (and (typep cor 'flegrea:vector3)
               (<= 0 (flegrea:x cor) 1) (<= 0 (flegrea:y cor) 1) (<= 0 (flegrea:z cor) 1))
    (error 'renderer-error :message "A cor do renderer deve ser vector3 sRGB entre zero e um."))
  cor)

(defun %criar-renderizador-sem-protecao (&key (width 800) (height 600) (title "Flegrea")
                           (clear-color (flegrea:make-vector3 0.02 0.025 0.04))
                           (vsync t) (resizable t) (visible t))
  "Cria imediatamente a janela nativa e seu contexto OpenGL."
  (unless (and (integerp width) (plusp width) (integerp height) (plusp height))
    (error 'renderer-error :message "As dimensões da janela precisam ser inteiros positivos."))
  (%validar-cor clear-color)
  (let ((inicializou nil) (janela nil))
    (handler-case
        (progn
          (bt:with-lock-held (*trava-glfw*)
            (when (zerop *usuarios-glfw*) (glfw:initialize))
            (incf *usuarios-glfw*)
            (setf inicializou t))
          (setf janela
                (glfw:create-window :width width :height height :title title :resizable resizable :visible visible
                                    :context-version-major 3 :context-version-minor 3
                                    :opengl-profile :opengl-core-profile :opengl-forward-compat t
                                    :depth-bits 24 :stencil-bits 8))
          (setf %gl:*gl-get-proc-address* #'glfw:get-proc-address)
          (glfw:make-context-current janela)
          (glfw:swap-interval (if vsync 1 0))
          (gl:enable :depth-test)
          (gl:depth-func :less)
          (destructuring-bind (largura-real altura-real) (glfw:get-framebuffer-size janela)
            (make-instance 'renderer :window janela :owner (bt:current-thread)
                           :width largura-real :height altura-real :title title :clear-color (flegrea:clone clear-color)
                           :basic-program (%criar-programa +vertice-basico+ +fragmento-basico+)
                           :standard-program (%criar-programa +vertice-padrao+ +fragmento-padrao+))))
      (error (condicao)
        (when janela (ignore-errors (glfw:destroy-window janela)))
        (when inicializou
          (bt:with-lock-held (*trava-glfw*)
            (decf *usuarios-glfw*)
            (when (zerop *usuarios-glfw*) (glfw:terminate))))
        (if (typep condicao 'flegrea:flegrea-error)
            (error condicao)
            (error 'renderer-error :message (format nil "Não foi possível criar o renderer: ~A" condicao)))))))

(defun make-renderer (&rest argumentos &key &allow-other-keys)
  "Cria imediatamente a janela nativa e seu contexto OpenGL."
  (float-features:with-float-traps-masked t
    (apply #'%criar-renderizador-sem-protecao argumentos)))

(defun %enviar-array (alvo tipo dados uso)
  (let ((array (gl:alloc-gl-array tipo (length dados))))
    (unwind-protect
         (progn
           (dotimes (indice (length dados))
             (setf (gl:glaref array indice) (aref dados indice)))
           (gl:buffer-data alvo uso array))
      (gl:free-gl-array array))))

(defun %criar-geometria-gpu ()
  (make-instance '%geometria-gpu :vao (gl:gen-vertex-array) :buffers (make-hash-table :test #'eq)
                                  :index-buffer nil :count 0 :indexed nil))

(defun %garantir-buffer (estado nome)
  (or (gethash nome (%buffers-gpu estado))
      (setf (gethash nome (%buffers-gpu estado)) (gl:gen-buffer))))

(defun %enviar-atributo (estado nome atributo localizacao)
  (let ((buffer (%garantir-buffer estado nome)))
    (gl:bind-buffer :array-buffer buffer)
    (%enviar-array :array-buffer :float (flegrea:attribute-array atributo) (flegrea:usage atributo))
    (gl:enable-vertex-attrib-array localizacao)
    (gl:vertex-attrib-pointer localizacao (flegrea:item-size atributo) :float
                              (flegrea:normalized atributo) 0 (cffi:null-pointer))
    (setf (flegrea:needs-update atributo) nil)))

(defun %atributo-branco (quantidade)
  (flegrea:make-buffer-attribute
   (make-array (* quantidade 3) :element-type 'single-float :initial-element 1.0f0) 3))

(defun %preparar-geometria (renderizador geometria exige-normal)
  (let* ((cache (%cache-geometrias renderizador))
         (estado (or (gethash geometria cache)
                     (setf (gethash geometria cache) (%criar-geometria-gpu))))
         (posicao (flegrea:get-attribute geometria :position))
         (normal (flegrea:get-attribute geometria :normal))
         (cor (flegrea:get-attribute geometria :color))
         (uv (flegrea:get-attribute geometria :uv)))
    (unless (and posicao (= (flegrea:item-size posicao) 3))
      (error 'renderer-error :message "A geometria renderizada precisa de um atributo :position tridimensional."))
    (when (and exige-normal (not (and normal (= (flegrea:item-size normal) 3))))
      (error 'renderer-error :message "O material standard exige normais tridimensionais."))
    (let ((quantidade (/ (length (flegrea:attribute-array posicao)) 3)))
      (gl:bind-vertex-array (%vao-gpu estado))
      (when (or (flegrea:needs-update posicao) (not (gethash :position (%buffers-gpu estado))))
        (%enviar-atributo estado :position posicao 0))
      (when normal
        (when (or (flegrea:needs-update normal) (not (gethash :normal (%buffers-gpu estado))))
          (%enviar-atributo estado :normal normal 1)))
      (if cor
          (when (or (flegrea:needs-update cor) (not (gethash :color (%buffers-gpu estado))))
            (%enviar-atributo estado :color cor 2))
          (unless (gethash :color (%buffers-gpu estado))
            (%enviar-atributo estado :color (%atributo-branco quantidade) 2)))
      (when uv
        (unless (= (flegrea:item-size uv) 2)
          (error 'renderer-error :message "O atributo :uv precisa ter dois componentes."))
        (when (or (flegrea:needs-update uv) (not (gethash :uv (%buffers-gpu estado))))
          (%enviar-atributo estado :uv uv 3)))
      (let ((indice (flegrea:index geometria)))
        (if indice
            (progn
              (unless (%buffer-indice-gpu estado)
                (setf (%buffer-indice-gpu estado) (gl:gen-buffer)))
              (when (or (flegrea:needs-update indice) (not (%indexada-gpu estado)))
                (gl:bind-buffer :element-array-buffer (%buffer-indice-gpu estado))
                (%enviar-array :element-array-buffer :unsigned-int (flegrea:attribute-array indice) (flegrea:usage indice))
                (setf (flegrea:needs-update indice) nil))
              (setf (%quantidade-gpu estado) (length (flegrea:attribute-array indice))
                    (%indexada-gpu estado) t))
            (setf (%quantidade-gpu estado) quantidade (%indexada-gpu estado) nil)))
      (gl:bind-vertex-array 0) estado)))

(defun %uniforme-matriz (programa nome matriz dimensao)
  (gl:uniform-matrix (gl:get-uniform-location programa nome) dimensao
                     (vector (flegrea:elements matriz)) nil))
(defun %uniforme-cor (programa nome cor)
  (gl:uniformf (gl:get-uniform-location programa nome)
               (flegrea:x cor) (flegrea:y cor) (flegrea:z cor)))

(defun %enviar-uniforme-personalizado (programa nome valor)
  (let ((localizacao (gl:get-uniform-location programa nome)))
    (when (>= localizacao 0)
      (typecase valor
        (flegrea:matrix4 (%uniforme-matriz programa nome valor 4))
        (flegrea:matrix3 (%uniforme-matriz programa nome valor 3))
        (flegrea:vector4
         (gl:uniformf localizacao (flegrea:x valor) (flegrea:y valor)
                      (flegrea:z valor) (flegrea:w valor)))
        (flegrea:vector3 (%uniforme-cor programa nome valor))
        (flegrea:vector2 (gl:uniformf localizacao (flegrea:x valor) (flegrea:y valor)))
        (integer (gl:uniformi localizacao valor))
        (real (gl:uniformf localizacao (coerce valor 'single-float)))
        ((eql t) (gl:uniformi localizacao 1))
        (null (gl:uniformi localizacao 0))
        (t (error 'renderer-error :message
                  (format nil "O uniforme ~A possui um tipo de valor não suportado." nome)))))))

(defun %programa-personalizado (renderizador material)
  (let* ((cache (%cache-programas renderizador))
         (entrada (gethash material cache))
         (fonte-vertice (flegrea:vertex-shader material))
         (fonte-fragmento (flegrea:fragment-shader material)))
    (if (and entrada (string= fonte-vertice (second entrada))
             (string= fonte-fragmento (third entrada)))
        (first entrada)
        (progn
          (when entrada (gl:delete-program (first entrada)))
          (let ((programa (%criar-programa fonte-vertice fonte-fragmento)))
            (setf (gethash material cache)
                  (list programa fonte-vertice fonte-fragmento))
            programa)))))

(defun %configurar-faces (material)
  (let ((lado (if (typep material 'flegrea:shader-material)
                  (flegrea:side material) :front)))
    (if (eq lado :double)
        (gl:disable :cull-face)
        (progn
          (gl:enable :cull-face)
          (gl:cull-face (if (eq lado :back) :front :back)))))
  (gl:depth-mask (if (and (typep material 'flegrea:shader-material)
                          (not (flegrea:depth-write material)))
                     nil t)))
(defun %posicao-mundial (objeto)
  (let ((dados (flegrea:elements (flegrea:matrix-world objeto))))
    (flegrea:make-vector3 (aref dados 12) (aref dados 13) (aref dados 14))))

(defun %srgb-linear-componente (valor)
  (if (<= valor 0.04045f0) (/ valor 12.92f0)
      (expt (/ (+ valor 0.055f0) 1.055f0) 2.4f0)))
(defun %cor-luz-linear (luz)
  (let ((cor (flegrea:color luz)) (potencia (flegrea:intensity luz)))
    (flegrea:make-vector3 (* potencia (%srgb-linear-componente (flegrea:x cor)))
                          (* potencia (%srgb-linear-componente (flegrea:y cor)))
                          (* potencia (%srgb-linear-componente (flegrea:z cor))))))

(defun %coletar-luzes (cena)
  (let ((ambientes nil) (direcionais nil) (pontuais nil))
    (flegrea:traverse cena
      (lambda (objeto)
        (when (flegrea:visible objeto)
          (cond ((typep objeto 'flegrea:ambient-light) (push objeto ambientes))
                ((typep objeto 'flegrea:directional-light) (push objeto direcionais))
                ((typep objeto 'flegrea:point-light) (push objeto pontuais))))))
    (when (or (> (length direcionais) 8) (> (length pontuais) 8))
      (error 'renderer-error :message "O renderer aceita no máximo oito luzes direcionais e oito pontuais."))
    (values ambientes (nreverse direcionais) (nreverse pontuais))))

(defun %enviar-luzes (programa cena camera)
  (multiple-value-bind (ambientes direcionais pontuais) (%coletar-luzes cena)
    (let ((ambiente (flegrea:make-vector3)))
      (dolist (luz ambientes) (flegrea:add ambiente (%cor-luz-linear luz)))
      (%uniforme-cor programa "luzAmbiente" ambiente))
    (gl:uniformi (gl:get-uniform-location programa "quantidadeDirecionais") (length direcionais))
    (loop for luz in direcionais for indice from 0 do
      (let ((direcao (flegrea:subtract (%posicao-mundial luz) (%posicao-mundial (flegrea:target luz))))
            (cor (%cor-luz-linear luz)))
        (flegrea:normalize direcao)
        (%uniforme-cor programa (format nil "direcoesDirecionais[~D]" indice) direcao)
        (%uniforme-cor programa (format nil "coresDirecionais[~D]" indice) cor)))
    (gl:uniformi (gl:get-uniform-location programa "quantidadePontuais") (length pontuais))
    (loop for luz in pontuais for indice from 0 do
      (%uniforme-cor programa (format nil "posicoesPontuais[~D]" indice) (%posicao-mundial luz))
      (%uniforme-cor programa (format nil "coresPontuais[~D]" indice) (%cor-luz-linear luz))
      (gl:uniformf (gl:get-uniform-location programa (format nil "distanciasPontuais[~D]" indice)) (flegrea:distance luz))
      (gl:uniformf (gl:get-uniform-location programa (format nil "decaimentosPontuais[~D]" indice)) (flegrea:decay luz)))
    (%uniforme-cor programa "posicaoCamera" (%posicao-mundial camera))))

(defun %desenhar-malha (renderizador malha cena camera)
  (let* ((material (flegrea:material malha))
         (padrao (typep material 'flegrea:mesh-standard-material))
         (personalizado (typep material 'flegrea:shader-material))
         (programa (cond (personalizado (%programa-personalizado renderizador material))
                         (padrao (%programa-padrao renderizador))
                         (t (%programa-basico renderizador))))
         (estado (%preparar-geometria renderizador (flegrea:geometry malha) padrao)))
    (unless (or personalizado padrao (typep material 'flegrea:mesh-basic-material))
      (error 'renderer-error :message "O tipo de material da malha não é suportado."))
    (%configurar-faces material)
    (gl:use-program programa)
    (%uniforme-matriz programa "matrizModelo" (flegrea:matrix-world malha) 4)
    (%uniforme-matriz programa "matrizVisao" (flegrea:view-matrix camera) 4)
    (%uniforme-matriz programa "matrizProjecao" (flegrea:projection-matrix camera) 4)
    (if personalizado
        (progn
          (%uniforme-cor programa "posicaoCamera" (%posicao-mundial camera))
          (maphash (lambda (nome valor)
                     (%enviar-uniforme-personalizado programa nome valor))
                   (flegrea:uniforms material)))
        (progn
          (%uniforme-cor programa "corMaterial" (flegrea:color material))
          (gl:uniformi (gl:get-uniform-location programa "usaCores") (if (flegrea:vertex-colors material) 1 0))
          (when padrao
            (let ((normal (flegrea:set-normal-matrix3 (flegrea:make-matrix3) (flegrea:matrix-world malha))))
              (%uniforme-matriz programa "matrizNormal" normal 3))
            (%uniforme-cor programa "corEmissiva" (flegrea:emissive material))
            (gl:uniformf (gl:get-uniform-location programa "rugosidade") (flegrea:roughness material))
            (gl:uniformf (gl:get-uniform-location programa "metalicidade") (flegrea:metalness material))
            (%enviar-luzes programa cena camera))))
    (gl:bind-vertex-array (%vao-gpu estado))
    (if (%indexada-gpu estado)
        (gl:draw-elements :triangles (gl:make-null-gl-array :unsigned-int) :count (%quantidade-gpu estado))
        (gl:draw-arrays :triangles 0 (%quantidade-gpu estado)))
    (gl:bind-vertex-array 0)))

(defun %renderizar-sem-protecao (renderizador cena camera)
  "Renderiza uma cena com uma câmera no contexto proprietário."
  (%assertar-thread renderizador)
  (glfw:make-context-current (%janela-renderizador renderizador))
  (destructuring-bind (largura altura) (glfw:get-framebuffer-size (%janela-renderizador renderizador))
    (setf (renderer-width renderizador) largura (renderer-height renderizador) altura)
    (gl:viewport 0 0 largura altura))
  (flegrea:update-matrix-world cena t)
  ;; Uma câmera externa à cena também precisa ter a matriz mundial atualizada.
  (unless (or (eq camera cena) (flegrea:parent camera)) (flegrea:update-matrix-world camera t))
  (let ((cor (%cor-limpeza renderizador)))
    (gl:clear-color (flegrea:x cor) (flegrea:y cor) (flegrea:z cor) 1.0f0))
  (gl:depth-mask t)
  (gl:clear :color-buffer-bit :depth-buffer-bit)
  (labels ((visitar (objeto visivel-p)
             (let ((visivel-agora (and visivel-p (flegrea:visible objeto))))
               (when (and visivel-agora (typep objeto 'flegrea:mesh))
                 (%desenhar-malha renderizador objeto cena camera))
               (dolist (filho (flegrea:children objeto)) (visitar filho visivel-agora)))))
    (visitar cena t))
  renderizador)

(defun render (renderizador cena camera)
  "Renderiza uma cena com uma câmera no contexto proprietário."
  (float-features:with-float-traps-masked t
    (%renderizar-sem-protecao renderizador cena camera)))

(defun render-scene (renderizador instancia)
  "Renderiza uma instância produzida pelo metagrafo."
  (render renderizador (flegrea:instance-scene instancia) (flegrea:instance-camera instancia)))

(defun %deve-fechar-sem-protecao (renderer)
  "Informa se a janela recebeu pedido de fechamento."
  (%assertar-thread renderer)
  (glfw:window-should-close-p (%janela-renderizador renderer)))

(defun renderer-should-close-p (renderer)
  "Informa se a janela recebeu pedido de fechamento."
  (float-features:with-float-traps-masked t
    (%deve-fechar-sem-protecao renderer)))

(defun key-down-p (renderizador tecla)
  "Informa se uma tecla está pressionada na janela do renderer."
  (float-features:with-float-traps-masked t
    (%assertar-thread renderizador)
    (not (null (member (glfw:get-key tecla (%janela-renderizador renderizador))
                       '(:press :repeat))))))

(defun request-close (renderizador)
  "Solicita o fechamento da janela e a parada do loop."
  (float-features:with-float-traps-masked t
    (%assertar-thread renderizador)
    (glfw:set-window-should-close (%janela-renderizador renderizador) t)
    (setf (%executando renderizador) nil))
  renderizador)

(defun stop-animation (renderer)
  "Solicita a parada do loop de animação."
  (%assertar-thread renderer)
  (setf (%executando renderer) nil)
  renderer)

(defun %segundos ()
  (/ (get-internal-real-time) (coerce internal-time-units-per-second 'single-float)))

(defun %animar-sem-protecao (renderer scene camera &optional callback)
  "Executa o loop bloqueante da API direta."
  (%assertar-thread renderer)
  (let ((inicio (%segundos)) (anterior (%segundos)))
    (setf (%executando renderer) t)
    (unwind-protect
         (loop while (and (%executando renderer) (not (renderer-should-close-p renderer))) do
           (let* ((agora (%segundos)) (delta (- agora anterior)) (tempo (- agora inicio)))
             (setf anterior agora)
             (when callback (funcall callback delta tempo))
             (render renderer scene camera)
             (glfw:swap-buffers (%janela-renderizador renderer))
             (glfw:poll-events)
             (when (member (glfw:get-key :escape (%janela-renderizador renderer)) '(:press :repeat))
               (setf (%executando renderer) nil))))
      (setf (%executando renderer) nil)))
  renderer)

(defun animate (renderer scene camera &optional callback)
  "Executa o loop bloqueante da API direta."
  (float-features:with-float-traps-masked t
    (%animar-sem-protecao renderer scene camera callback)))

(defun animate-scene (renderer instance &optional callback)
  "Executa o loop bloqueante, avaliando os bindings do metagrafo."
  (animate renderer (flegrea:instance-scene instance) (flegrea:instance-camera instance)
           (lambda (delta tempo)
             (flegrea:update-scene instance tempo delta)
             (when callback (funcall callback delta tempo)))))

(defun animation-loop (renderer scene camera &optional callback)
  "Alias explícito para o loop direto de animação."
  (animate renderer scene camera callback))

(defun %descartar-geometria-gpu (estado)
  (let ((buffers nil))
    (maphash (lambda (nome buffer) (declare (ignore nome)) (push buffer buffers)) (%buffers-gpu estado))
    (when (%buffer-indice-gpu estado) (push (%buffer-indice-gpu estado) buffers))
    (when buffers (gl:delete-buffers (coerce buffers 'vector)))
    (gl:delete-vertex-array (%vao-gpu estado))))

(defun %descartar-sem-protecao (renderer)
  "Libera programas, buffers, contexto e janela de forma idempotente."
  (unless (%descartado renderer)
    (%assertar-thread renderer)
    (glfw:make-context-current (%janela-renderizador renderer))
    (maphash (lambda (geometria estado) (declare (ignore geometria)) (%descartar-geometria-gpu estado))
             (%cache-geometrias renderer))
    (clrhash (%cache-geometrias renderer))
    (maphash (lambda (material entrada)
               (declare (ignore material))
               (gl:delete-program (first entrada)))
             (%cache-programas renderer))
    (clrhash (%cache-programas renderer))
    (gl:delete-program (%programa-basico renderer))
    (gl:delete-program (%programa-padrao renderer))
    (glfw:destroy-window (%janela-renderizador renderer))
    (setf (%descartado renderer) t (%executando renderer) nil)
    (bt:with-lock-held (*trava-glfw*)
      (decf *usuarios-glfw*)
      (when (zerop *usuarios-glfw*) (glfw:terminate))))
  renderer)

(defun dispose (renderer)
  "Libera programas, buffers, contexto e janela de forma idempotente."
  (float-features:with-float-traps-masked t
    (%descartar-sem-protecao renderer)))
