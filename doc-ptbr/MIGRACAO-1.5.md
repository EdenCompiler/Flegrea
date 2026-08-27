# Migração da 1.0 para a 1.5

1. Troque cores em vector3 por make-color ou (color r g b).
2. Revise make-renderer: qualidade, antialias, exposição e tone mapping são explícitos.
3. Grave cenas novamente; .fscene usa :flegrea-scene e :version 1.
4. Declare (:parameters ...) e (:state ...) em define-scene.
5. Registre bindings com register-binding-function.
6. Chame dispose em recursos e no renderer.

Não há sistema de compatibilidade 1.0.
