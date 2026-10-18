## [Unreleased]

- Fixed the JSON Patch `move` operation overwriting the item at its target array index instead of inserting before it, which corrupted arrays when reordering their items. [RFC 6902 section 4.4](https://datatracker.ietf.org/doc/html/rfc6902#section-4.4) defines `move` as a `remove` followed by an `add`, and [section 4.1](https://datatracker.ietf.org/doc/html/rfc6902#section-4.1) says that when an `add` targets an array index "a new value is inserted into the array at the specified index".
- Fixed the JSON Patch `add` operation rejecting an array index equal to the length of the array. [RFC 6902 section 4.1](https://datatracker.ietf.org/doc/html/rfc6902#section-4.1) only requires that the specified index "MUST NOT be greater than the number of elements in the array", so an index equal to the length is valid and appends to the array.
- Fixed the JSON Patch `move` and `copy` operations padding an array with `nil` when their target index was past the end of the array. Both are defined in terms of `add` (RFC 6902 [section 4.4](https://datatracker.ietf.org/doc/html/rfc6902#section-4.4) and [section 4.5](https://datatracker.ietf.org/doc/html/rfc6902#section-4.5)), whose index "MUST NOT be greater than the number of elements in the array" ([section 4.1](https://datatracker.ietf.org/doc/html/rfc6902#section-4.1)). Under [section 5](https://datatracker.ietf.org/doc/html/rfc6902#section-5), violating a normative requirement means the patch "SHALL NOT be deemed successful", so they now raise a `JSONP3::Patch::Error`, as `add` does.
- Fixed the JSON Patch `move` and `copy` operations replacing the whole document with the moved or copied value when the parent of the target does not exist. [RFC 6902 section 4.1](https://datatracker.ietf.org/doc/html/rfc6902#section-4.1) says the object or array being added to "does need to exist, and it remains an error for that not to be the case", and `move` and `copy` inherit that from `add` ([section 4.4](https://datatracker.ietf.org/doc/html/rfc6902#section-4.4) and [section 4.5](https://datatracker.ietf.org/doc/html/rfc6902#section-4.5)). They now raise a `JSONP3::Patch::Error`.
- Fixed the JSON Patch `move` operation silently discarding the moved value when the parent of the target is neither an array nor an object. [RFC 6902 section 4.1](https://datatracker.ietf.org/doc/html/rfc6902#section-4.1) says the target location "MUST reference one of" the document root, a member of an existing object or an element of an existing array, and [section 5](https://datatracker.ietf.org/doc/html/rfc6902#section-5) requires an operation that cannot succeed to fail the patch. It now raises a `JSONP3::Patch::Error`, as `add` and `copy` already did.
- Fixed the JSON Patch `copy` operation not copying the value when appending it to an array with `-`, so the copy and its source shared nested arrays and objects. [RFC 6902 section 4.5](https://datatracker.ietf.org/doc/html/rfc6902#section-4.5) defines `copy` as an `add` of the value at `from`, which leaves the document with two independent values. With the shared objects, a later operation on one changed the other, and copying an array to its own end made the array contain itself.
- Fixed JSON Patch operations targeting an object member whose name is a non-negative integer, like `/foo/1`. `add`, `copy` and `move` wrote the value under an integer key instead of the member name, duplicating the member when it already existed, `replace` added an integer key alongside the existing member, `remove` did nothing, and `move` left its source member in place. Under [RFC 6901 section 4](https://datatracker.ietf.org/doc/html/rfc6901#section-4), when a reference token is applied to an object, "the new referenced value is the object member with the name identified by the reference token". A token is only read as an array index when it is applied to an array. [RFC 8259 section 4](https://datatracker.ietf.org/doc/html/rfc8259#section-4) says "A name is a string" and "The names within an object SHOULD be unique", so a second key for the same name produced JSON with duplicate member names.
- Fixed JSON Pointer resolution of reference tokens starting with `#`. Previously a token such as `#foo` resolved to the string `"foo"` when the object had a `foo` member, and `#1` resolved to the integer `1` against an array, so JSON Patch `remove`, `replace`, `copy`, `move` and `test` operations could act on a location that does not exist. RFC 6901 section 4 says "If the currently referenced value is a JSON object, the new referenced value is the object member with the name identified by the reference token", so `#foo` now refers only to a member named `#foo`. RFC 6902 sections 4.2 and 4.3 say "The target location MUST exist for the operation to be successful", and sections 4.4 and 4.5 say "The "from" location MUST exist for the operation to be successful". Relative JSON Pointers ending in `#` still resolve to a member name or array index. `JSONP3::Pointer#to` now returns a `JSONP3::RelativePointer::IndexPointer` for them.
- Fixed JSON Patch `add` and `replace` operations inserting their value into the target document by reference. Later operations in the same patch, or changes to the result, could modify the operation's value, so applying a patch a second time gave a different result. The value is now deep copied each time it is inserted, as `copy` already does.
- Fixed JSON Pointer parsing of `~` not followed by `0` or `1`. Previously `/~2` was accepted and resolved to a member named `~2`. RFC 6901 section 3 defines `escaped = "~" ( "0" / "1" )` and says "It is an error condition if a JSON Pointer value does not conform to this syntax", so such pointers now raise a `JSONP3::Pointer::SyntaxError`.
- Fixed Relative JSON Pointers ending in `#` resolving to an array index that is out of range. Previously `0#` from `/foo/7`, or `0+5#` from `/foo/1`, resolved to `7` or `6` against a three item array. Section 4 of the Relative JSON Pointer draft says "If the referenced value is an item within an array, then the final evaluation result is the value's index position within the array", and there is no item at those indexes, so they now resolve to the default value, as a missing object member already did.
- Fixed Relative JSON Pointer index offsets applied to values that are not array items. Previously `0+1` from `/o/1` resolved to the member `2` of the object `o`, and an offset from a member name such as `/highly/nested`, or from the document root, was ignored. Section 4 of the Relative JSON Pointer draft says "If the current referenced value is not an item of an array, then evaluation fails". `JSONP3::Pointer#to` now raises a `JSONP3::Pointer::IndexError` when the offset is applied to the document root or to a member name, and the resulting pointer resolves to the default value when the offset is applied to an object member with a numeric name.
- Fixed Relative JSON Pointers ending in `#` that reach the document root, such as `1#` from `/foo`, raising Ruby's `IndexError` instead of a `JSONP3::Pointer::IndexError`. Section 4 of the Relative JSON Pointer draft says "If the current referenced value is the root of the document, then evaluation fails", so `JSONP3::Pointer#to` still fails, but now with the same error class it uses for an origin that exceeds the root.

## [1.0.0] - 2026-04-21

This major release includes breaking changes. No new features have been added.

- Changed the JSONPath tokenizer and parser. The new parser is faster and more JIT friendly.
- Changed our module and class layout to better separate JSONPath, JSON Pointer and JSON Patch, and to remove "stuttering". For example, previously we had `JSONP3::JSONPathEnvironment` and `JSONP3::JSONPathNode`. Now we have `JSONP3::Path::Environment` and `JSONP3::Path:Node`. This ASCII tree view show our new module and class hierarchy.
    
    ```
    module JSONP3
    ├── class Error < StandardError
    │
    ├── module Path                              # JSONPath (RFC 9535)
    │   ├── class Environment                    
    │   ├── class Query    
    │   ├── class Node
    │   ├── class NodeList
    │   ├── class Error < JSONP3::Error
    │   │    ├── class SyntaxError
    │   │    ├── class TypeError
    │   │    ├── class NameError
    │   │    └── class RecursionError
    │   ├── def self.find
    │   ├── def self.find_enum
    │   ├── def self.compile
    │   ├── def self.match
    │   ├── def self.match?
    │   └── def self.first
    │
    ├── class Pointer                            # JSON Pointer (RFC 6901)
    │   ├── class Error < JSONP3::Error
    │   │   ├── class IndexError
    │   │   ├── class SyntaxError
    │   │   └── class TypeError
    │   └── def self.resolve
    │
    └── class Patch                              # JSON Patch (RFC 6902)
        ├── class OpAdd                          
        ├── class OpCopy                          
        ├── class OpMove                          
        ├── class OpRemove                       
        ├── class OpReplace                       
        ├── class OpTest                       
        ├── class Error < JSONP3::Error
        │   └── class TestFailure
        └── def !self.apply
    ```

    Note that top-level convenience methods - like `JSONP3.find` and `JSONP3.compile` - are unchanged. Most dependent projects should only need to change error class names.

- Renamed `JSONP3::JSONPath` to `JSONP3::Path::Query`.
- Renamed `JSONP3::RecursiveDescentSegment` to `JSONP3::Path::DescendantSegment` to better match the spec.
- Renamed `JSONP3.apply` to `JSONP3.apply!`, `JSONP3::Patch#apply` to `JSONP3::Patch#apply!` and `JSONP3::Patch::Op#apply` to `JSONP3::Patch::Op#apply!`. There is no "safe", non mutating version of `apply!`.
- Dropped support for Ruby 3.1 and 3.2, they are end of life.

## [0.4.1] - 2025-03-18

- Fixed `JSONPathSyntaxError` claiming "unbalanced parentheses" when the query has balanced brackets.

## [0.4.0] - 2025-02-10

- Added `JSONP3.find_enum`, `JSONP3::JSONPathEnvironment.find_enum` and `JSONP3::JSONPath.find_enum`. `find_enum` is like `find`, but returns an Enumerable (usually an Enumerator) of `JSONPathNode` instances instead of a `JSONPathNodeList`. `find_enum` can be more efficient for some combinations of query and data, especially for large data and recursive queries.
- Added `JSONP3.match`, `JSONP3.match?`, `JSONP3.first` and equivalent methods for `JSONPathEnvironment` and `JSONPath`.

## [0.3.2] - 2025-01-29

- Fix normalized string representations of node locations as returned by `JSONPathNode.path`.
- Fix canonical string representations of instances of `JSONPath`, as returned by `to_s`.
- Fixed filter queries with multiple bracketed segments. Previously we were failing to tokenize queries like `$[?@[0][0]]`. See [#15](https://github.com/jg-rp/ruby-json-p3/issues/15).

## [0.3.1] - 2024-12-05

- Fix JSON Patch `move` and `copy` operations when using the special JSON Pointer token `-`.

## [0.3.0] - 2024-11-25

- Implement JSON Pointer and Relative JSON Pointer
- Implement JSON Patch

## [0.2.1] - 2024-10-24

- Rename project and gem

## [0.2.0] - 2024-10-24

- Initial release
