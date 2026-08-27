;;;; Demo autocontido de cubo da DSL metagráfica de Flegrea.

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

(flegrea:define-scene criar-cubo-girando
  (flegrea:scene
   :id :raiz
   :active-camera (flegrea:ref :camera)
   :resources
   ((flegrea:box-geometry
     :id :geometria-cubo
     :width 1.7 :height 1.7 :depth 1.7
     :face-colors
     ((flegrea:color 0.95 0.18 0.22)
      (flegrea:color 0.12 0.65 0.95)
      (flegrea:color 0.22 0.85 0.42)
      (flegrea:color 0.96 0.70 0.12)
      (flegrea:color 0.64 0.30 0.92)
      (flegrea:color 0.95 0.42 0.12)))
    (flegrea:mesh-standard-material
     :id :material-cubo
     :color (flegrea:color 1 1 1)
     :roughness 0.32
     :metalness 0.18
     :vertex-colors t))
   :children
   ((flegrea:perspective-camera
     :id :camera
     :fov 48 :aspect 1.3333333 :near 0.1 :far 100
     :position (flegrea:vector3 0 0 5.2))
    (flegrea:group :id :alvo)
    (flegrea:ambient-light
     :id :luz-ambiente
     :color (flegrea:color 0.55 0.62 0.78)
     :intensity 0.22)
    (flegrea:directional-light
     :id :luz-direcional
     :color (flegrea:color 1 0.88 0.72)
     :intensity 2.4
     :target (flegrea:ref :alvo)
     :position (flegrea:vector3 3 4 5))
    (flegrea:point-light
     :id :luz-pontual
     :color (flegrea:color 0.28 0.52 1)
     :intensity 18
     :distance 12 :decay 2
     :position (flegrea:vector3 -3 -1 3))
    (flegrea:mesh
     :id :cubo
     :geometry (flegrea:ref :geometria-cubo)
     :material (flegrea:ref :material-cubo)
     :rotation
     (flegrea:euler
      (flegrea:bind (* :time 0.58))
      (flegrea:bind (* :time 0.83))
      (flegrea:bind (* :time 0.17))
      :xyz)))))

(defun executar-demo ()
  (let* ((teste-fumaca (member "--smoke" (uiop:command-line-arguments) :test #'string=))
         (renderizador (flegrea:make-renderer
                        :width 960 :height 720
                        :title "Flegrea 1.5 — Cubo metagráfico"
                        :visible (not teste-fumaca) :vsync (not teste-fumaca)
                        :clear-color (flegrea:make-color 0.018 0.022 0.04)))
         (instancia (criar-cubo-girando))
         (quadros 0))
    (unwind-protect
         (flegrea:animate-scene
          renderizador instancia
          (lambda (delta tempo)
            (declare (ignore delta tempo))
            (when (and teste-fumaca (>= (incf quadros) 2))
              (flegrea:stop-animation renderizador))))
      (flegrea:dispose renderizador))))

(handler-case
    (progn (executar-demo) (uiop:quit 0))
  (error (condicao)
    (format *error-output* "Não foi possível executar o demo: ~A~%" condicao)
    (uiop:quit 1)))
