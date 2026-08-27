(defsystem "flegrea/core"
  :description "Núcleo metagráfico, matemática e grafo de cena de Flegrea."
  :author "Bruno"
  :version "1.5.0"
  :serial t
  :depends-on ("alexandria" "bordeaux-threads")
  :components ((:module "src"
                :components ((:file "package")
                             (:file "matematica")
                             (:file "recursos")
                             (:file "matematica-espacial")
                             (:file "nucleo")
                             (:file "nucleo-15")
                             (:file "geometrias")
                             (:file "geometrias-15")
                             (:file "materiais")
                             (:file "materiais-15")
                             (:file "metagrafo")
                             (:file "metagrafo-15")))))

(defsystem "flegrea/assets"
  :description "Texturas, cache e carregamento assíncrono de Flegrea."
  :author "Bruno"
  :version "1.5.0"
  :serial t
  :depends-on ("flegrea/core" "cffi" "zpng" "cl-jpeg" "chipz" "babel"
               "com.inuoe.jzon" "qbase64" "flexi-streams")
  :components ((:module "src" :components ((:file "assets")))))

(defsystem "flegrea/animation"
  :description "Clipes, trilhas, mixers e ações de Flegrea."
  :author "Bruno"
  :version "1.5.0"
  :serial t
  :depends-on ("flegrea/core")
  :components ((:module "src" :components ((:file "animacao")))))

(defsystem "flegrea/controls"
  :description "Entrada, raycasting e controles de câmera de Flegrea."
  :author "Bruno"
  :version "1.5.0"
  :serial t
  :depends-on ("flegrea/core" "flegrea/animation")
  :components ((:module "src" :components ((:file "controles")))))

(defsystem "flegrea/renderer"
  :description "Renderer OpenGL 3.3 e janela GLFW de Flegrea."
  :author "Bruno"
  :version "1.5.0"
  :serial t
  :depends-on ("flegrea/core" "flegrea/assets" "flegrea/animation" "flegrea/controls"
               "cffi" "cl-glfw3" "cl-opengl" "float-features")
  :components ((:module "src"
                :components ((:file "listas-renderizacao")
                             (:file "renderizador")
                             (:file "renderizador-15")))))

(defsystem "flegrea/postprocessing"
  :description "Alvos e composição de pós-processamento de Flegrea."
  :author "Bruno"
  :version "1.5.0"
  :serial t
  :depends-on ("flegrea/renderer")
  :components ((:module "src" :components ((:file "pos-processamento")))))

(defsystem "flegrea/gltf"
  :description "Leitor próprio glTF 2.0 e GLB de Flegrea."
  :author "Bruno"
  :version "1.5.0"
  :serial t
  :depends-on ("flegrea/assets")
  :components ((:module "src" :components ((:file "gltf")))))

(defsystem "flegrea"
  :description "Framework metagráfico 3D nativo para Common Lisp."
  :author "Bruno"
  :license "MIT"
  :version "1.5.0"
  :depends-on ("flegrea/core" "flegrea/assets" "flegrea/animation" "flegrea/controls"
               "flegrea/renderer" "flegrea/postprocessing" "flegrea/gltf")
  :in-order-to ((test-op (test-op "flegrea/tests"))))

(defsystem "flegrea/tests"
  :description "Testes automatizados de Flegrea 1.5."
  :serial t
  :depends-on ("flegrea" "fiveam")
  :components ((:module "tests"
                :components ((:file "testes"))))
  :perform (test-op (operacao sistema)
             (declare (ignore operacao sistema))
             (uiop:symbol-call :flegrea.tests :run-tests)))
