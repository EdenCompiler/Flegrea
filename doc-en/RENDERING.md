# Rendering

## Renderer creation

`make-renderer` initializes GLFW on first use, creates a window and OpenGL 3.3 Core context, enables depth testing, compiles built-in programs, and records the creating thread.

```lisp
(flegrea:make-renderer
 :width 1280 :height 720
 :title "Flegrea"
 :clear-color (flegrea:make-color 0.02 0.025 0.04)
 :vsync t :resizable t :visible t)
```

The clear color is sRGB with components from zero to one. Invisible renderers are useful for integration tests. The framebuffer size, not merely the logical window size, controls the viewport.

## Built-in materials

`mesh-basic-material` multiplies its color by optional per-vertex color and does not read lights.

`mesh-standard-material` is a compact metallic/roughness forward shader. It uses GGX distribution, Schlick Fresnel, Smith geometry, inverse-power attenuation, exposure, Reinhard/ACES tone mapping, and configurable output color space. A scene can contain any number of ambient lights and up to eight of each directional, point, spot, and hemisphere type per draw.

`mesh-physical-material` adds clearcoat and screen-space transmission/refraction with roughness LOD, IOR, volume thickness, and attenuation. Standard/physical shaders consume base color, metallic-roughness, normal, emissive, occlusion, opacity, clearcoat, transmission, and thickness maps. `mesh-normal-material` and `mesh-depth-material` provide diagnostics.

Directional light direction runs from its target toward the light position. Point and spot `distance` apply a smooth range cutoff when positive; `decay` controls inverse-power attenuation. The first shadow-enabled directional or spot light renders a depth map with 3×3 PCF; meshes opt in with `cast-shadow` and `receive-shadow`.

## Geometry attributes

The renderer assigns fixed shader locations:

| Attribute | Location | Shape |
| --- | ---: | --- |
| `:position` | 0 | three floats, required |
| `:normal` | 1 | three floats, required by standard material |
| `:color` | 2 | three floats; white is supplied when absent |
| `:uv` | 3 | two floats, optional |
| instance matrix | 4–7 | four `vec4` columns |
| instance color | 8 | three floats; white is supplied when absent |
| `:uv1` | 9 | two floats, optional secondary UV set |

`instanced-mesh` emits actual instanced draw calls and applies values written by `set-instance-color`. A texture selects `:uv` or `:uv1` through `uv-channel`; its repeat, offset, center, and rotation are applied by the managed shaders. All maps on one material currently share the transform selected from the base-color map, or from the first active map when no base-color map exists. Geometry groups and draw ranges restrict indexed or non-indexed draws; lines, points, and camera-facing sprites use their matching primitive/state path.

Index data uses unsigned 32-bit integers. Geometry is uploaded lazily and cached by object identity. Set an attribute's `needs-update` accessor to true after mutating its array.

## Custom shaders

`shader-material` makes GLSL programmable without exposing GLFW or raw program ownership:

```lisp
(flegrea:make-shader-material
 :vertex-shader vertex-source
 :fragment-shader fragment-source
 :uniforms (list "time" 0.0f0 "tint" (flegrea:make-vector3 1 0.4 0.2))
 :side :double
 :depth-write t)
```

If declared, these uniforms are filled automatically before user uniforms:

- `matrizModelo` — mesh world matrix;
- `matrizVisao` — camera view matrix;
- `matrizProjecao` — camera projection matrix;
- `posicaoCamera` — camera world position.

User uniform names are case-sensitive strings. Supported values are real numbers, integers, booleans/NIL, `vector2`, `vector3`, `vector4`, `color`, `matrix3`, `matrix4`, and `texture`. Use `set-uniform` each frame or place bindings inside the metagraph `:uniforms` list.

`side` accepts `:front`, `:back`, or `:double`. `depth-write` controls writing to the depth buffer; depth testing remains enabled. Programs compile lazily on first draw, are rebuilt if either source changes, and are owned by the renderer cache.

## Frame flow and state

`render` refreshes the viewport, updates world and camera matrices, clears color/depth buffers, builds stable render lists, and issues the matching triangle, line, point, sprite, or instanced draws. It does not swap buffers or poll events.

`animate` adds timing, callback, buffer swap, event polling, Escape handling, and close handling. `animate-scene` wraps the callback so metagraph bindings update first. Call `stop-animation` for a clean loop exit or `request-close` to set both the loop and native window state.

Flegrea restores culling, depth, and blending state for every drawable. Opaque items are drawn front-to-back and transparent items back-to-front, with stable render-order precedence.

`render-target` owns color and optional depth attachments and supports resizing and pixel readback. An `effect-composer` chains a `render-pass` with full-screen `shader-pass` objects; `make-fxaa-pass` supplies the built-in antialiasing pass.

## Resource lifetime

Always place `dispose` in `unwind-protect`. It deletes cached custom programs, built-in programs, VAOs, buffers, the window, and finally GLFW when the last renderer is gone. Several renderers can coexist on one thread, but resource caches are not shared between them.
