# MoonBit Appendix

Read this appendix only when the current slice is MoonBit (`.mbt`, `moon.mod.json`, `moon.pkg.json`).

## Focus Checks

- The root entry file acts as a package facade while also accumulating core business implementation
- Directories and files are not organized by capability, so `.mbt` files keep growing
- `pub` declarations are too broad and leak internal structures, helper functions, or transitional representations across packages
- Core paths still pass around naked `String`, `Int`, or low-level error text instead of domain meaning
- A file or module name uses multiple words, but part of the name only repeats parent meaning
- Tests are too far from the implementation, or large test files are not split by behavior
- Structural changes require updates to `moon.mod.json` or `moon.pkg.json`, but there is no clear boundary reason for doing so

## Instructions

1. Treat the top-level entry file as the package facade; beyond required exports, do not keep piling primary implementation into the root entry.
2. Split large files by capability into subdirectories or adjacent `.mbt` files. Names should state responsibility directly and should not repeat parent meaning.
3. Prefer narrower visibility by default, and mark only real cross-package contracts as `pub`; do not turn internal helper layers into public APIs.
4. Organize dependencies through stable package facades and public entry points so callers do not depend directly on internal file layout.
5. If a file or module name contains multiple words, first see whether renaming it, sinking it, or splitting it further can shorten the name. Keep multi-word names only when they clearly reduce ambiguity.
6. Use domain types, enums, or structs to encode core constraints instead of making naked strings and magic numbers act as implicit protocol.
7. Collapse parsing, IO, platform, or third-party errors into domain errors at boundaries instead of exposing low-level details directly to upper layers.
8. Delete mirror forwarding files and responsibility-free directories; keep exactly one layer for each concept.
9. Keep white-box tests close to the implementation with nearby `test` blocks or adjacent test files; split larger behavioral tests by workflow or error family.
10. Update `moon.mod.json` or `moon.pkg.json` only when dependencies, package boundaries, backend targets, or build configuration genuinely changed.

## Validation

- `moon fmt`
- `moon check`
- `moon test`
- If the repository depends on interface artifacts or documentation indexes, also run `moon info`
