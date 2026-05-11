MOON ?= moon
MOON_MANIFEST ?= moon.work
CARGO ?= cargo
RUST_MANIFEST ?= reference/nom-json/Cargo.toml

.PHONY: format format-check lint test ci

format:
	$(MOON) fmt --manifest-path $(MOON_MANIFEST)
	$(CARGO) fmt --all --manifest-path $(RUST_MANIFEST)

format-check:
	$(MOON) fmt --check --manifest-path $(MOON_MANIFEST)
	$(CARGO) fmt --all --check --manifest-path $(RUST_MANIFEST)

lint:
	$(MOON) check --manifest-path $(MOON_MANIFEST)
	$(CARGO) check --manifest-path $(RUST_MANIFEST)

test:
	$(MOON) test --manifest-path $(MOON_MANIFEST) --no-render
	$(CARGO) test --manifest-path $(RUST_MANIFEST)

ci: format-check lint test