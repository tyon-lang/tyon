# Typed Object Notation | [Specification](SPECIFICATION.md) | [Data Formats](FORMAT.md)

![CLI Version](https://img.shields.io/badge/TYON%20CLI-0.3.0-brightgreen)
![Spec Version](https://img.shields.io/badge/Spec-1.0.0--rc.2-blue)
![Format Version](https://img.shields.io/badge/Format-1.0.0--rc.1-blue)

AKA, can we be simpler and more compact than JSON without sacrificing readability.

## Example.tyon

```lisp
; This is a TYON document

title = "TYON Example" ; files are implicitly maps

list = [1 2 3]

map = (
    first = John
    last = Doe
    age = 42
    "favorite numbers" = [13 42]
)

; strings can contain any character except ", which is escaped as ""
string = "hello, this is a string
with some ""quoted text"" and
multiple lines"

; a type declaration specifies the keys for the type
/person = (first last age)

; a typed map matches the type keys to values in order
owner = /person (Mary Sue 36) ; first = Mary, last = Sue, age = 36

; a value of _ in a typed map means there is no corresponding value
employee = /person (Other _ 25) ; first = Other, age = 25

; lists can also be typed, with the type applying to the children
typed-list = /person [
    (John Doe 42)
    (Mary Sue 36)
]

; types can be declared inline
points = /(x y z) [
    (1 2 3)
    (4 5 6)
    (7 8 9)
]

; types can be overridden
people = /person [
    (John Doe 42)
    /(x y) (1 2)    ; type overridden by the inline type
    /_ (            ; type overridden to be untyped
        a = 1
        b = 2
        c = 3
    )
]
```

---

## Motivations

### Key Repetition

Typed lists and maps let you specify the keys once at the start of the collection.

<table>
<tr>
<th>JSON</th>
<th>TYON</th>
</tr>
<tr>
<td>

```json
"points": [
    {"x": 1, "y": 2, "z": 3},
    {"x": 4, "y": 5},
    {"x": 6, "y": 7},
    {"x": 8, "z": 9},
    {"y": 10, "z": 11},
    ...
]
```

</td>
<td>

```lisp
points = /(x y z) [
    (1 2 3)
    (4 5)
    (6 7)
    (8 _ 9)
    (_ 10 11)
    ...
]
```

</td>
</tr>
</table>

---

### Escaping Strings

Strings can span multiple lines, and everything is literal except for `"` which is escaped as `""`

<table>
<tr>
<th>JSON</th>
<th>TYON</th>
</tr>
<tr>
<td>

```json
"regex": "\\[[0-9]+\\]\\.[0-9]+",
"multiline": "some\n\tindented\nmultiline \"quoted\"\ntext"
```

</td>
<td>

```lisp
regex = "\[[0-9]+\]\.[0-9]+"
multiline =
"some
    indented
multiline ""quoted""
text"
```

</td>
</tr>
</table>

---

### Symbol Clutter

TYON files are implicitly maps and do not require brackets.  
Keys do not require quotes unless they contain breaking characters such as whitespace.  
Commas are not used between items.

<table>
<tr>
<th>JSON</th>
<th>TYON</th>
</tr>
<tr>
<td>

```json
{
    "first": 1,
    "second": "two",
    "third": "hello world",
    "fourth key": 4
}
```

</td>
<td>

```lisp
first = 1
second = two
third = "hello world"
"fourth key" = 4
```

</td>
</tr>
</table>

---

### Decoupling Syntax and Data Formats

Recommended data formats for booleans, numbers, etc. are separate from the main specification, and are only made for easier interoperability between systems.

---

## The TYON CLI

### Usage

```
tyon <command>
```

### Commands

```
format   <files>    Format specified files.
to-json  <files>    Convert files to JSON, the output file name is [input file name].json
validate <files>    Validate specified files.

debug    <files>    Print debug information for the specified files.

help                Print help information and exit.
version             Print program version and exit.
```

### Building From Source

The TYON CLI is implemented in [Zig](https://ziglang.org/), last compiled with 0.11.0-dev.2371+a31450375.

You will need [a build of Zig master](https://ziglang.org/download/) to build the CLI.

```
git clone https://github.com/defiant00/tyon
cd tyon
zig build -Doptimize=ReleaseSafe
```
