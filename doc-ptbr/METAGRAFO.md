# Metagrafo e bindings

## Por que um metagrafo

Um grafo de cena direto responde “quais objetos existem agora?”. O metagrafo da Flegrea também registra “qual programa declarativo os produziu?”. `meta-scene` é dado Lisp tipado com IDs estáveis. `scene-instance` liga esse dado à cena viva, à câmera ativa e à tabela de objetos instanciados.

Essa separação permite inspeção, persistência segura, reconstrução determinística, reescritas em runtime e commits estruturais com preservação de identidade.

## Sintaxe da cena

Cada nó é uma lista tipada com `:id` keyword único. Uma cena declara `:active-camera`, `:resources` opcionais e `:children`:

```lisp
(flegrea:define-scene criar-cena
  (flegrea:scene
   :id :raiz
   :active-camera (flegrea:ref :camera)
   :resources
   ((flegrea:box-geometry :id :geometria)
    (flegrea:mesh-basic-material
     :id :material :color (flegrea:color 0.1 0.6 1.0)))
   :children
   ((flegrea:perspective-camera
     :id :camera :position (flegrea:vector3 0 0 4))
    (flegrea:mesh
     :id :caixa :geometry (flegrea:ref :geometria)
     :material (flegrea:ref :material)))))
```

Os nós de objeto cobrem cenas, grupos, meshes, meshes instanciadas, linhas, segmentos, pontos, sprites, as duas câmeras e luzes ambiente/direcional/pontual/spot/hemisférica. Propriedades comuns incluem transformações, visibilidade, camadas, ordem de renderização, corte por frustum e participação em sombras; meshes instanciadas aceitam matrizes e cores. Recursos incluem geometrias buffer e primitivas, derivados edges/wireframe, materiais basic/standard/physical/normal/depth/line/points/sprite/shader e data textures transformáveis. Referências entre recursos são instanciadas em ordem de dependência; ciclos são rejeitados. `ref` conecta IDs e é validado antes da instanciação.

## Bindings

`bind` envolve uma expressão restrita avaliada por `update-scene`. Os terminais são números reais, `:time` e `:delta`. Os operadores permitidos são aritmética, `sin`, `cos`, `tan`, `abs`, `min`, `max` e `clamp`.

```lisp
:rotation (flegrea:euler
           (flegrea:bind (* :time 0.4))
           (flegrea:bind (* :time 0.7))
           0 :xyz)
```

O parser valida a expressão como dado; a persistência nunca habilita avaliação pelo reader. Bindings podem aparecer em formas de vetor/Euler e em listas de uniformes de shader. `animate-scene` chama `update-scene` com o tempo total e o delta antes do callback opcional.

## Inspeção e transformação

- `scene-description` devolve uma cópia editável de uma descrição registrada.
- `find-node` procura metadados por ID; `find-object` procura o objeto vivo correspondente.
- `node-property` e sua forma `setf` acessam propriedades declaradas.
- `walk-scene` visita todos os nós, inclusive recursos.
- `transform-scene` copia uma descrição e aplica uma função a cada nó.

Os readers públicos `node-id`, `node-type`, `node-properties` e `node-children` atendem ferramentas que precisam de uma visão de baixo nível.

## Commits estruturais

`commit-scene instance description` prepara e valida uma substituição e então a reconcilia por ID estável e tipo declarado. Objetos compatíveis mantêm sua identidade e recebem o novo estado. Tipos alterados criam objetos substitutos. Nós removidos invocam `dispose-node`, arestas da hierarquia são refeitas, referências de recursos das malhas são reparadas e a câmera ativa é atualizada.

O grafo substituto é interpretado, validado e totalmente instanciado antes da reconciliação do grafo vivo. Recursos compatíveis preservam identidade; texturas alteradas são marcadas para novo upload na GPU; recursos removidos são descartados. A operação deve ocorrer na thread de aplicação/renderização, entre quadros, e não concorrentemente.

## Persistência

`write-scene` grava uma S-expression canônica e legível em stream ou pathname. `read-scene` lê exatamente uma forma com `*read-eval*` desabilitado e então executa a interpretação e validação normais.

Strings de shaders e arrays de buffers próprios são serializáveis, mas geometrias geradas muito grandes costumam ser melhor reconstruídas proceduralmente na inicialização, como faz `demos/oceano.lisp`.

## Extensões

`register-node-class` registra tag, classe de metadado, propriedades permitidas, propriedades bindable, política de filhos e condição de recurso. Especialize `validate-node`, `instantiate-node`, `update-node` e `dispose-node` para comportamento próprio. Métodos de extensão recebem um contexto tratado como opaco na versão 1.5; use os accessors documentados dos nós e construtores públicos de runtime.
