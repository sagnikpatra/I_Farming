# ADR-0003: Cloud Save & Player Identity

## Status

Proposed

## Date

2026-08-22

## Last Verified

2026-08-22

## Decision Makers

Technical Director (analysis), project owner (final decision)

## Summary

The project owner requested that player data be saved to a backend platform
with login (Appwrite named as an example) so player progress is protected.
This ADR evaluates backend options against the project's actual shape —
Android-only, solo developer, zero existing backend or network code, no
revenue — and recommends Google Play Games Services Snapshots for cloud save
and identity, deferring a general-purpose backend until cross-platform
support or server-authoritative features become real requirements.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 (pinned 2026-08-18) |
| **Domain** | Networking, Persistence, Core |
| **Knowledge Risk** | **HIGH** — Godot 4.7.1 is post-cutoff. Additionally, *every* candidate integration is a third-party Android plugin or REST client whose 4.7.1 compatibility is unverified by this project. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `modules/android-export.md`; `production/security/security-audit-2026-08-21.md`; ADR-0002; `godot/scripts/economy/save_system.gd` |
| **Post-Cutoff APIs Used** | Godot Android plugin loading under GABE (stable since 4.7); `HTTPRequest` TLS defaults in 4.7.x |
| **Verification Required** | (1) Chosen plugin loads and functions under 4.7.1 specifically — published compatibility claims top out at "4.2+ / compiled with 4.5.1", so 4.7.1 is untested territory. (2) The existing Gradle Android export still produces a working APK after a plugin is added. (3) `HTTPRequest` certificate validation behavior against the chosen host. |

> **Note**: Knowledge Risk is HIGH. This ADR must be re-validated on any engine upgrade.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted) — this ADR partially revises its save-format decision at the transport layer |
| **Enables** | Any future cross-device, leaderboard, or server-authoritative feature |
| **Blocks** | Store release, if adopted — an account system triggers Play Console Data Safety and account-deletion obligations that must be satisfied before listing |
| **Ordering Note** | Phase 0 (transport format + schema version) is required by *every* option and can start before the platform choice is final |

## Context

### Problem Statement

Player progress currently exists only as `user://save.tres` on one device.
Uninstalling the app, switching phones, or clearing app data destroys it
permanently. With the Godot cutover complete and store release the remaining
milestone, this becomes a real player-facing risk at launch rather than a
theoretical one.

The owner framed the request as a backend platform with login. That framing
bundles several separable concerns — durable backup, cross-device sync,
account identity, and anti-tamper — which have materially different costs.
This ADR separates them.

### Current State

- `godot/scripts/economy/save_system.gd` — 35 lines. `ResourceSaver.save()` /
  `ResourceLoader.load()` against `user://save.tres`. Graceful fallback to a
  fresh `GameState` on corrupt or missing saves.
- `GameState` (`godot/scripts/economy/game_state.gd`) — ~25 `@export`
  fields plus `Array[Plot]`, `Array[Decoration]`, and several dictionaries.
  Small; estimated single-digit KB serialized.
- **No network code exists anywhere in the project.** A grep for
  `HTTPRequest`/`HTTPClient` across `godot/` matches only the GUT test
  addon's update checker. `export_presets.cfg` requests no custom Android
  permissions, including no `INTERNET`.
- **No third-party runtime dependencies.** The dependency inventory in the
  security audit lists exactly one entry (GUT, a test-only addon).
- The security audit confirmed the game currently collects **zero** player
  data of any kind.

### Constraints

- **Free/open-source-only project constraint.** Written for engines, asset
  packs, and SDKs. See "Constraint Interpretation" under Decision — it does
  not transfer literally to an operational service, but its underlying
  motivations do.
- **Solo developer, no demonstrated backend or network programming.** The
  codebase contains no client-server code, no auth handling, no retry or
  conflict logic. Skill acquisition cost is a first-class input here, not a
  footnote.
