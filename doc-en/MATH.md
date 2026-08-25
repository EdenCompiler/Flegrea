# Math

## Data model

Flegrea implements its own minimal math layer; it does not wrap an external math library. Components and matrix storage are specialized to `single-float` at object boundaries. Constructors accept ordinary real numbers and coerce them.

Vectors, quaternions, Euler angles, and matrices are mutable CLOS objects. Most operations mutate and return the first argument:

```lisp
(let ((direction (flegrea:make-vector3 1 2 3)))
  (flegrea:normalize direction)
  (flegrea:multiply-scalar direction 4)
  direction)
```

Use `clone` when the source must remain unchanged and `copy-from` to reuse an existing destination. `equals` accepts an optional numeric tolerance.

## Vectors

`vector2`, `vector3`, and `vector4` support setters, cloning, copying, approximate equality, addition, subtraction, scalar multiplication/division, dot product, squared length, length, and normalization. `cross` is defined for `vector3`. Transform operations include `apply-matrix3`, `apply-matrix4`, and `apply-quaternion`.

Normalizing a zero vector leaves it at zero. Dividing by zero signals `validation-error` instead of producing implementation-dependent infinities.

## Matrices

`matrix3` and `matrix4` expose a flat `elements` array in column-major order. A constructor without elements creates the identity matrix. `set-identity`, `matrix-multiply`, `matrix-premultiply`, `matrix-transpose`, `matrix-determinant`, and `matrix-invert` operate in place. Inverting a singular matrix signals `validation-error`.

Matrix4 builders cover translation, scale, X/Y/Z rotation, perspective projection, orthographic projection, and look-at orientation. Projection field of view is expressed in degrees.

`compose-matrix4` combines position, quaternion, and scale. `decompose-matrix4` extracts those values, including reflected transforms. `set-normal-matrix3` derives the inverse-transpose upper-left 3×3 matrix used for surface normals.

## Quaternion and Euler rotation

Euler orders `:xyz`, `:yxz`, `:zxy`, `:zyx`, `:yzx`, and `:xzy` are supported. `set-from-euler` fills a quaternion; `set-from-quaternion` fills an Euler object while preserving or accepting the requested order.

`quaternion-multiply` composes rotations and `slerp` performs spherical interpolation with shortest-path handling. Quaternions can also use `normalize`, `dot`, `clone`, and `copy-from`.

## Camera math

Perspective matrices validate positive near distance, far greater than near, positive aspect, and positive zoom. Orthographic matrices validate a nonempty extent and far greater than near. Camera classes store both a mutable projection matrix and a view matrix derived from the inverse world transform.
