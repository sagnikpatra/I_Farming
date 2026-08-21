# 2D UI asset kits (UI chrome restyle, 2026-08)

Free, open-source (CC0 / public domain) 2D UI kits acquired for the UI
chrome restyle scoped in `design/art/ui-visual-direction-2026-08.md`
(Track A) — replacing the current hand-rolled `StyleBoxFlat`-only chrome
across `godot/scripts/ui/*.gd` with real carved-panel/gold-inlay texture
assets. Not yet wired into the Godot project — this directory is source
material, same convention as `assets_3d/`'s "full sourced kit at repo root,
curated subset copied into `godot/assets_3d/`."

All four kits are by **Kenney** (<https://kenney.nl>), released under
**CC0 1.0** (<https://creativecommons.org/publicdomain/zero/1.0/>) — free to
use in personal, educational and commercial projects, no attribution
required (crediting Kenney is appreciated but optional). Each kit's original
`License.txt` is kept alongside its files as the license record. Sourced
2026-08-21 directly from kenney.nl (browser-verified download links, not
guessed URLs).

## Kits

| Folder | Kenney page | Files | Good for |
|---|---|---|---|
| `fantasy-ui-borders/` | [fantasy-ui-borders](https://kenney.nl/assets/fantasy-ui-borders) | 140 | The primary pick for Track A — carved-wood/gold-bordered 9-slice panel borders, exactly the visual family of the user's inspiration image 3. `PNG/Default/Border/` and `PNG/Double/Border/` hold the 9-slice-ready panel-border sprites. |
| `ui-pack-rpg-expansion/` | [ui-pack-rpg-expansion](https://kenney.nl/assets/ui-pack-rpg-expansion) | 85 | Warm brown/tan/gold button and slider primitives — closest palette match to Fantasy UI Borders among the button-focused kits. |
| `ui-pack-adventure/` | [ui-pack-adventure](https://kenney.nl/assets/ui-pack-adventure) | 130 | Buttons, banners, and circular icon-frame elements (`PNG/Default/circle_*` — matches this project's existing circular icon-button convention in `hud.gd` directly). |
| `game-icons/` | [game-icons](https://kenney.nl/assets/game-icons) | 105 | Generic UI glyphs (house, gear/settings, lock, cart, audio on/off, info, checkmark/X) in both Black and White variants, `@1x`/`@2x`. Covers several of the current emoji icons (⚙ settings, 🏠 nav) directly; does **not** cover farm-specific icons (coin, crop/wheat) — see note below. |

No `board-game-icons` or `rpg-icons` kit was used: `board-game-icons`
(checked, not downloaded) is dice/chess/card-mechanic iconography, not a
fit for coin/crop icons; `rpg-icons` doesn't exist as a Kenney asset page
(404). **No Kenney kit has farm-specific icons (coin, wheat/crop glyph)** —
for those, either keep emoji, or use this project's existing
runtime-painted-texture technique (`village_board.gd`'s
`_build_rangoli_texture()`/`_build_ready_badge_texture()` pattern, already
proven on this exact Godot/`gl_compatibility` pin) to hand-draw simple
coin/crop glyphs instead of sourcing a mismatched icon pack.

## Not yet done

This is asset acquisition only, per
`design/art/ui-visual-direction-2026-08.md`'s Track A/Track B split. None of
this is imported into the Godot project or wired into `godot/scripts/ui/*.gd`
yet. Implementation (picking specific sprites, importing as Godot
`NinePatchRect`/`StyleBoxTexture` resources into `godot/assets/ui/`, theming
pass across the HUD and all 9 management/picker sheets, on-device
verification under the pinned `gl_compatibility` renderer) is separate,
not-yet-started work.