- **No existing server infrastructure**, no ops practice, no on-call.
- **No revenue.** Any recurring cost is funded personally and indefinitely.
- **Android-only today** (minSdk 24, targetSdk 37), with no committed
  cross-platform plan.
- **Offline play is non-negotiable.** This is a semi-idle farming sim whose
  economy relies on lazy offline resolution
  (`resolve_growth_completions()`, `resolve_worker_actions()`). Players
  will open it on commutes and in poor connectivity.
- **The GUT suite (379 tests) is the primary regression safety net**, per
  ADR-0002. Coding standards forbid unit tests touching external APIs.

### Requirements

- **R1** — Progress survives uninstall/reinstall and device change.
- **R2** — The game remains fully playable with no network connection, for
  an unbounded period, with zero feature loss.
- **R3** — Cloud sync must never block startup or interrupt gameplay. Cold
  start must not regress measurably.
- **R4** — Local/cloud divergence resolves deterministically and must never
  silently discard the larger body of player progress.
- **R5** — No secret usable for privileged backend access ships in the APK.
- **R6** — Recurring cost of $0 at current scale.
- **R7** — Testable headlessly and offline via dependency injection.
- **R8** — Whatever is stored must be legally defensible under GDPR and Play
  Console policy, with obligations a solo developer can actually discharge.

## Decision

### Constraint Interpretation (prerequisite)

The project's free/open-source-only constraint governs **redistributed
artifacts** — code and assets shipped inside the APK, where licensing
creates legal obligations on distribution. A backend service is an
**operational dependency**, not a redistributed artifact, so the constraint
does not apply literally.

The constraint's *motivations* do apply, and are restated here as the real
evaluation criteria:

- **C1 — No recurring cash cost** at current scale.
- **C2 — No vendor able to strand the project** by pricing change, shutdown,
  or policy change, without an exit path.
- **C3 — No proprietary code shipped in the APK** where a free alternative
  exists.

C3 is where the honest tension sits: the recommended option links Google
Play Services, which is proprietary. This is a real, deliberate exception,
justified below.

### Chosen: Google Play Games Services (PGS) Snapshots, offline-first

1. **Identity** — PGS sign-in. Google is the identity provider. The game
   stores no email, no password, no credential of any kind; only an opaque
   player ID. There is no login form.
2. **Storage** — PGS Snapshots. Save payload uploaded as an opaque blob.
   The 3 MB per-snapshot cap gives roughly three orders of magnitude of
   headroom over this project's estimated payload.
3. **Offline-first, local-authoritative in-session** — `user://save.tres`
   remains the working save and single source of truth while the app runs.
   Cloud is a backup/sync layer, never a read-path dependency.
4. **Transport format is JSON, not `.tres`** — see Security Considerations.
   This narrowly amends ADR-0002: the *local* format stays Resource-based;
   the *transport* format is plain validated data.
5. **Sync triggers** — on resume-with-network and on app pause/background.
   Never on the 3-second growth tick.
6. **Conflict resolution** — surfaced to the player, never silently
   resolved. See Conflict Policy.
7. **Behind an interface** — all sync goes through a `CloudSaveProvider`
   abstraction with a no-op default, so the engine choice is reversible and
   the test suite stays offline.

### Architecture

```
                  ┌─────────────────────────────┐
                  │        GameEconomy          │  (unchanged)
                  └──────────────┬──────────────┘
                                 │ GameState
                  ┌──────────────▼──────────────┐
                  │         SaveSystem          │  local, authoritative in-session
                  │   user://save.tres (.tres)  │
                  └──────────────┬──────────────┘
                                 │ to_dict() / from_dict()  ◄── NEW, validated
                  ┌──────────────▼──────────────┐
                  │      SaveSerializer         │  GameState <-> plain Dictionary
                  │  + schema_version, checksum │
                  └──────────────┬──────────────┘
                                 │ JSON bytes
                  ┌──────────────▼──────────────┐
                  │   CloudSaveProvider (iface) │  ◄── seam: swap backends here
                  ├─────────────────────────────┤
                  │ NullCloudProvider (default) │  tests + offline builds
                  │ PgsSnapshotProvider         │  chosen impl
                  │ (future: HttpCloudProvider) │  Supabase/Appwrite if ever needed
                  └─────────────────────────────┘
```

