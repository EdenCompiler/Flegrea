;;;; Demo autocontido de oceano animado com shaders programáveis.

(eval-when (:compile-toplevel :load-toplevel :execute)
  (require "asdf"))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (let* ((diretorio-demo (uiop:pathname-directory-pathname *load-truename*))
         (sistema (truename (merge-pathnames "../flegrea.asd" diretorio-demo)))
         (quicklisp (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
    (unless (find-package :ql)
      (unless (probe-file quicklisp)
        (error "Quicklisp não foi encontrado. Instale-o antes de executar o demo."))
      (load quicklisp))
    (asdf:load-asd sistema)
    (uiop:symbol-call :ql :quickload :flegrea)))

(in-package #:cl-user)

(defparameter +colunas-oceano+ 420)
(defparameter +linhas-oceano+ 300)
(defparameter +largura-oceano+ 180.0f0)
(defparameter +profundidade-oceano+ 150.0f0)

(defparameter +vertice-oceano+
  "#version 330 core
layout(location=0) in vec3 posicao;
uniform mat4 matrizModelo;
uniform mat4 matrizVisao;
uniform mat4 matrizProjecao;
uniform float tempo;
out vec3 posicaoMundial;
out vec3 normalMundial;
out float alturaOnda;
out float energiaCrista;
const float PI_FLEGREA=3.14159265359;
vec3 ondaGerstner(vec3 ponto,vec2 direcao,float inclinacao,float comprimento,float velocidade){
  vec2 rumo=normalize(direcao);
  float numero=2.0*PI_FLEGREA/comprimento;
  float celeridade=sqrt(9.8/numero)*velocidade;
  float fase=numero*(dot(rumo,ponto.xz)-celeridade*tempo);
  float amplitude=inclinacao/numero;
  return vec3(rumo.x*amplitude*cos(fase),amplitude*sin(fase),rumo.y*amplitude*cos(fase));
}
vec3 superficie(vec3 ponto){
  return ponto
    +ondaGerstner(ponto,vec2(.16,-1.0),.46,10.5,.82)
    +ondaGerstner(ponto,vec2(-.28,-1.0),.24,6.2,.94)
    +ondaGerstner(ponto,vec2(.72,-.62),.12,2.8,1.12)
    +ondaGerstner(ponto,vec2(-.82,-.34),.06,1.25,1.34);
}
float crista(vec3 ponto){
  float energia=0.0;
  vec2 rumo;
  float numero,celeridade,fase;
  rumo=normalize(vec2(.16,-1.0));numero=2.0*PI_FLEGREA/10.5;celeridade=sqrt(9.8/numero)*.82;
  fase=numero*(dot(rumo,ponto.xz)-celeridade*tempo);energia+=smoothstep(.64,.98,sin(fase))*.46;
  rumo=normalize(vec2(-.28,-1.0));numero=2.0*PI_FLEGREA/6.2;celeridade=sqrt(9.8/numero)*.94;
  fase=numero*(dot(rumo,ponto.xz)-celeridade*tempo);energia+=smoothstep(.64,.98,sin(fase))*.24;
  return energia;
}
void main(){
  vec3 base=posicao;
  vec3 ponto=superficie(base);
  float passo=.18;
  vec3 pontoX=superficie(base+vec3(passo,0,0));
  vec3 pontoZ=superficie(base+vec3(0,0,passo));
  normalMundial=normalize(mat3(matrizModelo)*normalize(cross(pontoZ-ponto,pontoX-ponto)));
  alturaOnda=ponto.y;
  energiaCrista=crista(base);
  posicaoMundial=(matrizModelo*vec4(ponto,1.0)).xyz;
  gl_Position=matrizProjecao*matrizVisao*vec4(posicaoMundial,1.0);
}")

(defparameter +fragmento-oceano+
  "#version 330 core
in vec3 posicaoMundial;
in vec3 normalMundial;
in float alturaOnda;
in float energiaCrista;
out vec4 corSaida;
uniform vec3 posicaoCamera;
uniform vec3 direcaoSol;
uniform vec3 corProfunda;
uniform vec3 corRasa;
float espalhar(vec2 ponto){return fract(sin(dot(ponto,vec2(127.1,311.7)))*43758.5453);}
float ruido(vec2 ponto){
  vec2 inteiro=floor(ponto),fracao=fract(ponto);fracao=fracao*fracao*(3.0-2.0*fracao);
  return mix(mix(espalhar(inteiro),espalhar(inteiro+vec2(1,0)),fracao.x),
             mix(espalhar(inteiro+vec2(0,1)),espalhar(inteiro+vec2(1)),fracao.x),fracao.y);
}
void main(){
  vec3 normal=normalize(normalMundial);if(normal.y<0.0)normal=-normal;
  vec3 direcaoVista=normalize(posicaoCamera-posicaoMundial);
  vec3 direcaoLuz=normalize(-direcaoSol);
  float fresnel=.04+.96*pow(1.0-max(dot(normal,direcaoVista),0.0),5.0);
  float difusa=max(dot(normal,direcaoLuz),0.0);
  float reflexo=max(dot(reflect(-direcaoLuz,normal),direcaoVista),0.0);
  float brilho=pow(reflexo,240.0)*3.2+pow(reflexo,32.0)*.30;
  float misturaProfundidade=smoothstep(.08,.82,alturaOnda);
  vec3 agua=mix(corProfunda,corRasa,misturaProfundidade*.56);
  vec3 direcaoRefletida=reflect(-direcaoVista,normal);
  vec3 ceu=mix(vec3(.72,.55,.56),vec3(.08,.27,.55),clamp(direcaoRefletida.y*2.2,0.0,1.0));
  float declive=1.0-normal.y;
  float quebra=ruido(posicaoMundial.xz*1.45)+.45*ruido(posicaoMundial.xz*4.2);
  float faixaEspuma=smoothstep(.38,.61,energiaCrista+declive*.08);
  float espuma=faixaEspuma*smoothstep(.66,1.02,quebra+energiaCrista*.10);
  vec3 cor=agua*(.34+.66*difusa)+ceu*fresnel*.78+vec3(1.0,.76,.46)*brilho;
  cor=mix(cor,vec3(.84,.92,.96),clamp(espuma*.82,0.0,1.0));
  corSaida=vec4(cor,1.0);
}")

(defparameter +vertice-ceu+
  "#version 330 core
layout(location=0) in vec3 posicao;
out vec3 direcao;
void main(){
  vec2 ponto=posicao.xy;
  direcao=normalize(vec3(ponto.x,ponto.y*.72,-1.0));
  gl_Position=vec4(ponto,.9999,1.0);
}")

(defparameter +fragmento-ceu+
  "#version 330 core
in vec3 direcao;
out vec4 corSaida;
uniform float tempo;
uniform vec3 direcaoSol;
float espalhar(vec2 ponto){return fract(sin(dot(ponto,vec2(127.1,311.7)))*43758.5453);}
float ruido(vec2 ponto){
  vec2 inteiro=floor(ponto),fracao=fract(ponto);fracao=fracao*fracao*(3.0-2.0*fracao);
  return mix(mix(espalhar(inteiro),espalhar(inteiro+vec2(1,0)),fracao.x),
             mix(espalhar(inteiro+vec2(0,1)),espalhar(inteiro+vec2(1)),fracao.x),fracao.y);
}
float movimentoFractal(vec2 ponto){
  float valor=0.0,peso=.55;
  for(int indice=0;indice<4;indice++){valor+=ruido(ponto)*peso;ponto=ponto*2.07+vec2(1.7,.9);peso*=.48;}
  return valor;
}
void main(){
  vec3 rumo=normalize(direcao);
  float altura=clamp(rumo.y,0.0,1.0);
  float horizonte=pow(1.0-altura,4.0);
  vec3 zenite=vec3(.055,.19,.42),baixo=vec3(.58,.43,.47);
  vec3 cor=mix(baixo,zenite,smoothstep(0.0,.72,altura));
  vec2 coordenadaNuvem=vec2(atan(rumo.z,rumo.x)*1.15,rumo.y*5.0)+vec2(tempo*.004,0.0);
  float formaNuvem=movimentoFractal(coordenadaNuvem*.72);
  float volumes=.50+.24*sin(coordenadaNuvem.x*2.1+formaNuvem*5.0)+.18*sin(coordenadaNuvem.x*4.7-coordenadaNuvem.y*1.3);
  float nuvens=smoothstep(.57,.73,volumes+formaNuvem*.22)*smoothstep(.02,.18,altura);
  float sombraNuvem=movimentoFractal(coordenadaNuvem*1.8+3.4);
  vec3 corNuvem=mix(vec3(.24,.27,.37),vec3(.76,.70,.72),sombraNuvem);
  cor=mix(cor,corNuvem,nuvens*.74);
  vec3 rumoSol=normalize(-direcaoSol);
  float quantidadeSol=max(dot(rumo,rumoSol),0.0);
  float sol=pow(quantidadeSol,1100.0),halo=pow(quantidadeSol,18.0);
  cor+=vec3(1.0,.72,.45)*horizonte*.18+vec3(1.0,.78,.50)*(sol*2.4+halo*.20);
  corSaida=vec4(cor,1.0);
}")

(defun criar-malha-oceano ()
  (let* ((colunas +colunas-oceano+)
         (linhas +linhas-oceano+)
         (quantidade-vertices (* (1+ colunas) (1+ linhas)))
         (posicoes (make-array (* quantidade-vertices 3) :element-type 'single-float))
         (indices (make-array (* colunas linhas 6) :element-type '(unsigned-byte 32)))
         (vertice 0)
         (indice 0))
    (dotimes (linha (1+ linhas))
      (dotimes (coluna (1+ colunas))
        (let ((u (/ coluna (coerce colunas 'single-float)))
              (v (/ linha (coerce linhas 'single-float))))
          (setf (aref posicoes (* vertice 3)) (* (- u 0.5f0) +largura-oceano+)
                (aref posicoes (1+ (* vertice 3))) 0.0f0
                (aref posicoes (+ 2 (* vertice 3))) (* (- v 0.5f0) +profundidade-oceano+))
          (incf vertice))))
    (dotimes (linha linhas)
      (dotimes (coluna colunas)
        (let ((a (+ coluna (* linha (1+ colunas)))))
          (setf (aref indices indice) a
                (aref indices (+ indice 1)) (+ a colunas 1)
                (aref indices (+ indice 2)) (1+ a)
                (aref indices (+ indice 3)) (1+ a)
                (aref indices (+ indice 4)) (+ a colunas 1)
                (aref indices (+ indice 5)) (+ a colunas 2))
          (incf indice 6))))
    (values posicoes indices)))

(defun criar-cena-oceano ()
  (multiple-value-bind (posicoes indices) (criar-malha-oceano)
    (flegrea:instantiate-scene
     (flegrea:parse-scene
      `(flegrea:scene
        :id :raiz
        :active-camera (flegrea:ref :camera)
        :resources
        ((flegrea:buffer-geometry
          :id :superficie
          :attributes ((:position ,posicoes 3))
          :index ,indices)
         (flegrea:plane-geometry :id :plano-ceu :width 2 :height 2)
         (flegrea:shader-material
          :id :material-oceano
          :vertex-shader ,+vertice-oceano+
          :fragment-shader ,+fragmento-oceano+
          :side :double
          :uniforms
          ("tempo" (flegrea:bind :time)
           "direcaoSol" (flegrea:vector3 -0.55 -0.12 0.82)
           "corProfunda" (flegrea:vector3 0.001 0.008 0.052)
           "corRasa" (flegrea:vector3 0.004 0.12 0.30)))
         (flegrea:shader-material
          :id :material-ceu
          :vertex-shader ,+vertice-ceu+
          :fragment-shader ,+fragmento-ceu+
          :side :double
          :uniforms
          ("tempo" (flegrea:bind :time)
           "direcaoSol" (flegrea:vector3 -0.55 -0.12 0.82))))
        :children
        ((flegrea:perspective-camera
          :id :camera :fov 60.16 :aspect 1.5555556 :near 0.05 :far 500
          :position (flegrea:vector3 0 2.75 32))
         (flegrea:mesh
          :id :oceano :geometry (flegrea:ref :superficie)
          :material (flegrea:ref :material-oceano))
         (flegrea:mesh
          :id :ceu :geometry (flegrea:ref :plano-ceu)
          :material (flegrea:ref :material-ceu))))))))

(defun executar-oceano ()
  (let* ((teste-fumaca (or (uiop:getenv "FLEGREA_TESTE_FUMACA")
                           (member "--smoke" (uiop:command-line-arguments)
                                   :test #'string=)))
         (renderizador (flegrea:make-renderer
                        :width 1120 :height 720 :title "Flegrea 1.5 — Oceano"
                        :visible (not teste-fumaca) :vsync (not teste-fumaca)
                        :clear-color (flegrea:make-color 0.34 0.48 0.61)))
         (instancia (criar-cena-oceano))
         (camera (flegrea:instance-camera instancia))
         (camera-x 0.0f0)
         (camera-z 32.0f0)
         (quadros 0))
    (unwind-protect
         (flegrea:animate-scene
          renderizador instancia
          (lambda (delta tempo)
            (when (flegrea:key-down-p renderizador :a) (decf camera-x (* 8.0f0 delta)))
            (when (flegrea:key-down-p renderizador :d) (incf camera-x (* 8.0f0 delta)))
            (when (flegrea:key-down-p renderizador :w) (decf camera-z (* 8.0f0 delta)))
            (when (flegrea:key-down-p renderizador :s) (incf camera-z (* 8.0f0 delta)))
            (flegrea:set-position camera camera-x
                                  (+ 2.75f0 (* (sin (* tempo 0.42f0)) 0.035f0))
                                  camera-z)
            (when (and teste-fumaca (>= (incf quadros) 2))
              (flegrea:stop-animation renderizador))))
      (flegrea:dispose renderizador))))

(handler-case
    (progn (executar-oceano) (uiop:quit 0))
  (error (condicao)
    (format *error-output* "Não foi possível executar o demo do oceano: ~A~%" condicao)
    (uiop:quit 1)))
