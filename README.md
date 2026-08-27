# Flegrea — Native Metagraphics for Common Lisp

> **Languages / Idiomas:** [English](#english) · [Português do Brasil](#português-do-brasil)

---

# English

Flegrea is a native 3D metagraphics framework for Common Lisp. It owns its GLFW window, OpenGL context, scene graph, and animation loop while preserving declarative scenes as typed, inspectable, transformable, and persistable Lisp data.

It provides an idiomatic CLOS API for scenes, cameras, meshes, geometry, materials, lights, animation, input, picking, post-processing, and glTF assets. Applications do not need a browser, JavaScript runtime, external canvas, or direct GLFW calls.

**Current stable release: 1.5.0** · **Author: Bruno**

![Flegrea version](https://img.shields.io/badge/Flegrea-1.5.0-blue)
![Common Lisp](https://img.shields.io/badge/Common%20Lisp-SBCL%20%7C%20ECL%20%7C%20CCL-informational)
![OpenGL](https://img.shields.io/badge/OpenGL-3.3%20Core-informational)
[![CI](https://github.com/EdenCompiler/Flegrea/actions/workflows/ci.yml/badge.svg)](https://github.com/EdenCompiler/Flegrea/actions/workflows/ci.yml)
![License](https://img.shields.io/badge/license-MIT-green)

## What 1.5 means

Flegrea 1.5 is a metagraph-first redesign. A typed declarative description is the canonical scene program, while a live CLOS graph is its executable instance. Stable IDs connect both layers and allow transactional commits to preserve compatible object identity during runtime edits.

The release also expands the renderer into a compact native engine: managed color, bounds and culling, stable render queues, instancing, physical materials, shadows, screen-space transmission, render targets, FXAA, asynchronous assets, animation, raycasting, OrbitControls, and an in-project glTF 2.0/GLB parser.

| Subsystem | 1.5 status |
| --- | --- |
| Metagraph | Typed S-expressions, stable IDs, references, parameters, state, restricted bindings, safe persistence, structural commits, and hot reload |
| Scene graph | CLOS objects, groups, meshes, cameras, lights, layers, hooks, world transforms, bounds, and resource ownership |
| Geometry | Generic buffer geometry, groups, draw ranges, boxes, spheres, planes, circles, rings, cylinders, cones, toruses, capsules, edges, and wireframes |
| Materials | Basic, metallic/roughness standard, physical, normal, depth, line, points, sprite, and custom GLSL materials |
| Rendering | OpenGL 3.3 Core, GLFW-owned window, stable opaque/transparent queues, culling, instancing, shadows, transmission, tone mapping, and statistics |
| Assets | PNG/JPEG textures, data textures, cache, jobs, cancellation, progress, URI resolvers, and render-thread draining |
| Animation and input | Clips, tracks, mixers, actions, cross-fades, input transitions, raycasting, and OrbitControls |
| glTF 2.0 | `.gltf`/`.glb`, embedded and external resources, sparse/normalized/strided accessors, materials, cameras, lights, variants, and selected extensions |
| Post-processing | Render targets, pixel readback, effect composer, render/shader passes, and FXAA |
| Implementations | CI-validated on SBCL, ECL, and CCL under Linux with Mesa software OpenGL |

In other words, **1.5 makes Flegrea a practical native metagraphics runtime while keeping the scene description available as ordinary Lisp data**.

## 1.5 release highlights

- modular ASDF systems with one public `flegrea` package;
- typed, versioned metagraph descriptions with parameters, state, references, and registered binding functions;
- identity-preserving transactional `commit-scene` and file-based hot reload;
- managed sRGB/linear color flow, exposure, Reinhard/ACES tone mapping, and configurable quality;
- frustum culling, layers, bounds, stable render order, renderer statistics, and object lifecycle hooks;
- lines, line segments, points, sprites, and GPU-instanced meshes with per-instance transforms and colors;
- physical materials with clearcoat, transmission, thickness, IOR, attenuation, normal maps, and secondary UVs;
- directional and spot shadows with PCF, bias controls, and per-object participation;
- asynchronous texture and glTF loading with cache, deduplication, progress, cancellation, and explicit URI resolvers;
- keyframe clips, weighted actions, repeat/once/ping-pong modes, time scaling, and cross-fades;
- mouse and keyboard state, mesh/instance/line/point/sprite raycasting, and damped OrbitControls;
- render targets, pixel readback, effect composition, programmable screen passes, and built-in FXAA;
- an in-project glTF 2.0/GLB reader with no dependency on a separate model-loading framework;
- two offline native demos and CI coverage for SBCL, ECL, and CCL.

## Highlights

- opens and owns a native OS window immediately from Common Lisp;
- modern shader-based OpenGL 3.3 Core renderer with no fixed-function path;
- public API names in English and idiomatic `make-*` constructors;
- mutable vector, matrix, quaternion, Euler, color, ray, plane, triangle, box, sphere, and frustum math;
- perspective and orthographic cameras;
- ambient, directional, point, spot, and hemisphere lights;
- procedural and custom buffer geometry with indexed and non-indexed drawing;
- programmable GLSL materials with typed uniform upload;
- native animation loops for direct scenes and metagraph instances;
- explicit, idempotent disposal for CPU/GPU resources;
- English and Brazilian Portuguese documentation;
- no browser, WebGL, Node, Electron, HTML, or external canvas.

## Installation

Flegrea requires a native Common Lisp implementation, ASDF, Quicklisp, GLFW 3, and an OpenGL 3.3-capable driver. The complete Lisp dependency set is recorded in [`qlfile`](qlfile).

On Debian or Ubuntu:

```sh
sudo apt update
sudo apt install sbcl ecl libglfw3 libglfw3-dev libgl1-mesa-dev libffi-dev
```

Clone the repository somewhere ASDF can find it:

```sh
git clone https://github.com/EdenCompiler/Flegrea.git
cd Flegrea
```

Load the complete framework:

```lisp
(asdf:load-asd (truename "flegrea.asd"))
(ql:quickload :flegrea)
```

Or load only the subsystem an application needs:

```lisp
(asdf:load-system :flegrea/core)
(asdf:load-system :flegrea/assets)
(asdf:load-system :flegrea/animation)
(asdf:load-system :flegrea/controls)
(asdf:load-system :flegrea/renderer)
(asdf:load-system :flegrea/postprocessing)
(asdf:load-system :flegrea/gltf)
```

The umbrella `flegrea` system loads every runtime subsystem. All public symbols remain in the `flegrea` package regardless of which ASDF system supplies their implementation.

GLFW was chosen because it is a small, focused window, context, and input layer. It keeps the native boundary compact without imposing SDL2's broader multimedia subsystem.

### Run the demos

```sh
sbcl --load demos/cubo.lisp
sbcl --load demos/oceano.lisp
```

Use `ecl` instead of `sbcl` to run the same files on ECL. Both demos locate the adjacent ASDF definition, load their dependencies, create the renderer internally, open a native window, and release their resources on exit.

Use `--smoke` for an invisible two-frame validation:

```sh
sbcl --load demos/cubo.lisp -- --smoke
sbcl --load demos/oceano.lisp -- --smoke
```

The cube demonstrates the typed metagraph, shared resources, per-face colors, physical lighting, and time bindings. The ocean renders a 126,721-vertex Gerstner-wave surface, finite-difference normals, Fresnel water, crest foam, sun glitter, and a procedural sky.

### Run the tests

```sh
sbcl --non-interactive --load ~/quicklisp/setup.lisp \
  --eval '(asdf:load-asd (truename "flegrea.asd"))' \
  --eval '(asdf:test-system :flegrea)'
```

Add hidden-window OpenGL integration tests under a display server:

```sh
FLEGREA_RUN_GL_TESTS=1 xvfb-run -a sbcl --non-interactive \
  --load ~/quicklisp/setup.lisp \
  --eval '(asdf:load-asd (truename "flegrea.asd"))' \
  --eval '(asdf:test-system :flegrea)'
```

The GitHub Actions matrix runs unit tests, Mesa/OpenGL integration, and both demo smoke paths on SBCL, ECL, and CCL.

## Metagraph-first API

A Flegrea scene can be authored as typed data instead of being assembled only through imperative object mutation:

```lisp
(flegrea:define-scene make-spinning-box
  (flegrea:scene
   :id :root
   :active-camera (flegrea:ref :camera)
   :resources
   ((flegrea:box-geometry :id :box)
    (flegrea:mesh-standard-material
     :id :surface
     :color (flegrea:color 0.15 0.55 1.0)
     :roughness 0.3
     :metalness 0.2))
   :children
   ((flegrea:perspective-camera
     :id :camera
     :aspect 1.3333333
     :position (flegrea:vector3 0 0 5))
    (flegrea:ambient-light :id :ambient :intensity 0.25)
    (flegrea:directional-light
     :id :sun
     :position (flegrea:vector3 3 4 5)
     :intensity 2.0)
    (flegrea:mesh
     :id :box-mesh
     :geometry (flegrea:ref :box)
     :material (flegrea:ref :surface)
     :rotation
     (flegrea:euler
      (flegrea:bind (* :time 0.4))
      (flegrea:bind (* :time 0.7))
      0 :xyz)))))
```

`define-scene` creates a factory returning a `scene-instance`. Its description remains available for `find-node`, `walk-scene`, `transform-scene`, `write-scene`, `read-scene`, and transactional `commit-scene` operations.

Bindings are restricted expressions over numeric values, `:time`, `:delta`, arithmetic, trigonometric functions, and explicitly registered calls. Persisted `.fscene` files are read with `*read-eval*` disabled.

## Quick tour

### Native renderer and animation loop

`make-renderer` opens the window and creates its OpenGL context. The application never handles a GLFW object:

```lisp
(let ((renderer (flegrea:make-renderer
                 :width 960
                 :height 720
                 :title "Flegrea"
                 :clear-color (flegrea:make-color 0.02 0.025 0.04)))
      (instance (make-spinning-box)))
  (unwind-protect
       (flegrea:animate-scene renderer instance)
    (flegrea:dispose renderer)))
```

`render` draws one direct scene frame. `render-scene` draws one metagraph instance. `animate` and `animate-scene` provide blocking loops with timing, input polling, asset draining, controls, mixers, callbacks, buffer swapping, and close handling.

### Direct CLOS scene graph

The declarative layer is optional when direct object construction is more appropriate:

```lisp
(let* ((scene (flegrea:make-scene))
       (camera (flegrea:make-perspective-camera :aspect (/ 16.0 9.0)))
       (mesh (flegrea:make-mesh
              (flegrea:make-box-geometry)
              (flegrea:make-mesh-basic-material
               :color (flegrea:make-color 0.2 0.7 1.0)))))
  (flegrea:set-position camera 0 0 5)
  (flegrea:add-child scene mesh)
  (flegrea:update-matrix-world scene))
```

`object-3d` supplies position, rotation, quaternion, scale, hierarchy, local/world matrices, layers, visibility, render order, bounds, lifecycle hooks, and user data.

### Custom buffer geometry

```lisp
(let ((geometry (flegrea:make-buffer-geometry)))
  (flegrea:set-attribute
   geometry :position
   (flegrea:make-buffer-attribute
    '(0 1 0  -1 -1 0  1 -1 0)
    3))
  (flegrea:set-index geometry '(0 1 2))
  (flegrea:compute-vertex-normals geometry)
  (flegrea:compute-bounding-box geometry)
  geometry)
```

Attributes upload lazily and are cached by identity. Set `needs-update` after mutating an uploaded attribute array. Geometry groups and draw ranges restrict individual indexed or non-indexed draws.

### Physical materials, textures, and lights

```lisp
(let* ((texture (flegrea:load-texture #P"assets/albedo.png"))
       (material
         (flegrea:make-mesh-physical-material
          :color (flegrea:make-color 1 1 1)
          :base-color-map texture
          :roughness 0.2
          :metalness 0.1
          :clearcoat 0.7
          :transmission 0.35
          :ior 1.45)))
  material)
```

Managed shaders support base-color, metallic/roughness, normal, emissive, occlusion, opacity, clearcoat, transmission, and thickness maps. Lights include ambient, directional, point, spot, and hemisphere types. The first shadow-enabled directional or spot light renders a PCF-filtered depth map.

### Animation, picking, and OrbitControls

Animation uses `keyframe-track`, `animation-clip`, `animation-mixer`, and `animation-action`. Actions support play, pause, stop, seek, weights, time scale, repeat, once, ping-pong, and cross-fade.

```lisp
(let* ((raycaster (flegrea:make-raycaster))
       (mouse (flegrea:make-vector2 0.0 0.0)))
  (flegrea:set-ray-from-camera raycaster mouse camera)
  (flegrea:intersect-object raycaster scene :recursive t))
```

The raycaster handles meshes, instances, points, lines, and sprites. Mesh hits include distance, world-space point and normal, interpolated UV, face index, and instance index where applicable.

```lisp
(let ((controls
        (flegrea:make-orbit-controls camera (flegrea:renderer-input renderer)
                                    :enable-damping t)))
  (flegrea:add-controls renderer controls))
```

Left-drag rotates, right- or middle-drag pans, and the wheel dollies. Distance and polar-angle limits are configurable.

### glTF 2.0 and asynchronous assets

```lisp
(let* ((asset (flegrea:load-gltf #P"assets/model.glb"))
       (model (flegrea:instantiate-asset asset :variant "Blue")))
  (flegrea:add-child scene model))
```

`load-gltf-async` returns a job managed by a `loading-manager`. Flegrea's animation loop drains completed jobs on the render thread; applications with a custom loop call `drain-loading-manager` explicitly.

The parser covers external files, data URIs, GLB chunks, sparse/normalized/strided accessors, multiple primitives, hierarchy, TRS/matrices, cameras, samplers, PNG/JPEG images, and selected material/light/instancing extensions. Paths escaping the asset root are rejected, and HTTP is not built in.

### Render targets and post-processing

```lisp
(let ((composer (flegrea:make-effect-composer renderer)))
  (unwind-protect
       (progn
         (flegrea:add-pass composer (flegrea:make-render-pass scene camera))
         (flegrea:add-pass composer (flegrea:make-fxaa-pass))
         (flegrea:composer-render composer))
    (flegrea:dispose composer)))
```

Render targets support resizing and pixel readback. Shader passes use regular `shader-material` instances, keeping custom effects inside the same program and uniform lifecycle as scene materials.

## Suggested architecture

```text
typed scene data (.fscene or Lisp forms)
                 |
                 v
            meta-scene
        / inspect | transform \
       /          |             \
read/write   commit/hot reload   bindings
       \          |             /
        \         v            /
          live CLOS scene graph
                 |
       animation / input / jobs
                 |
                 v
       stable render lists + culling
                 |
                 v
     OpenGL 3.3 renderer / composer
                 |
                 v
          native GLFW window
```

Use the metagraph as durable application data and the CLOS graph as runtime state. Keep OpenGL work, job draining, scene commits, and resource disposal on the renderer's owner thread. Use `unwind-protect` for every renderer and composer lifetime.

## Systems

| ASDF system | Purpose |
| --- | --- |
| `flegrea/core` | Math, resources, scene graph, geometry, materials, lights, and metagraph |
| `flegrea/assets` | Textures, image decoding, loading jobs, cache, and URI resolution |
| `flegrea/animation` | Tracks, clips, mixers, actions, and target registration |
| `flegrea/controls` | Input state, raycasting, and OrbitControls |
| `flegrea/renderer` | GLFW window, OpenGL 3.3 renderer, render lists, shaders, shadows, and loop |
| `flegrea/postprocessing` | Render targets, composer, render/shader passes, and FXAA |
| `flegrea/gltf` | Native glTF 2.0 and GLB parser |
| `flegrea` | Complete public runtime |
| `flegrea/tests` | FiveAM unit and optional OpenGL integration tests |

## Documentation

- [1.5 overview](doc-en/VERSION-1.5.md)
- [API guide](doc-en/API.md)
- [Building and loading](doc-en/BUILDING.md)
- [Architecture](doc-en/ARCHITECTURE.md)
- [Metagraph and bindings](doc-en/METAGRAPH.md)
- [Math](doc-en/MATH.md)
- [Rendering](doc-en/RENDERING.md)
- [glTF 2.0](doc-en/GLTF-2.0.md)
- [Examples](doc-en/EXAMPLES.md)
- [Migration from 1.0](doc-en/MIGRATION-1.5.md)
- [Changelog](doc-en/CHANGELOG.md)

Brazilian Portuguese mirrors are available under [`doc-ptbr`](doc-ptbr/).

## Platform and runtime safety

- Linux is the validated 1.5 platform; SBCL, ECL, and CCL run in CI.
- Windows and macOS remain portability targets and require their normal GLFW/OpenGL setup.
- The renderer, OpenGL calls, scene commits, and disposal must remain on the thread that created the renderer.
- Flegrea masks host floating-point traps around GLFW/OpenGL operations where native drivers may perform otherwise trapped calculations.
- GLFW is loaded dynamically through CFFI; the operating-system library must be visible to the dynamic linker.
- The first ECL build can be slow because image decoders and dependencies are compiled as portable Common Lisp.
- On Wayland systems, an XWayland session or explicit X11 environment may be needed when the installed GLFW build lacks native Wayland support.

## Current limitations

- OpenGL 3.3 Core is the only rendering backend.
- The renderer is a compact forward renderer, not a complete production renderer.
- Physical transmission is screen-space; objects outside the captured frame cannot appear in refraction.
- One shadowed directional or spot light is selected per frame; cascaded shadows and PCSS are not implemented.
- Material maps currently share one UV transform chosen from the base-color map or first active map.
- glTF skins, morph targets, animation import, Draco, Meshopt, and image-based lighting are deferred.
- Cubemaps, environment probes, bloom, physics, audio, networking, and editor tooling are outside 1.5.
- HTTP asset fetching is intentionally absent; applications may register explicit URI resolvers.
- WebGL, WebGPU, browser canvases, and JavaScript interop are non-goals.

## License

Flegrea is released under the [MIT License](LICENSE). Copyright © 2026 Bruno.

---

# Português do Brasil

Flegrea é um framework metagráfico 3D nativo para Common Lisp. Ele controla sua janela GLFW, contexto OpenGL, grafo de cena e loop de animação enquanto preserva cenas declarativas como dados Lisp tipados, inspecionáveis, transformáveis e persistentes.

O projeto oferece uma API CLOS idiomática para cenas, câmeras, malhas, geometrias, materiais, luzes, animação, entrada, seleção, pós-processamento e assets glTF. Aplicações não precisam de navegador, runtime JavaScript, canvas externo nem chamadas diretas a GLFW.

**Versão estável atual: 1.5.0** · **Autor: Bruno**

![Versão Flegrea](https://img.shields.io/badge/Flegrea-1.5.0-blue)
![Common Lisp](https://img.shields.io/badge/Common%20Lisp-SBCL%20%7C%20ECL%20%7C%20CCL-informational)
![OpenGL](https://img.shields.io/badge/OpenGL-3.3%20Core-informational)
[![CI](https://github.com/EdenCompiler/Flegrea/actions/workflows/ci.yml/badge.svg)](https://github.com/EdenCompiler/Flegrea/actions/workflows/ci.yml)
![Licença](https://img.shields.io/badge/licen%C3%A7a-MIT-green)

## O que a 1.5 significa

Flegrea 1.5 é uma reformulação centrada no metagrafo. Uma descrição declarativa tipada é o programa canônico da cena, enquanto um grafo CLOS vivo é sua instância executável. IDs estáveis conectam as duas camadas e permitem que commits transacionais preservem a identidade de objetos compatíveis durante edições em runtime.

A versão também expande o renderer para um motor nativo compacto: cor gerenciada, volumes e culling, filas estáveis, instancing, materiais físicos, sombras, transmissão em espaço de tela, render targets, FXAA, assets assíncronos, animação, raycasting, OrbitControls e um parser próprio de glTF 2.0/GLB.

| Subsistema | Estado na 1.5 |
| --- | --- |
| Metagrafo | S-expressions tipadas, IDs estáveis, referências, parâmetros, estado, bindings restritos, persistência segura, commits estruturais e hot reload |
| Grafo de cena | Objetos CLOS, grupos, malhas, câmeras, luzes, layers, hooks, transformações mundiais, volumes e posse de recursos |
| Geometria | Buffer geometry genérica, grupos, draw ranges, caixas, esferas, planos, círculos, anéis, cilindros, cones, toros, cápsulas, arestas e wireframes |
| Materiais | Basic, standard metálico/rugoso, physical, normal, depth, line, points, sprite e GLSL programável |
| Renderização | OpenGL 3.3 Core, janela GLFW própria, filas estáveis opacas/transparentes, culling, instancing, sombras, transmissão, tone mapping e estatísticas |
| Assets | Texturas PNG/JPEG, data textures, cache, jobs, cancelamento, progresso, resolvedores de URI e drenagem na thread de renderização |
| Animação e entrada | Clips, tracks, mixers, actions, cross-fades, transições de entrada, raycasting e OrbitControls |
| glTF 2.0 | `.gltf`/`.glb`, recursos externos e embutidos, accessors sparse/normalized/strided, materiais, câmeras, luzes, variantes e extensões selecionadas |
| Pós-processamento | Render targets, leitura de pixels, effect composer, passes de render/shader e FXAA |
| Implementações | Validação em CI com SBCL, ECL e CCL no Linux usando OpenGL por software do Mesa |

Em outras palavras, **a 1.5 transforma Flegrea em um runtime metagráfico nativo prático sem esconder a descrição da cena dentro de estado opaco**.

## Principais novidades da 1.5

- sistemas ASDF modulares com um único pacote público `flegrea`;
- descrições metagráficas tipadas e versionadas com parâmetros, estado, referências e funções de binding registradas;
- `commit-scene` transacional com preservação de identidade e hot reload por arquivo;
- fluxo gerenciado de cor sRGB/linear, exposição, tone mapping Reinhard/ACES e qualidade configurável;
- frustum culling, layers, volumes, ordem estável, estatísticas do renderer e hooks de objetos;
- linhas, segmentos, pontos, sprites e malhas instanciadas na GPU com transformações e cores por instância;
- materiais físicos com clearcoat, transmission, thickness, IOR, atenuação, normal maps e UV secundária;
- sombras direcionais e spot com PCF, controles de bias e participação por objeto;
- carregamento assíncrono de texturas e glTF com cache, deduplicação, progresso, cancelamento e resolvedores explícitos;
- clips de keyframes, actions ponderadas, modos repeat/once/ping-pong, escala de tempo e cross-fades;
- estado de mouse e teclado, raycasting de malhas/instâncias/linhas/pontos/sprites e OrbitControls com damping;
- render targets, leitura de pixels, composição de efeitos, passes de tela programáveis e FXAA embutido;
- leitor próprio de glTF 2.0/GLB, sem depender de outro framework de modelos;
- dois demos nativos offline e cobertura de CI para SBCL, ECL e CCL.

## Destaques

- abre e controla imediatamente uma janela nativa a partir de Common Lisp;
- renderer moderno OpenGL 3.3 Core baseado em shaders, sem caminho fixed-function;
- nomes públicos em inglês e construtores idiomáticos `make-*`;
- matemática mutável de vetores, matrizes, quaternion, Euler, cor, raio, plano, triângulo, caixa, esfera e frustum;
- câmeras perspectiva e ortográfica;
- luzes ambiente, direcional, pontual, spot e hemisférica;
- geometrias procedurais e buffers próprios com desenho indexado e não indexado;
- materiais GLSL programáveis com envio tipado de uniforms;
- loops nativos de animação para cenas diretas e instâncias metagráficas;
- descarte explícito e idempotente de recursos de CPU/GPU;
- documentação em inglês e português brasileiro;
- nenhum navegador, WebGL, Node, Electron, HTML ou canvas externo.

## Instalação

Flegrea requer uma implementação Common Lisp nativa, ASDF, Quicklisp, GLFW 3 e um driver compatível com OpenGL 3.3. O conjunto completo de dependências Lisp está registrado em [`qlfile`](qlfile).

No Debian ou Ubuntu:

```sh
sudo apt update
sudo apt install sbcl ecl libglfw3 libglfw3-dev libgl1-mesa-dev libffi-dev
```

Clone o repositório em um local visível ao ASDF:

```sh
git clone https://github.com/EdenCompiler/Flegrea.git
cd Flegrea
```

Carregue o framework completo:

```lisp
(asdf:load-asd (truename "flegrea.asd"))
(ql:quickload :flegrea)
```

Ou carregue somente o subsistema necessário:

```lisp
(asdf:load-system :flegrea/core)
(asdf:load-system :flegrea/assets)
(asdf:load-system :flegrea/animation)
(asdf:load-system :flegrea/controls)
(asdf:load-system :flegrea/renderer)
(asdf:load-system :flegrea/postprocessing)
(asdf:load-system :flegrea/gltf)
```

O sistema agregador `flegrea` carrega todos os subsistemas de runtime. Todos os símbolos públicos permanecem no pacote `flegrea`, independentemente do sistema ASDF que fornece sua implementação.

GLFW foi escolhido por ser uma camada pequena e focada em janela, contexto e entrada. Ele mantém compacta a fronteira nativa sem impor o subsistema multimídia mais amplo do SDL2.

### Execute os demos

```sh
sbcl --load demos/cubo.lisp
sbcl --load demos/oceano.lisp
```

Troque `sbcl` por `ecl` para executar os mesmos arquivos no ECL. Os dois demos localizam a definição ASDF adjacente, carregam suas dependências, criam o renderer internamente, abrem uma janela nativa e liberam seus recursos ao encerrar.

Use `--smoke` para uma validação invisível de dois quadros:

```sh
sbcl --load demos/cubo.lisp -- --smoke
sbcl --load demos/oceano.lisp -- --smoke
```

O cubo demonstra metagrafo tipado, recursos compartilhados, cores por face, iluminação física e bindings temporais. O oceano renderiza uma superfície de ondas de Gerstner com 126.721 vértices, normais por diferenças finitas, água Fresnel, espuma nas cristas, brilho solar e céu procedural.

### Execute os testes

```sh
sbcl --non-interactive --load ~/quicklisp/setup.lisp \
  --eval '(asdf:load-asd (truename "flegrea.asd"))' \
  --eval '(asdf:test-system :flegrea)'
```

Inclua a integração OpenGL em janela invisível sob um servidor de display:

```sh
FLEGREA_RUN_GL_TESTS=1 xvfb-run -a sbcl --non-interactive \
  --load ~/quicklisp/setup.lisp \
  --eval '(asdf:load-asd (truename "flegrea.asd"))' \
  --eval '(asdf:test-system :flegrea)'
```

A matriz do GitHub Actions executa testes unitários, integração Mesa/OpenGL e os smoke tests dos dois demos em SBCL, ECL e CCL.

## API centrada no metagrafo

Uma cena Flegrea pode ser criada como dados tipados em vez de existir somente como montagem imperativa de objetos:

```lisp
(flegrea:define-scene make-spinning-box
  (flegrea:scene
   :id :root
   :active-camera (flegrea:ref :camera)
   :resources
   ((flegrea:box-geometry :id :box)
    (flegrea:mesh-standard-material
     :id :surface
     :color (flegrea:color 0.15 0.55 1.0)
     :roughness 0.3
     :metalness 0.2))
   :children
   ((flegrea:perspective-camera
     :id :camera
     :aspect 1.3333333
     :position (flegrea:vector3 0 0 5))
    (flegrea:ambient-light :id :ambient :intensity 0.25)
    (flegrea:directional-light
     :id :sun
     :position (flegrea:vector3 3 4 5)
     :intensity 2.0)
    (flegrea:mesh
     :id :box-mesh
     :geometry (flegrea:ref :box)
     :material (flegrea:ref :surface)
     :rotation
     (flegrea:euler
      (flegrea:bind (* :time 0.4))
      (flegrea:bind (* :time 0.7))
      0 :xyz)))))
```

`define-scene` cria uma factory que devolve `scene-instance`. A descrição permanece acessível por `find-node`, `walk-scene`, `transform-scene`, `write-scene`, `read-scene` e pelo commit transacional `commit-scene`.

Bindings são expressões restritas sobre valores numéricos, `:time`, `:delta`, aritmética, funções trigonométricas e chamadas explicitamente registradas. Arquivos `.fscene` persistidos são lidos com `*read-eval*` desabilitado.

## Visão rápida

### Renderer nativo e loop de animação

`make-renderer` abre a janela e cria seu contexto OpenGL. A aplicação nunca manipula um objeto GLFW:

```lisp
(let ((renderer (flegrea:make-renderer
                 :width 960
                 :height 720
                 :title "Flegrea"
                 :clear-color (flegrea:make-color 0.02 0.025 0.04)))
      (instance (make-spinning-box)))
  (unwind-protect
       (flegrea:animate-scene renderer instance)
    (flegrea:dispose renderer)))
```

`render` desenha um quadro de uma cena direta. `render-scene` desenha uma instância metagráfica. `animate` e `animate-scene` fornecem loops bloqueantes com tempo, input, drenagem de assets, controles, mixers, callbacks, troca de buffers e encerramento.

### Grafo de cena CLOS direto

A camada declarativa é opcional quando a construção direta de objetos é mais apropriada:

```lisp
(let* ((scene (flegrea:make-scene))
       (camera (flegrea:make-perspective-camera :aspect (/ 16.0 9.0)))
       (mesh (flegrea:make-mesh
              (flegrea:make-box-geometry)
              (flegrea:make-mesh-basic-material
               :color (flegrea:make-color 0.2 0.7 1.0)))))
  (flegrea:set-position camera 0 0 5)
  (flegrea:add-child scene mesh)
  (flegrea:update-matrix-world scene))
```

`object-3d` fornece posição, rotação, quaternion, escala, hierarquia, matrizes local/mundial, layers, visibilidade, ordem, volumes, hooks de ciclo de vida e dados de usuário.

### Buffer geometry própria

```lisp
(let ((geometry (flegrea:make-buffer-geometry)))
  (flegrea:set-attribute
   geometry :position
   (flegrea:make-buffer-attribute
    '(0 1 0  -1 -1 0  1 -1 0)
    3))
  (flegrea:set-index geometry '(0 1 2))
  (flegrea:compute-vertex-normals geometry)
  (flegrea:compute-bounding-box geometry)
  geometry)
```

Attributes são enviados sob demanda e armazenados em cache por identidade. Marque `needs-update` depois de alterar o array de um atributo já enviado. Grupos e draw ranges restringem draws indexados ou não indexados.

### Materiais físicos, texturas e luzes

```lisp
(let* ((texture (flegrea:load-texture #P"assets/albedo.png"))
       (material
         (flegrea:make-mesh-physical-material
          :color (flegrea:make-color 1 1 1)
          :base-color-map texture
          :roughness 0.2
          :metalness 0.1
          :clearcoat 0.7
          :transmission 0.35
          :ior 1.45)))
  material)
```

Shaders gerenciados aceitam mapas de base color, metallic/roughness, normal, emissive, occlusion, opacity, clearcoat, transmission e thickness. As luzes incluem tipos ambiente, direcional, pontual, spot e hemisférico. A primeira luz direcional ou spot com sombras renderiza um depth map filtrado por PCF.

### Animação, picking e OrbitControls

A animação usa `keyframe-track`, `animation-clip`, `animation-mixer` e `animation-action`. Actions aceitam play, pause, stop, seek, pesos, escala de tempo, repeat, once, ping-pong e cross-fade.

```lisp
(let* ((raycaster (flegrea:make-raycaster))
       (mouse (flegrea:make-vector2 0.0 0.0)))
  (flegrea:set-ray-from-camera raycaster mouse camera)
  (flegrea:intersect-object raycaster scene :recursive t))
```

O raycaster cobre malhas, instâncias, pontos, linhas e sprites. Hits de malha incluem distância, ponto e normal mundiais, UV interpolada, índice da face e índice da instância quando aplicável.

```lisp
(let ((controls
        (flegrea:make-orbit-controls camera (flegrea:renderer-input renderer)
                                    :enable-damping t)))
  (flegrea:add-controls renderer controls))
```

Arrastar com o botão esquerdo rotaciona; botão direito ou central desloca; a roda aproxima e afasta. Limites de distância e ângulo polar são configuráveis.

### glTF 2.0 e assets assíncronos

```lisp
(let* ((asset (flegrea:load-gltf #P"assets/model.glb"))
       (model (flegrea:instantiate-asset asset :variant "Blue")))
  (flegrea:add-child scene model))
```

`load-gltf-async` devolve um job administrado por `loading-manager`. O loop de Flegrea drena jobs concluídos na thread de renderização; aplicações com loop próprio chamam `drain-loading-manager` explicitamente.

O parser cobre arquivos externos, data URIs, chunks GLB, accessors sparse/normalized/strided, múltiplas primitives, hierarquia, TRS/matrizes, câmeras, samplers, imagens PNG/JPEG e extensões selecionadas de materiais/luzes/instancing. Caminhos que escapam a raiz do asset são rejeitados e HTTP não vem embutido.

### Render targets e pós-processamento

```lisp
(let ((composer (flegrea:make-effect-composer renderer)))
  (unwind-protect
       (progn
         (flegrea:add-pass composer (flegrea:make-render-pass scene camera))
         (flegrea:add-pass composer (flegrea:make-fxaa-pass))
         (flegrea:composer-render composer))
    (flegrea:dispose composer)))
```

Render targets podem ser redimensionados e lidos de volta. Shader passes usam instâncias normais de `shader-material`, mantendo efeitos próprios no mesmo ciclo de programa e uniforms dos materiais de cena.

## Arquitetura sugerida

```text
dados tipados de cena (.fscene ou formas Lisp)
                     |
                     v
                 meta-scene
          / inspecionar | transformar \
         /              |               \
ler/escrever      commit/hot reload      bindings
         \              |               /
          \             v              /
              grafo CLOS vivo
                     |
          animação / input / jobs
                     |
                     v
          listas estáveis + culling
                     |
                     v
       renderer OpenGL 3.3 / composer
                     |
                     v
              janela GLFW nativa
```

Use o metagrafo como dado durável da aplicação e o grafo CLOS como estado de runtime. Mantenha trabalho OpenGL, drenagem de jobs, commits de cena e descarte de recursos na thread proprietária do renderer. Use `unwind-protect` em todo ciclo de vida de renderer e composer.

## Sistemas

| Sistema ASDF | Finalidade |
| --- | --- |
| `flegrea/core` | Matemática, recursos, grafo de cena, geometria, materiais, luzes e metagrafo |
| `flegrea/assets` | Texturas, decodificação de imagens, jobs, cache e resolução de URI |
| `flegrea/animation` | Tracks, clips, mixers, actions e registro de targets |
| `flegrea/controls` | Estado de entrada, raycasting e OrbitControls |
| `flegrea/renderer` | Janela GLFW, renderer OpenGL 3.3, listas, shaders, sombras e loop |
| `flegrea/postprocessing` | Render targets, composer, passes de render/shader e FXAA |
| `flegrea/gltf` | Parser nativo de glTF 2.0 e GLB |
| `flegrea` | Runtime público completo |
| `flegrea/tests` | Testes FiveAM unitários e integração OpenGL opcional |

## Documentação

- [Visão da 1.5](doc-ptbr/VERSAO-1.5.md)
- [Guia da API](doc-ptbr/API.md)
- [Compilação e carregamento](doc-ptbr/COMPILACAO.md)
- [Arquitetura](doc-ptbr/ARQUITETURA.md)
- [Metagrafo e bindings](doc-ptbr/METAGRAFO.md)
- [Matemática](doc-ptbr/MATEMATICA.md)
- [Renderização](doc-ptbr/RENDERIZACAO.md)
- [glTF 2.0](doc-ptbr/GLTF-2.0.md)
- [Exemplos](doc-ptbr/EXEMPLOS.md)
- [Migração da 1.0](doc-ptbr/MIGRACAO-1.5.md)
- [Changelog](doc-ptbr/CHANGELOG.md)

## Segurança de plataforma e runtime

- Linux é a plataforma validada da 1.5; SBCL, ECL e CCL executam no CI.
- Windows e macOS permanecem alvos de portabilidade e exigem sua configuração normal de GLFW/OpenGL.
- Renderer, chamadas OpenGL, commits de cena e descarte devem permanecer na thread que criou o renderer.
- Flegrea mascara traps de ponto flutuante do host ao redor de operações GLFW/OpenGL nas quais drivers nativos podem executar cálculos normalmente válidos.
- GLFW é carregado dinamicamente por CFFI; a biblioteca do sistema operacional precisa estar visível ao dynamic linker.
- O primeiro build no ECL pode demorar porque decoders de imagem e dependências são compilados como Common Lisp portável.
- Em sistemas Wayland, uma sessão XWayland ou ambiente X11 explícito pode ser necessário quando o GLFW instalado não oferece suporte Wayland nativo.

## Limitações atuais

- OpenGL 3.3 Core é o único backend de renderização.
- O renderer é um forward renderer compacto, não um renderer completo de produção.
- A transmissão física opera em espaço de tela; objetos fora do frame capturado não aparecem na refração.
- Uma luz direcional ou spot com sombras é escolhida por quadro; sombras cascaded e PCSS não estão implementadas.
- Mapas de um material compartilham uma transformação UV escolhida do base-color map ou primeiro mapa ativo.
- Skins, morph targets, importação de animações glTF, Draco, Meshopt e image-based lighting ficam adiados.
- Cubemaps, environment probes, bloom, física, áudio, rede e editor estão fora da 1.5.
- Fetch HTTP de assets é propositalmente ausente; aplicações podem registrar resolvedores de URI explícitos.
- WebGL, WebGPU, canvas de navegador e interop JavaScript são não objetivos.

## Licença

Flegrea é distribuída sob a [Licença MIT](LICENSE). Copyright © 2026 Bruno.