### Key Interfaces

```gdscript
class_name CloudSaveProvider
extends RefCounted

signal sign_in_completed(success: bool)
signal upload_completed(success: bool)
signal download_completed(success: bool, payload: Dictionary)
signal conflict_detected(local: Dictionary, remote: Dictionary)

func is_available() -> bool          # false offline / unsupported platform
func sign_in_silent() -> void        # never prompts, never blocks first frame
func upload(payload: Dictionary) -> void
func download() -> void
func resolve_conflict(chosen: Dictionary) -> void
```

```gdscript
class_name SaveSerializer
extends RefCounted

const SCHEMA_VERSION: int = 1

static func to_dict(state: GameState) -> Dictionary
static func from_dict(data: Dictionary) -> GameState   # returns null if invalid
static func validate(data: Dictionary) -> bool         # field-by-field, no trust
```

### Implementation Guidelines

- `from_dict()` must **never** call `ResourceLoader.load()` on network data,
  and must bounds-check every enum ordinal — the same class of defect as
  SEC-001, which already caused a real repeating crash from local data.
- `sign_in_silent()` must be fire-and-forget from `_ready()`. No `await` on
  the startup path.
- The `INTERNET` permission must be added explicitly to `export_presets.cfg`
  and disclosed in the Play Data Safety form.
- Delegate implementation to `godot-gdscript-specialist`; the Android
  plugin/export-pipeline work routes to `godot-specialist`.
- Add a `CloudSaveProvider` fake to the GUT suite. No test may touch a real
  network, per coding standards.

## Alternatives Considered

### Alternative 1: Appwrite Cloud (as requested)

- **Description**: Managed Appwrite. Account service for email/password
  auth, Databases or Storage for save blobs. Client integration via a
  community Godot SDK or hand-rolled `HTTPRequest` against the REST API.
- **Pros**: Server is open-source (self-host exit exists, satisfying C2 in
  principle). Real account system, platform-independent. Good docs.
- **Cons**:
  - **No official Godot SDK.** Appwrite's own SDK list does not include
    Godot. Available integrations are community-maintained and small
    (the main one is in the tens of GitHub stars).
  - **Active foot-gun**: the most discoverable Godot asset-store entry is an
    Appwrite **Server** SDK, intended for headless Godot. Server SDKs
    authenticate with an admin API key. Embedding one in a client APK
    would expose full project access — a direct R5 violation reachable by
    following the obvious path.
  - **Free tier pauses projects after ~1 week of inactivity** — hostile to a
    long solo dev cycle and to a low-traffic launch.
  - Pro tier ~$15/mo indefinitely against zero revenue (violates R6/C1).
  - Free-tier quotas have tightened as recently as January 2026, which is
    evidence about trajectory, not just current numbers.
  - Requires building password auth, session/token refresh, and secure token
    storage — none of which exist in this codebase or this developer's
    demonstrated experience.
  - Triggers the heavier GDPR posture: storing credentials makes the project
    a data controller for authentication data.
- **Estimated Effort**: 3–4× the recommended option.
- **Rejection Reason**: Highest cost, highest new-skill requirement, and the
  worst compliance posture, to deliver capabilities (cross-platform accounts)
  the project has no current use for. Recurring cost fails R6 outright.

### Alternative 2: Self-hosted Appwrite

- **Description**: Appwrite on a VPS the owner administers.
- **Pros**: Best possible score against the OSS constraint read literally —
  fully open-source, fully owned, no vendor. Satisfies C2 completely.
