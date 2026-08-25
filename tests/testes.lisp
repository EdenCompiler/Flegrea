(defpackage #:flegrea.tests
  (:use #:cl #:fiveam)
  (:shadowing-import-from #:flegrea #:position)
  (:export #:run-tests))

(in-package #:flegrea.tests)

(def-suite conjunto-flegrea
  :description "Testes da versão 1.0 de Flegrea.")
(in-suite conjunto-flegrea)

(defun perto-p (a b &optional (tolerancia 1.0e-5))
  (<= (abs (- a b)) tolerancia))

(test vetores-e-quaternion
  (let ((a (flegrea:make-vector3 1 2 3))
        (b (flegrea:make-vector3 3 2 1)))
    (is (eq a (flegrea:add a b)))
    (is (flegrea:equals a (flegrea:make-vector3 4 4 4)))
    (is (= 24.0f0 (flegrea:dot a b)))
    (is (flegrea:equals (flegrea:cross (flegrea:make-vector3 1 0 0)
                                      (flegrea:make-vector3 0 1 0))
                        (flegrea:make-vector3 0 0 1)))
    (is (flegrea:equals (flegrea:normalize (flegrea:make-vector3))
                        (flegrea:make-vector3))))
  (let* ((angulos (flegrea:make-euler 0.2 0.4 -0.1 :zyx))
         (giro (flegrea:set-from-euler (flegrea:make-quaternion) angulos))
         (retorno (flegrea:set-from-quaternion (flegrea:make-euler 0 0 0 :zyx) giro)))
    (is (flegrea:equals angulos retorno 1.0e-4))))

(test matrizes
  (let* ((matriz (flegrea:set-translation-matrix4 (flegrea:make-matrix4) 2 3 4))
         (inversa (flegrea:matrix-invert (flegrea:clone matriz)))
         (produto (flegrea:matrix-multiply (flegrea:clone matriz) inversa)))
    (is (flegrea:equals produto (flegrea:make-matrix4) 1.0e-5))
    (is (flegrea:equals (flegrea:apply-matrix4 (flegrea:make-vector3 1 1 1) matriz)
                        (flegrea:make-vector3 3 4 5))))
  (signals flegrea:validation-error
    (flegrea:matrix-invert (flegrea:make-matrix4 (make-array 16 :initial-element 0.0f0)))))

(test composicao
  (let* ((posicao (flegrea:make-vector3 1 2 3))
         (giro (flegrea:set-from-euler (flegrea:make-quaternion)
                                      (flegrea:make-euler 0.2 0.3 0.4)))
         (escala (flegrea:make-vector3 2 3 4))
         (matriz (flegrea:compose-matrix4 (flegrea:make-matrix4) posicao giro escala))
         (posicao-retorno (flegrea:make-vector3))
         (giro-retorno (flegrea:make-quaternion))
         (escala-retorno (flegrea:make-vector3)))
    (flegrea:decompose-matrix4 matriz posicao-retorno giro-retorno escala-retorno)
    (is (flegrea:equals posicao posicao-retorno))
    (is (flegrea:equals escala escala-retorno))
    (is (perto-p 1.0f0 (abs (flegrea:dot giro giro-retorno)) 1.0e-4))))

(test grafo-de-cena
  (let ((raiz (flegrea:make-scene)) (grupo (flegrea:make-group)) (filho (flegrea:make-object-3d)))
    (flegrea:add-child raiz grupo)
    (flegrea:add-child grupo filho)
    (signals flegrea:validation-error (flegrea:add-child filho raiz))
    (flegrea:set-position grupo 1 0 0)
    (flegrea:set-position filho 0 2 0)
    (flegrea:update-matrix-world raiz)
    (let ((dados (flegrea:elements (flegrea:matrix-world filho))))
      (is (perto-p 1.0f0 (aref dados 12)))
      (is (perto-p 2.0f0 (aref dados 13))))))

(test geometrias
  (let ((caixa (flegrea:make-box-geometry))
        (esfera (flegrea:make-sphere-geometry :width-segments 8 :height-segments 4))
        (plano (flegrea:make-plane-geometry :width-segments 2 :height-segments 3)))
    (is (= 72 (length (flegrea:attribute-array (flegrea:get-attribute caixa :position)))))
    (is (= 36 (length (flegrea:attribute-array (flegrea:index caixa)))))
    (is (= (* 9 5 3) (length (flegrea:attribute-array (flegrea:get-attribute esfera :position)))))
    (is (= (* 3 4 3) (length (flegrea:attribute-array (flegrea:get-attribute plano :position))))))
  (let ((customizada (flegrea:make-buffer-geometry)))
    (flegrea:set-attribute customizada :position
                           (flegrea:make-buffer-attribute '(0 0 0 1 0 0 0 1 0) 3))
    (flegrea:compute-vertex-normals customizada)
    (is (flegrea:get-attribute customizada :normal))))

(flegrea:define-scene criar-cena-de-teste
  (flegrea:scene
   :id :raiz
   :active-camera (flegrea:ref :camera)
   :resources
   ((flegrea:box-geometry :id :geometria)
    (flegrea:mesh-standard-material :id :material
                                    :color (flegrea:vector3 0.8 0.2 0.1)))
   :children
   ((flegrea:perspective-camera :id :camera
                                :position (flegrea:vector3 0 0 5))
    (flegrea:mesh :id :cubo
                  :geometry (flegrea:ref :geometria)
                  :material (flegrea:ref :material)
                  :rotation (flegrea:euler (flegrea:bind (* :time 0.5)) 0 0 :xyz)))))

(test metagrafo-e-bindings
  (let* ((instancia (criar-cena-de-teste))
         (cubo (flegrea:find-object instancia :cubo)))
    (flegrea:update-scene instancia 2.0 0.016)
    (is (perto-p 1.0f0 (flegrea:x (flegrea:rotation cubo))))
    (is (typep (flegrea:instance-camera instancia) 'flegrea:perspective-camera))))

(test commit-preserva-identidade
  (let* ((instancia (criar-cena-de-teste))
         (cubo (flegrea:find-object instancia :cubo))
         (descricao (flegrea:scene-description 'criar-cena-de-teste))
         (no (flegrea:find-node descricao :cubo)))
    (setf (flegrea:node-property no :position) '( :vector3 2 0 0))
    (flegrea:commit-scene instancia descricao)
    (is (eq cubo (flegrea:find-object instancia :cubo)))
    (is (perto-p 2.0f0 (flegrea:x (flegrea:position cubo))))))

(test persistencia
  (let* ((descricao (flegrea:scene-description 'criar-cena-de-teste))
         (texto (with-output-to-string (fluxo) (flegrea:write-scene descricao fluxo)))
         (retorno (with-input-from-string (fluxo texto) (flegrea:read-scene fluxo))))
    (is (flegrea:find-node retorno :cubo))
    (is (search "SCENE" texto))))

(test material-programavel
  (let ((material
          (flegrea:make-shader-material
           :vertex-shader "#version 330 core
void main(){gl_Position=vec4(0.0);}"
           :fragment-shader "#version 330 core
out vec4 corSaida;void main(){corSaida=vec4(1.0);}"
           :uniforms '("tempo" 0.0 "cor" nil)
           :side :double)))
    (is (typep material 'flegrea:shader-material))
    (is (zerop (flegrea:uniform material "tempo")))
    (is (eq material (flegrea:set-uniform material "tempo" 3.5f0)))
    (is (perto-p 3.5f0 (flegrea:uniform material "tempo")))
    (is (eq :double (flegrea:side material)))))

(test renderer-opcional
  (when (string= (or (uiop:getenv "FLEGREA_RUN_GL_TESTS") "") "1")
    (let ((renderizador (flegrea:make-renderer :width 64 :height 64 :visible nil))
          (instancia (criar-cena-de-teste)))
      (unwind-protect
           (progn
             (flegrea:render-scene renderizador instancia)
             (let* ((cena (flegrea:make-scene))
                    (camera (flegrea:make-perspective-camera :aspect 1.0f0))
                    (geometria (flegrea:make-buffer-geometry))
                    (material
                      (flegrea:make-shader-material
                       :vertex-shader
                       "#version 330 core
layout(location=0)in vec3 posicao;uniform mat4 matrizModelo;uniform mat4 matrizVisao;uniform mat4 matrizProjecao;void main(){gl_Position=matrizProjecao*matrizVisao*matrizModelo*vec4(posicao,1.0);}"
                       :fragment-shader
                       "#version 330 core
out vec4 corSaida;uniform vec3 corTeste;void main(){corSaida=vec4(corTeste,1.0);}"
                       :uniforms (list "corTeste" (flegrea:make-vector3 0.2 0.5 0.9)))))
               (flegrea:set-attribute geometria :position
                                      (flegrea:make-buffer-attribute '(-1 -1 0 1 -1 0 0 1 0) 3))
               (flegrea:set-position camera 0 0 3)
               (flegrea:add-child cena (flegrea:make-mesh geometria material))
               (flegrea:render renderizador cena camera))
             (pass))
        (flegrea:dispose renderizador)))))

(defun run-tests ()
  "Executa os testes automatizados e sinaliza falha para o ASDF."
  (let ((resultado (run 'conjunto-flegrea)))
    (unless (results-status resultado)
      (error "Os testes de Flegrea falharam."))
    resultado))
