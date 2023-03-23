# Typed Object Notation

AKA, can we be simpler and more compact than JSON without sacrificing readability.

File extension: `.tyon`

Implemented in [Zig](https://ziglang.org/), last compiled with 0.11.0-dev.2227+f9b582950.

```lisp
; a comment

; list = [first second ...]
; map = (key value key value ...)
; top level is an implicit map and does not need ()s

; can declare keys separately from values for maps

; list of customers
customers [
    (
        first First     ; breaks on whitespace, so here first = "First"
        last "D Last"   ; strings are surrounded by quotes, so here last = "D Last"
    )
    (
        first Second
        last  Last
    )
]

; list of people with a defined type
(/person first middle-initial last)

"business owner" /person("Mr Owner" _ Person)

people /person[
    (First D Last)
    (Second _ Last)
]

; with an inline type
people /(first middle last)[
    (First D Person)
    (Second)
]

; the type applies to the first level of maps encountered
multi /person[
    [
        (first _ last)
        (second D last)
    ]
    [
        (third)
        (fourth A Last)
    ]
]

; types can be overridden, and a type of _ is no type, so both keys and values are expected
multiple-types /person[
    [
        (first _ last)
        (second D last)
    ]
    /_[
        (x 1 y 2)
        /point(x 3 y 7)
    ]
]
```
