# Flegrea 1.5

Version 1.5 is a breaking, metagraph-first redesign. Declarative data is canonical; CLOS objects are executable instances. Stable IDs allow identity-preserving commits.

Systems: flegrea/core, assets, renderer, animation, controls, postprocessing, and gltf.

Frame order: input; jobs/hot reload; before-update; controls; mixers; bindings; user callback; after-update; matrices/culling/lists; before-render; render/composer; after-render; swap. User code runs after bindings and wins within a frame.

Geometry, materials, textures, assets, targets, and renderers have idempotent dispose. OpenGL objects must be released on their owner thread. Quality accepts :low, :medium, and :high.
