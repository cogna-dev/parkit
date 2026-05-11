---
name: clean-code
description: >
  Audit, narrow, and verify all relevant code inside the user-given scope so you can refactor
  "working code" into deeper modules with smaller public interfaces.
  Use it for oversized files, mixed responsibilities, fragile import paths, noisy naming,
  and leaked low-level error semantics.
license: MIT
metadata:
  author: yufeiminds
  version: "1.2.1"
---

# Clean Code

Use structural refactors that start with a full inventory and then land changes step by step to reduce complexity without breaking behavior.

## When to Apply

- Handwritten source files are too long, or one module carries multiple reasons to change
- A single function mixes business orchestration with low-level details
- Intermediate types, helper modules, barrels, or facades expose implementation details to callers
- Names repeat parent-level meaning, or the same concept exists as both a flat file and a directory module
- Import paths are too sensitive to directory depth, such as `super::super` or `../../`
- Errors leak IO, network, parsing, or framework details directly
- Test files have grown too large to navigate by behavior

## Do Not Apply

- The task is just a one-off local bug with no structural debt
- The current iteration forbids structural changes
- There is no minimal validation path to confirm behavior stays the same

## Instructions

1. Analyze all relevant code inside the user-given scope, not just the current file or smallest slice: implementations, entry points, exports, import paths, callers, tests, directory layout, dead code, and empty directories are all in scope.
2. After the full inventory, build a todo list that covers the relevant entry points, implementations, callers, exports, tests, and cleanup work for this round; execute it in dependency and risk order.
3. Aim for deep modules: hide more implementation complexity behind fewer, more stable interfaces instead of splitting code for its own sake.
4. Narrow visibility, exports, and import paths by default; callers should depend on stable root-package paths instead of climbing through relative directories or parent modules.
5. Delete shallow wrappers, mirror modules, duplicated logic, empty directories, and empty compatibility stubs; keep exactly one consistent layer for each concept. If an old path must remain temporarily, make it a facade with a clear responsibility and migration purpose, not an empty shell.
6. Names must state responsibility directly. If a file or module name contains multiple words, first test whether renaming it, moving it under the parent module, or splitting it further can reduce it to a shorter local name. Keep multi-word names only when they materially reduce ambiguity.
7. Map low-level errors into domain errors, and replace naked primitive types on core paths with semantically meaningful types.
8. Refactor large test files along with implementation code: keep white-box tests close to the implementation, and split broader behavioral tests by one organizing dimension instead of leaving them as a flat pile.
9. Run the closest validation you can after each completed item; when you cannot run it, explain why, what scope is affected, and what residual risk remains.

## Restructuring Heuristics

- Split files by responsibility boundaries, not by trying to equalize line counts; entry files should only declare modules, re-export symbols, or provide facades.
- Keep a parent module only when it aggregates multiple child modules, hides strategy, or unifies a contract; otherwise delete the forwarding layer.
- Do not leave old entry points behind as `export {}`, empty barrels, or compatibility shells with no responsibility; either delete dead paths or keep a stable facade with an explicit migration role.
- Prefer stable root-package paths or stable aliases for imports instead of climbing directories with relative paths; the refactored path should be more stable, not more dependent on the current folder depth.
- Multi-word file names are not the default; first see whether renaming, sinking, or further splitting can produce shorter local meaning.
- Split large test files by a single dimension such as workflow, error cases, or input family; keep white-box tests close to implementation where possible.
- Add documentation comments to stable exported items to explain purpose, examples, and caveats.

## Language Guides

- [Rust](./assets/rust.md)
- [TypeScript](./assets/typescript.md)
- [MoonBit](./assets/moonbit.md)

Only open the appendix for the language that is genuinely involved in the current slice; do not load every guide at once.

## References

- [Clean Code Summary](./references/clean-code.md)
- [A Philosophy of Software Design Summary](./references/a-philosophy-of-software-design.md)
- Deep Module: when judging whether a split is valid, first ask whether it actually reduces the number of concepts the caller must understand.

These references are supporting material only; prioritize the current repository's structural simplification and validation needs.

## Output

The final response should include:

1. Change summary
2. Key structural decisions
3. Compatibility notes
4. Validation results
5. Residual risks

## Guardrails

- Prefer the smallest necessary change, but the analysis must still cover all relevant code inside the user-given scope
- Do not place business implementation in entry files
- Do not make breaking API changes without explicit approval
- Do not mistake a higher file count for better design
