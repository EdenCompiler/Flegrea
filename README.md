# Flegrea 1.5

Framework metagráfico 3D nativo para Common Lisp. Flegrea abre e controla sua própria janela GLFW, usa OpenGL 3.3 Core e oferece um grafo CLOS com descrição declarativa persistente. Autor: **Bruno**. Licença: MIT.

Native metagraphics 3D framework for Common Lisp. Flegrea owns its GLFW window, targets OpenGL 3.3 Core, and combines a CLOS scene graph with a safe persistent format. Author: **Bruno**. License: MIT.

## Português (Brasil)

Em Debian/Ubuntu:

~~~sh
sudo apt install libglfw3 libglfw3-dev libgl1-mesa-dev
~~~

Com Quicklisp:

~~~lisp
(ql:quickload :flegrea)
~~~

O sistema principal carrega os subsistemas core, assets, renderer, animation, controls, postprocessing e gltf. `make-renderer` abre a janela; o programa cliente não chama GLFW. GLFW foi escolhido por oferecer uma camada pequena e focada em janela, contexto OpenGL e entrada, sem impor o subsistema multimídia mais amplo do SDL2.

### Demos

~~~sh
sbcl --load demos/cubo.lisp
sbcl --load demos/oceano.lisp
~~~

Os dois aceitam `--smoke`. O primeiro build de cl-jpeg no ECL pode demorar porque o decoder é Common Lisp puro.

Leia [visão da 1.5](doc-ptbr/VERSAO-1.5.md), [API](doc-ptbr/API.md), [migração](doc-ptbr/MIGRACAO-1.5.md) e [glTF](doc-ptbr/GLTF-2.0.md).

## English

Install GLFW and Mesa, load with `(ql:quickload :flegrea)`, and run either demo above. Both accept `--smoke`. GLFW was selected because it is a small, focused window/context/input layer and does not impose SDL2's broader multimedia subsystem. The first cl-jpeg build can be slow on ECL because its decoder is portable Common Lisp.

Read the [1.5 overview](doc-en/VERSION-1.5.md), [API](doc-en/API.md), [migration guide](doc-en/MIGRATION-1.5.md), and [glTF guide](doc-en/GLTF-2.0.md).

## Escopo / Scope

Flegrea 1.5 inclui cor gerenciada, volumes, culling/listas estáveis, drawables, materiais físicos, texturas PNG/JPEG, jobs/cache, animação, entrada, raycasting, OrbitControls, render targets/FXAA e parser próprio glTF 2.0/GLB. O formato .fscene desabilita *read-eval* e bindings só chamam funções registradas.

Flegrea 1.5 includes managed color, bounds, culling/stable lists, drawables, physical materials, PNG/JPEG textures, jobs/cache, animation, input, raycasting, OrbitControls, render targets/FXAA, and an in-project glTF 2.0/GLB parser. .fscene disables *read-eval* and bindings only call registered functions.

Futuro / Deferred: skins, morph targets, glTF animation, Draco/Meshopt, IBL/cubemaps, bloom, cascaded shadows/PCSS, physics, audio, editor, HTTP, WebGL/WebGPU, and APIs above OpenGL 3.3.
