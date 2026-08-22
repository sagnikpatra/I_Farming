---
paths:
  - "godot/tests/**"
---

# Test Standards

<!-- Update (2026-08-23): path corrected from the template-default
     `tests/**` to this project's real `godot/tests/**` (no root-level
     `tests/` directory exists) -- it was already firing in practice for
     `godot/tests/unit/*.gd` edits (the matcher appears to key on the
     `tests/` path segment appearing anywhere, not just at the root),
     but this makes the intent explicit rather than relying on that.
     One line below is a documented, deliberate exception in this
     project, not a violation to flag: "must not depend on external
     state (filesystem...)" -- GameEconomy/VillageBoard are wired to
     SaveSystem's real user:// disk persistence with no dependency-
     injected fake layer, so many real tests here do touch real files on
     purpose, cleaned up via RealSavePaths.wipe_all() (see that class's
     own doc comment for the full rationale -- this bug class recurred 6
     times before that utility consolidated the fix). -->

- Test naming: `test_[system]_[scenario]_[expected_result]` pattern
- Every test must have a clear arrange/act/assert structure
- Unit tests must not depend on external state (filesystem, network, database)
- Integration tests must clean up after themselves
- Performance tests must specify acceptable thresholds and fail if exceeded
- Test data must be defined in the test or in dedicated fixtures, never shared mutable state
- Mock external dependencies — tests should be fast and deterministic
- Every bug fix must have a regression test that would have caught the original bug

## Examples

**Correct** (proper naming + Arrange/Act/Assert):

```gdscript
func test_health_system_take_damage_reduces_health() -> void:
    # Arrange
    var health := HealthComponent.new()
    health.max_health = 100
    health.current_health = 100

    # Act
    health.take_damage(25)

    # Assert
    assert_eq(health.current_health, 75)
```

**Incorrect**:

```gdscript
func test1() -> void:  # VIOLATION: no descriptive name
    var h := HealthComponent.new()
    h.take_damage(25)  # VIOLATION: no arrange step, no clear assert
    assert_true(h.current_health < 100)  # VIOLATION: imprecise assertion
```
