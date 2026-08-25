(defsystem "flegrea"
  :description "Framework metagráfico 3D nativo para Common Lisp."
  :author "Bruno"
  :version "1.0.0"
  :serial t
  :depends-on ("alexandria" "cffi" "cl-glfw3" "cl-opengl" "bordeaux-threads"
               "float-features")
  :components ((:module "src"
                :components ((:file "package")
                             (:file "matematica")
                             (:file "nucleo")
                             (:file "geometrias")
                             (:file "materiais")
                             (:file "metagrafo")
                             (:file "renderizador"))))
  :in-order-to ((test-op (test-op "flegrea/tests"))))

(defsystem "flegrea/tests"
  :description "Testes automatizados de Flegrea."
  :serial t
  :depends-on ("flegrea" "fiveam")
  :components ((:module "tests"
                :components ((:file "testes"))))
  :perform (test-op (operacao sistema)
             (declare (ignore operacao sistema))
             (uiop:symbol-call :flegrea.tests :run-tests)))
