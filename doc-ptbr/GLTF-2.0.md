# glTF 2.0

`load-gltf` e `load-gltf-async` usam parser próprio, retornam `scene-asset`, e `instantiate-asset` cria grafos de objetos independentes. Selecione cena por `:scene` e uma entrada de `KHR_materials_variants` por nome ou índice com `:variant`.

O leitor cobre .gltf/.glb, imagens PNG/JPEG externas e embutidas, samplers, arquivos externos, data URI, chunks GLB, accessors esparsos/normalizados/intercalados, modos centrais, hierarquia, TRS/matriz, câmeras, múltiplas primitivas e atributos principais.

Extensões modeladas: unlit, texture transform, punctual lights, variants, emissive strength, clearcoat, transmission, IOR, volume e GPU instancing. Extensão obrigatória desconhecida rejeita; opcional vira aviso.

Caminhos que escapam da raiz são rejeitados. Outro esquema exige register-uri-resolver. HTTP não é embutido.
