# TYON Recommended Data Formats 1.0.0

The following are recommended data formats for interoperability between systems.  
It is recommended to always treat strings as strings, and only interpret literals.

## Boolean

The values `true` and `false`.

```
first = true
second = false
```

## Null

The value `null`.

```
null-value = null
```

## Numeric

All numbers can start with a `-` and contain a `.`  
If the number starts with `-`, the value is first calculated as unsigned and then negated.  
If present, the `.` must be between two digits.  
`_` can be used as a digits separator and must be between two digits.

### Binary

Starts with `0[bB]`, digits are `[01]`.

```lisp
val-1 = 0b1_1  ;  3
val-2 = -0B100 ; -4
val-3 = 0b10.1 ;  2.5
```

### Octal

Starts with `0[oO]`, digits are `[0-7]`.

```lisp
val-1 = 0o107  ;  71
val-2 = -0o1_3 ; -11
val-3 = 0o23.4 ;  19.5
```

### Decimal

Digits are `[0-9]`.

```lisp
val-1 = 1_234.567
val-2 = -42.42
```

### Hexadecimal

Starts with `0[xX]`, digits are `[0-9a-fA-F]`.

```lisp
val-1 = 0xf_f ; 255
val-2 = -0XA  ; -10
val-3 = 0xC.4 ;  12.25
```

## Date and Time

[RFC 3339](https://www.rfc-editor.org/rfc/rfc3339) formatted date and time, except replacing the `T` with another character is not permitted.

```lisp
date = 2023-01-03                     ; January 3, 2023
time-1 = 17:10:00-07:00               ; 17:10:00 UTC - 7
time-2 = 00:10:00Z                    ; 00:10:00 UTC
date-time = 2023-01-03T17:10:00-07:00 ; January 3, 2023 at 17:10:00 UTC - 7
```
