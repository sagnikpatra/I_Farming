## Crop catalogue identifiers. Port of GameModels.kt's `CropType` enum class.
##
## GDScript enums are plain named integers with no per-case data, unlike Kotlin
## enum classes (which can carry `displayName`/`seedCost`/etc. per case). The
## translation used throughout this economy port is: a plain `enum` for the
## identifier (this file) plus a parallel static lookup table of small data
## classes (see crop_def.gd, GameData.crop_def()) indexed by the enum's int
## ordinal. Ordinal order below matches CropType.kt's declaration order exactly
## (WHEAT=0 .. SAFFRON=8), since GameState persists crops by this ordinal.
class_name CropType
extends RefCounted

enum Kind {
	WHEAT,
	PADDY,
	TOMATO,
	CAPSICUM,
	DUTCH_ROSE,
	SANDALWOOD,
	MAKHANA,
	POND_FISH,
	SAFFRON,
}
