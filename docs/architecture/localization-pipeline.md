# Localization Pipeline — Phase 1

## Status

Phase 1 complete (infrastructure + a proven real slice). Phase 2's
entire mechanical sweep is now complete (2026-08-22, same day): every
`*_tab.gd`, `*_picker.gd`, `*_card.gd`, and `worker_assignment_row.gd`
file with hardcoded UI strings has been migrated. The one remaining
item, `game_economy.gd`'s `_push_event()` message strings, was flagged
from the start as its own larger design question, not a mechanical
sweep target -- see that section below.

## Date

2026-08-22

## Context

`docs/architecture/godot-migration-roadmap.md`'s EPIC-M8 (Release
Readiness) checklist flagged this as open: the game is
English/Hindi-label-mixed by design (crop names, "Mandi," festival
names, the "Kisan Khet" / "किसान खेत" title treatment — all intentional
flavor, not translatable UI chrome), but had no real i18n string-table
pipeline. Every UI string in `godot/scripts/ui/` was a hardcoded Godot
string literal.

## Decision

Godot 4's native CSV-translation import pipeline, not a hand-rolled
string table or a third-party addon. This is long-standing, stable
engine functionality (predates Godot 4.7 significantly) — low risk
despite this project's pinned version being past this assistant's
training cutoff (`docs/engine-reference/godot/VERSION.md`).

**Locales**: English (`en`, source/default) and Hindi (`hi`) — matching
the game's existing design intent, not introducing a third locale
speculatively.

## Architecture

```
godot/locales/ui_strings.csv          -- source of truth (keys,en,hi)
  → imported by Godot's csv_translation importer at edit/build time →
godot/locales/ui_strings.en.translation   -- generated Translation resources
godot/locales/ui_strings.hi.translation      (not hand-edited; regenerated
                                               from the CSV on any project
                                               filesystem scan)
```

`project.godot`'s new `[internationalization]` section registers both
generated `.translation` resources and sets `locale/fallback="en"`, so
an unmigrated key resolves to itself (Godot's own default `tr()`
behavior) rather than crashing or silently blanking.

