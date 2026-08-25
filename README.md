# Flegrea — Native metagraphics for Common Lisp

> **Languages / Idiomas:** [English](#english) · [Português do Brasil](#português-do-brasil)

---

# English

Flegrea is a native 3D metagraphics framework for Common Lisp. It owns its OS window, OpenGL context, scene graph, and animation loop while preserving a declarative scene as inspectable and transformable Lisp data.

**Current release: 1.0.0** · **Author: Bruno**

![Flegrea](https://img.shields.io/badge/Flegrea-1.0.0-blue)
![Common Lisp](https://img.shields.io/badge/Common%20Lisp-SBCL%20%7C%20ECL-informational)
![OpenGL](https://img.shields.io/badge/OpenGL-3.3%20Core-informational)

## What 1.0 provides

| Subsystem | Capabilities |
| --- | --- |
| Metagraph | Typed S-expressions, stable IDs, references, time bindings, traversal, transformation, persistence, structural commits |
| Scene | CLOS hierarchy, local/world transforms, scenes, groups, meshes, perspective and orthographic cameras |
| Geometry | Generic buffer geometry plus box, sphere, and plane generators |
| Materials | Unlit, metallic/roughness PBR-lite, and programmable GLSL materials |
| Lighting | Ambient, directional, and point lights |
| Math | Mutable vectors, matrices, quaternions, Euler angles, projection, composition, and decomposition |
| Runtime | Native GLFW window, OpenGL 3.3 Core renderer, keyboard state, and blocking animation loop |
| Implementations | Tested on SBCL and ECL; written portably for CCL |

The public API uses English names. Private implementation identifiers, source comments, diagnostics, and the Portuguese documentation use Brazilian Portuguese.

## Installation

On Debian or Ubuntu:

```sh
sudo apt install sbcl ecl libglfw3 libgl1-mesa-dev libffi-dev
```

Install Quicklisp under `~/quicklisp`, then clone or place Flegrea where ASDF can find it. The demos locate the adjacent `flegrea.asd` automatically and ask Quicklisp to load the Lisp dependencies.

GLFW was selected because its focused window, context, and input API keeps the native boundary small. Rendering uses shader-based OpenGL 3.3 Core through `cl-opengl`; Flegrea does not use a browser, web canvas, or JavaScript runtime.

See [Building and loading](doc-en/BUILDING.md) for SBCL, ECL, testing, and portability details.

## Run the examples

```sh
sbcl --load demos/cubo.lisp
sbcl --load demos/oceano.lisp
```

Use `ecl` instead of `sbcl` to run the same files on ECL. The cube demonstrates the declarative metagraph and PBR-lite lighting. The ocean reproduces a 420×300-cell Gerstner-wave surface, finite-difference normals, Fresnel water, crest foam, sun glitter, and a procedural sky. Move with WASD and close either demo with Escape.

For an invisible two-frame ocean validation:

```sh
sbcl --load demos/oceano.lisp -- --smoke
```

## Minimal direct scene

```lisp
(let* ((scene (flegrea:make-scene))
       (camera (flegrea:make-perspective-camera :aspect (/ 800.0 600.0)))
       (mesh (flegrea:make-mesh
              (flegrea:make-box-geometry)
              (flegrea:make-mesh-basic-material
               :color (flegrea:make-vector3 0.2 0.7 1.0))))
       (renderer (flegrea:make-renderer :width 800 :height 600)))
  (flegrea:set-position camera 0 0 4)
  (flegrea:add-child scene mesh)
  (unwind-protect
       (flegrea:animate renderer scene camera)
    (flegrea:dispose renderer)))
```

## Declarative metagraph

```lisp
(flegrea:define-scene make-spinning-box
  (flegrea:scene
   :id :root
   :active-camera (flegrea:ref :camera)
   :resources
   ((flegrea:box-geometry :id :box)
    (flegrea:mesh-standard-material
     :id :surface :roughness 0.3 :metalness 0.15))
   :children
   ((flegrea:perspective-camera
     :id :camera :aspect 1.3333
     :position (flegrea:vector3 0 0 5))
    (flegrea:mesh
     :id :mesh :geometry (flegrea:ref :box) :material (flegrea:ref :surface)
     :rotation (flegrea:euler 0 (flegrea:bind (* :time 0.8)) 0 :xyz)))))
```

`define-scene` creates a factory returning a `scene-instance`. `animate-scene` evaluates bindings before each frame. Descriptions remain available for `find-node`, `walk-scene`, `transform-scene`, `commit-scene`, `read-scene`, and `write-scene`.

## Documentation

- [API guide](doc-en/API.md)
- [Building and loading](doc-en/BUILDING.md)
- [Architecture](doc-en/ARCHITECTURE.md)
- [Metagraph and bindings](doc-en/METAGRAPH.md)
- [Math](doc-en/MATH.md)
- [Rendering and custom shaders](doc-en/RENDERING.md)
- [Examples](doc-en/EXAMPLES.md)

Brazilian Portuguese mirrors are under [`doc-ptbr`](doc-ptbr/).

## Tests

```sh
sbcl --non-interactive --load ~/quicklisp/setup.lisp \
  --eval '(asdf:load-asd (truename "flegrea.asd"))' \
  --eval '(asdf:test-system :flegrea)'
```

Set `FLEGREA_RUN_GL_TESTS=1` to add hidden-window rendering tests for built-in and custom shader materials.

## Current boundaries

- OpenGL 3.3 Core is the only backend, and the renderer must stay on its creating thread.
- Textures, model loaders, shadows, transparency, keyframe clips, post-processing, physics, audio, and editor tooling are future work.
- Linux with SBCL and ECL is validated. CCL, Windows, and macOS are portability targets but are not yet validated combinations.

---

# Português do Brasil

Flegrea é um framework metagráfico 3D nativo para Common Lisp. Ele controla sua própria janela do sistema operacional, contexto OpenGL, grafo de cena e loop de animação, preservando ao mesmo tempo a cena declarativa como dados Lisp inspecionáveis e transformáveis.

**Versão atual: 1.0.0** · **Autor: Bruno**

## O que a versão 1.0 oferece

| Subsistema | Capacidades |
| --- | --- |
| Metagrafo | S-expressions tipadas, IDs estáveis, referências, bindings temporais, travessia, transformação, persistência e commits estruturais |
| Cena | Hierarquia CLOS, transformações locais/mundiais, cenas, grupos, malhas e duas câmeras |
| Geometria | Geometria genérica de buffers e geradores de caixa, esfera e plano |
| Materiais | Material sem luz, PBR-lite metálico/rugoso e material GLSL programável |
| Iluminação | Luzes ambiente, direcional e pontual |
| Matemática | Vetores, matrizes, quaternions, Euler, projeção, composição e decomposição |
| Runtime | Janela GLFW nativa, renderer OpenGL 3.3 Core, estado do teclado e loop bloqueante |
| Implementações | Validado em SBCL e ECL; escrito portavelmente para CCL |

A API pública usa nomes em inglês. Identificadores privados, comentários do código-fonte, diagnósticos e esta documentação usam português brasileiro.

## Instalação

No Debian ou Ubuntu:

```sh
sudo apt install sbcl ecl libglfw3 libgl1-mesa-dev libffi-dev
```

Instale o Quicklisp em `~/quicklisp`. Os demos encontram o `flegrea.asd` adjacente e solicitam ao Quicklisp as dependências Lisp. GLFW foi escolhido por manter pequena a fronteira de janela, contexto e entrada. A renderização usa OpenGL 3.3 Core por `cl-opengl`, sem navegador, canvas web ou runtime JavaScript.

Consulte [Compilação e carregamento](doc-ptbr/COMPILACAO.md) para detalhes de SBCL, ECL, testes e portabilidade.

## Execute os exemplos

```sh
sbcl --load demos/cubo.lisp
sbcl --load demos/oceano.lisp
```

Troque `sbcl` por `ecl` para executar os mesmos arquivos no ECL. O cubo demonstra o metagrafo declarativo e a iluminação PBR-lite. O oceano reproduz uma superfície de 420×300 células com ondas de Gerstner, normais por diferenças finitas, água Fresnel, espuma nas cristas, brilho solar e céu procedural. Navegue com WASD e encerre com Escape.

Para validar o oceano em dois quadros invisíveis:

```sh
sbcl --load demos/oceano.lisp -- --smoke
```

## Metagrafo declarativo

`define-scene` registra uma descrição tipada e cria uma factory que devolve `scene-instance`. `animate-scene` avalia os bindings antes de cada quadro. A descrição continua acessível por `find-node`, `walk-scene`, `transform-scene`, `commit-scene`, `read-scene` e `write-scene`.

O loop direto `animate` e o loop metagráfico `animate-scene` são bloqueantes e devem permanecer na thread que criou o renderer. Use `unwind-protect` com `dispose` para liberar programas, buffers, contexto e janela mesmo quando ocorrer um erro.

## Documentação

- [Guia da API](doc-ptbr/API.md)
- [Compilação e carregamento](doc-ptbr/COMPILACAO.md)
- [Arquitetura](doc-ptbr/ARQUITETURA.md)
- [Metagrafo e bindings](doc-ptbr/METAGRAFO.md)
- [Matemática](doc-ptbr/MATEMATICA.md)
- [Renderização e shaders próprios](doc-ptbr/RENDERIZACAO.md)
- [Exemplos](doc-ptbr/EXEMPLOS.md)

## Testes

```sh
sbcl --non-interactive --load ~/quicklisp/setup.lisp \
  --eval '(asdf:load-asd (truename "flegrea.asd"))' \
  --eval '(asdf:test-system :flegrea)'
```

Defina `FLEGREA_RUN_GL_TESTS=1` para incluir testes com janela invisível dos materiais internos e programáveis.

## Limites atuais

- OpenGL 3.3 Core é o único backend e o renderer precisa permanecer na thread criadora.
- Texturas, loaders de modelos, sombras, transparência, clips de keyframes, pós-processamento, física, áudio e editor ficam para versões futuras.
- Linux com SBCL e ECL está validado. CCL, Windows e macOS são alvos de portabilidade, mas essas combinações ainda não foram validadas.
