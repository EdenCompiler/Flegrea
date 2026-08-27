# Guia da API Flegrea 1.5

## Convenções e condições

Todos os símbolos públicos são exportados por `flegrea`. Construtores usam `make-*`; operações mutáveis normalmente alteram e devolvem o primeiro objeto para permitir encadeamento. Accessors de slots são funções genéricas CLOS e aceitam `setf` quando a definição da classe permite.

A hierarquia de condições começa em `flegrea-error`. Dados inválidos sinalizam `validation-error`; falhas nativas de renderização sinalizam `renderer-error`; falhas de compilação ou link GLSL sinalizam `shader-error`. Os diagnósticos informam a restrição relevante e, para shaders, o registro do driver.

## Matemática

| Tipos | Construtores | Operações principais |
| --- | --- | --- |
| `vector2`, `vector3`, `vector4` | `make-vector2`, `make-vector3`, `make-vector4` | `add`, `subtract`, `dot`, `normalize`, `apply-matrix*` |
| `quaternion`, `euler` | `make-quaternion`, `make-euler` | `set-from-euler`, `set-from-quaternion`, `quaternion-multiply`, `slerp` |
| `matrix3`, `matrix4` | `make-matrix3`, `make-matrix4` | multiplicação, transposição, determinante, inversa, projeções e composição |

Accessors compartilhados incluem `x`, `y`, `z`, `w`, `elements` e `order`. Consulte [Matemática](MATEMATICA.md) para regras de mutação e convenções de coordenadas.

## Grafo de cena

`object-3d` é a classe base de `scene`, `group`, `mesh`, câmeras e luzes. Seus accessors principais são `position`, `rotation`, `scale`, `parent`, `children`, `matrix`, `matrix-world`, `visible` e `name`.

```lisp
(let ((cena (flegrea:make-scene))
      (grupo (flegrea:make-group :name "pivo")))
  (flegrea:add-child cena grupo)
  (flegrea:set-position grupo 1 2 3)
  (flegrea:traverse cena #'print)
  (flegrea:update-matrix-world cena))
```

`add-child` muda o parentesco e rejeita ciclos. `remove-child` remove o vínculo. `look-at` orienta um objeto em direção a um alvo `vector3`. `mesh` acrescenta os accessors `geometry` e `material`.

## Câmeras

Crie `perspective-camera` com `fov`, `aspect`, `near`, `far` e `zoom`, ou `orthographic-camera` com `left`, `right`, `top`, `bottom`, `near`, `far` e `zoom`. Chame `update-projection-matrix` depois de alterar diretamente os accessors de projeção. Atualizações metagráficas fazem isso automaticamente nas propriedades dinâmicas da câmera perspectiva.

## Geometria

`make-box-geometry`, `make-sphere-geometry` e `make-plane-geometry` devolvem subclasses de `buffer-geometry`. A caixa pode receber seis `face-colors`; contagens de segmentos controlam a tesselação da esfera e do plano.

Uma geometria própria usa:

```lisp
(let ((geometria (flegrea:make-buffer-geometry)))
  (flegrea:set-attribute
   geometria :position
   (flegrea:make-buffer-attribute '(0 1 0 -1 -1 0 1 -1 0) 3))
  (flegrea:set-index geometria '(0 1 2))
  (flegrea:compute-vertex-normals geometria)
  geometria)
```

Use `attributes`, `index`, `get-attribute`, `delete-attribute`, `attribute-array`, `item-size`, `normalized`, `usage` e `needs-update` para acesso de baixo nível. Marque `needs-update` depois de modificar um array já enviado à GPU.

## Materiais e luzes

`make-mesh-basic-material` não recebe iluminação. `make-mesh-standard-material` fornece PBR-lite metálico/rugoso com `color`, `roughness`, `metalness`, `emissive` e cores opcionais por vértice.

`make-shader-material` recebe `vertex-shader`, `fragment-shader`, `uniforms`, `side` e `depth-write`. Use `uniform` e `set-uniform` para valores individuais. Consulte [Renderização](RENDERIZACAO.md) para a interface dos shaders.

Os construtores de luz são `make-ambient-light`, `make-directional-light` e `make-point-light`. Os accessors comuns são `color` e `intensity`. Luzes direcionais acrescentam `target`; pontuais acrescentam `distance` e `decay`.

