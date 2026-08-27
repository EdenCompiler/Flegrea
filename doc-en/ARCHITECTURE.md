# Flegrea architecture

## Purpose and module shape

Flegrea separates a declarative metagraph from the live CLOS scene graph. The metagraph is durable program data: it can be inspected, rewritten, serialized, compared, and committed. The live graph owns mutable transforms and renderable resources.

The ASDF graph is split into `flegrea/core`, `flegrea/assets`, `flegrea/animation`, `flegrea/controls`, `flegrea/renderer`, `flegrea/postprocessing`, and `flegrea/gltf`. The umbrella `flegrea` system loads them all. Core has no windowing or image-decoder dependency; assets extends its metagraph resource factory without introducing a circular dependency.

Only `flegrea` is a public API package. The subsystem packages organize implementation dependencies without requiring callers to assemble several packages.

## Runtime data flow

```text
typed S-expression
        |
        v
   meta-scene  ---- transform/read/write ----> meta-scene
        |
 instantiate-scene
        v
  scene-instance -- update-scene --> live CLOS graph
        |                                  |
        +--------- commit-scene -----------+
                                           |
                                      render-scene
                                           v
                              GLFW window + OpenGL context
```

`define-scene` stores the parsed description and creates a Lisp factory. The factory returns a `scene-instance` containing the root scene, active camera, description, and ID-to-object mapping. `animate-scene` evaluates bindings and renders that instance every frame.

## Coordinates and transforms

Flegrea uses right-handed local coordinates and OpenGL clip-space conventions. Cameras look along local negative Z. Matrices are stored in OpenGL-compatible column-major order.

Each `object-3d` owns mutable `position`, `rotation`, and `scale` values plus `matrix` and `matrix-world`. `update-matrix-world` composes parent and local matrices recursively. Camera view matrices are the inverse of their world matrices.

## Ownership and lifetime

CPU geometry, materials, and scene objects are ordinary Lisp objects. The renderer lazily creates VAOs, vertex/index/instance buffers, textures, shadow targets, and custom shader programs, caching them by object identity. `dispose` releases the entire renderer-owned GPU cache, built-in programs, context, and window.

Use `unwind-protect` around every renderer lifetime. `dispose` is idempotent, but using a disposed renderer or using it from another thread signals `renderer-error`.

## Extension points

`register-node-class` adds a typed metagraph node contract. Extension code can specialize `validate-node`, `instantiate-node`, `update-node`, and `dispose-node`. Stable node IDs allow `commit-scene` to preserve compatible live objects while replacing nodes whose declared type changes, or instanced meshes whose fixed instance count changes.

The renderer currently recognizes the built-in geometry attribute semantics and material classes. Arbitrary visual effects are supported through `shader-material`; adding an entirely new renderer resource category still requires an extension to the renderer implementation.

## Boundaries

The 1.5 renderer is a compact forward renderer with stable opaque/transparent queues, frustum culling, textures, instancing, glTF import, and an explicit post-processing pipeline. Physics, audio, editor services, cascaded shadows, and advanced image-based lighting remain outside this release.
