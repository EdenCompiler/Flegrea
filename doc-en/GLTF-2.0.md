# glTF 2.0

`load-gltf` and `load-gltf-async` use Flegrea's own parser, return `scene-asset`, and `instantiate-asset` creates independent object graphs. Select a scene with `:scene` and a `KHR_materials_variants` entry by name or index with `:variant`.

The reader covers .gltf/.glb, external and embedded PNG/JPEG images, samplers, external files, data URIs, GLB chunks, sparse/normalized/strided accessors, core modes, hierarchy, TRS/matrices, cameras, multiple primitives, and core attributes.

Modeled extensions include unlit, texture transform, punctual lights, variants, emissive strength, clearcoat, transmission, IOR, volume, and GPU instancing. Unknown required extensions reject; optional ones become warnings.

Paths escaping the asset root are rejected. Other schemes require register-uri-resolver. HTTP is not built in.
