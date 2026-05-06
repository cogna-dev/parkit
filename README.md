# parkit

A MoonBit parsing toolkit for two user workflows: composing parsers with nom-like combinators, or turning `.g4` grammars into generated parseable packages.

[![CI](https://github.com/cogna-dev/parkit/actions/workflows/ci.yml/badge.svg)](https://github.com/cogna-dev/parkit/actions/workflows/ci.yml)

## Highlights

- **Rust nom–shaped combinators** — `tag`, `take_while`, `many0`, `many1`, `alt`, `pair`, `preceded`, `terminated`, `delimited`, `opt`, `verify`, `map`, `map_res`, `separated_list0/1`, and more
- **ANTLR CLI workflow** — run `parkit generate antlr ./hello.g4`, import the generated package, and call `@hello.parse(...)`
- **Evidence-driven compatibility** — repository-managed fixtures, snapshots, suite catalogs, and CI-backed contract tests
- **Cross-language validation** — Rust nom reference tests and benchmarks keep the combinator surface honest
- **MoonBit-native workflow** — `make ci` drives format, static checks, and tests across MoonBit and Rust reference code

## Two Surfaces

### `src/nom/`

The original parkit surface: a nom-like combinator toolkit for directly composing parsers in MoonBit.

### `src/antlr/`

The user-facing flow is straightforward: write a `.g4`, run `parkit generate antlr`, import the generated package, and call `parse` in normal MoonBit code.

See the package guide: [src/antlr/READMD.md](src/antlr/READMD.md)

## Project layout

```
src/
  nom/            — the parkit parser combinator library (cogna-dev/parkit/nom)
  antlr/          — frontend, runtime, CST, typed CST, fixtures, and specs
examples/
  antlr/          — generated-package ANTLR sample built with `parkit generate antlr --out`
  json/           — JSON parser sample built with parkit (not published to mooncakes)
  benchmark/      — MoonBit benchmarks (not published to mooncakes)
reference/
  nom-json/       — Rust nom reference JSON parser (cross-language validation + benchmarks)
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

## ANTLR Quick Tour

The shortest path on the ANTLR side is:

1. Write a normal `.g4` grammar.
2. Run `parkit generate antlr ./hello.g4 --out ./src/hello`.
3. Import the generated package with an alias such as `@hello`.
4. Call `@hello.parse(...)` and use typed fields such as `fields.id_token.lexeme`.

The full end-to-end guide lives in [src/antlr/READMD.md](src/antlr/READMD.md). A checked-in sample project lives in [examples/antlr/app/main.mbt](examples/antlr/app/main.mbt) and its grammar source in [examples/antlr/grammar/hello.g4](examples/antlr/grammar/hello.g4). The deeper design and contract documents stay indexed in [src/antlr/spec/README.md](src/antlr/spec/README.md).

## Running tests

```bash
moon test --manifest-path moon.work
```

## Engineering checks

```bash
make format        # rewrite MoonBit and Rust formatting in place
make format-check  # verify formatting without changing files
make lint          # MoonBit static checks plus Rust compile checks
make test          # MoonBit workspace tests plus Rust reference tests
make ci            # format-check, lint, then test
```

## Running benchmarks

```bash
# MoonBit benchmarks (native target)
moon bench --manifest-path moon.work --target native

# Rust criterion benchmarks
cargo bench --manifest-path reference/nom-json/Cargo.toml
```

## Benchmark results

Benchmarks run on `ubuntu-latest`. MoonBit targets the native backend; Rust
uses [criterion.rs](https://github.com/bheisler/criterion.rs) with a native
release build. Both use the same 3-object JSON array input.

| Benchmark | MoonBit (native) | Rust nom (native) |
|---|---|---|
| `json_parse` (3-object array) | 1.17 ms | 5.53 µs |

> **Note:** The performance difference reflects the overhead of MoonBit's
> runtime and memory model compared to Rust's zero-cost abstractions, not
> algorithmic differences — both parsers implement the same combinator logic
> and produce identical results.

MoonBit native benchmark details:

| Benchmark | Mean | σ | Range |
|---|---|---|---|
| `json_parse` (3-object array) | 1.17 ms | ±6.29 µs | 1.16 ms … 1.19 ms |
| `tag` | 0.21 µs | ±0.00 µs | 0.21 µs … 0.21 µs |
| `take_while1_digits` | 0.43 µs | ±0.00 µs | 0.43 µs … 0.43 µs |
| `separated_list0` | 2.49 µs | ±0.02 µs | 2.47 µs … 2.54 µs |

## Reference testing (Rust nom)

`reference/nom-json/` contains an equivalent JSON parser built with Rust
[nom 8](https://docs.rs/nom). The test suite in
`reference/nom-json/src/lib.rs` mirrors every case in
`examples/json/json_test.mbt`, ensuring both implementations produce the same
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
