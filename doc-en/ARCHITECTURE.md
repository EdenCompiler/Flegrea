# Flegrea architecture

## Purpose and module shape

Flegrea separates a declarative metagraph from the live CLOS scene graph. The metagraph is durable program data: it can be inspected, rewritten, serialized, compared, and committed. The live graph owns mutable transforms and renderable resources.

The serial ASDF load order is:

1. `package.lisp` defines the public package and private subsystem packages;
2. `matematica.lisp` provides independent numerical primitives;
3. `nucleo.lisp` implements the scene hierarchy and cameras;
4. `geometrias.lisp` provides CPU-side vertex/index data;
5. `materiais.lisp` defines materials and lights;
6. `metagrafo.lisp` parses, validates, instantiates, updates, and persists descriptions;
7. `renderizador.lisp` owns GLFW, OpenGL, GPU caches, drawing, input, and loops.

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

CPU geometry, materials, and scene objects are ordinary Lisp objects. The renderer lazily creates VAOs, vertex buffers, index buffers, and custom shader programs, caching them by object identity. `dispose` releases the entire renderer-owned GPU cache, built-in programs, context, and window.

Use `unwind-protect` around every renderer lifetime. `dispose` is idempotent, but using a disposed renderer or using it from another thread signals `renderer-error`.

## Extension points

`register-node-class` adds a typed metagraph node contract. Extension code can specialize `validate-node`, `instantiate-node`, `update-node`, and `dispose-node`. Stable node IDs allow `commit-scene` to preserve compatible live objects while replacing nodes whose declared type changes.

The renderer currently recognizes the built-in geometry attribute semantics and material classes. Arbitrary visual effects are supported through `shader-material`; adding an entirely new renderer resource category still requires an extension to the renderer implementation.

## Boundaries

The 1.0 renderer is a compact forward renderer. It deliberately omits render queues, transparency sorting, textures, shadows, instancing, culling, model import, post-processing, physics, audio, and editor services. These boundaries keep the first metagraph and native-window contract small enough to validate across Lisp implementations.
