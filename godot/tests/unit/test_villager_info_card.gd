## Covers VillagerInfoCard's own construction -- the tap-interaction
## decision made and built 2026-08-22 (design/gdd/villagers.md rule 8).
## Same shape as test_decoration_info_card.gd/test_growing_info_card.gd:
## verifies the actual node tree the card builds, not just that the code
## compiles.
extends GutTest

const VillagerInfoCardScene := preload("res://scenes/ui/villager_info_card.tscn")


func _find_label_with_text(node: Node, substring: String) -> Label:
	if node is Label and (node as Label).text.contains(substring):
		return node
	for child in node.get_children():
		var found := _find_label_with_text(child, substring)
		if found:
			return found
	return null


func test_card_shows_the_real_display_name_for_a_known_character() -> void:
	var card: VillagerInfoCard = add_child_autofree(VillagerInfoCardScene.instantiate())
	card.configure("mage")
	assert_not_null(_find_label_with_text(card, "Mage"))


func test_card_shows_the_real_emoji_for_a_known_character() -> void:
	var card: VillagerInfoCard = add_child_autofree(VillagerInfoCardScene.instantiate())
	card.configure("knight")
	assert_not_null(_find_label_with_text(card, VillagerInfoCard.CHARACTER_EMOJI["knight"]))


func test_card_shows_a_greeting() -> void:
	var card: VillagerInfoCard = add_child_autofree(VillagerInfoCardScene.instantiate())
	card.configure("ranger")
	assert_not_null(_find_label_with_text(card, "Namaste"))


## An unknown character key must fall back safely (a default display name
## and emoji), not crash -- same defensive-fallback bar
## GameData.crop_def()/decoration_type_def() already hold for an
## out-of-range save value (production/security/security-audit-2026-08-21.md's
## SEC-001), applied here even though this card has no save-loaded input
## to defend against (character_key always comes from a live
## VillagerRoamer, never from disk) -- cheap insurance, not a reaction to
## a real found gap.
func test_card_falls_back_safely_for_an_unknown_character_key() -> void:
	var card: VillagerInfoCard = add_child_autofree(VillagerInfoCardScene.instantiate())
	card.configure("not_a_real_character")
	assert_not_null(_find_label_with_text(card, "🧑"), "an unknown key falls back to the default emoji, not a crash")
	assert_not_null(_find_label_with_text(card, "not_a_real_character"), "an unknown key's display name falls back to the raw key itself, same pattern worker_assignment_row.gd already uses")


func test_every_character_scenes_key_has_a_display_name_and_emoji() -> void:
	# Consistency guard: every real character key must resolve both
	# lookups, not just the ones spot-checked above.
	for key: String in Villager.CHARACTER_SCENES.keys():
		assert_true(Villager.CHARACTER_DISPLAY_NAMES.has(key), "missing display name for '%s'" % key)
		assert_true(VillagerInfoCard.CHARACTER_EMOJI.has(key), "missing emoji for '%s'" % key)
