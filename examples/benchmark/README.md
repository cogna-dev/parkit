# Benchmark Example

This example benchmarks representative parser workloads.

## Files

- `bench.mbt`: benchmark cases (`json_parse`, `tag`, `take_while1_digits`, `separated_list0`)
- `moon.pkg`: imports for nom, JSON example package, and benchmark runtime

## Run Benchmarks

From the repository root:

```bash
moon bench --manifest-path examples/moon.mod.json --package cogna-dev/parkit-examples/benchmark --target native
```

## Notes

- The benchmark reuses the JSON parser from `examples/json`.
- Use native target for the most stable local benchmark signal.
