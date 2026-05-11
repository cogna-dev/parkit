# JSON Example

This example shows a JSON parser built with `cogna-dev/parkit/nom`.

## Files

- `json.mbt`: parser implementation and `JsonValue` model
- `json_test.mbt`: black-box tests for parsing behavior
- `moon.pkg`: package imports for this example

## Run Tests

From the repository root:

```bash
moon test --manifest-path examples/moon.mod.json --package cogna-dev/parkit-examples/json --no-render
```

## Notes

- This package is part of the `examples` module (`examples/moon.mod.json`).
- It is intended as a practical parser composition reference.
