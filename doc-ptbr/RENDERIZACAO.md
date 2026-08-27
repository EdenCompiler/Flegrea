# Renderização

## Criação do renderer

`make-renderer` inicializa GLFW no primeiro uso, cria uma janela e contexto OpenGL 3.3 Core, habilita teste de profundidade, compila programas internos e registra a thread criadora.

```lisp
(flegrea:make-renderer
 :width 1280 :height 720
 :title "Flegrea"
 :clear-color (flegrea:make-color 0.02 0.025 0.04)
 :vsync t :resizable t :visible t)
```

A cor de limpeza é sRGB com componentes entre zero e um. Renderers invisíveis são úteis em testes de integração. O tamanho do framebuffer, não apenas o tamanho lógico da janela, controla o viewport.

## Materiais internos

`mesh-basic-material` multiplica sua cor pela cor opcional por vértice e não lê luzes.

`mesh-standard-material` é um shader forward compacto metálico/rugoso. Ele usa distribuição GGX, Fresnel de Schlick, geometria de Smith, atenuação por potência inversa, exposição, tone mapping Reinhard/ACES e espaço de saída configurável. Uma cena pode ter qualquer número de luzes ambiente e até oito de cada tipo direcional, pontual, spot e hemisphere por draw.

`mesh-physical-material` acrescenta clearcoat e transmissão/refração em espaço de tela com LOD por rugosidade, IOR, espessura de volume e atenuação. Os shaders standard/physical consomem mapas de cor base, metálico-rugoso, normal, emissivo, oclusão, opacidade, clearcoat, transmissão e espessura. `mesh-normal-material` e `mesh-depth-material` oferecem diagnóstico.

A direção de uma luz direcional vai do alvo à posição da luz. O `distance` de luzes pontuais e spot aplica corte suave de alcance quando positivo; `decay` controla a atenuação por potência inversa. A primeira luz direcional ou spot habilitada para sombra desenha um mapa de profundidade com PCF 3×3; meshes participam com `cast-shadow` e `receive-shadow`.

## Atributos geométricos

O renderer atribui posições fixas de shader:

| Atributo | Local | Forma |
| --- | ---: | --- |
| `:position` | 0 | três floats, obrigatório |
| `:normal` | 1 | três floats, obrigatório no material standard |
| `:color` | 2 | três floats; branco é fornecido quando ausente |
| `:uv` | 3 | dois floats, opcional |
| matriz de instância | 4–7 | quatro colunas `vec4` |
| cor de instância | 8 | três floats; branco é fornecido quando ausente |
| `:uv1` | 9 | dois floats, conjunto UV secundário opcional |

`instanced-mesh` emite draws realmente instanciados e aplica valores escritos por `set-instance-color`. Uma textura seleciona `:uv` ou `:uv1` por `uv-channel`; repetição, deslocamento, centro e rotação são aplicados pelos shaders gerenciados. Todos os mapas de um material ainda compartilham a transformação escolhida pelo mapa base, ou pelo primeiro mapa ativo quando não há mapa base. Grupos e faixas restringem desenho indexado ou não indexado; linhas, pontos e sprites orientados à câmera usam o caminho de primitiva/estado correspondente.

Índices usam inteiros sem sinal de 32 bits. A geometria é enviada sob demanda e guardada por identidade de objeto. Marque o accessor `needs-update` do atributo como verdadeiro depois de alterar seu array.

## Shaders próprios

`shader-material` oferece GLSL programável sem expor ownership de GLFW ou programas crus:

```lisp
(flegrea:make-shader-material
 :vertex-shader fonte-vertice
 :fragment-shader fonte-fragmento
 :uniforms (list "tempo" 0.0f0 "cor" (flegrea:make-vector3 1 0.4 0.2))
 :side :double
 :depth-write t)
```

Quando declarados, estes uniformes são preenchidos automaticamente antes dos valores do usuário:

- `matrizModelo` — matriz mundial da malha;
- `matrizVisao` — matriz de visão da câmera;
- `matrizProjecao` — matriz de projeção da câmera;
- `posicaoCamera` — posição mundial da câmera.

Nomes de uniformes do usuário são strings sensíveis a maiúsculas e minúsculas. Valores aceitos: números reais, inteiros, booleanos/NIL, `vector2`, `vector3`, `vector4`, `color`, `matrix3`, `matrix4` e `texture`. Use `set-uniform` em cada quadro ou coloque bindings na lista metagráfica `:uniforms`.

`side` aceita `:front`, `:back` ou `:double`. `depth-write` controla escrita no buffer de profundidade; o teste de profundidade continua habilitado. Programas compilam sob demanda no primeiro desenho, são reconstruídos quando uma fonte muda e pertencem ao cache do renderer.

## Fluxo do quadro e estado

`render` atualiza o viewport, matrizes mundiais e de câmera, limpa buffers de cor/profundidade, constrói listas estáveis e emite os desenhos apropriados de triângulos, linhas, pontos, sprites ou instâncias. Ele não troca buffers nem consulta eventos.

`animate` acrescenta tempo, callback, troca de buffers, polling de eventos, Escape e fechamento. `animate-scene` envolve o callback para atualizar primeiro os bindings metagráficos. Use `stop-animation` para saída limpa ou `request-close` para marcar tanto o loop quanto a janela nativa.

Flegrea restaura culling, profundidade e blending para cada objeto desenhável. Itens opacos são desenhados da frente para trás e transparentes de trás para frente, preservando a precedência estável de render-order.

`render-target` controla anexos de cor e profundidade opcional e permite resize e leitura de pixels. Um `effect-composer` encadeia `render-pass` com objetos `shader-pass` de tela inteira; `make-fxaa-pass` fornece o passe interno de antialiasing.

## Vida útil dos recursos

Sempre coloque `dispose` em `unwind-protect`. Ele apaga programas próprios em cache, programas internos, VAOs, buffers, janela e por fim GLFW quando o último renderer termina. Vários renderers podem coexistir na mesma thread, mas seus caches não são compartilhados.