- **Cons**: Converts a solo game developer into a solo sysadmin. Appwrite is
  a multi-container Docker stack, not a single binary. Realistic VPS spend
  is roughly $12–25/mo (still failing R6), plus domain and backup costs.
  Ongoing burden: TLS renewal, security patching, database backups *that are
  restore-tested*, uptime monitoring. **Every player is locked out of their
  own save whenever the box is down** — strictly worse availability than the
  status quo of a purely local file. This is the trap: it is the option that
  scores best on paper against the written constraint and worst against the
  constraint's actual intent.
- **Estimated Effort**: 4–6× the recommended option, most of it recurring
  rather than one-time.
- **Rejection Reason**: Ops burden and availability risk are unjustifiable
  for cloud backup of a single-player game. Revisit only if the project goes
  cross-platform or gains server-authoritative features.

### Alternative 3: Firebase (Auth + Firestore)

- **Description**: Firebase Anonymous or Google Auth plus Firestore
  documents, via REST or a community plugin.
- **Pros**: Most mature option. Free tier realistically covers a small game
  indefinitely (satisfies R6). Anonymous-auth-upgrade is a well-trodden
  pattern. Cross-platform.
- **Cons**: No first-party Godot SDK; community Android plugins vary in
  maintenance, or you hand-roll REST. Proprietary and closed (worst score on
  C2/C3 of all options). Real lock-in — Firestore's data model is not
  portable. Firebase config in the client is normal and not itself a secret,
  but that makes **Firestore security rules the entire security boundary**,
  and a rules mistake is a public database — a sharp edge for a first
  backend. Google has a track record of deprecating products.
- **Estimated Effort**: 2–3× the recommended option.
- **Rejection Reason**: Trades the owner's stated open-source preference for
  maturity the project doesn't need, while still costing more integration
  work than PGS and delivering no advantage on an Android-only game.

### Alternative 4: Supabase

- **Description**: Postgres + GoTrue auth + PostgREST, consumed directly via
  Godot's built-in `HTTPRequest`.
- **Pros**: **The strongest non-PGS option, and the best choice if a real
  account system is wanted regardless of this ADR's recommendation.**
  Open-source core with a genuine self-host exit (good C2). Crucially,
  **needs no Godot plugin at all** — PostgREST is plain HTTP+JSON, so
  `HTTPRequest` suffices. That sidesteps the entire post-cutoff plugin
  compatibility risk, which is the single largest technical unknown across
  every other option. Row-Level Security is declarative and reviewable.
  Postgres data is genuinely portable.
- **Cons**: Free tier also **pauses after ~1 week of inactivity**; Pro is
  ~$25/mo (fails R6 if the project outgrows free). Still requires the
  developer to learn auth, token refresh, RLS policy authoring, and secure
  token storage. RLS misconfiguration has the same catastrophic failure mode
  as Firestore rules. Delivers cross-platform capability the project has no
  use for today.
- **Estimated Effort**: 2–3× the recommended option.
- **Rejection Reason**: Not rejected on merit — deferred. It is the
  recommended migration target *if* the game later goes cross-platform. It
  simply costs more than PGS to solve today's actual problem.

### Alternative 5: Do nothing (status quo) + manual export

- **Description**: Keep local-only saves; optionally add a share/export
  button so players can back up manually.
- **Pros**: Zero cost, zero risk, zero new dependency. Genre-normal —
  Stardew Valley and peers ship local, hand-editable saves.
- **Cons**: Fails R1. Progress loss on device change is a genuine one-star
  review generator for a progression-heavy game. Manual export is used by
  almost nobody. A save-import feature would activate SEC-003 anyway,
  meaning it does not even avoid the security work.
- **Rejection Reason**: R1 is a legitimate player-facing need and the owner
  raised it directly. But this is the correct fallback if the recommended
  option fails its verification gate.

## Consequences

### Positive

- Satisfies R1 and R2 at **$0 recurring cost** and with **no server to
  operate** — the two dominant constraints for this project.
- **Smallest possible compliance surface for an account system**: no
  credentials stored, only a pseudonymous ID. Google carries the identity-
  provider burden.
- No new auth, token-refresh, or credential-storage code — the largest
  category of security defect for a first-time backend implementer is
  avoided entirely rather than mitigated.
