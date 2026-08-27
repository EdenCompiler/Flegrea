(in-package #:flegrea.renderer)

(define-condition renderer-error (flegrea:flegrea-error) ())
(define-condition shader-error (renderer-error) ())

(defparameter *trava-glfw* (bt:make-lock "trava global do GLFW"))
(defparameter *usuarios-glfw* 0)
(defvar *largura-do-alvo* nil)
(defvar *altura-do-alvo* nil)

(defclass %geometria-gpu ()
  ((vao :initarg :vao :reader %vao-gpu)
   (buffers :initarg :buffers :reader %buffers-gpu)
   (buffer-indice :initarg :index-buffer :accessor %buffer-indice-gpu)
   (quantidade :initarg :count :accessor %quantidade-gpu)
   (indexada :initarg :indexed :accessor %indexada-gpu)))

(defclass %sombra-gpu ()
  ((framebuffer :initarg :framebuffer :reader %framebuffer-sombra)
   (textura :initarg :texture :reader %textura-sombra)
   (largura :initarg :width :reader %largura-sombra)
   (altura :initarg :height :reader %altura-sombra)
   (matriz :initarg :matrix :accessor %matriz-sombra)))

(defclass renderer (flegrea:resource)
  ((janela :initarg :window :reader %janela-renderizador)
   (dono :initarg :owner :reader %dono-renderizador)
   (renderer-width :initarg :width :accessor renderer-width)
   (renderer-height :initarg :height :accessor renderer-height)
   (renderer-title :initarg :title :reader renderer-title)
   (cor-limpeza :initarg :clear-color :reader %cor-limpeza)
   (programa-basico :initarg :basic-program :reader %programa-basico)
   (programa-padrao :initarg :standard-program :reader %programa-padrao)
   (programa-de-sombra :initarg :shadow-program :reader %programa-de-sombra)
   (programa-de-normais :initarg :normal-program :reader %programa-de-normais)
   (programa-de-profundidade :initarg :depth-program :reader %programa-de-profundidade)
   (cache-geometrias :initform (make-hash-table :test #'eq) :reader %cache-geometrias)
   (cache-programas :initform (make-hash-table :test #'eq) :reader %cache-programas)
   (cache-texturas :initform (make-hash-table :test #'eq) :reader %cache-texturas)
   (cache-de-sombras :initform (make-hash-table :test #'eq) :reader %cache-de-sombras)
   (sombra-ativa :initform nil :accessor %sombra-ativa)
   (geometria-de-sprite :initform nil :accessor %geometria-de-sprite)
   (textura-de-transmissao :initform nil :accessor %textura-de-transmissao)
   (largura-da-transmissao :initform 0 :accessor %largura-da-transmissao)
   (altura-da-transmissao :initform 0 :accessor %altura-da-transmissao)
   (entrada :initform (flegrea:make-input-state) :reader flegrea:renderer-input)
   (qualidade :initarg :quality :initform :medium :accessor flegrea:renderer-quality)
   (estatisticas :initform (make-instance 'flegrea:renderer-stats) :accessor flegrea:renderer-stats)
   (antialias :initarg :antialias :initform t :reader flegrea:renderer-antialias)
   (espaco-de-saida :initarg :output-color-space :initform :srgb :accessor flegrea:output-color-space)
   (exposicao :initarg :exposure :initform 1.0f0 :accessor flegrea:exposure)
   (mapeamento-de-tom :initarg :tone-mapping :initform :aces :accessor flegrea:tone-mapping)
   (razao-de-pixel :initarg :pixel-ratio :initform 1.0f0 :accessor flegrea:pixel-ratio)
   (mixers :initform nil :accessor %mixers-do-renderizador)
   (controles :initform nil :accessor %controles-do-renderizador)
   (executando :initform nil :accessor %executando)
   (descartado :initform nil :accessor %descartado)))

(defun %largura-de-renderizacao (renderizador)
  (or *largura-do-alvo* (renderer-width renderizador)))

(defun %altura-de-renderizacao (renderizador)
  (or *altura-do-alvo* (renderer-height renderizador)))

(defparameter +vertice-basico+
  "#version 330 core
layout(location = 0) in vec3 posicao;
layout(location = 1) in vec3 normalIgnorada;
layout(location = 2) in vec3 corVerticeEntrada;
layout(location = 3) in vec2 uvEntrada;
layout(location = 4) in vec4 instancia0;
layout(location = 5) in vec4 instancia1;
layout(location = 6) in vec4 instancia2;
layout(location = 7) in vec4 instancia3;
layout(location = 8) in vec3 corDaInstancia;
layout(location = 9) in vec2 uvSecundariaEntrada;
uniform mat4 matrizModelo;
uniform mat4 matrizVisao;
uniform mat4 matrizProjecao;
uniform int usaInstancias;
out vec3 corVertice;
out vec3 corInstancia;
out vec2 uvFragmento;
out vec2 uvSecundaria;
void main() {
  corVertice = corVerticeEntrada;
  corInstancia = corDaInstancia;
  uvFragmento = uvEntrada;
  uvSecundaria = uvSecundariaEntrada;
  mat4 matrizDaInstancia = mat4(instancia0, instancia1, instancia2, instancia3);
  mat4 modeloFinal = matrizModelo;
  if (usaInstancias == 1) modeloFinal *= matrizDaInstancia;
  gl_Position = matrizProjecao * matrizVisao * modeloFinal * vec4(posicao, 1.0);
}")

(defparameter +fragmento-basico+
  "#version 330 core
in vec3 corVertice;
in vec3 corInstancia;
in vec2 uvFragmento;
in vec2 uvSecundaria;
uniform vec3 corMaterial;
uniform int usaCores;
uniform int usaCoresInstancia;
uniform int usaMapaBase;
uniform sampler2D mapaBase;
uniform float opacidade;
uniform float testeAlfa;
uniform vec2 escalaUV;
uniform vec2 deslocamentoUV;
uniform vec2 centroUV;
uniform float rotacaoUV;
uniform int canalUV;
out vec4 corSaida;
void main() {
  vec2 uvOrigem = canalUV == 1 ? uvSecundaria : uvFragmento;
  vec2 uvLocal = (uvOrigem - centroUV) * escalaUV;
  float c = cos(rotacaoUV);
  float s = sin(rotacaoUV);
  vec2 uvAmostra = mat2(c, -s, s, c) * uvLocal + centroUV + deslocamentoUV;
  vec3 corFinal = corMaterial;
  if (usaCores == 1) corFinal *= corVertice;
  if (usaCoresInstancia == 1) corFinal *= corInstancia;
  float alfa = opacidade;
  if (usaMapaBase == 1) {
    vec4 texel = texture(mapaBase, uvAmostra);
    corFinal *= texel.rgb;
    alfa *= texel.a;
  }
  if (alfa < testeAlfa) discard;
  corSaida = vec4(corFinal, alfa);
}")

(defparameter +vertice-de-sombra+
  "#version 330 core
layout(location = 0) in vec3 posicao;
layout(location = 4) in vec4 instancia0;
layout(location = 5) in vec4 instancia1;
layout(location = 6) in vec4 instancia2;
layout(location = 7) in vec4 instancia3;
uniform mat4 matrizModelo;
uniform mat4 matrizLuz;
uniform int usaInstancias;
void main() {
  mat4 modeloFinal = matrizModelo;
  if (usaInstancias == 1) modeloFinal *= mat4(instancia0, instancia1, instancia2, instancia3);
  gl_Position = matrizLuz * modeloFinal * vec4(posicao, 1.0);
}")

(defparameter +fragmento-de-sombra+
  "#version 330 core
void main() {}");

(defparameter +fragmento-de-normais+
  "#version 330 core
in vec3 normalMundial;
out vec4 corSaida;
void main() { corSaida = vec4(normalize(normalMundial) * 0.5 + 0.5, 1.0); }")

(defparameter +fragmento-de-profundidade+
  "#version 330 core
out vec4 corSaida;
void main() { corSaida = vec4(vec3(gl_FragCoord.z), 1.0); }")

(defparameter +vertice-padrao+
  "#version 330 core
layout(location = 0) in vec3 posicao;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec3 corVerticeEntrada;
layout(location = 3) in vec2 uvEntrada;
layout(location = 4) in vec4 instancia0;
layout(location = 5) in vec4 instancia1;
layout(location = 6) in vec4 instancia2;
layout(location = 7) in vec4 instancia3;
layout(location = 8) in vec3 corDaInstancia;
layout(location = 9) in vec2 uvSecundariaEntrada;
uniform mat4 matrizModelo;
uniform mat4 matrizVisao;
uniform mat4 matrizProjecao;
uniform mat3 matrizNormal;
uniform int usaInstancias;
uniform mat4 matrizSombra;
uniform float deslocamentoNormalSombra;
out vec3 posicaoMundial;
out vec3 normalMundial;
out vec3 corVertice;
out vec3 corInstancia;
out vec2 uvFragmento;
out vec2 uvSecundaria;
out vec4 posicaoNaSombra;
void main() {
  mat4 matrizDaInstancia = mat4(instancia0, instancia1, instancia2, instancia3);
  mat4 modeloFinal = matrizModelo;
  if (usaInstancias == 1) modeloFinal *= matrizDaInstancia;
  vec4 mundial = modeloFinal * vec4(posicao, 1.0);
  posicaoMundial = mundial.xyz;
  normalMundial = normalize((usaInstancias == 1 ? transpose(inverse(mat3(modeloFinal))) : matrizNormal) * normal);
  corVertice = corVerticeEntrada;
  corInstancia = corDaInstancia;
  uvFragmento = uvEntrada;
  uvSecundaria = uvSecundariaEntrada;
  posicaoNaSombra = matrizSombra * vec4(mundial.xyz + normalMundial * deslocamentoNormalSombra, 1.0);
  gl_Position = matrizProjecao * matrizVisao * mundial;
}")

(defparameter +fragmento-padrao+
  "#version 330 core
#define MAX_LUZES 8
const float PI_FLEGREA = 3.14159265359;
in vec3 posicaoMundial;
in vec3 normalMundial;
in vec3 corVertice;
in vec3 corInstancia;
in vec2 uvFragmento;
in vec2 uvSecundaria;
in vec4 posicaoNaSombra;
uniform vec3 corMaterial;
uniform vec3 corEmissiva;
uniform float intensidadeEmissiva;
uniform vec2 escalaNormal;
uniform float forcaOclusao;
uniform float rugosidade;
uniform float metalicidade;
uniform int usaCores;
uniform int usaCoresInstancia;
uniform int usaMapaBase;
uniform int usaMapaMetalicoRugoso;
uniform int usaMapaEmissivo;
uniform int usaMapaOclusao;
uniform int usaMapaOpacidade;
uniform int usaMapaNormal;
uniform sampler2D mapaBase;
uniform sampler2D mapaMetalicoRugoso;
uniform sampler2D mapaEmissivo;
uniform sampler2D mapaOclusao;
uniform sampler2D mapaOpacidade;
uniform sampler2D mapaNormal;
uniform int usaMapaVerniz;
uniform int usaMapaNormalVerniz;
uniform int usaMapaRugosidadeVerniz;
uniform int usaMapaTransmissao;
uniform int usaMapaEspessura;
uniform sampler2D mapaVerniz;
uniform sampler2D mapaNormalVerniz;
uniform sampler2D mapaRugosidadeVerniz;
uniform sampler2D mapaTransmissao;
uniform sampler2D mapaEspessura;
uniform float opacidade;
uniform float testeAlfa;
uniform float exposicao;
uniform int mapeamentoDeTom;
uniform int saidaSRGB;
uniform int materialFisico;
uniform float verniz;
uniform float rugosidadeVerniz;
uniform float transmissao;
uniform float espessura;
uniform float indiceRefracao;
uniform vec3 corAtenuacao;
uniform float distanciaAtenuacao;
uniform int usaCapturaOpaca;
uniform sampler2D capturaOpaca;
uniform vec2 tamanhoViewport;
uniform int recebeSombra;
uniform int usaSombra;
uniform sampler2D mapaSombra;
uniform float deslocamentoSombra;
uniform int tipoSombra;
uniform vec2 escalaUV;
uniform vec2 deslocamentoUV;
uniform vec2 centroUV;
uniform float rotacaoUV;
uniform int canalUV;
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
uniform int quantidadeSpots;
uniform vec3 posicoesSpots[MAX_LUZES];
uniform vec3 direcoesSpots[MAX_LUZES];
uniform vec3 coresSpots[MAX_LUZES];
uniform float distanciasSpots[MAX_LUZES];
uniform float decaimentosSpots[MAX_LUZES];
uniform float cossenosExternosSpots[MAX_LUZES];
uniform float cossenosInternosSpots[MAX_LUZES];
uniform int quantidadeHemisfericas;
uniform vec3 direcoesHemisfericas[MAX_LUZES];
uniform vec3 coresCeuHemisfericas[MAX_LUZES];
uniform vec3 coresSoloHemisfericas[MAX_LUZES];
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
vec3 normalMapeada(vec3 posicao, vec3 normalBase, vec2 uv, vec3 amostra) {
  vec3 q1 = dFdx(posicao);
  vec3 q2 = dFdy(posicao);
  vec2 st1 = dFdx(uv);
  vec2 st2 = dFdy(uv);
  vec3 tangente = normalize(q1 * st2.t - q2 * st1.t);
  vec3 bitangente = normalize(-q1 * st2.s + q2 * st1.s);
  return normalize(mat3(tangente, bitangente, normalBase) * (amostra * 2.0 - 1.0));
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
float fatorDeSombra() {
  if (usaSombra == 0 || recebeSombra == 0) return 1.0;
  vec3 projetada = posicaoNaSombra.xyz / posicaoNaSombra.w;
  projetada = projetada * 0.5 + 0.5;
  if (projetada.z <= 0.0 || projetada.z >= 1.0 ||
      projetada.x <= 0.0 || projetada.x >= 1.0 ||
      projetada.y <= 0.0 || projetada.y >= 1.0) return 1.0;
  vec2 texel = 1.0 / vec2(textureSize(mapaSombra, 0));
  float iluminado = 0.0;
  for (int y = -1; y <= 1; ++y) {
    for (int x = -1; x <= 1; ++x) {
      float profundidade = texture(mapaSombra, projetada.xy + vec2(x, y) * texel).r;
      iluminado += (projetada.z - deslocamentoSombra <= profundidade) ? 1.0 : 0.0;
    }
  }
  return iluminado / 9.0;
}
void main() {
  vec2 uvOrigem = canalUV == 1 ? uvSecundaria : uvFragmento;
  vec2 uvLocal = (uvOrigem - centroUV) * escalaUV;
  float c = cos(rotacaoUV);
  float s = sin(rotacaoUV);
  vec2 uvAmostra = mat2(c, -s, s, c) * uvLocal + centroUV + deslocamentoUV;
  vec3 base = paraLinear(corMaterial);
  if (usaCores == 1) base *= paraLinear(corVertice);
  if (usaCoresInstancia == 1) base *= paraLinear(corInstancia);
  float alfa = opacidade;
  if (usaMapaBase == 1) {
    vec4 texelBase = texture(mapaBase, uvAmostra);
    base *= paraLinear(texelBase.rgb);
    alfa *= texelBase.a;
  }
  if (usaMapaOpacidade == 1) alfa *= texture(mapaOpacidade, uvAmostra).r;
  if (alfa < testeAlfa) discard;
  vec3 emissiva = paraLinear(corEmissiva) * intensidadeEmissiva;
  if (usaMapaEmissivo == 1) emissiva *= paraLinear(texture(mapaEmissivo, uvAmostra).rgb);
  vec3 normal = normalize(normalMundial);
  if (usaMapaNormal == 1) {
    vec3 amostraNormal = texture(mapaNormal, uvAmostra).rgb;
    amostraNormal.xy = (amostraNormal.xy * 2.0 - 1.0) * escalaNormal * 0.5 + 0.5;
    normal = normalMapeada(posicaoMundial, normal, uvAmostra, amostraNormal);
  }
  vec3 vista = normalize(posicaoCamera - posicaoMundial);
  float rugoso = rugosidade;
  float metalico = metalicidade;
  if (usaMapaMetalicoRugoso == 1) {
    vec4 mr = texture(mapaMetalicoRugoso, uvAmostra);
    rugoso *= mr.g;
    metalico *= mr.b;
  }
  rugoso = clamp(rugoso, 0.04, 1.0);
  vec3 f0 = mix(vec3(0.04), base, metalico);
  vec3 resultado = luzAmbiente * base * (1.0 - metalico) + emissiva;
  for (int indice = 0; indice < MAX_LUZES; ++indice) {
    if (indice >= quantidadeHemisfericas) break;
    float pesoCeu = dot(normal, normalize(direcoesHemisfericas[indice])) * 0.5 + 0.5;
    resultado += mix(coresSoloHemisfericas[indice], coresCeuHemisfericas[indice], pesoCeu)
                 * base * (1.0 - metalico);
  }
  if (quantidadeDirecionais > 0) resultado += (tipoSombra == 1 ? fatorDeSombra() : 1.0) * contribuicao(normal, vista, normalize(direcoesDirecionais[0]), coresDirecionais[0], base, f0, rugoso, metalico);
  if (quantidadeDirecionais > 1) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[1]), coresDirecionais[1], base, f0, rugoso, metalico);
  if (quantidadeDirecionais > 2) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[2]), coresDirecionais[2], base, f0, rugoso, metalico);
  if (quantidadeDirecionais > 3) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[3]), coresDirecionais[3], base, f0, rugoso, metalico);
  if (quantidadeDirecionais > 4) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[4]), coresDirecionais[4], base, f0, rugoso, metalico);
  if (quantidadeDirecionais > 5) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[5]), coresDirecionais[5], base, f0, rugoso, metalico);
  if (quantidadeDirecionais > 6) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[6]), coresDirecionais[6], base, f0, rugoso, metalico);
  if (quantidadeDirecionais > 7) resultado += contribuicao(normal, vista, normalize(direcoesDirecionais[7]), coresDirecionais[7], base, f0, rugoso, metalico);
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
                              coresPontuais[indice] * atenuacao, base, f0, rugoso, metalico);
  }
  for (int indice = 0; indice < MAX_LUZES; ++indice) {
    if (indice >= quantidadeSpots) break;
    vec3 deslocamento = posicoesSpots[indice] - posicaoMundial;
    float distancia = length(deslocamento);
    float atenuacao = 1.0 / max(pow(max(distancia, 0.01), decaimentosSpots[indice]), 0.01);
    if (distanciasSpots[indice] > 0.0) {
      float faixa = clamp(1.0 - distancia / distanciasSpots[indice], 0.0, 1.0);
      atenuacao *= faixa * faixa;
    }
    float cosseno = dot(normalize(-deslocamento), normalize(direcoesSpots[indice]));
    float cone = smoothstep(cossenosExternosSpots[indice], cossenosInternosSpots[indice], cosseno);
    float sombraSpot = (indice == 0 && tipoSombra == 2) ? fatorDeSombra() : 1.0;
    resultado += sombraSpot * contribuicao(normal, vista, normalize(deslocamento),
                                           coresSpots[indice] * atenuacao * cone,
                                           base, f0, rugoso, metalico);
  }
  if (usaMapaOclusao == 1) resultado *= mix(1.0, texture(mapaOclusao, uvAmostra).r, forcaOclusao);
  float vernizFinal = verniz * (usaMapaVerniz == 1 ? texture(mapaVerniz, uvAmostra).r : 1.0);
  float rugosidadeVernizFinal = rugosidadeVerniz *
    (usaMapaRugosidadeVerniz == 1 ? texture(mapaRugosidadeVerniz, uvAmostra).g : 1.0);
  vec3 normalVerniz = normal;
  if (usaMapaNormalVerniz == 1)
    normalVerniz = normalMapeada(posicaoMundial, normal, uvAmostra,
                                 texture(mapaNormalVerniz, uvAmostra).rgb);
  if (materialFisico == 1 && vernizFinal > 0.0) {
    float nvVerniz = max(dot(normalVerniz, vista), 0.0);
    float fresnelVerniz = 0.04 + 0.96 * pow(1.0 - nvVerniz, 5.0);
    resultado += vec3(vernizFinal * fresnelVerniz * (1.0 - rugosidadeVernizFinal * 0.7));
  }
  float transmissaoFinal = transmissao *
    (usaMapaTransmissao == 1 ? texture(mapaTransmissao, uvAmostra).r : 1.0);
  float espessuraFinal = espessura *
    (usaMapaEspessura == 1 ? texture(mapaEspessura, uvAmostra).g : 1.0);
  if (materialFisico == 1 && transmissaoFinal > 0.0 && usaCapturaOpaca == 1) {
    vec2 coordenadaTela = gl_FragCoord.xy / tamanhoViewport;
    float escalaRefracao = espessuraFinal * (1.0 - 1.0 / max(indiceRefracao, 1.0));
    vec2 coordenadaRefratada = clamp(coordenadaTela + normal.xy * escalaRefracao * 0.025,
                                     vec2(0.001), vec2(0.999));
    vec3 fundo = paraLinear(textureLod(capturaOpaca, coordenadaRefratada,
                                      clamp(rugoso * 5.0, 0.0, 5.0)).rgb);
    if (distanciaAtenuacao < 1.0e20) {
      fundo *= pow(max(corAtenuacao, vec3(0.0001)),
                   vec3(max(espessuraFinal, 0.0) / max(distanciaAtenuacao, 0.0001)));
    }
    resultado = mix(resultado, fundo, transmissaoFinal);
  }
  resultado *= exposicao;
  if (mapeamentoDeTom == 1) resultado = resultado / (resultado + vec3(1.0));
  if (mapeamentoDeTom == 2) {
    resultado = clamp((resultado * (2.51 * resultado + 0.03)) /
                      (resultado * (2.43 * resultado + 0.59) + 0.14), 0.0, 1.0);
  }
  if (saidaSRGB == 1) resultado = paraSRGB(max(resultado, vec3(0.0)));
  corSaida = vec4(resultado, alfa);
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
  (unless (typep cor 'flegrea:color)
    (error 'renderer-error :message "A cor do renderer deve ser uma instância de color."))
  cor)

(defun %criar-renderizador-sem-protecao (&key (width 800) (height 600) (title "Flegrea")
                           (clear-color (flegrea:make-color 0.02 0.025 0.04))
                           (vsync t) (resizable t) (visible t) (quality :medium)
                           (antialias t) (output-color-space :srgb) (exposure 1.0f0)
                           (tone-mapping :aces) (pixel-ratio 1.0f0))
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
                                    :samples (if antialias 4 0) :srgb-capable t
                                    :depth-bits 24 :stencil-bits 8))
          (setf %gl:*gl-get-proc-address* #'glfw:get-proc-address)
          (glfw:make-context-current janela)
          ;; Alguns backends X11 mantêm a janela sem mapear apesar do hint inicial.
          (when visible (glfw:show-window janela))
          (glfw:swap-interval (if vsync 1 0))
          (gl:enable :depth-test)
          (gl:depth-func :less)
          (destructuring-bind (largura-real altura-real) (glfw:get-framebuffer-size janela)
            (let ((renderizador
                    (make-instance 'renderer :window janela :owner (bt:current-thread)
                     :width largura-real :height altura-real :title title :clear-color (flegrea:clone clear-color)
                     :quality quality :antialias antialias :output-color-space output-color-space
                     :exposure exposure :tone-mapping tone-mapping :pixel-ratio pixel-ratio
                     :basic-program (%criar-programa +vertice-basico+ +fragmento-basico+)
                     :standard-program (%criar-programa +vertice-padrao+ +fragmento-padrao+)
                     :shadow-program (%criar-programa +vertice-de-sombra+
                                                      +fragmento-de-sombra+)
                     :normal-program (%criar-programa +vertice-padrao+
                                                      +fragmento-de-normais+)
                     :depth-program (%criar-programa +vertice-basico+
                                                     +fragmento-de-profundidade+))))
              (%instalar-entrada renderizador)
              renderizador)))
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

(defun %preparar-geometria (renderizador geometria exige-normal)
  (let* ((cache (%cache-geometrias renderizador))
         (estado (or (gethash geometria cache)
                     (setf (gethash geometria cache) (%criar-geometria-gpu))))
         (posicao (flegrea:get-attribute geometria :position))
         (normal (flegrea:get-attribute geometria :normal))
         (cor (flegrea:get-attribute geometria :color))
         (uv (flegrea:get-attribute geometria :uv))
         (uv-secundaria (flegrea:get-attribute geometria :uv1)))
    (unless (and posicao (= (flegrea:item-size posicao) 3))
      (error 'renderer-error :message "A geometria renderizada precisa de um atributo :position tridimensional."))
    (when (and exige-normal (not (and normal (= (flegrea:item-size normal) 3))))
      (error 'renderer-error :message "O material standard exige normais tridimensionais."))
    (let ((quantidade (/ (length (flegrea:attribute-array posicao)) 3)))
      (gl:bind-vertex-array (%vao-gpu estado))
      (when (or (flegrea:needs-update posicao) (not (gethash :position (%buffers-gpu estado))))
        (%enviar-atributo estado :position posicao 0))
      (if normal
          (when (or (flegrea:needs-update normal) (not (gethash :normal (%buffers-gpu estado))))
            (%enviar-atributo estado :normal normal 1))
          (progn
            (gl:disable-vertex-attrib-array 1)
            (gl:vertex-attrib 1 0.0f0 0.0f0 1.0f0)))
      (if cor
          (when (or (flegrea:needs-update cor) (not (gethash :color (%buffers-gpu estado))))
            (%enviar-atributo estado :color cor 2))
          (progn
            (gl:disable-vertex-attrib-array 2)
            (gl:vertex-attrib 2 1.0f0 1.0f0 1.0f0)))
      (flet ((preparar-uv (atributo nome localizacao)
               (if atributo
                   (progn
                     (unless (= (flegrea:item-size atributo) 2)
                       (error 'renderer-error :message
                              "Um atributo de coordenadas UV precisa ter dois componentes."))
                     (when (or (flegrea:needs-update atributo)
                               (not (gethash nome (%buffers-gpu estado))))
                       (%enviar-atributo estado nome atributo localizacao)))
                   (progn
                     (gl:disable-vertex-attrib-array localizacao)
                     (gl:vertex-attrib localizacao 0.0f0 0.0f0)))))
        (preparar-uv uv :uv 3)
        (preparar-uv uv-secundaria :uv1 9))
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
               (if (typep cor 'flegrea:color) (flegrea:color-r cor) (flegrea:x cor))
               (if (typep cor 'flegrea:color) (flegrea:color-g cor) (flegrea:y cor))
               (if (typep cor 'flegrea:color) (flegrea:color-b cor) (flegrea:z cor))))

(defvar *unidade-de-textura* 0)

(defun %octetos-da-textura (textura)
  (let* ((largura (flegrea:image-width textura))
         (altura (flegrea:image-height textura))
         (origem (flegrea:image-data textura))
         (esperado (* largura altura 4)))
    (unless (= (length origem) esperado)
      (error 'renderer-error :message "A textura RGBA não possui a quantidade esperada de octetos."))
    (if (not (flegrea:flip-y textura))
        origem
        (let* ((linha (* largura 4))
               (destino (make-array esperado :element-type '(unsigned-byte 8))))
          (dotimes (y altura destino)
            (replace destino origem :start1 (* y linha) :end1 (* (1+ y) linha)
                     :start2 (* (- altura y 1) linha) :end2 (* (- altura y) linha)))))))

(defun %enviar-textura-rgba (textura)
  (let ((dados (%octetos-da-textura textura)))
    (gl:pixel-store :unpack-alignment 1)
    ;; A conversão de entrada é feita explicitamente pelos shaders gerenciados.
    ;; Manter RGBA8 também entrega texéis crus a shaders personalizados.
    (gl:tex-image-2d :texture-2d 0 :rgba8
                     (flegrea:image-width textura) (flegrea:image-height textura)
                     0 :rgba :unsigned-byte dados)))

(defun %garantir-textura (renderizador textura)
  (when (flegrea:disposed-p textura)
    (error 'flegrea:disposed-resource-error :message "Uma textura descartada foi usada pelo renderer."
           :operation :render :resource textura))
  (let* ((cache (%cache-texturas renderizador))
         (identificador (or (gethash textura cache) (gl:gen-texture))))
    (when (or (null (gethash textura cache)) (flegrea:needs-update textura))
      (gl:bind-texture :texture-2d identificador)
        (gl:tex-parameter :texture-2d :texture-min-filter (flegrea:min-filter textura))
        (gl:tex-parameter :texture-2d :texture-mag-filter (flegrea:mag-filter textura))
        (gl:tex-parameter :texture-2d :texture-wrap-s (flegrea:wrap-s textura))
        (gl:tex-parameter :texture-2d :texture-wrap-t (flegrea:wrap-t textura))
        (%enviar-textura-rgba textura)
      (when (flegrea:generate-mipmaps textura) (gl:generate-mipmap :texture-2d))
      (setf (flegrea:needs-update textura) nil
            (gethash textura cache) identificador))
    identificador))

(defun %ligar-textura (renderizador programa nome textura)
  (let ((unidade *unidade-de-textura*))
    (incf *unidade-de-textura*)
    (gl:active-texture (intern (format nil "TEXTURE~D" unidade) :keyword))
    (gl:bind-texture :texture-2d (%garantir-textura renderizador textura))
    (gl:uniformi (gl:get-uniform-location programa nome) unidade)
    unidade))

(defun %enviar-transformacao-uv (programa textura)
  (let ((referencia (or textura nil)))
    (if referencia
        (progn
          (%enviar-uniforme-personalizado nil programa "escalaUV" (flegrea:repeat referencia))
          (%enviar-uniforme-personalizado nil programa "deslocamentoUV" (flegrea:offset referencia))
          (%enviar-uniforme-personalizado nil programa "centroUV" (flegrea:texture-center referencia))
          (gl:uniformf (gl:get-uniform-location programa "rotacaoUV")
                       (coerce (flegrea:texture-rotation referencia) 'single-float))
          (gl:uniformi (gl:get-uniform-location programa "canalUV")
                       (flegrea:uv-channel referencia)))
        (progn
          (gl:uniformf (gl:get-uniform-location programa "escalaUV") 1.0f0 1.0f0)
          (gl:uniformf (gl:get-uniform-location programa "deslocamentoUV") 0.0f0 0.0f0)
          (gl:uniformf (gl:get-uniform-location programa "centroUV") 0.0f0 0.0f0)
          (gl:uniformf (gl:get-uniform-location programa "rotacaoUV") 0.0f0)
          (gl:uniformi (gl:get-uniform-location programa "canalUV") 0)))))

(defun %textura-de-referencia-uv (material)
  (or (flegrea:base-color-map material)
      (when (typep material 'flegrea:mesh-standard-material)
        (or (flegrea:metallic-roughness-map material)
            (flegrea:normal-map material)
            (flegrea:emissive-map material)
            (flegrea:occlusion-map material)
            (flegrea:opacity-map material)
            (when (typep material 'flegrea:mesh-physical-material)
              (or (flegrea:clearcoat-map material)
                  (flegrea:clearcoat-normal-map material)
                  (flegrea:clearcoat-roughness-map material)
                  (flegrea:transmission-map material)
                  (flegrea:thickness-map material)))))))

(defun %enviar-uniforme-personalizado (renderizador programa nome valor)
  (let ((localizacao (gl:get-uniform-location programa nome)))
    (when (>= localizacao 0)
      (typecase valor
        (flegrea:matrix4 (%uniforme-matriz programa nome valor 4))
        (flegrea:matrix3 (%uniforme-matriz programa nome valor 3))
        (flegrea:vector4
         (gl:uniformf localizacao (flegrea:x valor) (flegrea:y valor)
                      (flegrea:z valor) (flegrea:w valor)))
        (flegrea:vector3 (%uniforme-cor programa nome valor))
        (flegrea:color (%uniforme-cor programa nome valor))
        (flegrea:vector2 (gl:uniformf localizacao (flegrea:x valor) (flegrea:y valor)))
        (flegrea:texture
         (unless renderizador
           (error 'renderer-error :message "Um uniforme texture requer um renderer."))
         (%ligar-textura renderizador programa nome valor))
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

(defun %ligar-mapa-opcional (renderizador programa textura nome-do-sampler nome-do-indicador)
  (gl:uniformi (gl:get-uniform-location programa nome-do-indicador) (if textura 1 0))
  (when textura (%ligar-textura renderizador programa nome-do-sampler textura))
  textura)

(defun %capturar-opacos (renderizador largura altura)
  (unless (%textura-de-transmissao renderizador)
    (setf (%textura-de-transmissao renderizador) (gl:gen-texture))
    (gl:bind-texture :texture-2d (%textura-de-transmissao renderizador))
    (gl:tex-parameter :texture-2d :texture-min-filter :linear-mipmap-linear)
    (gl:tex-parameter :texture-2d :texture-mag-filter :linear)
    (gl:tex-parameter :texture-2d :texture-wrap-s :clamp-to-edge)
    (gl:tex-parameter :texture-2d :texture-wrap-t :clamp-to-edge))
  (gl:active-texture :texture0)
  (gl:bind-texture :texture-2d (%textura-de-transmissao renderizador))
  (when (or (/= largura (%largura-da-transmissao renderizador))
            (/= altura (%altura-da-transmissao renderizador)))
    (gl:tex-image-2d :texture-2d 0 :rgb8 largura altura 0
                     :rgb :unsigned-byte (cffi:null-pointer)))
  (gl:copy-tex-sub-image-2d :texture-2d 0 0 0 0 0 largura altura)
  (gl:generate-mipmap :texture-2d)
  (setf (%largura-da-transmissao renderizador) largura
        (%altura-da-transmissao renderizador) altura)
  renderizador)

(defun %material-transmissivo-p (material)
  (and (typep material 'flegrea:mesh-physical-material)
       (plusp (flegrea:transmission material))))

(defun %preparar-instancias (estado objeto)
  (gl:bind-vertex-array (%vao-gpu estado))
  (if (typep objeto 'flegrea:instanced-mesh)
      (let* ((quantidade (flegrea:instance-count objeto))
             (dados (make-array (* quantidade 16) :element-type 'single-float))
             (cores (make-array (* quantidade 3) :element-type 'single-float
                                                 :initial-element 1.0f0))
             (buffer (%garantir-buffer estado :instance-matrix))
             (buffer-de-cores (%garantir-buffer estado :instance-color)))
        (dotimes (indice quantidade)
          (replace dados (flegrea:elements (aref (flegrea:instance-matrices objeto) indice))
                   :start1 (* indice 16))
          (let ((cor (and (flegrea:instance-colors objeto)
                          (aref (flegrea:instance-colors objeto) indice))))
            (when cor
              (setf (aref cores (* indice 3)) (flegrea:color-r cor)
                    (aref cores (1+ (* indice 3))) (flegrea:color-g cor)
                    (aref cores (+ 2 (* indice 3))) (flegrea:color-b cor)))))
        (gl:bind-buffer :array-buffer buffer)
        (%enviar-array :array-buffer :float dados :dynamic-draw)
        (dotimes (coluna 4)
          (let ((localizacao (+ 4 coluna)))
            (gl:enable-vertex-attrib-array localizacao)
            (gl:vertex-attrib-pointer localizacao 4 :float nil 64
                                      (cffi:make-pointer (* coluna 16)))
            (%gl:vertex-attrib-divisor localizacao 1)))
        (gl:bind-buffer :array-buffer buffer-de-cores)
        (%enviar-array :array-buffer :float cores :dynamic-draw)
        (gl:enable-vertex-attrib-array 8)
        (gl:vertex-attrib-pointer 8 3 :float nil 0 (cffi:null-pointer))
        (%gl:vertex-attrib-divisor 8 1)
        quantidade)
      (progn
        (dotimes (coluna 4)
          (let ((localizacao (+ 4 coluna)))
            (gl:disable-vertex-attrib-array localizacao)
            (%gl:vertex-attrib-divisor localizacao 0)))
        (gl:disable-vertex-attrib-array 8)
        (%gl:vertex-attrib-divisor 8 0)
        (gl:vertex-attrib 8 1.0f0 1.0f0 1.0f0)
        1)))

(defun %intervalo-de-desenho (geometria grupo total)
  (let* ((faixa (flegrea:draw-range geometria))
         (inicio-faixa (car faixa))
         (quantidade-faixa (or (cdr faixa) (- total inicio-faixa)))
         (inicio-grupo (if grupo (getf grupo :start) 0))
         (quantidade-grupo (if grupo (getf grupo :count) total))
         (inicio (max inicio-faixa inicio-grupo))
         (fim (min total (+ inicio-faixa quantidade-faixa)
                   (+ inicio-grupo quantidade-grupo))))
    (values inicio (max 0 (- fim inicio)))))

(defun %configurar-faces (material)
  (let ((lado (flegrea:side material)))
    (if (eq lado :double)
        (gl:disable :cull-face)
        (progn
          (gl:enable :cull-face)
          (gl:cull-face (if (eq lado :back) :front :back)))))
  (if (flegrea:depth-test material) (gl:enable :depth-test) (gl:disable :depth-test))
  (gl:depth-mask (not (null (flegrea:depth-write material))))
  (if (or (flegrea:transparent material) (< (flegrea:opacity material) 1.0f0)
          (eq (flegrea:alpha-mode material) :blend))
      (progn
        (gl:enable :blend)
        (case (flegrea:blending material)
          (:additive (gl:blend-func :src-alpha :one))
          (:multiply (gl:blend-func :dst-color :one-minus-src-alpha))
          (otherwise (gl:blend-func :src-alpha :one-minus-src-alpha))))
      (gl:disable :blend)))
(defun %posicao-mundial (objeto)
  (let ((dados (flegrea:elements (flegrea:matrix-world objeto))))
    (flegrea:make-vector3 (aref dados 12) (aref dados 13) (aref dados 14))))

(defun %valor-escalar-gl (valor)
  (if (typep valor 'sequence) (elt valor 0) valor))

(defun %camera-da-sombra (luz configuracao)
  (or (flegrea:shadow-camera configuracao)
      (setf (flegrea:shadow-camera configuracao)
            (if (typep luz 'flegrea:spot-light)
                (flegrea:make-perspective-camera
                 :fov (coerce (* 2.0f0 (/ (* 180.0f0 (flegrea:angle luz)) pi))
                              'single-float)
                 :aspect 1.0f0 :near 0.1f0
                 :far (if (plusp (flegrea:distance luz)) (flegrea:distance luz) 100.0f0))
                (flegrea:make-orthographic-camera
                 :left -20.0f0 :right 20.0f0 :top 20.0f0 :bottom -20.0f0
                 :near 0.1f0 :far 100.0f0)))))

(defun %preparar-camera-da-sombra (luz configuracao)
  (flegrea:update-matrix-world (flegrea:target luz) t)
  (let* ((camera (%camera-da-sombra luz configuracao))
         (origem (%posicao-mundial luz))
         (destino (%posicao-mundial (flegrea:target luz))))
    (flegrea:set-position camera (flegrea:x origem) (flegrea:y origem) (flegrea:z origem))
    (flegrea:look-at camera destino)
    (flegrea:update-projection-matrix camera)
    (flegrea:update-matrix-world camera t)
    camera))

(defun %descartar-sombra-gpu (estado)
  (gl:delete-texture (%textura-sombra estado))
  (gl:delete-framebuffer (%framebuffer-sombra estado)))

(defun %garantir-sombra-gpu (renderizador configuracao)
  (let* ((tamanho (flegrea:shadow-map-size configuracao))
         (largura (max 1 (round (flegrea:x tamanho))))
         (altura (max 1 (round (flegrea:y tamanho))))
         (cache (%cache-de-sombras renderizador))
         (anterior (gethash configuracao cache)))
    (when (and anterior
               (or (/= largura (%largura-sombra anterior))
                   (/= altura (%altura-sombra anterior))))
      (%descartar-sombra-gpu anterior)
      (remhash configuracao cache)
      (setf anterior nil))
    (or anterior
        (let ((framebuffer (gl:gen-framebuffer)) (textura (gl:gen-texture)))
          (gl:bind-texture :texture-2d textura)
          (gl:tex-parameter :texture-2d :texture-min-filter :linear)
          (gl:tex-parameter :texture-2d :texture-mag-filter :linear)
          (gl:tex-parameter :texture-2d :texture-wrap-s :clamp-to-border)
          (gl:tex-parameter :texture-2d :texture-wrap-t :clamp-to-border)
          (gl:tex-parameter :texture-2d :texture-border-color #(1.0f0 1.0f0 1.0f0 1.0f0))
          (gl:tex-image-2d :texture-2d 0 :depth-component24 largura altura 0
                           :depth-component :float (cffi:null-pointer))
          (gl:bind-framebuffer :framebuffer framebuffer)
          (gl:framebuffer-texture-2d :framebuffer :depth-attachment :texture-2d textura 0)
          (gl:draw-buffer :none)
          (gl:read-buffer :none)
          (unless (gl::enum= (gl:check-framebuffer-status :framebuffer) :framebuffer-complete)
            (error 'renderer-error :message "O framebuffer do shadow map está incompleto."))
          (setf (gethash configuracao cache)
                (make-instance '%sombra-gpu :framebuffer framebuffer :texture textura
                               :width largura :height altura :matrix (flegrea:make-matrix4)))))))

(defun %primeira-luz-com-sombra (cena)
  (let ((resultado nil))
    (flegrea:traverse
     cena
     (lambda (objeto)
       (when (and (null resultado) (flegrea:visible objeto)
                  (typep objeto '(or flegrea:directional-light flegrea:spot-light))
                  (typep (flegrea:shadow objeto) 'flegrea:light-shadow))
         (setf resultado objeto))))
    resultado))

(defun %desenhar-profundidade (renderizador objeto matriz-da-luz)
  (let* ((geometria (flegrea:geometry objeto))
         (estado (%preparar-geometria renderizador geometria nil))
         (programa (%programa-de-sombra renderizador))
         (instancias (%preparar-instancias estado objeto))
         (modo (flegrea:primitive-mode geometria)))
    (when (member modo '(:triangles :triangle-strip :triangle-fan))
      (gl:use-program programa)
      (%uniforme-matriz programa "matrizModelo" (flegrea:matrix-world objeto) 4)
      (%uniforme-matriz programa "matrizLuz" matriz-da-luz 4)
      (gl:uniformi (gl:get-uniform-location programa "usaInstancias")
                   (if (typep objeto 'flegrea:instanced-mesh) 1 0))
      (gl:bind-vertex-array (%vao-gpu estado))
      (if (%indexada-gpu estado)
          (if (> instancias 1)
              (gl:draw-elements-instanced modo (gl:make-null-gl-array :unsigned-int)
                                          instancias :count (%quantidade-gpu estado))
              (gl:draw-elements modo (gl:make-null-gl-array :unsigned-int)
                                :count (%quantidade-gpu estado)))
          (if (> instancias 1)
              (gl:draw-arrays-instanced modo 0 (%quantidade-gpu estado) instancias)
              (gl:draw-arrays modo 0 (%quantidade-gpu estado)))))))

(defun %renderizar-shadow-map (renderizador cena)
  (let ((luz (%primeira-luz-com-sombra cena)))
    (setf (%sombra-ativa renderizador) nil)
    (when luz
      (let* ((configuracao (flegrea:shadow luz))
             (camera (%preparar-camera-da-sombra luz configuracao))
             (framebuffer-anterior (%valor-escalar-gl (gl:get-integer :framebuffer-binding)))
             (buffer-de-leitura-anterior (%valor-escalar-gl (gl:get-integer :read-buffer)))
             (buffer-de-desenho-anterior (%valor-escalar-gl (gl:get-integer :draw-buffer)))
             (viewport-anterior (gl:get-integer :viewport))
             (estado (%garantir-sombra-gpu renderizador configuracao))
             (matriz (flegrea:matrix-multiply
                      (flegrea:clone (flegrea:projection-matrix camera))
                      (flegrea:view-matrix camera))))
        (setf (%matriz-sombra estado) matriz)
        (gl:bind-framebuffer :framebuffer (%framebuffer-sombra estado))
        (gl:viewport 0 0 (%largura-sombra estado) (%altura-sombra estado))
        (gl:enable :depth-test)
        (gl:depth-mask t)
        (gl:clear :depth-buffer-bit)
        (gl:enable :cull-face)
        (gl:cull-face :front)
        (flegrea:traverse
         cena
         (lambda (objeto)
           (when (and (flegrea:visible objeto) (typep objeto 'flegrea:mesh)
                      (flegrea:cast-shadow objeto))
             (%desenhar-profundidade renderizador objeto matriz))))
        (gl:bind-framebuffer :framebuffer framebuffer-anterior)
        (gl:read-buffer buffer-de-leitura-anterior)
        (gl:draw-buffer buffer-de-desenho-anterior)
        (gl:viewport (elt viewport-anterior 0) (elt viewport-anterior 1)
                     (elt viewport-anterior 2) (elt viewport-anterior 3))
        (gl:cull-face :back)
        (setf (%sombra-ativa renderizador) (list luz configuracao estado)))))
  renderizador)

(defun %srgb-linear-componente (valor)
  (if (<= valor 0.04045f0) (/ valor 12.92f0)
      (expt (/ (+ valor 0.055f0) 1.055f0) 2.4f0)))
(defun %cor-luz-linear (luz)
  (let ((cor (flegrea:color luz)) (potencia (flegrea:intensity luz)))
    (let ((linear (flegrea:convert-color cor :linear)))
      (flegrea:make-vector3 (* potencia (flegrea:color-r linear))
                            (* potencia (flegrea:color-g linear))
                            (* potencia (flegrea:color-b linear))))))

(defun %coletar-luzes (cena)
  (let ((ambientes nil) (direcionais nil) (pontuais nil) (spots nil) (hemisfericas nil))
    (flegrea:traverse cena
      (lambda (objeto)
        (when (flegrea:visible objeto)
          (cond ((typep objeto 'flegrea:ambient-light) (push objeto ambientes))
                ((typep objeto 'flegrea:directional-light) (push objeto direcionais))
                ((typep objeto 'flegrea:spot-light) (push objeto spots))
                ((typep objeto 'flegrea:point-light) (push objeto pontuais))
                ((typep objeto 'flegrea:hemisphere-light) (push objeto hemisfericas))))))
    (when (some (lambda (lista) (> (length lista) 8))
                (list direcionais pontuais spots hemisfericas))
      (error 'renderer-error :message "O renderer aceita no máximo oito luzes de cada tipo."))
    (flet ((ordenar-sombra (lista)
             (stable-sort (nreverse lista)
                          (lambda (a b)
                            (and (typep (flegrea:shadow a) 'flegrea:light-shadow)
                                 (not (typep (flegrea:shadow b) 'flegrea:light-shadow)))))))
      (values ambientes (ordenar-sombra direcionais) (nreverse pontuais)
              (ordenar-sombra spots) (nreverse hemisfericas)))))

(defun %enviar-luzes (programa cena camera)
  (multiple-value-bind (ambientes direcionais pontuais spots hemisfericas) (%coletar-luzes cena)
    (let ((ambiente (flegrea:make-vector3)))
      (dolist (luz ambientes) (flegrea:add ambiente (%cor-luz-linear luz)))
      (%uniforme-cor programa "luzAmbiente" ambiente))
    (gl:uniformi (gl:get-uniform-location programa "quantidadeDirecionais") (length direcionais))
    (loop for luz in direcionais for indice from 0 do
      (flegrea:update-matrix-world (flegrea:target luz) t)
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
    (gl:uniformi (gl:get-uniform-location programa "quantidadeSpots") (length spots))
    (loop for luz in spots for indice from 0 do
      (flegrea:update-matrix-world (flegrea:target luz) t)
      (let ((direcao (flegrea:subtract (%posicao-mundial (flegrea:target luz))
                                        (%posicao-mundial luz))))
        (flegrea:normalize direcao)
        (%uniforme-cor programa (format nil "direcoesSpots[~D]" indice) direcao))
      (%uniforme-cor programa (format nil "posicoesSpots[~D]" indice) (%posicao-mundial luz))
      (%uniforme-cor programa (format nil "coresSpots[~D]" indice) (%cor-luz-linear luz))
      (gl:uniformf (gl:get-uniform-location programa (format nil "distanciasSpots[~D]" indice))
                   (flegrea:distance luz))
      (gl:uniformf (gl:get-uniform-location programa (format nil "decaimentosSpots[~D]" indice))
                   (flegrea:decay luz))
      (gl:uniformf (gl:get-uniform-location programa (format nil "cossenosExternosSpots[~D]" indice))
                   (cos (flegrea:angle luz)))
      (gl:uniformf (gl:get-uniform-location programa (format nil "cossenosInternosSpots[~D]" indice))
                   (cos (* (flegrea:angle luz) (- 1.0f0 (flegrea:penumbra luz))))))
    (gl:uniformi (gl:get-uniform-location programa "quantidadeHemisfericas") (length hemisfericas))
    (loop for luz in hemisfericas for indice from 0 do
      (let ((direcao (%posicao-mundial luz)))
        (when (< (flegrea:length-squared direcao) 1.0e-8) (flegrea:set-vector3 direcao 0 1 0))
        (flegrea:normalize direcao)
        (%uniforme-cor programa (format nil "direcoesHemisfericas[~D]" indice) direcao))
      (%uniforme-cor programa (format nil "coresCeuHemisfericas[~D]" indice) (%cor-luz-linear luz))
      (let* ((linear (flegrea:convert-color (flegrea:ground-color luz) :linear))
             (potencia (flegrea:intensity luz)))
        (%uniforme-cor programa (format nil "coresSoloHemisfericas[~D]" indice)
                        (flegrea:make-vector3 (* potencia (flegrea:color-r linear))
                                              (* potencia (flegrea:color-g linear))
                                              (* potencia (flegrea:color-b linear))))))
    (%uniforme-cor programa "posicaoCamera" (%posicao-mundial camera))))

(defun %desenhar-malha (renderizador malha cena camera &optional grupo)
  (let* ((material (flegrea:material malha))
         (padrao (and (typep malha 'flegrea:mesh)
                      (typep material 'flegrea:mesh-standard-material)))
         (normais (typep material 'flegrea:mesh-normal-material))
         (profundidade (typep material 'flegrea:mesh-depth-material))
         (personalizado (typep material 'flegrea:shader-material))
         (programa (cond (personalizado (%programa-personalizado renderizador material))
                         (padrao (%programa-padrao renderizador))
                         (normais (%programa-de-normais renderizador))
                         (profundidade (%programa-de-profundidade renderizador))
                         (t (%programa-basico renderizador))))
         (estado (%preparar-geometria renderizador (flegrea:geometry malha)
                                      (or padrao normais))))
    (unless (or personalizado padrao (typep material 'flegrea:mesh-basic-material)
                (typep material 'flegrea:mesh-normal-material)
                (typep material 'flegrea:mesh-depth-material)
                (typep material 'flegrea:line-material) (typep material 'flegrea:points-material)
                (typep material 'flegrea:sprite-material))
      (error 'renderer-error :message "O tipo de material da malha não é suportado."))
    (%configurar-faces material)
    (gl:use-program programa)
    (%uniforme-matriz programa "matrizModelo" (flegrea:matrix-world malha) 4)
    (%uniforme-matriz programa "matrizVisao" (flegrea:view-matrix camera) 4)
    (%uniforme-matriz programa "matrizProjecao" (flegrea:projection-matrix camera) 4)
    ;; O contrato público de shader usa nomes ingleses estáveis.
    (%uniforme-matriz programa "modelMatrix" (flegrea:matrix-world malha) 4)
    (%uniforme-matriz programa "viewMatrix" (flegrea:view-matrix camera) 4)
    (%uniforme-matriz programa "projectionMatrix" (flegrea:projection-matrix camera) 4)
    (let ((*unidade-de-textura* 0))
      (if personalizado
          (progn
          (%uniforme-cor programa "posicaoCamera" (%posicao-mundial camera))
          (%uniforme-cor programa "cameraPosition" (%posicao-mundial camera))
          (%uniforme-matriz programa "normalMatrix"
                            (flegrea:set-normal-matrix3 (flegrea:make-matrix3)
                                                        (flegrea:matrix-world malha)) 3)
          (maphash (lambda (nome valor)
                     (%enviar-uniforme-personalizado renderizador programa nome valor))
                   (flegrea:uniforms material)))
          (progn
          (%uniforme-cor programa "corMaterial" (flegrea:color material))
          (gl:uniformi (gl:get-uniform-location programa "usaCores") (if (flegrea:vertex-colors material) 1 0))
          (gl:uniformi (gl:get-uniform-location programa "usaCoresInstancia")
                       (if (and (typep malha 'flegrea:instanced-mesh)
                                (flegrea:instance-colors malha))
                           1 0))
          (gl:uniformf (gl:get-uniform-location programa "opacidade")
                       (coerce (flegrea:opacity material) 'single-float))
          (gl:uniformf (gl:get-uniform-location programa "testeAlfa")
                       (coerce (if (and (eq (flegrea:alpha-mode material) :mask)
                                        (zerop (flegrea:alpha-test material)))
                                   0.5f0 (flegrea:alpha-test material)) 'single-float))
          (%ligar-mapa-opcional renderizador programa (flegrea:base-color-map material)
                                "mapaBase" "usaMapaBase")
          (%enviar-transformacao-uv programa (%textura-de-referencia-uv material))
          (when normais
            (%uniforme-matriz programa "matrizNormal"
                              (flegrea:set-normal-matrix3 (flegrea:make-matrix3)
                                                          (flegrea:matrix-world malha)) 3))
          (when padrao
            (let ((normal (flegrea:set-normal-matrix3 (flegrea:make-matrix3) (flegrea:matrix-world malha))))
              (%uniforme-matriz programa "matrizNormal" normal 3))
            (%uniforme-cor programa "corEmissiva" (flegrea:emissive material))
            (gl:uniformf (gl:get-uniform-location programa "intensidadeEmissiva")
                         (flegrea:emissive-intensity material))
            (gl:uniformf (gl:get-uniform-location programa "escalaNormal")
                         (flegrea:x (flegrea:normal-scale material))
                         (flegrea:y (flegrea:normal-scale material)))
            (gl:uniformf (gl:get-uniform-location programa "forcaOclusao")
                         (flegrea:occlusion-strength material))
            (gl:uniformf (gl:get-uniform-location programa "rugosidade") (flegrea:roughness material))
            (gl:uniformf (gl:get-uniform-location programa "metalicidade") (flegrea:metalness material))
            (gl:uniformf (gl:get-uniform-location programa "exposicao")
                         (coerce (flegrea:exposure renderizador) 'single-float))
            (gl:uniformi (gl:get-uniform-location programa "mapeamentoDeTom")
                         (case (flegrea:tone-mapping renderizador) (:reinhard 1) (:aces 2) (otherwise 0)))
            (gl:uniformi (gl:get-uniform-location programa "saidaSRGB")
                         (if (eq (flegrea:output-color-space renderizador) :srgb) 1 0))
            (%ligar-mapa-opcional renderizador programa
                                  (flegrea:metallic-roughness-map material)
                                  "mapaMetalicoRugoso" "usaMapaMetalicoRugoso")
            (%ligar-mapa-opcional renderizador programa (flegrea:emissive-map material)
                                  "mapaEmissivo" "usaMapaEmissivo")
            (%ligar-mapa-opcional renderizador programa (flegrea:occlusion-map material)
                                  "mapaOclusao" "usaMapaOclusao")
            (%ligar-mapa-opcional renderizador programa (flegrea:opacity-map material)
                                  "mapaOpacidade" "usaMapaOpacidade")
            (%ligar-mapa-opcional renderizador programa (flegrea:normal-map material)
                                  "mapaNormal" "usaMapaNormal")
            (let ((sombra (%sombra-ativa renderizador)))
              (gl:uniformi (gl:get-uniform-location programa "recebeSombra")
                           (if (flegrea:receive-shadow malha) 1 0))
              (gl:uniformi (gl:get-uniform-location programa "usaSombra") (if sombra 1 0))
              (gl:uniformi (gl:get-uniform-location programa "tipoSombra")
                           (if sombra
                               (if (typep (first sombra) 'flegrea:spot-light) 2 1)
                               0))
              (if sombra
                  (destructuring-bind (luz configuracao estado-sombra) sombra
                    (declare (ignore luz))
                    (%uniforme-matriz programa "matrizSombra" (%matriz-sombra estado-sombra) 4)
                    (gl:uniformf (gl:get-uniform-location programa "deslocamentoSombra")
                                 (coerce (flegrea:shadow-bias configuracao) 'single-float))
                    (gl:uniformf (gl:get-uniform-location programa "deslocamentoNormalSombra")
                                 (coerce (flegrea:shadow-normal-bias configuracao) 'single-float))
                    (let ((unidade *unidade-de-textura*))
                      (incf *unidade-de-textura*)
                      (gl:active-texture (intern (format nil "TEXTURE~D" unidade) :keyword))
                      (gl:bind-texture :texture-2d (%textura-sombra estado-sombra))
                      (gl:uniformi (gl:get-uniform-location programa "mapaSombra") unidade)))
                  (progn
                    (%uniforme-matriz programa "matrizSombra" (flegrea:make-matrix4) 4)
                    (gl:uniformf (gl:get-uniform-location programa "deslocamentoNormalSombra") 0.0f0))))
            (let ((fisico (typep material 'flegrea:mesh-physical-material)))
              (gl:uniformi (gl:get-uniform-location programa "materialFisico") (if fisico 1 0))
              (%ligar-mapa-opcional renderizador programa
                                    (and fisico (flegrea:clearcoat-map material))
                                    "mapaVerniz" "usaMapaVerniz")
              (%ligar-mapa-opcional renderizador programa
                                    (and fisico (flegrea:clearcoat-normal-map material))
                                    "mapaNormalVerniz" "usaMapaNormalVerniz")
              (%ligar-mapa-opcional renderizador programa
                                    (and fisico (flegrea:clearcoat-roughness-map material))
                                    "mapaRugosidadeVerniz" "usaMapaRugosidadeVerniz")
              (%ligar-mapa-opcional renderizador programa
                                    (and fisico (flegrea:transmission-map material))
                                    "mapaTransmissao" "usaMapaTransmissao")
              (%ligar-mapa-opcional renderizador programa
                                    (and fisico (flegrea:thickness-map material))
                                    "mapaEspessura" "usaMapaEspessura")
              (when fisico
                (gl:uniformf (gl:get-uniform-location programa "verniz")
                             (flegrea:clearcoat material))
                (gl:uniformf (gl:get-uniform-location programa "rugosidadeVerniz")
                             (flegrea:clearcoat-roughness material))
                (gl:uniformf (gl:get-uniform-location programa "transmissao")
                             (flegrea:transmission material))
                (gl:uniformf (gl:get-uniform-location programa "espessura")
                             (flegrea:thickness material))
                (gl:uniformf (gl:get-uniform-location programa "indiceRefracao")
                             (flegrea:ior material))
                (%uniforme-cor programa "corAtenuacao"
                               (flegrea:convert-color (flegrea:attenuation-color material) :linear))
                (gl:uniformf (gl:get-uniform-location programa "distanciaAtenuacao")
                             (coerce (flegrea:attenuation-distance material) 'single-float))
                (let ((captura (%textura-de-transmissao renderizador)))
                  (gl:uniformi (gl:get-uniform-location programa "usaCapturaOpaca")
                               (if captura 1 0))
                  (when captura
                    (let ((unidade *unidade-de-textura*))
                      (incf *unidade-de-textura*)
                      (gl:active-texture (intern (format nil "TEXTURE~D" unidade) :keyword))
                      (gl:bind-texture :texture-2d captura)
                      (gl:uniformi (gl:get-uniform-location programa "capturaOpaca") unidade))))
                (gl:uniformf (gl:get-uniform-location programa "tamanhoViewport")
                             (coerce (%largura-de-renderizacao renderizador) 'single-float)
                             (coerce (%altura-de-renderizacao renderizador) 'single-float))))
            (%enviar-luzes programa cena camera)))))
    (gl:bind-vertex-array (%vao-gpu estado))
    (let* ((modo (cond ((typep malha 'flegrea:line-segments) :lines)
                       ((typep malha 'flegrea:line) :line-strip)
                       ((typep malha 'flegrea:points) :points)
                       (t (flegrea:primitive-mode (flegrea:geometry malha)))))
           (instancias (%preparar-instancias estado malha)))
      (when (typep material 'flegrea:line-material)
        (gl:line-width (flegrea:line-width material)))
      (when (typep material 'flegrea:points-material)
        (gl:point-size (flegrea:point-size material)))
      (gl:uniformi (gl:get-uniform-location programa "usaInstancias")
                   (if (typep malha 'flegrea:instanced-mesh) 1 0))
      (multiple-value-bind (inicio quantidade)
          (%intervalo-de-desenho (flegrea:geometry malha) grupo (%quantidade-gpu estado))
        (when (plusp quantidade)
          (if (%indexada-gpu estado)
              (if (> instancias 1)
                  (gl:draw-elements-instanced modo (gl:make-null-gl-array :unsigned-int)
                                              instancias :count quantidade :offset (* inicio 4))
                  (gl:draw-elements modo (gl:make-null-gl-array :unsigned-int)
                                    :count quantidade :offset (* inicio 4)))
              (if (> instancias 1)
                  (gl:draw-arrays-instanced modo inicio quantidade instancias)
                  (gl:draw-arrays modo inicio quantidade))))))
    (gl:bind-vertex-array 0)))

(defun %garantir-geometria-de-sprite (renderizador)
  (or (%geometria-de-sprite renderizador)
      (setf (%geometria-de-sprite renderizador)
            (flegrea:make-plane-geometry :width 1.0f0 :height 1.0f0))))

(defun %matriz-de-billboard (sprite camera)
  (let* ((resultado (flegrea:make-matrix4))
         (saida (flegrea:elements resultado))
         (camera-m (flegrea:elements (flegrea:matrix-world camera)))
         (sprite-m (flegrea:elements (flegrea:matrix-world sprite)))
         (escala (flegrea:scale sprite)))
    (setf (aref saida 0) (* (aref camera-m 0) (flegrea:x escala))
          (aref saida 1) (* (aref camera-m 1) (flegrea:x escala))
          (aref saida 2) (* (aref camera-m 2) (flegrea:x escala))
          (aref saida 4) (* (aref camera-m 4) (flegrea:y escala))
          (aref saida 5) (* (aref camera-m 5) (flegrea:y escala))
          (aref saida 6) (* (aref camera-m 6) (flegrea:y escala))
          (aref saida 8) (aref camera-m 8)
          (aref saida 9) (aref camera-m 9)
          (aref saida 10) (aref camera-m 10)
          (aref saida 12) (aref sprite-m 12)
          (aref saida 13) (aref sprite-m 13)
          (aref saida 14) (aref sprite-m 14))
    resultado))

(defun %desenhar-sprite (renderizador sprite cena camera)
  (let ((substituto (flegrea:make-mesh (%garantir-geometria-de-sprite renderizador)
                                        (flegrea:material sprite))))
    (flegrea:copy-from (flegrea:matrix-world substituto) (%matriz-de-billboard sprite camera))
    (setf (flegrea:frustum-culled substituto) nil)
    (%desenhar-malha renderizador substituto cena camera)))

(defun %renderizar-sem-protecao (renderizador cena camera)
  "Renderiza uma cena com uma câmera no contexto proprietário."
  (%assertar-thread renderizador)
  (glfw:make-context-current (%janela-renderizador renderizador))
  (destructuring-bind (largura altura) (glfw:get-framebuffer-size (%janela-renderizador renderizador))
    (setf (renderer-width renderizador) largura (renderer-height renderizador) altura)
    (gl:viewport 0 0 (%largura-de-renderizacao renderizador)
                   (%altura-de-renderizacao renderizador)))
  (flegrea:update-matrix-world cena t)
  ;; Uma câmera externa à cena também precisa ter a matriz mundial atualizada.
  (unless (or (eq camera cena) (flegrea:parent camera)) (flegrea:update-matrix-world camera t))
  (%renderizar-shadow-map renderizador cena)
  (let ((cor (%cor-limpeza renderizador)))
    (gl:clear-color (flegrea:color-r cor) (flegrea:color-g cor) (flegrea:color-b cor) 1.0f0))
  (gl:depth-mask t)
  (gl:clear :color-buffer-bit :depth-buffer-bit)
  (let* ((estatisticas (flegrea:renderer-stats renderizador))
         (lista (flegrea:build-render-list cena camera estatisticas)))
    (setf (flegrea:draw-calls estatisticas) 0
          (flegrea:triangles-rendered estatisticas) 0)
    (labels ((desenhar-itens (itens)
               (dolist (item itens)
                 (let ((objeto (flegrea::%objeto-do-item item))
                       (material-do-item (flegrea::%material-do-item item)))
                   (when (typep objeto '(or flegrea:mesh flegrea:line flegrea:points flegrea:sprite))
                     (let ((material-original (flegrea:material objeto)))
                       (unwind-protect
                            (progn
                              (setf (flegrea:material objeto) material-do-item)
                              (if (typep objeto 'flegrea:sprite)
                                  (%desenhar-sprite renderizador objeto cena camera)
                                  (%desenhar-malha renderizador objeto cena camera
                                                   (flegrea::%grupo-do-item item)))
                              (incf (flegrea:draw-calls estatisticas)))
                         (setf (flegrea:material objeto) material-original))))))))
      (desenhar-itens (flegrea:opaque-items lista))
      (when (find-if (lambda (item)
                       (%material-transmissivo-p (flegrea::%material-do-item item)))
                     (flegrea:transparent-items lista))
        (%capturar-opacos renderizador (%largura-de-renderizacao renderizador)
                         (%altura-de-renderizacao renderizador)))
      (desenhar-itens (flegrea:transparent-items lista))))
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
  (if (typep renderizador 'flegrea:input-state)
      (not (null (gethash tecla (flegrea::%teclas-atuais renderizador))))
      (float-features:with-float-traps-masked t
        (%assertar-thread renderizador)
        (not (null (member (glfw:get-key tecla (%janela-renderizador renderizador))
                           '(:press :repeat)))))))

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

(defun flegrea:add-animation-mixer (renderer mixer)
  "Registra um mixer para atualização automática no loop do renderer."
  (check-type mixer flegrea:animation-mixer)
  (pushnew mixer (%mixers-do-renderizador renderer) :test #'eq)
  renderer)

(defun flegrea:remove-animation-mixer (renderer mixer)
  "Remove um mixer da atualização automática."
  (setf (%mixers-do-renderizador renderer)
        (remove mixer (%mixers-do-renderizador renderer) :test #'eq))
  renderer)

(defun flegrea:add-controls (renderer controls)
  "Registra controles para atualização automática no loop do renderer."
  (check-type controls flegrea:orbit-controls)
  (pushnew controls (%controles-do-renderizador renderer) :test #'eq)
  renderer)

(defun flegrea:remove-controls (renderer controls)
  "Remove controles da atualização automática."
  (setf (%controles-do-renderizador renderer)
        (remove controls (%controles-do-renderizador renderer) :test #'eq))
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
             (glfw:poll-events)
             (flegrea:poll-input (flegrea:renderer-input renderer))
             (flegrea:drain-loading-manager (flegrea:default-loading-manager))
             (flegrea.meta::%drenar-hot-reloads)
             (flegrea:traverse scene (lambda (objeto) (flegrea:before-update objeto delta tempo)))
             (dolist (controles (reverse (%controles-do-renderizador renderer)))
               (flegrea:controls-update controles delta))
             (dolist (mixer (reverse (%mixers-do-renderizador renderer)))
               (flegrea:mixer-update mixer delta))
             (flegrea:traverse scene (lambda (objeto) (flegrea:update objeto delta tempo)))
             (when callback (funcall callback delta tempo))
             (flegrea:traverse scene (lambda (objeto) (flegrea:after-update objeto delta tempo)))
             (flegrea:traverse scene (lambda (objeto)
                                       (flegrea:before-render objeto renderer scene camera)))
             (render renderer scene camera)
             (flegrea:traverse scene (lambda (objeto)
                                       (flegrea:after-render objeto renderer scene camera)))
             (glfw:swap-buffers (%janela-renderizador renderer))
             (flegrea::%finalizar-frame-de-entrada (flegrea:renderer-input renderer))
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
    (let ((texturas nil))
      (maphash (lambda (textura identificador)
                 (declare (ignore textura))
                 (push identificador texturas))
               (%cache-texturas renderer))
      (when texturas (gl:delete-textures (coerce texturas 'vector)))
      (clrhash (%cache-texturas renderer)))
    (when (%textura-de-transmissao renderer)
      (gl:delete-texture (%textura-de-transmissao renderer))
      (setf (%textura-de-transmissao renderer) nil))
    (maphash (lambda (configuracao estado)
               (declare (ignore configuracao))
               (%descartar-sombra-gpu estado))
             (%cache-de-sombras renderer))
    (clrhash (%cache-de-sombras renderer))
    (gl:delete-program (%programa-basico renderer))
    (gl:delete-program (%programa-padrao renderer))
    (gl:delete-program (%programa-de-sombra renderer))
    (gl:delete-program (%programa-de-normais renderer))
    (gl:delete-program (%programa-de-profundidade renderer))
    (when (%geometria-de-sprite renderer)
      (flegrea:dispose (%geometria-de-sprite renderer))
      (setf (%geometria-de-sprite renderer) nil))
    (glfw:destroy-window (%janela-renderizador renderer))
    (setf (%descartado renderer) t (%executando renderer) nil)
    (bt:with-lock-held (*trava-glfw*)
      (decf *usuarios-glfw*)
      (when (zerop *usuarios-glfw*) (glfw:terminate))))
  renderer)

(defmethod dispose ((renderer renderer))
  "Libera programas, buffers, contexto e janela de forma idempotente."
  (float-features:with-float-traps-masked t
    (%descartar-sem-protecao renderer))
  (call-next-method))
