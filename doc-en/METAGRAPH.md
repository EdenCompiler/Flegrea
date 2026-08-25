# Metagraph and bindings

## Why a metagraph

A direct scene graph answers “what objects exist now?” The Flegrea metagraph additionally records “what declarative program produced them?” A `meta-scene` is typed Lisp data with stable IDs. A `scene-instance` connects that data to the live scene, active camera, and instantiated object table.

This separation enables inspection, safe persistence, deterministic rebuilding, runtime rewrites, and identity-preserving structural commits.

## Scene syntax

Every node is a typed list with a unique keyword `:id`. A scene declares `:active-camera`, optional `:resources`, and `:children`:

```lisp
(flegrea:define-scene make-scene
  (flegrea:scene
   :id :root
   :active-camera (flegrea:ref :camera)
   :resources
   ((flegrea:box-geometry :id :geometry)
    (flegrea:mesh-basic-material
     :id :material :color (flegrea:vector3 0.1 0.6 1.0)))
   :children
   ((flegrea:perspective-camera
     :id :camera :position (flegrea:vector3 0 0 4))
    (flegrea:mesh
     :id :box :geometry (flegrea:ref :geometry)
     :material (flegrea:ref :material)))))
```

Built-in object node types are `scene`, `group`, `mesh`, both camera types, and all three light types. Resource node types are the four geometry types and three material types. `ref` connects IDs and is validated before instantiation.

## Bindings

`bind` wraps a restricted expression evaluated by `update-scene`. The terminals are real numbers, `:time`, and `:delta`. Allowed operators are arithmetic, `sin`, `cos`, `tan`, `abs`, `min`, `max`, and `clamp`.

```lisp
:rotation (flegrea:euler
           (flegrea:bind (* :time 0.4))
           (flegrea:bind (* :time 0.7))
           0 :xyz)
```

The parser validates the expression as data; persistence never enables reader evaluation. Bindings can appear inside vector/Euler forms and custom shader uniform lists. `animate-scene` calls `update-scene` with elapsed and delta seconds before the optional user callback.

## Inspection and transformation

- `scene-description` returns an editable copy of a registered description.
- `find-node` looks up metadata by ID; `find-object` looks up the corresponding live object.
- `node-property` and its `setf` form access declared properties.
- `walk-scene` visits every node, including resources.
- `transform-scene` copies a description and applies a function to each node.

The public node readers `node-id`, `node-type`, `node-properties`, and `node-children` support tools that need a lower-level view.

## Structural commits

`commit-scene instance description` prepares and validates a replacement, then reconciles it by stable ID and declared type. Compatible objects keep their identity and receive updated state. Changed types create replacement objects. Removed nodes invoke `dispose-node`, hierarchy edges are rebuilt, mesh resource links are repaired, and the active camera is refreshed.

This is structural synchronization, not a concurrent transaction. Call it on the same application thread between frames.

## Persistence

`write-scene` writes one canonical, readable S-expression to a stream or pathname. `read-scene` reads exactly one form with `*read-eval*` disabled, then runs normal parsing and reference validation.

Shader source strings and custom buffer arrays are serializable, but large generated geometries are usually better rebuilt procedurally at startup, as `demos/oceano.lisp` does.

## Extensions

`register-node-class` records a tag, metadata class, allowed properties, bindable properties, child policy, and resource status. Specialize `validate-node`, `instantiate-node`, `update-node`, and `dispose-node` for custom behavior. Extension methods receive a context object intentionally treated as opaque in 1.0; use documented node accessors and public runtime constructors.
