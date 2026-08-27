# Migrating from 1.0 to 1.5

1. Replace vector3 colors with make-color or (color r g b).
2. Review make-renderer: quality, antialiasing, exposure, and tone mapping are explicit.
3. Re-save scenes; .fscene uses :flegrea-scene and :version 1.
4. Declare (:parameters ...) and (:state ...) in define-scene.
5. Register binding calls with register-binding-function.
6. Call dispose on resources and the renderer.

There is no 1.0 compatibility system.
