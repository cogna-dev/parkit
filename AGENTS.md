# AGENTS

## Engineering Rules

1. ANTLR grammar fixtures used by MoonBit tests must live as standalone `.g4` files under repository-managed resource directories. Do not add or keep large grammar bodies as inline `.mbt` string concatenations.
2. Tests must consume grammar fixtures through a dedicated package boundary with a minimal public surface. Keep resource loading and fixture catalog details behind that package.
3. Prefer hierarchical package structure with small interfaces and deep implementations. Each package should expose only the minimum public definitions required by its callers.
4. Every public function added or changed in this repository must carry documentation that covers its purpose, a short usage example, and the main caveats or invariants callers need to know.
5. When MoonBit runtime file I/O is not portable across targets, use repository-local build automation such as `pre-build` resource embedding so the `.g4` file remains the source of truth.