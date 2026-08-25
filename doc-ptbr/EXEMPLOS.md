# Exemplos práticos da Flegrea

## Execução

Na raiz do projeto:

```sh
sbcl --load demos/cubo.lisp
sbcl --load demos/oceano.lisp
```

Troque `sbcl` por `ecl` para usar ECL. Os dois exemplos carregam Quicklisp, registram o sistema ASDF local, criam internamente o renderer e o liberam com `unwind-protect`.

## Cubo metagráfico

`demos/cubo.lisp` é a menor demonstração completa do desenho 1.0. Sua forma `define-scene` declara:

- uma caixa com seis cores por face;
- um material metálico/rugoso que usa essas cores de vértice;
- uma câmera perspectiva;
- luzes ambiente, direcional e pontual;
- uma malha cujos três componentes Euler são controlados por bindings de tempo.

O programa somente cria um renderer, chama a factory gerada para a cena e executa `animate-scene`. Esse é o primeiro exemplo recomendado para aprender a DSL tipada, recursos compartilhados, referências e atualizações automáticas de animação.

## Oceano com shaders

`demos/oceano.lisp` reproduz na Flegrea o desenho visual e a interação da referência de oceano nativa em C. Ele cria proceduralmente uma grade contínua com 126.721 vértices e 756.000 índices (252.000 triângulos) e coloca essa geometria de buffers em um metagrafo construído em runtime.

O vertex shader do oceano combina quatro ondas de Gerstner com direções, inclinações, comprimentos e velocidades diferentes. A normal deslocada é estimada por duas avaliações próximas da superfície. O fragment shader combina luz difusa, reflexo Fresnel no estilo Schlick, brilhos solares estreito e largo, cor de profundidade, ruído de ruptura e espuma baseada na crista e na inclinação.

Um segundo material programável desenha um céu procedural de tela inteira na profundidade distante. Seu ruído em camadas cria nuvens móveis; gradiente de horizonte baixo, disco solar e halo usam a mesma direção de iluminação da água. Os dois materiais recebem tempo total por bindings do metagrafo.

Controles:

| Tecla | Ação |
| --- | --- |
| W / S | Avançar / recuar no eixo Z |
| A / D | Mover à esquerda / direita no eixo X |
| Escape | Fechar a janela |

A câmera permanece próxima à superfície e recebe uma oscilação vertical sutil. Trata-se de um oceano artístico em tempo real, não um solver de fluidos: as ondas se sobrepõem analiticamente, não quebram dinamicamente e não interagem com geometria.

Renderize dois quadros invisíveis como teste de fumaça dos shaders e da GPU:

```sh
sbcl --load demos/oceano.lisp -- --smoke
```

O caminho de fumaça exercita interpretação do metagrafo, buffers próprios grandes, uniformes vinculados ao tempo, compilação de dois programas próprios, desenho indexado, loop de animação e descarte do renderer.
