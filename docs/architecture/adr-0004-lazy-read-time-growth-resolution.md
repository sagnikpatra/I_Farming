# ADR-0004: Lazy, Read-Time Growth Resolution (Not a Live Ticking Timer)

## Status

Accepted (retroactive — the decision was made and implemented before this
project adopted ADR documentation; this record captures it after the
fact, per `crop-economy.md` §7's own flagged follow-up item)

## Date

2026-08-22 (record written; original decision predates this project's ADR
practice, made during the original Kotlin implementation and carried
forward unchanged into the Godot port)

## Last Verified

2026-08-22 — confirmed against the current Godot implementation
(`game_economy.gd`'s `resolve_growth_completions()`,
`village_board.gd`'s `GrowthTickTimer`)

## Decision Makers

Original Kotlin implementation (pre-dates this template's adoption);
carried forward as-is through the Godot migration (no re-litigation
needed — EPIC-M2's port preserved the pattern deliberately, see
`adr-0002`'s save-format decision, which assumes this same resolution
model)

## Summary

Crop/structure growth completion (`Growing → ReadyToHarvest`) is
determined by comparing `now − planted_at_epoch_ms` against the crop's
grow duration **at read time**, not by scheduling a timer/callback per
plot that fires exactly when growth finishes. A periodic "heartbeat"
(Godot: a 3-second `Timer`) re-runs this check during live play purely
for near-real-time UI feedback — it is a convenience, not the source of
correctness. This makes offline growth (the app closed for hours or
days) work correctly with zero special-case code, at the cost of up to
one heartbeat interval of visible lag between a crop actually finishing
and the UI showing it as ready.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 (decision itself is engine-agnostic; the heartbeat mechanism uses a plain `Timer` node, one of Godot's oldest, most stable APIs) |
| **Domain** | Core / Economy simulation |
| **Knowledge Risk** | LOW — `Timer.timeout`, `Time.get_unix_time_from_system()`, and basic arithmetic are all long-standing, unchanged Godot APIs; nothing here depends on any 4.6/4.7-era feature |
| **References Consulted** | None needed — no post-cutoff API surface involved |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | `adr-0002-godot-language-and-save-format.md`'s clean-save-format decision assumes this resolution model (no "pending timer" state needs to survive a save/load round-trip); `adr-0003-cloud-save-and-player-accounts.md`'s "offline play is non-negotiable" constraint (§ Context) is satisfied *by* this decision, not incidentally compatible with it |
| **Blocks** | None |
| **Ordering Note** | None — already fully implemented across every growth-adjacent system (crop plots, worker automation, Sandalwood theft rolls, Mandi glut decay all use the same lazy-read pattern) |

## Context

### Problem Statement

A farming sim's core loop is "plant something, wait, come back to
harvest it." The player will routinely close the app mid-grow and
reopen it hours or days later — this is the *expected*, not exceptional,
play pattern for a semi-idle game (confirmed in `adr-0003`'s own
Context section: "Players will open it on commutes and in poor
connectivity"). Whatever mechanism determines "is this crop ready yet"
has to handle that gap correctly, without needing the app process to
have stayed alive the whole time.

### Current State

Every growth-adjacent system in this codebase uses the same shape:
- `game_economy.gd`'s `resolve_growth_completions(now)` walks every
  `Growing` plot and transitions it to `ReadyToHarvest` once
  `now − planted_at_epoch_ms >= effective_grow_seconds * 1000` — a pure
  function of the timestamp passed in, called from real gameplay entry
  points (the growth-tick heartbeat, a direct harvest attempt, the
  grow-skip button, `GrowingInfoCard`'s own resolve call) rather than a
  single authoritative "tick" the whole game depends on.
- `resolve_worker_actions()` (worker automation) is explicitly
  documented as using "the same lazy pattern as
  `resolve_growth_completions()` above."
- Sandalwood's theft risk (`land-and-structures.md` §2.2) rolls
  per-elapsed-hour, deterministically seeded by `(plot_id, hour)`, so
  replaying the same elapsed-time gap reproduces the same rolls — also
  lazy, also offline-safe, by construction.
- Mandi glut decay (`mandi-trading.md` §2.2) is a continuous exponential
  function of elapsed time, not a per-tick decrement.
- `village_board.gd`'s `GrowthTickTimer` (3-second `Timer`,
  `autostart = true`) calls `resolve_growth_completions(now)` on a
  heartbeat during live play — this is the *only* place anything
  resembling "a live ticking timer" appears, and its job is narrow: give
  the player near-real-time feedback (within ~3 seconds) that something
  finished, not compute correctness. If this timer were deleted
  entirely, every plot would still resolve correctly the next time any
  other entry point read state — just without the ambient "it just
  turned ready while I was looking at the board" feel.

### Constraints

- Offline play must work with zero server/backend involvement (no
  push notifications, no server-authoritative clock) — confirmed as a
  hard constraint in `adr-0003`.
- The save format must not need to persist "pending timer" state (an
  in-flight scheduled callback isn't a serializable value) — confirmed
  compatible with `adr-0002`'s clean-Resource save format, which has no
  such field anywhere in `GameState`.
- This project has no unit-test-unfriendly dependency on real wall-clock
  waiting — every test in `godot/tests/unit/` that exercises growth
  passes an explicit `now: int` rather than sleeping or mocking a timer,
  which only works because the resolution function is a pure
  `f(state, now) → state` computation.

### Requirements

- A crop planted, then the app closed for an arbitrary real-time gap,
  then reopened, must show the correct final state (ready, or spoiled if
  applicable) without any special "catch-up" code path.
- Live play should still feel responsive — a crop shouldn't sit visibly
  "Growing" for a full extra heartbeat interval after it's actually done
  in the common case of the player watching the board.
- Every growth-adjacent formula must be independently unit-testable
  without real time elapsing during test execution (this project's own
  hard testing rule — `.claude/rules/test-standards.md`: "no
  time-dependent assertions").

## Decision

Compute grow-completion (and every other growth-adjacent state
transition) as a **pure function of an explicitly-passed timestamp**,
evaluated on demand rather than driven by a scheduled callback per
in-flight grow cycle. Godot's `GrowthTickTimer` exists solely as a
**heartbeat that re-invokes the same pure function periodically during
live play** — it is not the mechanism that makes growth "work," it's a
UX nicety layered on top of a mechanism that already works without it.

### Architecture

```
                    ┌─────────────────────────────┐
                    │  Any real entry point:       │
                    │  - GrowthTickTimer (3s)       │
                    │  - direct harvest attempt      │
                    │  - grow-skip button             │
                    │  - GrowingInfoCard resolve       │
                    └──────────────┬────────────────┘
                                   │  passes real now
                                   ▼
                    ┌─────────────────────────────┐
                    │ resolve_growth_completions(now)│
                    │ -- pure, stateless w.r.t. how  │
                    │    long it's been since the    │
                    │    last call                   │
                    └──────────────┬────────────────┘
                                   │  for each Growing plot:
                                   ▼
              now - planted_at_epoch_ms >= effective_grow_seconds*1000 ?
                     │ yes                          │ no
                     ▼                               ▼
            transition to ReadyToHarvest      leave Growing, re-check
            (weather/theft roll, if any,      next time any entry point
            resolved AT THIS MOMENT using     calls resolve again
            the real elapsed time -- correct
            whether that's 3 seconds or
            3 days since planting)
```

### Key Interfaces

```gdscript
# game_economy.gd -- the actual shape already implemented
func resolve_growth_completions(now: int) -> void:
    for plot in state.plots:
        if plot.state.kind != PlotState.Kind.GROWING:
            continue
        var elapsed_ms: int = now - plot.state.planted_at_epoch_ms
        if elapsed_ms < plot.state.effective_grow_seconds * 1000:
            continue
        # ... risk rolls, transition to READY_TO_HARVEST ...
```

No new interface is introduced by this ADR — it documents the shape
that already exists across `resolve_growth_completions()`,
`resolve_worker_actions()`, Sandalwood's theft check, and Mandi's glut
decay, so future growth-adjacent systems have a named pattern to follow
rather than reinventing the choice each time.

### Implementation Guidelines

Any **new** time-based mechanic in this codebase should default to this
same shape unless there's a concrete reason not to:
1. Store only a start timestamp (and whatever parameters were snapshotted
   at that moment — e.g. `effective_grow_seconds`, per `crop-economy.md`
   §2.1's "captured at planting time" rule).
2. Compute the current/final state as `f(start_timestamp, duration,
   now)`, called from wherever state is actually read or acted on.
3. If live-play responsiveness matters, add a heartbeat call site — but
   treat it as optional polish, not the mechanism itself, and never let
   correctness depend on the heartbeat having fired a specific number of
   times.
4. Never introduce a per-instance scheduled `Timer`/callback for
   something that could instead be a lazy read — that reintroduces
   exactly the "must persist pending timer state, must reconcile on
   load" complexity this pattern avoids.

## Alternatives Considered

### Alternative 1: Per-Plot Scheduled Timer

- **Description**: Each planted crop gets its own `Timer` (or
  equivalent scheduled callback) set to fire exactly
  `effective_grow_seconds` after planting, transitioning the plot the
  moment it fires.
- **Pros**: Growth completion is "pushed" the instant it happens during
  live play, with no heartbeat-interval lag at all.
- **Cons**: Doesn't survive the app being closed — a scheduled `Timer`
  node is destroyed with the scene tree, so every in-flight grow cycle
  would need its remaining duration serialized into the save file, then
  a new `Timer` reconstructed and re-armed with that remaining duration
  on load. Every one of Sandalwood's per-hour theft rolls, Mandi's glut
  decay, and worker-automation cycles would need the same treatment
  independently. Real added complexity for a benefit (near-zero live-play
  lag) this game's own pacing (grow times from 2 minutes to 21 days)
  doesn't need.
- **Estimated Effort**: Meaningfully higher — a save-format field per
  in-flight timer, reconstruction logic on load, and a real risk of
  subtle bugs in the reconstruction path (this is exactly the kind of
  "trust the pipeline's claim, not the measured output" mistake this
  project's own `production/qa/accessibility/audio-accessibility-
  reaudit-2026-08-21.md` warns against making elsewhere).
- **Rejection Reason**: Solves a problem (live-play lag) this game
  doesn't meaningfully have (a 3-second heartbeat is imperceptible for
  grow times measured in minutes to weeks) by introducing a problem
  (offline-gap correctness) this game definitely does have.

### Alternative 2: A Live, Continuously-Running Game-Loop Tick

- **Description**: A single global "simulation tick" (e.g., once per
  physics/process frame, or once per real second) that decrements
  remaining-time counters on every in-flight grow cycle directly, rather
  than computing elapsed time from a stored start timestamp.
- **Pros**: Conceptually simple to reason about moment-to-moment ("time
  is passing, counters go down").
- **Cons**: Requires the process to have actually been running,
  continuously, for the counter to have decremented correctly — the
  exact offline-play failure mode this ADR's Constraints section rules
  out. Would need an explicit "how much real time passed while closed,
  replay that many ticks" catch-up pass on load anyway, which is *more*
  code than just computing elapsed time directly once, not less.
- **Estimated Effort**: Higher — the catch-up-on-load logic this
  approach still needs is strictly additional to what a live tick
  otherwise provides, not a substitute for the lazy approach's simplicity.
- **Rejection Reason**: Every practical benefit of "ticking" collapses
  once you add the catch-up pass offline correctness requires — at that
  point it's just a more complicated way to arrive at the same
  `elapsed_time >= duration` comparison the chosen approach already does
  directly.

## Consequences

### Positive

- Offline growth (the actual, expected common case for this genre) works
  correctly with zero special-case "catch-up" code — the same
  `resolve_growth_completions(now)` call handles a 3-second gap and a
  3-week gap identically.
- Every growth-adjacent formula is trivially unit-testable: pass a fixed
  `now`, assert the result — no timer mocking, no `await`, no flaky
  real-clock dependency. This is the exact pattern this project's own
  `.claude/rules/test-standards.md` requires ("no time-dependent
  assertions") and the one every GUT test in `godot/tests/unit/`
  touching growth already uses.
- The save format stays clean — no in-flight-timer state needs to exist
  anywhere in `GameState`, which `adr-0002`'s clean-save-format decision
  already assumed without this ADR having been written yet.
- New time-based mechanics (grow-skip, Sandalwood theft, Mandi glut, the
  daily-task day-key rollover pattern used throughout `game_economy.gd`)
  have a proven, consistent shape to copy rather than each inventing its
  own timer strategy.

### Negative

- Up to one heartbeat interval (3 seconds, Godot's current
  `GrowthTickTimer.wait_time`) of visible lag between a crop actually
  finishing and the UI reflecting it, during live play. Deliberately
  accepted — imperceptible against grow times measured in minutes to
  weeks, and correctly framed in this ADR's Summary as a real, bounded
  cost, not swept under the rug.
- A plot's `ReadyToHarvest` transition is only ever *discovered*, never
  proactively pushed to the player outside the heartbeat's cadence — if
  the heartbeat were ever removed or its interval lengthened
  significantly, the player could genuinely wait longer than expected to
  *see* something that already finished, even though the underlying
  state is already correct.

### Neutral

- This pattern was never a deliberate "decision" documented anywhere
  before this ADR — it was simply how the original Kotlin implementation
  worked, carried forward unchanged. This ADR doesn't change any
  behavior; it names and justifies a choice that was already made and
  already shipped.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| A future feature adds a per-instance scheduled `Timer` instead of following this pattern, reintroducing the offline-correctness problem this ADR exists to avoid | LOW | MEDIUM — would need its own save-format field and reconciliation logic, a real regression in save-format cleanliness | This ADR's Implementation Guidelines section names the pattern explicitly so it's easy to point to during code review |
| The `GrowthTickTimer`'s 3-second interval is lengthened for a performance reason without anyone re-checking §"Negative" above | LOW | LOW — worst case is a longer felt lag, not a correctness bug, since the heartbeat is documented here as a UX nicety, not a correctness dependency | This ADR itself is the documentation that would surface during that future decision |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | N/A — this ADR documents an existing pattern, no change | Unchanged — `resolve_growth_completions()` is already the current implementation | Not applicable; no performance change results from writing this ADR |
| Memory | N/A | Unchanged | Not applicable |
| Load Time | N/A | Unchanged | Not applicable |
| Network (if applicable) | N/A | Not applicable — no network involvement in growth resolution | Not applicable |

## Migration Plan

None — this ADR documents an already-implemented, already-shipped
pattern retroactively. No code changes result from Accepting it.

**Rollback plan**: Not applicable (no migration performed).

## Validation Criteria

- [x] Offline growth (app closed, reopened after an arbitrary gap)
      resolves correctly — verified throughout this project's existing
      test suite (every growth-related GUT test passes an explicit
      elapsed-time gap rather than relying on real waiting) and via
      real on-device verification earlier in this project's history
      (see `production/session-state/active.md`'s save-recovery and
      grow-skip verification entries)
- [x] No in-flight-timer state exists anywhere in the save format —
      confirmed: `GameState`'s only growth-related persisted field is
      `planted_at_epoch_ms` (a timestamp), never a remaining-duration
      counter or scheduled-callback reference
- [x] Every growth-adjacent formula is unit-testable without real time
      elapsing during the test — confirmed true for every existing test
      touching `resolve_growth_completions()`,
      `resolve_worker_actions()`, Sandalwood theft, and Mandi glut decay

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/crop-economy.md` | Crop Economy | "Growth resolution is lazy... This is what makes offline growth 'just work'" (§2.1, Plot Lifecycle) | This ADR is the formal architectural record of exactly that already-stated design requirement |
| `design/gdd/worker-economy.md` | Worker Economy | Automated harvest-and-replant must resolve correctly across an offline gap (§8 Acceptance Criteria) | `resolve_worker_actions()` explicitly follows this same pattern |
| `design/gdd/land-and-structures.md` | Sandalwood theft | Theft rolls must be "replayable across offline gaps" (§2.2) | Achieved via the same lazy, deterministic-per-elapsed-hour approach this ADR documents |

## Related

- Enables/assumed-by `adr-0002-godot-language-and-save-format.md`'s
  clean-save-format decision
- Satisfies a constraint stated in
  `adr-0003-cloud-save-and-player-accounts.md`'s Context section
  ("offline play is non-negotiable")
- Requested explicitly in `design/gdd/crop-economy.md` §7's Flagged
  Follow-Up Work ("Consider an ADR for 'lazy/read-time growth
  resolution over a live ticking timer'") — this ADR closes that item
- Code: `godot/scripts/economy/game_economy.gd`'s
  `resolve_growth_completions()`/`resolve_worker_actions()`;
  `godot/scripts/village_board/village_board.gd`'s `GrowthTickTimer`/
  `_on_growth_tick_timeout()`
