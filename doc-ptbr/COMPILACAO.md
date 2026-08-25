# Compilação e carregamento da Flegrea

## Requisitos

Flegrea 1.0 requer uma implementação Common Lisp nativa, ASDF, Quicklisp, driver OpenGL 3.3 funcional e GLFW 3. A base suportada inclui SBCL e ECL. O código usa recursos portáveis de ASDF/UIOP, CFFI e Bordeaux Threads para viabilizar CCL sem ramificações específicas de implementação.

As dependências ASDF são `alexandria`, `cffi`, `cl-glfw3`, `cl-opengl`, `bordeaux-threads` e `float-features`. O sistema `flegrea/tests` também usa FiveAM.

No Debian ou Ubuntu:

```sh
sudo apt update
sudo apt install sbcl ecl libglfw3 libgl1-mesa-dev libffi-dev
```

Instale o Quicklisp em `~/quicklisp` ou ajuste os caminhos dos comandos abaixo.

## Carregamento com SBCL

Na raiz do projeto:

```sh
sbcl --load ~/quicklisp/setup.lisp \
  --eval '(asdf:load-asd (truename "flegrea.asd"))' \
  --eval '(ql:quickload :flegrea)'
```

No desenvolvimento regular, inclua o diretório do projeto no registro de fontes do ASDF e use diretamente `(ql:quickload :flegrea)`.

## Carregamento com ECL

```sh
ecl -norc -load ~/quicklisp/setup.lisp \
  -eval '(asdf:load-asd (truename "flegrea.asd"))' \
  -eval '(ql:quickload :flegrea)'
```

A primeira carga no ECL pode demorar mais porque CFFI, bindings OpenGL e Flegrea são compilados em objetos nativos. As cargas seguintes reutilizam o cache da implementação.

## Execução dos exemplos

```sh
sbcl --load demos/cubo.lisp
sbcl --load demos/oceano.lisp
ecl --load demos/cubo.lisp
ecl --load demos/oceano.lisp
```

Os dois arquivos inicializam ASDF e Quicklisp em relação ao próprio caminho e abrem imediatamente uma janela nativa. Nenhum canvas ou aplicativo hospedeiro é necessário.

O oceano possui um modo de fumaça não interativo:

```sh
sbcl --load demos/oceano.lisp -- --smoke
```

## Testes

Execute os testes independentes do dispositivo:

```sh
sbcl --non-interactive --load ~/quicklisp/setup.lisp \
  --eval '(asdf:load-asd (truename "flegrea.asd"))' \
  --eval '(asdf:test-system :flegrea)'
```

Inclua a integração OpenGL com janela invisível:

```sh
FLEGREA_RUN_GL_TESTS=1 sbcl --non-interactive \
  --load ~/quicklisp/setup.lisp \
  --eval '(asdf:load-asd (truename "flegrea.asd"))' \
  --eval '(asdf:test-system :flegrea)'
```

Em CI Linux sem servidor gráfico, execute o comando OpenGL por `xvfb-run -a` e instale a renderização por software do Mesa.

## Notas de plataforma

- O renderer e todo trabalho OpenGL precisam permanecer na thread que chamou `make-renderer`.
- Flegrea mascara traps de ponto flutuante do host ao redor de GLFW/OpenGL, pois drivers gráficos nativos podem executar operações incompatíveis com a configuração de traps da implementação.
- GLFW é carregado dinamicamente por CFFI. Se a carga falhar, verifique a instalação da biblioteca da plataforma e sua visibilidade ao carregador dinâmico.
- Windows e macOS exigem seus pré-requisitos normais de GLFW/OpenGL. São alvos de portabilidade, não combinações validadas na versão 1.0.
