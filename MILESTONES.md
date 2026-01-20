# Milestones

## M1: flight-lint Core (Tasks 001-005)

Build the `flight-lint` CLI tool with tree-sitter integration, rule loading, and output formatting.

**Exit Criteria**: Can run `flight-lint test.rules.json src/` and get formatted output with pass/fail counts.

**Validation**: Manual testing with fixture files. `.flight/validate-all.sh` passes.

## M2: Compiler Integration (Tasks 006-008)

Update `flight-domain-compile` to generate `.rules.json` files alongside `.md` files. Support new `type: ast` check format in `.flight` YAML.

**Exit Criteria**: Running `flight-domain-compile javascript.flight` produces `javascript.md` + `javascript.rules.json`.

**Validation**: Generated `.rules.json` is valid JSON and passes schema validation.

## M3: Domain Migration (Tasks 009-011)

Convert JavaScript domain from grep-based to AST-based validation. Write tree-sitter queries for existing rules.

**Exit Criteria**: `javascript.rules.json` can lint actual JavaScript code with zero false positives from strings/comments.

**Validation**: `flight-lint javascript.rules.json fixtures/` produces correct results on test fixtures.

## M4: Integration & Documentation (Tasks 012-013)

Integrate `flight-lint` into the Flight workflow. Update documentation. Create migration guide.

**Exit Criteria**: `flight-lint --auto .` works. FLIGHT.md documents the new system.

**Validation**: End-to-end workflow works: `.flight` → compile → `flight-lint` → results.
