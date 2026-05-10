# Rust Appendix

Read this appendix only when the current slice is Rust or a Cargo workspace.

## Focus Checks

- `mod.rs`, `lib.rs`, or `main.rs` accumulates business implementation instead of staying an entry point or facade
- A large `impl` mixes orchestration, persistence, parsing, validation, or serialization
- A parent module only forwards `child::x()` calls or repeats `pub use`
- The same concept still exists as both `foo.rs` and a `foo/` directory module
- `pub` or `pub(crate)` has spread too far, leaking internal types and transitional structures
- Imports depend on fragile ancestor paths such as `use super::super::...`
- A file or module name uses multiple words, but part of the name only repeats parent meaning
- Large test files are far away from the implementation and hard to navigate by behavior

## Instructions

1. Keep `mod.rs` focused on module declarations, re-exports, or facades; do not pile business logic into entry layers.
2. Split large `impl` blocks by capability into files such as `read.rs`, `write.rs`, or `validate.rs`, but do not create thin shells that only forward calls.
3. Widen visibility gradually from private → `pub(super)` → `pub(crate)` → `pub`, and only promote items when a real cross-boundary need appears.
4. Prefer stable paths from the crate root, such as `use crate::foo::bar`, instead of `use super::super::bar`, unless a local test module or language boundary makes that unavoidable.
5. Delete shallow parent wrappers and duplicated `pub use` unless they genuinely reduce the number of entry points callers must understand.
6. If a file or module name contains multiple words, first see whether renaming it, sinking it into the parent module, or splitting it further can shorten the name. Keep multi-word names only when they clearly reduce ambiguity.
7. Replace naked `String`, `usize`, and `io::Error` propagation across module boundaries with domain types and domain errors.
8. Prefer white-box tests in `#[cfg(test)] mod tests`; split large integration-style tests by workflow or error domain.
9. Add doc comments to stable `pub` or `pub(crate)` APIs that explain purpose, examples, and caveats.

## Validation

- `cargo fmt`
- `cargo clippy` or the repository's established lint
- The closest `cargo test` for the current slice
- If features, workspace members, or targets limit validation, state the exact validation scope
