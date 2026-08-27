## Crop variety identifiers (e.g., Kashmiri Saffron vs. standard Saffron).
## Not all crops have varieties -- those without are treated as having a single
## "default" variety (ordinal 0) to simplify the UI and economy logic.
##
## Port pattern: mirrors crop_type.gd's enum+def structure. Each variety is a
## small data class (CropVarietyDef) indexed by this ordinal, looked up via
## GameData.crop_variety_def(crop_ordinal, variety_ordinal).
class_name CropVarietyType
extends RefCounted

enum Kind {
	# Wheat variants
	WHEAT_STANDARD,
	WHEAT_BASMATI,

	# Paddy variants
	PADDY_STANDARD,
	PADDY_JASMINE,

	# Tomato variants
	TOMATO_STANDARD,
	TOMATO_HEIRLOOM,

	# Capsicum variants (Polyhouse)
	CAPSICUM_STANDARD,
	CAPSICUM_HYBRID,

	# Dutch Rose variants (Polyhouse)
	DUTCH_ROSE_STANDARD,
	DUTCH_ROSE_PREMIUM,

	# Sandalwood variants (Agroforestry)
	SANDALWOOD_STANDARD,
	SANDALWOOD_KASHMIRI,

	# Makhana variants (Aquaculture)
	MAKHANA_STANDARD,
	MAKHANA_PREMIUM,

	# Pond Fish variants (Aquaculture)
	POND_FISH_STANDARD,
	POND_FISH_SILVER,

	# Saffron variants (Vertical Farm)
	SAFFRON_STANDARD,
	SAFFRON_KASHMIRI,
	SAFFRON_ASSAMESE,
}
