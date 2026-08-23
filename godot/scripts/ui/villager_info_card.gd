## Read-only greeting card for a tapped roaming villager -- the tap-
## interaction decision made and built 2026-08-22, see
## design/gdd/villagers.md rule 8 (Detailed Rules) and its Tuning Knobs
## "Tap interaction" row for the full reasoning. Deliberately the
## simplest info card in this project: no economy reference, no
## decoration/plot id, no action button -- a roaming villager has no
## persistent identity at all (design/gdd/villagers.md rule 2: never part
## of `GameState`), so `character_key` alone is genuinely the entire input
## this card needs.
##
## ARCHITECTURE: same "small static shell would be overkill" call as
## growing_info_card.gd/decoration_info_card.gd -- everything built
## procedurally in configure(), no static .tscn content beyond the root
## container. Visual language matches every other ported card (ported
## Color.kt palette, LabelSettings drop-shadow text, explicit
## mouse_filter on every node).
##
## Explicitly out of scope (see the GDD): a `WorkerStation`-stationed
## (assigned) villager is a different scene entirely, never routed
## through this card -- board_interactor.gd only wires this up for
## VillagerRoamer's own PickArea.
class_name VillagerInfoCard
extends VBoxContainer

const SOIL_BROWN_DARK := UiTheme.SOIL_BROWN_DARK

## One glyph per CHARACTER_SCENES key. Was a fantasy-class icon (⚔️/🔮/🏹/
## etc.) matching the old RPG-class display names -- replaced 2026-08-23
## alongside Villager.CHARACTER_DISPLAY_NAMES' switch to real Hindi names,
## since a crystal ball or dagger next to "Deepak" or "Sunita" reads as a
## mismatch, not a claim about what the on-board model is holding (every
## fantasy prop is already hidden per villager.gd's own visual-pass
## comment either way).
const CHARACTER_EMOJI: Dictionary = {
	"barbarian": "👨🏽‍🌾",
	"knight": "🧑🏽‍🌾",
	"mage": "👴🏽",
	"ranger": "👨🏻‍🌾",
	"rogue": "👩🏽‍🌾",
	"rogue_hooded": "👵🏽",
}
const _DEFAULT_EMOJI := "🧑"

var _character_key: String = "ranger"


## Must be called before this instance is added under a BottomSheet's
## content slot -- same precondition/ordering guarantee as every other
## ported card's configure() method.
func configure(character_key: String) -> void:
	_character_key = character_key
	if is_inside_tree():
		_populate()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_populate()


func _populate() -> void:
	for child in get_children():
		child.queue_free()

	# A11Y (village-board-and-management-sheets-audit-2026-08-21.md, §1):
	# this card is added straight to the BottomSheet's cream body with no
	# panel wrapper, so Color.WHITE (safe only on colored panels) is
	# unreadable here -- measured ~1.06:1 contrast.
	var emoji_label := Label.new()
	emoji_label.text = CHARACTER_EMOJI.get(_character_key, _DEFAULT_EMOJI)
	emoji_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.label_settings = _make_label_settings(40, SOIL_BROWN_DARK)
	add_child(emoji_label)

	var name_label := Label.new()
	name_label.text = Villager.CHARACTER_DISPLAY_NAMES.get(_character_key, _character_key)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.label_settings = _make_label_settings(18, SOIL_BROWN_DARK)
	add_child(name_label)

	var greeting_label := Label.new()
	greeting_label.text = tr(&"villager_info.greeting")
	greeting_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	greeting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	greeting_label.label_settings = _make_label_settings(14, Color(0.243, 0.141, 0.071, 0.9))
	add_child(greeting_label)


func _make_label_settings(font_size: int, color: Color) -> LabelSettings:
	return UiTheme.make_label_settings(font_size, color)