**Locale preference**: `AccessibilitySettings.locale` (`godot/scripts/
accessibility/accessibility_settings.gd`), bounded to `SUPPORTED_LOCALES
= ["en", "hi"]` — the same "small, deliberately-bounded set" philosophy
`TEXT_SCALE_STEPS` already uses in that file. This is a **player
preference**, not game progress, so it lives in `AccessibilitySettings`'
own small `user://accessibility.tres` file (per that class's own
architecture note) rather than `GameState`/`save.tres` — consistent
with every other field already there, and keeps it off the
save-integrity/tamper-audit surface (`production/security/
security-audit-2026-08-21.md`'s SEC-001 scope).

`set_locale(new_locale)` persists + emits `settings_changed`, same
shape as every other setter in that class. `VillageBoard` (the sole
owner of the loaded `AccessibilitySettings` instance, same pattern as
`GameEconomy`) is the one place that calls `TranslationServer.
set_locale(...)` — once in `_ready()` (applies the persisted choice on
launch) and again in `_on_accessibility_settings_changed()` (applies a
live change unconditionally, cheap, no scene mutation, same treatment
`_apply_audio_settings_to_bus_server()` already gets on every signal).

**Live-apply boundary, deliberate**: `TranslationServer.set_locale()`
only affects text built by a `tr()` call made *after* the switch. A
sheet that re-populates itself after its own settings mutation (every
`*_sheet.gd`/`*_tab.gd`'s `_populate()`-on-every-handler pattern) picks
up the new language immediately. Already-built Control trees elsewhere
(HUD, a *different* already-open sheet) keep their current-language
text until next relaunch. This is the same documented, deliberate
limitation `cycle_text_scale()`'s own hint label already carries for
text size, for the same reason (`accessibility_sheet.gd`'s class doc
explains why: live-rebuilding HUD's five interdependent Control trees
is a real risk of a new bug, not proven safe this pass) — not a new gap
introduced by this feature.

## What's migrated (the proven real slice)

- `godot/scripts/ui/hud.gd`: "Sell All," "🌾 Field Worker," "Shop"
  (`hud.sell_all` / `hud.field_worker` / `hud.shop`).
- `godot/scripts/ui/accessibility_sheet.gd`: every label — title, text-
  size row (including its `%d%%` format string), colorblind row, audio
  row (title, mute toggle, all 4 volume-slider labels), and the new
  language-toggle row this phase adds (`a11y.*` keys — see
  `godot/locales/ui_strings.csv` for the full list).

**Translation accuracy caveat, stated plainly**: the Hindi column is a
good-faith mobile-app-register pass by this assistant (matching
existing patterns in this codebase — e.g. "सुगम्यता" for Accessibility,
the term used in India's "Sugamya Bharat" accessible-India initiative —
rather than an overly literal or overly Sanskritized translation), not
reviewed by a native speaker. Recommend a real review pass before this
ships to players, same caveat class as this project's own temple-bell
audio note (`design/audio/audio-core-gameplay-loop.md`) that a later
human listen-through closed.

## What's migrated so far, Phase 2 (2026-08-22, same day as Phase 1)

- `farmhouse_tab.gd`: header ("Farmhouse Level %d of %d"), the current/
  next-level bonuses card (title, storage/growth-speed/sell-price rows),
  the storage card, the upgrade button, and the max-level message.
- `mandi_tab.gd`: the pre-registration build card (title, blurb,
  register button), the post-registration intro (title, blurb), the
  Digital Auction Terminal offer, and every crop row's static text
  (A-Grade tag, "Held: N," tomorrow's forecast line, the Sell/"Nothing
  to sell" button). Crop display names/emoji themselves are NOT
  migrated -- they come from `GameData`'s catalogue data, the same
  larger data-migration question Phase 1's doc flagged as deliberately
  out of scope.
- `polyhouse_tab.gd`: build card (title, blurb, button), the Subsidy
  Quest card, and all 3 upgrade chips (Fan & Pad, Drip Irrigation,
  Renew Film, both their active/inactive text).
- `agroforestry_tab.gd`: build card (title, blurb, button), the
  Security chip (both states), and the post-build hint label.
- `niche_farming_tab.gd`: both section headers (Makhana Ponds, Saffron
  Vertical Farm), both build cards (title/blurb/button), and the
  electricity chip (both Powered/Pay states).
- `open_field_tab.gd`: its one header label.
- `events_tab.gd`: all 4 cards (Monsoon, Festival, Chanda Visit, Daily
  Tasks) — every static label, blurb, button, and tier/reward-row
  format string. The largest single-file slice of this pass (~26 keys).
  Festival/crop display names themselves stay data-driven from
  `GameData`, unchanged.

This completes every management sheet reachable from a board-zone tap
or the HUD's LiveOps banner. What's left is narrower UI surface area.

- `seed_picker.gd`: the sheet title and every row's "Xm grow · sells
  ₹Y" details line. **Real API pitfall found and fixed while authoring
  this file**: `format_crop_details()` is a `static func` (unit-tested
  directly, no scene-tree dependency, per this file's own class doc) --
  `tr()` is an `Object`/`Node` instance method and cannot be called from
  a static context (a genuine parse error, not just wrong output --
  Godot refused to even load the script). Fixed with
  `TranslationServer.translate()`, the same lookup, callable from
  anywhere.
- `agro_plant_picker.gd`: the sheet title, all 3 host rows' subtitle
  text (Instant / Instant · shortens Sandalwood grow time), and
  Sandalwood's own conditional subtitle (grow-time-and-price vs. "needs
  an adjacent host"). Same static-function pitfall as `seed_picker.gd`
  -- `build_row_data()` is static too, migrated with
  `TranslationServer.translate()` throughout.
- `decoration_picker.gd`: the sheet title (its one hardcoded string;
  decoration display names stay data-driven).
- `decoration_info_card.gd`: the "Decoration" subtitle and "Remove"
  button.
- `growing_info_card.gd`: the "sells ₹%d" subtitle and the "⏩ Skip (%d
  gems)" button (see `gems-second-sink.md`).
- `worker_assignment_row.gd`: the "👤 Worker" header, the assigned-
  status line, and the Assign/Unassign buttons. Character class names
  (Barbarian, Knight, ...) stay data-driven, same treatment as crop/
  decoration names elsewhere. **Real regression risk found and
  guarded**: `test_worker_assignment_row.gd` finds its buttons by exact
  text match (`n.text == "Assign"`), so the English CSV column had to
  stay byte-identical to the original hardcoded strings -- verified by
  a dedicated `test_localization.gd` check, not just assumed safe.

This completes Phase 2's entire mechanical sweep -- every UI file with
hardcoded player-facing strings has been migrated.

## What's explicitly NOT yet migrated

- `game_economy.gd`'s `_push_event()` message strings (the toast/
  snackbar text surfaced to the player on a rejected or completed
  action, drained by `hud.gd` -- see this doc's Related section) -- a
  large, free-text surface (dozens of call sites), deliberately not
  folded into the mechanical sweep above.
- Any dynamically-composed string built with `%` interpolation
  elsewhere in the codebase not listed above.

**Phase 3 plan** (renamed from "Phase 2 remaining scope" now that the
mechanical sweep is done): migrate `_push_event()`'s message strings.
This is a separate, larger design question from the sweep above (worth
resolving alongside the now-closed `ui_action_rejected` audio-wiring
work in `design/audio/audio-core-gameplay-loop.md`, since both needed
the same "what does this message mean, structurally" answer that
`GameEvent.is_rejection` partially answered) -- scope it as its own
follow-up with its own classification pass, not a continuation of this
phase's per-file sweep.

## Tests

`godot/tests/unit/test_localization.gd` (new): CSV-derived translations
resolve correctly for both locales on migrated keys, a format-string key
keeps its placeholder through the CSV round-trip, an unmigrated key
falls back to itself rather than crashing, and `AccessibilitySettings.
locale`'s default/setter/bounds-guard/persistence/signal behavior —
mirroring `test_accessibility_settings.gd`'s existing coverage shape for
every sibling field.

`godot/tests/unit/test_village_board.gd` (extended): the actual wiring
— mutating the real `AccessibilitySettings` instance a loaded
`VillageBoard` owns and asserting `TranslationServer.get_locale()`
reflects it — not just the engine API in isolation.

Full suite verified green (558/558, up from 545/545) twice in a row,
non-flaky. Extended with 3 more spot-checks after the `farmhouse_tab.gd`/
`mandi_tab.gd` Phase 2 slice (two-placeholder format keys from each file,
plus an English-still-works sanity check) -- 569/569, twice, non-flaky.
Extended again after `polyhouse_tab.gd`/`agroforestry_tab.gd`/
`niche_farming_tab.gd` -- 571/571, twice, non-flaky. Extended again
after `open_field_tab.gd`/`events_tab.gd` (including a regression check
for a real CSV-quoting mistake caught and fixed while authoring that
slice -- a Hindi string with an embedded comma that needed explicit
quoting, per RFC 4180) -- 574/574, twice, non-flaky.
Extended again after the 3 pickers -- 576/576, run **three** times
(not the usual two) given what authoring that slice found: locale
tests that call `AccessibilitySettings.set_locale()` on a bare
`AccessibilitySettings.new()` persist to the real default
`user://accessibility.tres` (same as every setter in that class), and
any LATER test that instantiates a fresh `VillageBoard` reloads that
file in `_ready()` and applies its locale straight to the *global*
`TranslationServer` -- silently changing output for completely
unrelated tests (`test_seed_picker.gd`, which doesn't touch locale at
all) run afterward. This is the same disk-persistence test-isolation
bug class found repeatedly this session, but the first time it leaked
through a genuinely global singleton rather than a per-instance field.
Fixed by having the locale tests delete the real file (not just reset
`TranslationServer` in-memory) in both `before_each()`/`after_each()`.
That fix was then generalized into a shared `RealSavePaths` test
utility (`godot/tests/unit/test_helpers/real_save_paths.gd`) -- see its
own doc comment for the full 6-occurrence history across this session.
Extended once more after the 2 info cards/`worker_assignment_row.gd`
(the last mechanical-sweep slice, including a regression guard for
`test_worker_assignment_row.gd`'s exact-text button lookups) --
578/578, twice, non-flaky.

## Dependencies

- `docs/architecture/godot-migration-roadmap.md` (EPIC-M8 checklist item
  this closes)
- `godot/scripts/accessibility/accessibility_settings.gd` (locale
  preference lives here)

## Related

- Building this surfaced (and fixed) a real test-isolation bug of the
  same class found twice earlier this same session:
  `AccessibilitySettings`' setters always `save()` to the real default
  `user://accessibility.tres` path, so a test that calls one without an
  explicit test-only path leaves real state on disk for a later test to
  load. `test_accessibility_settings.gd` already lived with this
  harmlessly (nothing there asserted an exact fresh-load default
  sensitive to it); the new `test_village_board.gd` locale test is what
  first combined "fresh real-path load" with an exact-value assertion,
  exposing it. Fixed by forcing the field directly before the assertion
  (`test_village_board.gd`'s own established pattern), not by changing
  the pre-existing, consistent convention in `test_accessibility_
  settings.gd`.
