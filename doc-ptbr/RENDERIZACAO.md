# Renderização

## Criação do renderer

`make-renderer` inicializa GLFW no primeiro uso, cria uma janela e contexto OpenGL 3.3 Core, habilita teste de profundidade, compila programas internos e registra a thread criadora.

```lisp
(flegrea:make-renderer
 :width 1280 :height 720
 :title "Flegrea"
 :clear-color (flegrea:make-vector3 0.02 0.025 0.04)
 :vsync t :resizable t :visible t)
```

A cor de limpeza é sRGB com componentes entre zero e um. Renderers invisíveis são úteis em testes de integração. O tamanho do framebuffer, não apenas o tamanho lógico da janela, controla o viewport.

## Materiais internos

`mesh-basic-material` multiplica sua cor pela cor opcional por vértice e não lê luzes.

`mesh-standard-material` é um shader forward compacto metálico/rugoso. Ele converte cores sRGB para espaço linear, usa distribuição GGX, Fresnel de Schlick, geometria de Smith, atenuação de ponto por potência inversa, tone mapping simples e saída sRGB. Uma cena pode ter qualquer número de luzes ambiente, mas no máximo oito direcionais e oito pontuais por draw.

A direção de uma luz direcional vai do alvo à posição da luz. O `distance` de uma luz pontual aplica corte suave de alcance quando positivo; `decay` controla a atenuação por potência inversa.

## Atributos geométricos

O renderer atribui posições fixas de shader:

| Atributo | Local | Forma |
| --- | ---: | --- |
| `:position` | 0 | três floats, obrigatório |
| `:normal` | 1 | três floats, obrigatório no material standard |
| `:color` | 2 | três floats; branco é fornecido quando ausente |
| `:uv` | 3 | dois floats, opcional |

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

Nomes de uniformes do usuário são strings sensíveis a maiúsculas e minúsculas. Valores aceitos: números reais, inteiros, booleanos/NIL, `vector2`, `vector3`, `vector4`, `matrix3` e `matrix4`. Use `set-uniform` em cada quadro ou coloque bindings na lista metagráfica `:uniforms`.

`side` aceita `:front`, `:back` ou `:double`. `depth-write` controla escrita no buffer de profundidade; o teste de profundidade continua habilitado. Programas compilam sob demanda no primeiro desenho, são reconstruídos quando uma fonte muda e pertencem ao cache do renderer.

## Fluxo do quadro e estado

`render` atualiza o viewport, matrizes mundiais e de câmera, limpa buffers de cor/profundidade, percorre nós visíveis na ordem dos filhos e emite triângulos. Ele não troca buffers nem consulta eventos.

`animate` acrescenta tempo, callback, troca de buffers, polling de eventos, Escape e fechamento. `animate-scene` envolve o callback para atualizar primeiro os bindings metagráficos. Use `stop-animation` para saída limpa ou `request-close` para marcar tanto o loop quanto a janela nativa.

Flegrea restaura culling e escrita de profundidade para cada malha, portanto um material próprio não vaza essas escolhas ao próximo desenho. O renderer 1.0 não ordena objetos opacos/transparentes nem expõe blending.

## Vida útil dos recursos

Sempre coloque `dispose` em `unwind-protect`. Ele apaga programas próprios em cache, programas internos, VAOs, buffers, janela e por fim GLFW quando o último renderer termina. Vários renderers podem coexistir na mesma thread, mas seus caches não são compartilhados.
