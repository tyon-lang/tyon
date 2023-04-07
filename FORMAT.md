# TYON Recommended Data Formats 1.0.0

The following are recommended data formats for interoperability between systems.

These recommendations are not applicable to strings, which are always interpreted literally.

* __boolean__: the values `true` and `false`
* __null__: the value `null`
* __number__: all numbers can start with a `-` and contain a `.`
  * if present, the `.` must be between two digits
  * `_` can be used as a digits separator and must be between two digits
  * __binary__: starts with `0[bB]`, digits are `[01]`
  * __octal__: starts with `0[oO]`, digits are `[0-7]`
  * __decimal__: digits are `[0-9]`
  * __hexadecimal__: starts with `0[xX]`, digits are `[0-9a-fA-F]`
