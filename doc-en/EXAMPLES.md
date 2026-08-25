# Flegrea practical examples

## Running

From the project root:

```sh
sbcl --load demos/cubo.lisp
sbcl --load demos/oceano.lisp
```

Replace `sbcl` with `ecl` to use ECL. Both examples load Quicklisp, register the local ASDF system, create their renderer internally, and release it with `unwind-protect`.

## Metagraph cube

`demos/cubo.lisp` is the smallest complete demonstration of the 1.0 design. Its `define-scene` form declares:

- one box resource with six per-face colors;
- one metallic/roughness material using those vertex colors;
- a perspective camera;
- ambient, directional, and point lights;
- a mesh whose three Euler components are driven by time bindings.

The program only creates a renderer, calls the generated scene factory, and runs `animate-scene`. This is the recommended first example for learning the typed DSL, shared resources, references, and automatic animation updates.

## Shader ocean

`demos/oceano.lisp` reproduces the visual and interaction design of the native C ocean reference in Flegrea. It procedurally builds a continuous grid with 126,721 vertices and 756,000 indices (252,000 triangles), then places that generated buffer geometry in a runtime metagraph.

The ocean vertex shader combines four Gerstner waves with different directions, steepnesses, wavelengths, and speeds. It estimates the displaced normal from two nearby surface evaluations. The fragment shader combines diffuse light, Schlick-style Fresnel reflection, narrow and broad solar highlights, depth color, procedural breakup noise, and crest/slope foam.

A second programmable material draws a full-screen procedural sky at far depth. Its layered noise creates moving clouds; a low-horizon gradient, sun disk, and glow match the water lighting direction. Both materials receive elapsed time through metagraph bindings.

Controls:

| Key | Action |
| --- | --- |
| W / S | Move forward / backward along Z |
| A / D | Move left / right along X |
| Escape | Close the window |

The camera stays close to the surface and receives a subtle vertical oscillation. This is an artistic real-time ocean, not a fluid solver: waves superpose analytically, do not break dynamically, and do not interact with geometry.

Run two hidden frames for a shader and GPU smoke test:

```sh
sbcl --load demos/oceano.lisp -- --smoke
```

The smoke path exercises metagraph parsing, large custom buffers, time-bound uniforms, two custom program compilations, indexed drawing, the animation loop, and renderer disposal.
