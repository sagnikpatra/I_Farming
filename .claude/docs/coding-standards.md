# Coding Standards

- All game code must include doc comments on public APIs
- Every system must have a corresponding architecture decision record in `docs/architecture/`
- Gameplay values must be data-driven (external config), never hardcoded
- All public methods must be unit-testable (dependency injection over singletons)
- Commits must reference the relevant design document or task ID
- **Commit messages**: Use Conventional Commits format — `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`. Reference the story or task ID in the body (e.g., `Story: EPIC-001-S02`).
- **Verification-driven development**: Write tests first when adding gameplay systems.
  For UI changes, verify with screenshots. Compare expected output to actual output
  before marking work complete. Every implementation should have a way to prove it works.

# Design Document Standards

- All design docs use Markdown
- Each mechanic has a dedicated document in `design/gdd/`
- Documents must include these 8 required sections:
  1. **Overview** -- one-paragraph summary
  2. **Player Fantasy** -- intended feeling and experience
  3. **Detailed Rules** -- unambiguous mechanics
  4. **Formulas** -- all math defined with variables
  5. **Edge Cases** -- unusual situations handled
  6. **Dependencies** -- other systems listed
  7. **Tuning Knobs** -- configurable values identified
  8. **Acceptance Criteria** -- testable success conditions
- Balance values must link to their source formula or rationale

# Testing Standards

## Test Evidence by Story Type

All stories must have appropriate test evidence before they can be marked Done:

| Story Type | Required Evidence | Location | Gate Level |
|---|---|---|---|
| **Logic** (formulas, AI, state machines) | Automated unit test — must pass | `godot/tests/unit/` | BLOCKING |
| **Integration** (multi-system) | Real end-to-end test (e.g. a full `VillageBoard`+`GameEconomy` scene) OR documented playtest | `godot/tests/unit/` -- no separate `integration/` directory exists; this project's convention is real-scene tests living alongside pure-logic ones in the same flat directory | BLOCKING |
| **Visual/Feel** (animation, VFX, feel) | Screenshot + lead sign-off | `production/qa/evidence/` | ADVISORY |
| **UI** (menus, HUD, screens) | Manual walkthrough doc OR interaction test | `production/qa/evidence/` | ADVISORY |
| **Config/Data** (balance tuning) | Smoke check pass | `production/qa/smoke-[date].md` | ADVISORY |

**Update (2026-08-23)**: the Location column previously said
`tests/unit/[system]/`/`tests/integration/[system]/` -- neither matches
this project's real, flat `godot/tests/unit/test_[system].gd` layout
(confirmed against all 51 real test files; no per-system subdirectories,
no separate `integration/` tree). Corrected above.

## Automated Test Rules

- **Naming**: `test_[system].gd` for files, `test_[scenario]_[expected_result]` for
  functions -- matches `.claude/rules/test-standards.md`'s own naming rule and
  every real test file in `godot/tests/unit/` (e.g. `test_villager.gd`,
  `test_decoration_info_card.gd`). **Update (2026-08-23)**: this line
  previously said `[system]_[feature]_test.[ext]` (a `_test` suffix) --
  backwards from this project's actual `test_` prefix convention, and
  disagreed with `test-standards.md`'s own, correct rule. Corrected to
  match reality rather than leave two sibling docs disagreeing.
- **Determinism**: Tests must produce the same result every run — no random seeds, no time-dependent assertions
- **Isolation**: Each test sets up and tears down its own state; tests must not depend on execution order
- **No hardcoded data**: Test fixtures use constant files or factory functions, not inline magic numbers
  (exception: boundary value tests where the exact number IS the point)
- **Independence**: Unit tests do not call external APIs, databases, or file I/O — use dependency injection

## What NOT to Automate

- Visual fidelity (shader output, VFX appearance, animation curves)
- "Feel" qualities (input responsiveness, perceived weight, timing)
- Platform-specific rendering (test on target hardware, not headlessly)
- Full gameplay sessions (covered by playtesting, not automation)

## CI/CD Rules

**Update (2026-08-23)**: no CI pipeline actually exists in this repo yet
(no `.github/workflows/`, confirmed by directory check) -- the rules
below describe the intended target, not current practice. Current real
practice: the full GUT suite is run manually, twice in a row to catch
flakiness, before every commit that touches `godot/scripts/` or
`godot/tests/` (this session's own established discipline throughout).

- Automated test suite should run on every push to main and every PR, once CI exists
- No merge if tests fail — tests should be a blocking gate in CI
- Never disable or skip failing tests to make CI pass — fix the underlying issue
- The real, working local invocation (not the stale `gdunit4` command
  previously listed here -- this project uses **GUT** (Godot Unit Test),
  not gdUnit4):
  ```
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit --path godot
  ```
