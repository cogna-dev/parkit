# ANTLR Example

This example demonstrates the end-to-end workflow:

1. Write a `.g4` grammar.
2. Generate a typed package with `parkit generate antlr --out ...`.
3. Use `@hello.parse(...)` in application code.

## Files

- `grammar/hello.g4`: source grammar
- `hello/`: generated typed package (checked in)
- `app/main.mbt`: small app using `@hello.parse(...)`
- `app/moon.pkg`: app package manifest

## Regenerate Generated Package

From `examples/`:

```bash
../parkit generate antlr ./antlr/grammar/hello.g4 --out ./antlr/hello
```

## Run Example Tests

From the repository root:

```bash
moon test --manifest-path examples/moon.mod.json --package cogna-dev/parkit-examples/antlr/hello --no-render
moon test --manifest-path examples/moon.mod.json --package cogna-dev/parkit-examples/antlr/app --no-render
```

## Run Example App

From the repository root:

```bash
moon run --manifest-path examples/moon.mod.json antlr/app
```
