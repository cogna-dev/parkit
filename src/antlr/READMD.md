# parkit / antlr

If you already have a `.g4` grammar, this guide answers four questions:

1. How do you write the grammar?
2. How do you generate a package you can import directly?
3. How do you parse input directly?
4. How do you read fields, tokens, and spans in app code?

You do not need to understand internal implementation layers first. For users, the shortest path is:

`.g4` -> `parkit generate antlr` -> `@hello.parse()` -> use typed node

## What You Get

- A standard ANTLR `.g4` grammar.
- A generated MoonBit package directory, by default at `src/<grammar-file-stem>/` in your current project.
- A direct entrypoint: `@hello.parse(input)`.
- Strongly typed fields for application logic, instead of manual parse-tree walking.

## Basic Flow

### 1. Write `.g4`

Write your grammar as usual. No parkit-specific DSL is required.

```g4
grammar Hello;

r : 'hello' ID ;

ID : [a-z]+ ;
WS : [ \r\n\t]+ -> skip ;
```

This grammar generates a typed package whose root is the start rule `r`.

### 2. Generate the Package

From your MoonBit project root, run:

```bash
parkit generate antlr ./hello.g4
```

By default, this command will:

- Read `moon.mod.json` in the current directory.
- Derive output package directory `src/hello/` from `hello.g4`.
- Generate a set of regular MoonBit files there.

If you want to explicitly choose the target directory, add `--out`:

```bash
parkit generate antlr ./hello.g4 --out ./src/generated/hello
```

`--out` must point under the current MoonBit project's source root. For example, if source root is `src`, `./src/generated/hello` is valid, while `./examples/hello` is outside source root and invalid.

In most cases, you only need to care about these files:

- `moon.pkg`
- `types.mbt`
- `parse.mbt`
- `query.mbt`

Other files are package internals. In normal usage, you should not edit them manually.

If you want a complete in-repo example, see [examples/antlr/grammar/hello.g4](examples/antlr/grammar/hello.g4), [examples/antlr/hello/parse.mbt](examples/antlr/hello/parse.mbt), and [examples/antlr/app/main.mbt](examples/antlr/app/main.mbt).

### 3. Parse Input Directly

After generation, import the package in app code and call `parse` directly:

```moonbit
import {
  "your-org/demo/hello" @hello,
}

let root = match @hello.parse("hello abc") {
  Ok(value) => value
  Err(message) => abort(message)
}

ignore(root)
```

The goal is to hide the complexity inside the generated package so call sites only use a clean parse entrypoint.

### 4. Use Typed Nodes in App Code

The key value of the generated package is that grammar rules and tokens are exposed as directly consumable strongly typed fields.

In the `Hello` example, after parsing you get explicit node types and fields:

```moonbit
match root {
  Alt1(fields) => {
    let keyword = fields.hello_token.lexeme
    let name = fields.id_token.lexeme
    let span = fields.span

    ignore(keyword)
    ignore(name)
    ignore(span)
  }
}
```

Besides fields, the generated package also includes common queries:

```moonbit
let first = root.first_token()
let last = root.last_token()
let span = root.span()

ignore(first)
ignore(last)
ignore(span)
```

This is the value of the generated typed node API:

- You read business fields, not slot indexes.
- You get concrete tokens without assembling parse stages yourself.
- You work with rule-level unions that can be matched directly.

## Most Important Generated Files

### `types.mbt`

Defines typed nodes, constructors, and fields for grammar rules. This is the main place you import and pattern-match.

### `parse.mbt`

Provides `parse(input)`, the most common entrypoint for callers.

### `query.mbt`

Provides convenience queries like `span()`, `first_token()`, and `last_token()`.

Other files are support code for the generated package. Unless you are working on the generator itself, you can usually ignore them.

## Usage Tips

### Keep `.g4` as the Source of Truth

Do not manually edit generated package files. The real source of truth is always `.g4`.

### Treat Generated Package as a Checked-in Artifact

If your project needs stable review, diffs, and CI, the practical approach is to check generated packages into the repository instead of generating them ad hoc at runtime.

### Regenerate After Grammar Changes

The simplest workflow is: update `.g4`, then run `parkit generate antlr ./hello.g4` again.

If your project already has a fixed generated-package directory, rerun with the same `--out` path.

## One-line Summary

If the nom track is about writing parsers by hand, this track is about taking an existing `.g4` and getting a MoonBit package that you can call `parse()` on directly.

That is the core user-facing value of `src/antlr/`.