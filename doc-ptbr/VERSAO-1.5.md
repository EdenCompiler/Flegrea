# Flegrea 1.5

A 1.5 é uma reforma incompatível orientada ao metagrafo. Dados declarativos são o modelo canônico; objetos CLOS são a instância executável. IDs estáveis permitem commits que preservam identidade.

## Sistemas

- flegrea/core: matemática, recursos, grafo, geometrias, materiais e metagrafo.
- flegrea/assets: imagens, jobs, cache, progresso, cancelamento e resolvedores.
- flegrea/renderer: GLFW, OpenGL 3.3, input, culling e listas.
- flegrea/animation: clipes, trilhas, mixers, ações e crossfade.
- flegrea/controls: raycaster e OrbitControls.
- flegrea/postprocessing: render targets, compositor e FXAA.
- flegrea/gltf: parser próprio glTF 2.0/GLB.

## Ordem de frame

Entrada; jobs/hot reload; before-update; controles; mixers; bindings; callback do usuário; after-update; matrizes/culling/listas; before-render; render/compositor; after-render; swap. O callback do usuário acontece depois dos bindings e vence no mesmo frame.

Geometrias, materiais, texturas, assets, alvos e renderizadores têm dispose idempotente. Objetos OpenGL devem ser liberados no thread proprietário. Quality aceita :low, :medium e :high; :medium é o padrão.
