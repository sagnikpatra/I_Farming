## Purely cosmetic placeable-item identifiers. Port of GameModels.kt's
## `DecorationType` enum class. See crop_type.gd's header for the enum + def
## table pattern (decoration_type_def.gd, GameData.decoration_type_def()).
class_name DecorationType
extends RefCounted

enum Kind {
	POTTED_PLANT,
	SUNFLOWER,
	BAMBOO,
	LANTERN,
	FOUNTAIN,
	STATUE,
	DIRT_PATH,
	RANGOLI,
}