- Play Console setup is required for release regardless, so this adds no
  net account/admin overhead.
- The `SaveSerializer` + schema-version work is valuable independently of
  the platform choice and is not wasted if this decision is reversed.
- Forces SEC-003 and the missing schema-version field to be closed properly
  — both were already flagged as debts due for repayment before launch.

### Negative

- **Android/Google-account-locked.** If the game ever ships on iOS, desktop,
  or an alternative Android store (F-Droid, Amazon), this must be replaced.
  The `CloudSaveProvider` interface is the mitigation, not a cure.
- **Ships proprietary Google Play Services code** — a deliberate, documented
  exception to C3. No open-source equivalent provides zero-cost, zero-ops
  cloud save on Android.
- **No email/password login screen.** Confirmed acceptable by the project
  owner (2026-08-22) — silent sign-in is the intended UX, not a compromise.
- Adds the project's **first third-party runtime dependency** and its first
  Android plugin, changing the Android export pipeline that M0 established
  and every build since has relied on.
- Adds the `INTERNET` permission and a Data Safety disclosure to a listing
  that would otherwise declare zero data collection.
- Google's account-deletion policy requires an in-app deletion path *and* a
  publicly reachable deletion-request URL — an ongoing owner obligation.

### Neutral

- The local save format is unchanged; ADR-0002 stands except for the
  transport-layer amendment.
- Anti-cheat posture is unchanged and deliberately so — see below.

## Security Considerations

*(Expanded beyond the template because the request explicitly cited security.)*

**What "their data is secured" actually requires:**

1. **Transport format — the one genuinely serious issue.** SEC-003 accepted
   Godot's `.tres` resource-loading risk *explicitly conditional on save
   import/sync never being added*: "Worth revisiting if the project ever
   adds save import/export, cloud sync, or save-sharing between players."
   This ADR is that trigger. `ResourceLoader.load()` on a `.tres` fetched
   from a network is a remote-code-execution vector, not a theoretical one.
   **Mitigation: never transport `.tres`.** Serialize to a plain Dictionary,
   ship JSON, and reconstruct through validating code that trusts nothing.
2. **Schema versioning — currently blocking.** `GameState` has no version
   field (ADR-0002 deferral, re-flagged in the audit's Accepted Risk
   section). Local-only, it is harmless. With a shared cloud bucket, an old
   client can download a newer save and silently mangle it. `SCHEMA_VERSION`
   plus a refuse-to-load-if-newer rule is mandatory before any sync ships.
3. **Anti-tamper — deliberately unchanged.** The audit assessed local save
   editing and correctly declined to flag it: single-player, no leaderboard,
   no PvP, no IAP. **Cloud save does not change this**, and "cloud" must not
   be allowed to smuggle in server-authoritative economy validation — that
   would mean relocating `game_economy.gd` server-side, an enormous rewrite
   for zero benefit at this scale. A cheater cheats only themselves.
   Revisit **only** if leaderboards, IAP, or PvP appear. Recommended now: a
   non-cryptographic checksum for *corruption* detection, explicitly not a
   cheat deterrent, and never presented as one.
4. **Token handling.** PGS keeps credentials inside Google Play Services;
   the game never handles a token. This is the single largest security
   advantage over every alternative. If a backend is chosen instead, tokens
   must go to Android Keystore-backed storage, never `user://` and never a
   plain `.tres`.
5. **Conflict resolution / progress loss.** Losing a farm to a bad sync is
   a worse outcome than never syncing. Last-write-wins by wall clock is
   unsafe — device clocks are wrong and user-settable. Policy: maintain a
   monotonically increasing `save_counter` incremented on every local save;
   on divergence, **never auto-resolve** — present both saves with
   human-readable summaries (coins, total harvests, farmhouse level, real
   timestamps) and let the player choose. The PGS Snapshots API exposes a
   conflict signal for exactly this.
