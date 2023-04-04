# Typed Object Notation

AKA, can we be simpler and more compact than JSON without sacrificing readability.

File extension: `.tyon`

Implemented in [Zig](https://ziglang.org/), last compiled with 0.11.0-dev.2371+a31450375.

```lisp
; a comment

; list = [first second ...]
; map = (key = value key = value ...)
; top level is an implicit map and does not need ()s

; can declare keys separately from values for maps

; list of customers
customers = [
    (
        first = "First"     ; strings are surrounded by quotes, so here first = "First"
        last = Last         ; without quotes the value breaks on whitespace and a few
                            ; other characters (see below), so here last = "Last"
    )
    (
        first = Second
        last = Last
    )
]

; defining the type 'person'
/person = (first middle-initial last)

; "business owner" is of type person, the values following the type
; correspond to the keys declared by the type
; the _ is used to indicate no value for a key
"business owner" = /person ("Mr Owner" _ Person)

; a list of type person
people = /person [
    (First D Last)
    (Second _ Last)
]

; types can also be declared inline
; if there are fewer values than keys, the remaining keys will have no value
people = /(first middle last) [
    (First D Person)
    (Second)
]

; the type applies to the first level of maps encountered
multi = /person [
    [
        (first _ last)
        (second D last)
    ]
    [
        (third)
        (fourth A Last)
    ]
]

; types can be overridden, and a type of _ is no type, so both keys and values are then expected
multiple-types = /person [
    [
        (first _ last)
        (second D last)
    ]
    /_[
        (x = 1 y = 2)
        /(a b)(3 4)
    ]
]
```

---

## Formats

* __boolean__: the values `true` and `false`
* __number__: all numbers can start with a `-` and contain a `.`
    * if present, the `.` must be between two digits
    * `_` can be used as a digits separator and must be between two digits
    * __binary__: starts with `0[bB]`, digits are `[01]`
    * __octal__: starts with `0[oO]`, digits are `[0-7]`
    * __decimal__: digits are `[0-9]`
    * __hexadecimal__: starts with `0[xX]`, digits are `[0-9a-fA-F]`
* __null__: the value `null`
* __string__: `"` characters `"`
    * strings can span multiple lines, all content is literal except `"` which is escaped as `""`
* __value__: consecutive characters other than `space` `tab` `CR` `LF` `(` `)` `[` `]` `=` `;`
