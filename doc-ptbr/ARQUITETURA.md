# Arquitetura da Flegrea

## Objetivo e módulos

Flegrea separa um metagrafo declarativo do grafo de cena CLOS vivo. O metagrafo é dado durável do programa: pode ser inspecionado, reescrito, serializado, comparado e aplicado. O grafo vivo mantém transformações mutáveis e recursos renderizáveis.

A ordem serial de carga do ASDF é:

1. `package.lisp` define o pacote público e os pacotes privados dos subsistemas;
2. `matematica.lisp` fornece primitivas numéricas independentes;
3. `nucleo.lisp` implementa a hierarquia da cena e as câmeras;
4. `geometrias.lisp` fornece dados de vértices e índices na CPU;
5. `materiais.lisp` define materiais e luzes;
6. `metagrafo.lisp` interpreta, valida, instancia, atualiza e persiste descrições;
7. `renderizador.lisp` controla GLFW, OpenGL, caches GPU, desenho, entrada e loops.

Somente `flegrea` é pacote de API pública. Os pacotes de subsistema organizam dependências internas sem obrigar o chamador a combinar vários pacotes.

## Fluxo em runtime

```text
S-expression tipada
        |
        v
   meta-scene  ---- transforma/lê/grava ----> meta-scene
        |
 instantiate-scene
        v
  scene-instance -- update-scene --> grafo CLOS vivo
        |                                  |
        +--------- commit-scene -----------+
                                           |
                                      render-scene
                                           v
                              janela GLFW + contexto OpenGL
```

`define-scene` armazena a descrição interpretada e cria uma factory Lisp. Ela devolve `scene-instance` com cena raiz, câmera ativa, descrição e tabela de ID para objeto. `animate-scene` avalia bindings e renderiza a instância em cada quadro.

## Coordenadas e transformações

Flegrea usa coordenadas locais de mão direita e as convenções de clip space do OpenGL. Câmeras olham para o eixo Z local negativo. Matrizes usam ordem de armazenamento column-major compatível com OpenGL.

Cada `object-3d` possui valores mutáveis de `position`, `rotation` e `scale`, além de `matrix` e `matrix-world`. `update-matrix-world` compõe recursivamente a matriz local com a do pai. A matriz de visão da câmera é a inversa de sua matriz mundial.

## Ownership e vida útil

Geometrias de CPU, materiais e objetos de cena são objetos Lisp comuns. O renderer cria sob demanda VAOs, buffers de vértices, buffers de índices e programas customizados, guardando-os por identidade de objeto. `dispose` libera todo o cache GPU do renderer, programas internos, contexto e janela.

Use `unwind-protect` ao redor de toda vida útil do renderer. `dispose` é idempotente, mas usar um renderer descartado ou chamá-lo de outra thread sinaliza `renderer-error`.

## Pontos de extensão

`register-node-class` adiciona um contrato tipado de nó metagráfico. Extensões podem especializar `validate-node`, `instantiate-node`, `update-node` e `dispose-node`. IDs estáveis permitem que `commit-scene` preserve objetos compatíveis e substitua nós cujo tipo declarado mudou.

O renderer reconhece as semânticas internas de atributos geométricos e as classes de material. Efeitos visuais arbitrários são possíveis por `shader-material`; uma categoria inteiramente nova de recurso ainda exige uma extensão do renderer.

## Limites

O renderer 1.0 é um renderer forward compacto. Ele omite deliberadamente filas de renderização, ordenação de transparência, texturas, sombras, instancing, culling, importação de modelos, pós-processamento, física, áudio e serviços de editor. Esses limites mantêm pequeno o contrato inicial entre metagrafo e janela nativa para que ele possa ser validado em mais de uma implementação Lisp.
