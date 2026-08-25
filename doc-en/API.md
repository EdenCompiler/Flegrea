# Flegrea 1.0 API guide

## Conventions and conditions

All public symbols are exported from `flegrea`. Constructors use `make-*`; mutable operations normally change and return their first object so calls can be chained. Slot accessors are ordinary CLOS generic functions and support `setf` where their class definition permits it.

The condition hierarchy starts at `flegrea-error`. Invalid data signals `validation-error`; native rendering failures signal `renderer-error`; GLSL compile or link failures signal `shader-error`. Diagnostics include the relevant constraint and, for shaders, the driver log.

## Math

| Types | Constructors | Main operations |
| --- | --- | --- |
| `vector2`, `vector3`, `vector4` | `make-vector2`, `make-vector3`, `make-vector4` | `add`, `subtract`, `dot`, `normalize`, `apply-matrix*` |
| `quaternion`, `euler` | `make-quaternion`, `make-euler` | `set-from-euler`, `set-from-quaternion`, `quaternion-multiply`, `slerp` |
| `matrix3`, `matrix4` | `make-matrix3`, `make-matrix4` | multiply, transpose, determinant, inverse, projections, compose/decompose |

Shared accessors include `x`, `y`, `z`, `w`, `elements`, and `order`. See [Math](MATH.md) for mutation rules and coordinate conventions.

## Scene graph

`object-3d` is the base class for `scene`, `group`, `mesh`, cameras, and lights. Its principal accessors are `position`, `rotation`, `scale`, `parent`, `children`, `matrix`, `matrix-world`, `visible`, and `name`.

```lisp
(let ((scene (flegrea:make-scene))
      (group (flegrea:make-group :name "pivot")))
  (flegrea:add-child scene group)
  (flegrea:set-position group 1 2 3)
  (flegrea:traverse scene #'print)
  (flegrea:update-matrix-world scene))
```

`add-child` reparents an object and rejects cycles. `remove-child` detaches it. `look-at` orients an object toward a `vector3` target. `mesh` adds `geometry` and `material` accessors.

## Cameras

Create a `perspective-camera` with `fov`, `aspect`, `near`, `far`, and `zoom`, or an `orthographic-camera` with `left`, `right`, `top`, `bottom`, `near`, `far`, and `zoom`. `update-projection-matrix` must be called after changing projection accessors directly. Metagraph updates do this automatically for dynamic perspective properties.

## Geometry

`make-box-geometry`, `make-sphere-geometry`, and `make-plane-geometry` return subclasses of `buffer-geometry`. Box geometry can receive six `face-colors`; segment counts control sphere and plane tessellation.

Custom geometry uses:

```lisp
(let ((geometry (flegrea:make-buffer-geometry)))
  (flegrea:set-attribute
   geometry :position
   (flegrea:make-buffer-attribute '(0 1 0 -1 -1 0 1 -1 0) 3))
  (flegrea:set-index geometry '(0 1 2))
  (flegrea:compute-vertex-normals geometry)
  geometry)
```

Use `attributes`, `index`, `get-attribute`, `delete-attribute`, `attribute-array`, `item-size`, `normalized`, `usage`, and `needs-update` for lower-level access. Mark `needs-update` after changing an uploaded attribute array.

## Materials and lights

`make-mesh-basic-material` is unlit. `make-mesh-standard-material` provides metallic/roughness PBR-lite shading with `color`, `roughness`, `metalness`, `emissive`, and optional vertex colors.

`make-shader-material` accepts `vertex-shader`, `fragment-shader`, `uniforms`, `side`, and `depth-write`. Use `uniform` and `set-uniform` for individual values. See [Rendering](RENDERING.md) for the shader interface.

The light constructors are `make-ambient-light`, `make-directional-light`, and `make-point-light`. Shared accessors are `color` and `intensity`. Directional lights add `target`; point lights add `distance` and `decay`.

## Renderer, loop, and input

`make-renderer` accepts `width`, `height`, `title`, `clear-color`, `vsync`, `resizable`, and `visible`. It immediately opens a window and creates the OpenGL context.

- `render renderer scene camera` draws one frame without swapping buffers.
- `render-scene renderer instance` draws one metagraph instance.
- `animate renderer scene camera &optional callback` runs the direct blocking loop.
- `animate-scene renderer instance &optional callback` also evaluates bindings each frame.
- callbacks receive `delta-time` and `elapsed-time` in seconds before drawing.
- `key-down-p` queries a GLFW key keyword without exposing GLFW objects.
- `stop-animation` ends the loop; `request-close` also marks the window for closure.
- `renderer-should-close-p` reports the native close flag.
- `dispose` releases all renderer-owned resources.

`animation-loop` is an explicit alias for `animate`. Renderer dimensions are refreshed from framebuffer size and exposed by `renderer-width` and `renderer-height`; the configured title is available through `renderer-title`.

## Metagraph

The core entry points are `define-scene`, `parse-scene`, `instantiate-scene`, `update-scene`, and `commit-scene`. Introspection uses `scene-description`, `find-node`, `find-object`, `node-property`, `walk-scene`, and `transform-scene`. Persistence uses `read-scene` and `write-scene`. See [Metagraph and bindings](METAGRAPH.md) for the complete data model.
