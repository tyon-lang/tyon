# TYON 1.0.0

Typed Object Notation

## Specifications

* TYON is case-sensitive.
* A TYON file must be a valid UTF-8 encoded document.
* Whitespace is `space` (0x20), `tab` (0x09), `CR` (0x0D), and `LF` (0x0A)
* The `NULL` character is (0x00)
* The recommended file extension is `.tyon`

## File

A file is an implicit [map](#map) of [key / value pairs](#key--value-pair) that can also contain [type definitions](#type-definition).

## Comment

A comment begins with `;` and continues until, but does not include, a `LF` or `NULL`

A comment is valid after any other token.

## List

A list is an ordered set of [values](#value) separated by [whitespace](#specifications) and surrounded by `[` and `]`

## Map

A map is a set of [key / value pairs](#key--value-pair) separated by [whitespace](#specifications) and surrounded by `(` and `)`

## Key / Value Pair

A [key](#key) / [value](#value) pair is written as `key` `=` `value`

## Key

A key is a [literal](#literal) or [string](#string).

## Value

A value is a [literal](#literal), [string](#string), [list](#list), or [map](#map). [Lists](#list) and [maps](#map) can be typed or untyped.

## Literal

A literal is a contiguous set of characters that are not [whitespace](#specifications), `NULL`, or any of `(` `)` `[` `]` `=` `;`

A literal cannot start with `/` or `"`

## String

A string begins and ends with `"` and may contain any other characters. `"` can be escaped as `""`

## Type Definition

A type definition is a list of [keys](#key), written as `/` `name` `=` `(` keys `)`

A type name is a [literal](#literal).

## Typed List

A typed list is a [list](#list) preceded by `/` `name` or an [inline type](#inline-type).

The type is applied to any child [lists](#list) and [maps](#map) that are not typed.

A type name of `_` indicates that the list is not typed.

## Typed Map

A typed map is `/` `name` or an [inline type](#inline-type) followed by `(` values `)`

A type name of `_` indicates that the [map](#map) is not typed.

[Values](#value) are matched to [keys](#key) from the type in order.

A [literal](#literal) value of `_` indicates that the map does not have a value for the corresponding key.

A typed map can have at most the same number of values as the type has keys.

## Inline Type

An inline type is declared directly prior to a typed [list](#typed-list) or [map](#typed-map) as `/` `(` keys `)`
