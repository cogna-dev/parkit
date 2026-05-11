# TypeScript Appendix

Read this appendix only when the current slice is TypeScript, JavaScript, React, or Node.

## Focus Checks

- `index.ts` or a barrel file carries business logic
- A parent module only forwards a single path or repeats re-exports
- The same concept still exists as both `foo.ts` and a `foo/` directory module
- `export *`, wide exports, or intermediate types make callers depend on internal shapes
- A legacy service file, legacy barrel, or legacy directory entry was emptied into an `export {}`-style compatibility shell
- Imports depend on `../../`-style relative paths that change when directory depth changes
- One file mixes orchestration, data transforms, IO, side effects, and UI framework details
- `any`, `unknown as`, or naked `string` / `number` values flow through core paths without domain meaning
- A file or module name uses multiple words, but part of the name only repeats parent meaning
- Large `*.test.ts` or `*.spec.ts` files are still organized as a time-ordered pile instead of by behavior

## Instructions

1. Keep `index.ts` and barrel files limited to re-exports or facades; do not place business logic there.
2. Split oversized files by capability while keeping names local to their directory; once a file lives under a parent folder, do not repeat the parent prefix in the file name.
3. Keep file scope private by default; export only facades, domain types, and a small number of stable constants.
4. Prefer `export type` for pure types; use `export *` carefully so internal structure does not become public contract.
5. If the project already has a root alias, prefer stable alias imports such as `@/foo/bar` over climbing paths like `../../bar`. If there is no alias, still prefer a stable facade or package entry over turning relative directory layout into part of the contract.
6. Delete shallow parent wrappers unless they truly aggregate multiple child modules, hide routing strategy, or materially narrow entry points.
7. Do not leave old paths behind as `export {}`, empty files, or compatibility layers with no responsibility. If an old entry must remain, give it a clear migration or aggregation role and explain why it cannot be deleted yet.
8. If a file or module name contains multiple words, first see whether renaming it, sinking it, or splitting it further can shorten the name. Keep multi-word names only when they clearly reduce ambiguity.
9. Convert low-level errors from `fetch`, `axios`, database drivers, schema validators, and similar boundary dependencies into domain errors.
10. Replace naked primitives and loose objects on core paths with discriminated unions, domain objects, or more specific interfaces.
11. Keep white-box tests colocated where possible; split larger behavioral tests by workflow, error family, or input family.
12. Add TSDoc to stable exports explaining purpose, examples, and caveats.

## Validation

- The repository's existing formatter
- The repository's existing lint or typecheck
- The closest unit or integration tests for the current slice
- If React or rendering code changed, run an extra typecheck
- If only typecheck is possible, explain why the current slice lacks a behavior-closer validation path
