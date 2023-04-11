# Typed Object Notation | [Specification](SPECIFICATION.md) | [Data Formats](FORMAT.md)

AKA, can we be simpler and more compact than JSON without sacrificing readability.

Implemented in [Zig](https://ziglang.org/), last compiled with 0.11.0-dev.2371+a31450375.

---

## Comparison with JSON

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

### Less Punctuation

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

### Escaping Strings

Strings can span multiple lines and everything is literal except for `"` which is escaped as `""`

<table>
<tr>
<th>JSON</th>
<th>TYON</th>
</tr>
<tr>
<td>

```json
"regex": "\\[[0-9]+\\]\\.[0-9]+",
"multiline": "some\n\tindented\nmultiline\ntext"
```

</td>
<td>

```lisp
regex = "\[[0-9]+\]\.[0-9]+"
multiline =
"some
    indented
multiline
text"
```

</td>
</tr>
</table>

---

## The TYON CLI
