# parkit

A nom-like parser combinator framework for [MoonBit](https://www.moonbitlang.com/), inspired by Rust's [nom](https://github.com/rust-bakery/nom).

[![CI](https://github.com/cogna-dev/parkit/actions/workflows/ci.yml/badge.svg)](https://github.com/cogna-dev/parkit/actions/workflows/ci.yml)

## Features

- **Same API as Rust nom** — `tag`, `take_while`, `many0`, `many1`, `alt`, `pair`, `preceded`, `terminated`, `delimited`, `opt`, `verify`, `map`, `map_res`, `separated_list0/1`, and more
- **JSON parser sample** — a full [ECMA-404](https://ecma-international.org/publications-and-standards/standards/ecma-404/) compliant JSON parser built with the framework
- **Rust nom reference tests** — the same JSON test cases run against Rust nom, proving identical results
- **MoonBit benchmarks** — performance benchmarks using MoonBit's built-in benchmark runner
- **Rust criterion benchmarks** — performance comparison with a native Rust nom implementation

## Project layout

```
src/
  nom/        — the parkit parser combinator library (cogna-dev/parkit/nom)
  json/       — JSON parser built with parkit (cogna-dev/parkit/json)
  benchmark/  — MoonBit benchmarks
reference/
  nom-json/   — Rust nom reference JSON parser (cross-language validation + benchmarks)
```

## Quick start

```moonbit
// Tag: match an exact string
let p = @nom.tag("hello")
assert_eq!(p.parse("hello world"), Ok((" world", "hello")))

// many0: repeat zero or more times
let nums = @nom.many0(@nom.digit1())
assert_eq!(nums.parse("123 456"), Ok((" 456", ["123"])))

// JSON parsing
let json = @json.parse("{\"key\": 42}")
// => Ok(Object([("key", Number(42.0))]))
```

## Running tests

```bash
moon test
```

## Running benchmarks

```bash
# MoonBit benchmarks (moon bench)
moon bench

# Rust criterion benchmarks
cargo bench --manifest-path reference/nom-json/Cargo.toml
```

## Benchmark results

Benchmarks run on `ubuntu-latest`. MoonBit targets the wasm-gc backend; Rust
uses [criterion.rs](https://github.com/bheisler/criterion.rs) with the native
release build. The input is the same 3-object JSON array used in both suites.

| Benchmark | MoonBit (wasm-gc) | Rust nom (native) |
|---|---|---|
| `json_parse` (3-object array) | 431.20 µs | 5.53 µs |

> **Note:** MoonBit compiles to wasm-gc and runs in a wasm runtime; the
> difference reflects runtime overhead rather than algorithmic differences.
> Both parsers implement the same combinator logic and produce identical results.

## Reference testing (Rust nom)

`reference/nom-json/` contains an equivalent JSON parser built with Rust
[nom 8](https://docs.rs/nom). The test suite in
`reference/nom-json/src/lib.rs` mirrors every case in
`src/json/json_test.mbt`, ensuring both implementations produce the same
result for every input.

```bash
cargo test --manifest-path reference/nom-json/Cargo.toml
```

## Core combinators

| Combinator | Description |
|---|---|
| `tag(s)` | Match exact literal string |
| `satisfy(pred)` | Match single char satisfying predicate |
| `char_(c)` | Match exact character |
| `take_while(pred)` | Take chars while predicate holds (0+) |
| `take_while1(pred)` | Take chars while predicate holds (1+) |
| `take(n)` | Take exactly n characters |
| `take_while_m_n(m,n,pred)` | Take m..n chars while predicate holds |
| `many0(p)` | Run parser 0 or more times |
| `many1(p)` | Run parser 1 or more times |
| `alt(parsers)` | Try each parser; return first success |
| `pair(a, b)` | Run two parsers, return tuple |
| `tuple3(a, b, c)` | Run three parsers, return tuple |
| `preceded(skip, keep)` | Skip prefix, keep result |
| `terminated(keep, skip)` | Keep result, skip suffix |
| `delimited(open, p, close)` | Keep middle between delimiters |
| `separated_list0(sep, p)` | 0+ items separated by sep |
| `separated_list1(sep, p)` | 1+ items separated by sep |
| `opt(p)` | Optional: `Some(v)` or `None` |
| `map(p, f)` | Transform output |
| `map_res(p, f)` | Fallibly transform output |
| `verify(p, pred)` | Check output satisfies predicate |
| `ws(p)` | Skip leading whitespace, then run p |
| `context(msg, p)` | Add context to error messages |
| `eof()` | Match end of input |
| `success(v)` | Always succeed with value |
| `fail(msg)` | Always fail |
| `double()` | Parse floating-point number |
| `int()` | Parse signed integer |
| `uint()` | Parse unsigned integer |
| `digit0/1()` | Parse decimal digits |

## References

1. [ECMA-404 JSON specification](https://ecma-international.org/publications-and-standards/standards/ecma-404/)
2. [nom — Rust parser combinator library](https://github.com/rust-bakery/nom)
3. [criterion.rs — Rust benchmarking library](https://github.com/bheisler/criterion.rs)
4. [MoonBit benchmarks documentation](https://docs.moonbitlang.com/en/latest/language/benchmarks.html)

## License

Apache-2.0
