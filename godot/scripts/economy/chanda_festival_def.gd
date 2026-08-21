## One recurring Chanda Visit festival definition -- who the visiting
## neighbor is collecting for. Independent of FestivalDef/the Festival
## Event Pass rotation (see design/gdd/festival-visiting-npcs.md) -- a
## companion system, not a replacement. Looked up via
## GameData.chanda_festival_def(cycle_index).
class_name ChandaFestivalDef
extends RefCounted

var display_name: String
var emoji: String
## Warm, festival-specific line shown when the player gives.
var give_flavor: String


func _init(p_display_name: String, p_emoji: String, p_give_flavor: String) -> void:
	display_name = p_display_name
	emoji = p_emoji
	give_flavor = p_give_flavor