6. **Privacy / GDPR.** The audit confirmed the game currently collects zero
   data. Any account system makes the project a **data controller** with
   real obligations: a published privacy policy (needed for the store
   listing anyway), an accurate Play Data Safety declaration, a lawful
   basis, a data-deletion mechanism, and a processor agreement with the
   vendor. **PGS minimizes all of these** — a pseudonymous player ID and an
   opaque blob is about the smallest defensible footprint an account system
   can have. Storing email addresses and password hashes (Appwrite/Supabase
   auth) is a materially heavier and permanent obligation for a solo
   developer with no legal support.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| PGS plugin does not work on Godot 4.7.1 (published support claims stop around 4.2+/built with 4.5.1) | MEDIUM | HIGH | Spike it in Phase 1 before any integration work. Kill-switch: fall back to Alternative 5 or 4. |
| Adding an Android plugin breaks the working Gradle/GABE export pipeline | MEDIUM | MEDIUM | Phase 1 exports and launches a plugin-enabled APK on the AVD *before* feature work. Keep the current export config in version control for rollback. |
| Bad conflict resolution destroys a player's farm | LOW | **CRITICAL** | Never auto-resolve; player-facing choice; keep the last-known-good local save until an explicit choice is made. |
| Untrusted cloud payload crashes or exploits the client (SEC-003 class) | MEDIUM | HIGH | JSON transport only; field-by-field validation; bounds-check every enum, exactly as SEC-001's fix required. |
| Sync stalls or blocks gameplay on poor connections | MEDIUM | MEDIUM | Fire-and-forget, hard timeout, never `await` on a gameplay or startup path. Offline is a first-class state, not an error. |
| Project later goes cross-platform, stranding PGS | LOW-MEDIUM | MEDIUM | `CloudSaveProvider` interface; Supabase (Alternative 4) is the pre-identified migration target. |
| Account-deletion / Data Safety obligations unmet at listing time | MEDIUM | HIGH (blocks release) | Track explicitly in the roadmap's Release Readiness checklist, not as an engineering afterthought. |
| Network code proves hard to test, eroding the GUT safety net | MEDIUM | MEDIUM | `CloudSaveProvider` fake; all logic (conflict rules, serialization, validation) lives in pure testable functions, mirroring the `WalkableGrid`/`board_interactor.gd` precedent. |

## Performance Implications

