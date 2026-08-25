# Matemática

## Modelo de dados

Flegrea implementa sua própria camada matemática mínima; ela não encapsula uma biblioteca externa. Componentes e armazenamento de matrizes são especializados como `single-float` nas fronteiras dos objetos. Os construtores aceitam números reais comuns e fazem a coerção.

Vetores, quaternions, ângulos Euler e matrizes são objetos CLOS mutáveis. A maioria das operações altera e devolve o primeiro argumento:

```lisp
(let ((direcao (flegrea:make-vector3 1 2 3)))
  (flegrea:normalize direcao)
  (flegrea:multiply-scalar direcao 4)
  direcao)
```

Use `clone` quando a origem precisar permanecer intacta e `copy-from` para reutilizar um destino existente. `equals` aceita tolerância numérica opcional.

## Vetores

`vector2`, `vector3` e `vector4` oferecem setters, clonagem, cópia, igualdade aproximada, soma, subtração, multiplicação/divisão escalar, produto escalar, comprimento quadrado, comprimento e normalização. `cross` é definido para `vector3`. As transformações incluem `apply-matrix3`, `apply-matrix4` e `apply-quaternion`.

Normalizar um vetor zero o mantém em zero. Dividir por zero sinaliza `validation-error` em vez de produzir infinitos dependentes da implementação.

## Matrizes

`matrix3` e `matrix4` expõem um array plano `elements` em ordem column-major. O construtor sem elementos cria a identidade. `set-identity`, `matrix-multiply`, `matrix-premultiply`, `matrix-transpose`, `matrix-determinant` e `matrix-invert` operam in-place. Inverter uma matriz singular sinaliza `validation-error`.

Os construtores de Matrix4 cobrem translação, escala, rotação X/Y/Z, projeção perspectiva, projeção ortográfica e orientação look-at. O campo de visão da projeção é expresso em graus.

`compose-matrix4` combina posição, quaternion e escala. `decompose-matrix4` extrai esses valores, inclusive em transformações refletidas. `set-normal-matrix3` deriva a matriz 3×3 inversa-transposta usada para normais de superfície.

## Rotação Quaternion e Euler

As ordens Euler `:xyz`, `:yxz`, `:zxy`, `:zyx`, `:yzx` e `:xzy` são aceitas. `set-from-euler` preenche um quaternion; `set-from-quaternion` preenche um Euler preservando ou recebendo a ordem solicitada.

`quaternion-multiply` compõe rotações e `slerp` faz interpolação esférica pelo caminho mais curto. Quaternions também aceitam `normalize`, `dot`, `clone` e `copy-from`.

## Matemática de câmera

Matrizes perspectivas validam near positivo, far maior que near, aspect positivo e zoom positivo. Matrizes ortográficas validam uma extensão não vazia e far maior que near. As classes de câmera mantêm tanto a matriz de projeção mutável quanto a matriz de visão derivada da inversa da transformação mundial.
