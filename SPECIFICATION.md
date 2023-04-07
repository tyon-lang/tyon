# TYON 1.0.0

Typed Object Notation

## Specifications

* TYON is case-sensitive
* A TYON file must be a valid UTF-8 encoded document
* Whitespace is `space` (0x20), `tab` (0x09), `CR` (0x0D), and `LF` (0x0A)
* The `NULL` character is (0x00)
* The recommended file extension is `.tyon`

## File

A file is an implicit map of key / value pairs that can also contain type definitions.

## Comment

A comment begins with `;` and continues until, but does not include, a `LF` or `NULL`.

A comment is valid after any other token.

## List

## Map

## Literal

A literal is a contiguous set of characters that are not whitespace, `NULL`, or any of `(` `)` `[` `]` `=` `;`.

A literal cannot start with `/` or `"`.

## String

A string begins and ends with `"` and may contain any other characters. `"` can be escaped as `""`.

## Type Definition

## Typed Collections