This project now has real performance baselines (see
`docs/architecture/godot-migration-roadmap.md`'s EPIC-M6 section) but
**no formally adopted numeric budget** — a standing EPIC-M0 gap (the
measurement itself is closed as of 2026-08-22; only the *adoption* of a
threshold remains open). Per `technical-preferences.md`, numbers are not
invented here; the following are **proposed budgets to be validated by
measurement**, not asserted facts.

| Metric | Before | Expected After | Proposed Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | 49–51 FPS steady (real device) | Unchanged during play | No measurable regression vs. baseline |
| CPU (during sync) | n/a | Serialization on a background path | < 1 frame of hitch |
| Memory | ~59 MB static (real device) | +plugin overhead | < 10 MB delta |
| Cold start | 468ms (real device, Activity first-frame) | Sign-in is async, off the startup path | **0 ms added blocking time** |
| Network | 0 | Single-digit KB per sync (measure first) | < 50 KB/sync; no sync on the 3s growth tick |
| APK size | ~31.0 MB (current) | +PGS plugin AAR | < 5 MB delta, measured |

## Migration Plan

Sequenced so the highest-uncertainty item is proven first and each phase is
independently valuable.

**Phase 0 — Foundations (required by every option; safe to start now) --
Done (2026-08-22)**: `SaveSerializer` (`godot/scripts/economy/
save_serializer.gd`), `GameState.schema_version`, `CloudSaveProvider`/
`NullCloudSaveProvider` all built and tested (28 new GUT tests, real
JSON-transport round-trip proven, hostile-input rejection covered). Phase
1 onward (picking and spiking an actual backend) remains not started --
this ADR's overall Status stays Proposed until that choice is made.
1. Add `SCHEMA_VERSION` to `GameState`; refuse to load a newer schema.
2. Build `SaveSerializer` (`to_dict`/`from_dict`/`validate`) with strict
   bounds-checking on every enum — the SEC-001 defect class.
3. Round-trip tests: local `.tres` -> Dictionary -> `GameState`, plus
   hostile-input tests (missing fields, wrong types, out-of-range ordinals,
   deliberately malicious payloads).
4. Define `CloudSaveProvider` with `NullCloudProvider` as the default.
   *Verify: full GUT suite green; game behaves identically; no network.*

**Phase 1 — De-risking spike (kill-switch gate)**
5. Add the PGS plugin. Export, install, launch on the AVD. Confirm the
   existing export pipeline still works under Godot 4.7.1.
6. Silent sign-in only. No save data touched.
   *Verify: APK launches, signs in, no crash, no startup regression.*
   **If this fails, stop.** Fall back to Alternative 4 or 5, having spent
   days rather than weeks.

**Phase 2 — Backup-only (one-way, the safest useful increment)**
7. Upload on app pause. No download path at all.
8. A settings-screen indicator showing last successful sync.
   *Verify: on-device, snapshot visible in Play Games; airplane-mode play is
   completely unaffected.*
   This alone delivers most of R1's value at near-zero risk of data loss,
   because nothing can overwrite the local save yet.

**Phase 3 — Restore (fresh-install only)**
9. On first launch with no local save, offer to restore from cloud.
   *Verify: uninstall/reinstall genuinely recovers a farm on-device.*

**Phase 4 — Full sync with conflict handling**
10. Download-on-resume, divergence detection via `save_counter`.
11. Player-facing conflict UI showing both saves in human terms.
    *Verify: deliberately construct a conflict on two devices/emulators and
    confirm neither save is destroyed.*

**Phase 5 — Compliance (blocks store release, not code)**
12. Privacy policy, Data Safety declaration, in-app account deletion and its
    public deletion-request URL.

**Rollback plan**: Through Phase 3, remove the plugin and revert to
`NullCloudProvider` — local saves were never subordinated to cloud data, so
no player data is at risk. After Phase 4, rollback additionally requires
disabling the download path first. Phase 0's work is retained in all cases.

## Validation Criteria

- [ ] Full GUT suite green throughout; no test performs real network I/O
- [ ] Airplane mode: full play session, growth, harvest, worker resolution,
      save/load — indistinguishable from today
- [ ] Uninstall/reinstall on-device restores the exact prior `GameState`
- [ ] Deliberate two-device conflict resolves without destroying either save
- [ ] A hostile/corrupt cloud payload is rejected cleanly with no crash and
      no execution of embedded resources (closes SEC-003)
- [ ] An older client refuses a newer-schema save instead of mangling it
- [ ] Cold start shows no measurable regression against the recorded baseline
- [ ] `/security-audit` re-run shows no new HIGH or CRITICAL findings
- [ ] Recurring infrastructure cost is $0

## GDD Requirements Addressed

Foundational — no GDD requirement exists for cloud save or player accounts.
This ADR responds to a direct product request from the project owner
(2026-08-22) rather than a documented design requirement.

## Related

- Amends `docs/architecture/adr-0002-godot-language-and-save-format.md` at
  the transport layer only (local Resource format retained)
- Resolves the conditional in SEC-003 of
  `production/security/security-audit-2026-08-21.md`
- Addresses the "No save-format version field" item in that audit's
  Accepted Risk section
- Adds items to the Release Readiness checklist in
  `docs/architecture/godot-migration-roadmap.md` (privacy policy, Data
  Safety, account deletion)
- Implementation touches `godot/scripts/economy/save_system.gd`,
  `godot/scripts/economy/game_state.gd`, and `godot/export_presets.cfg`
- Decision confirmed by project owner 2026-08-22: silent sign-in (no
  login screen) is acceptable, so PGS Snapshots stands as chosen over
  Supabase