## Renderer, loop e entrada

`make-renderer` recebe `width`, `height`, `title`, `clear-color`, `vsync`, `resizable` e `visible`. A chamada abre imediatamente a janela e cria o contexto OpenGL.

- `render renderer scene camera` desenha um quadro sem trocar buffers.
- `render-scene renderer instance` desenha uma instância metagráfica.
- `animate renderer scene camera &optional callback` executa o loop direto bloqueante.
- `animate-scene renderer instance &optional callback` também avalia bindings a cada quadro.
- callbacks recebem `delta-time` e `elapsed-time` em segundos antes do desenho.
- `key-down-p` consulta uma keyword de tecla GLFW sem expor objetos GLFW.
- `stop-animation` encerra o loop; `request-close` também marca a janela para fechamento.
- `renderer-should-close-p` informa a flag nativa de fechamento.
- `dispose` libera todos os recursos controlados pelo renderer.

`animation-loop` é um alias explícito de `animate`. As dimensões são atualizadas pelo framebuffer e expostas por `renderer-width` e `renderer-height`; o título configurado está em `renderer-title`.

Registre animação e controles gerenciados pelo loop com `add-animation-mixer` / `remove-animation-mixer` e `add-controls` / `remove-controls`. Cada quadro consulta entrada, drena jobs e hot reload, executa `before-update`, controles, mixers, `update`, bindings metagráficos, callback do usuário e `after-update` antes da renderização.

## Tipos de cena e renderização da 1.5

Os drawables adicionais são `line`, `line-segments`, `points`, `sprite` e `instanced-mesh`. Seus construtores acompanham o nome da classe; use `set-instance-matrix` e `set-instance-color` para dados por instância. As primitivas incluem circle, ring, cylinder, cone, torus, capsule, edges e wireframe geometry. Grupos e faixas de desenho usam `add-group`, `clear-groups` e `set-draw-range`.

`mesh-physical-material` acrescenta `clearcoat`, `transmission`, `thickness`, `ior`, atenuação e seus mapas. Materiais standard expõem intensidade emissiva, escala de normal, força de oclusão e mapas base/normal/metálico-rugoso/emissivo/oclusão/opacidade. Materiais normal e depth são visões diagnósticas. Luzes spot e hemisphere complementam as três originais; `light-shadow` configura tamanho do mapa e bias de profundidade/normal.

Texturas são objetos `resource` criados por `make-texture`, `make-data-texture` ou `load-texture`. Marque `needs-update` depois de alterar dados de textura ou de um atributo de buffer já enviado. Render targets e pós-processamento usam `make-render-target`, `make-effect-composer`, passes de render/shader, `composer-render` e `make-fxaa-pass`.

## Assets, animação, picking e glTF

`loading-manager` fornece jobs assíncronos, deduplicação, remoção de cache, cancelamento, progresso, listeners e resolvedores explícitos de URI. Use `load-texture-async` ou `load-gltf-async`; chame `drain-loading-manager` na thread de renderização quando não usar o loop de animação da Flegrea.

Animação combina keyframe tracks, clips, mixer e actions. Actions oferecem play/pause/stop/seek, loops repeat/once/ping-pong, peso, escala de tempo e cross-fade. `raycaster` intersecta meshes, instâncias, pontos, linhas e sprites e devolve objetos `intersection` ordenados por distância; acertos em meshes incluem normal da face em espaço mundial e UV interpolada. `orbit-controls` consome o `input-state` do renderer: arraste esquerdo gira, direito ou central faz pan e a roda faz dolly, com damping, limites de distância e limites polares.

`load-gltf` e `load-gltf-async` devolvem `scene-asset`. `instantiate-asset` aceita `:scene` e `:variant`; readers de metadados expõem cenas, câmeras, variantes, avisos e a descrição canônica da importação. Consulte [glTF 2.0](GLTF-2.0.md).

## Metagrafo

As entradas centrais são `define-scene`, `parse-scene`, `instantiate-scene`, `update-scene` e `commit-scene`. A inspeção usa `scene-description`, `find-node`, `find-object`, `node-property`, `walk-scene` e `transform-scene`. A persistência usa `read-scene` e `write-scene`. Consulte [Metagrafo e bindings](METAGRAFO.md) para o modelo completo.
