# Building and loading Flegrea

## Requirements

Flegrea 1.0 requires a native Common Lisp implementation, ASDF, Quicklisp, a working OpenGL 3.3 driver, and GLFW 3. The supported implementation baseline is SBCL and ECL. The code uses portable ASDF/UIOP, CFFI, and Bordeaux Threads facilities so CCL can be supported without implementation-specific branches.

The ASDF dependencies are `alexandria`, `cffi`, `cl-glfw3`, `cl-opengl`, `bordeaux-threads`, and `float-features`. `flegrea/tests` additionally uses FiveAM.

On Debian or Ubuntu:

```sh
sudo apt update
sudo apt install sbcl ecl libglfw3 libgl1-mesa-dev libffi-dev
```

Install Quicklisp at `~/quicklisp` or adjust the paths in the commands below.

## Loading with SBCL

From the project root:

```sh
sbcl --load ~/quicklisp/setup.lisp \
  --eval '(asdf:load-asd (truename "flegrea.asd"))' \
  --eval '(ql:quickload :flegrea)'
```

For regular development, add the project directory to ASDF's source registry and use `(ql:quickload :flegrea)` directly.

## Loading with ECL

```sh
ecl -norc -load ~/quicklisp/setup.lisp \
  -eval '(asdf:load-asd (truename "flegrea.asd"))' \
  -eval '(ql:quickload :flegrea)'
```

The first ECL load may take longer because CFFI, OpenGL bindings, and Flegrea are compiled to native objects. Later loads reuse the implementation cache.

## Running examples

```sh
sbcl --load demos/cubo.lisp
sbcl --load demos/oceano.lisp
ecl --load demos/cubo.lisp
ecl --load demos/oceano.lisp
```

Both files bootstrap ASDF and Quicklisp relative to their own path, then open a native window immediately. No external canvas or host application is required.

The ocean has a noninteractive smoke mode:

```sh
sbcl --load demos/oceano.lisp -- --smoke
```

## Tests

Run implementation-independent tests:

```sh
sbcl --non-interactive --load ~/quicklisp/setup.lisp \
  --eval '(asdf:load-asd (truename "flegrea.asd"))' \
  --eval '(asdf:test-system :flegrea)'
```

Include hidden-window OpenGL integration:

```sh
FLEGREA_RUN_GL_TESTS=1 sbcl --non-interactive \
  --load ~/quicklisp/setup.lisp \
  --eval '(asdf:load-asd (truename "flegrea.asd"))' \
  --eval '(asdf:test-system :flegrea)'
```

On a Linux CI host without a display server, run the OpenGL command under `xvfb-run -a` and ensure Mesa software rendering is installed.

## Platform notes

- The renderer and all OpenGL work must remain on the thread that called `make-renderer`.
- Flegrea masks host floating-point traps around GLFW/OpenGL calls because native graphics drivers may legally perform operations that conflict with an implementation's trap configuration.
- GLFW is dynamically loaded by CFFI. If loading fails, verify that the platform library is installed and visible to the dynamic linker.
- Windows and macOS require their normal GLFW/OpenGL prerequisites. They are portability targets, not validated 1.0 combinations.
