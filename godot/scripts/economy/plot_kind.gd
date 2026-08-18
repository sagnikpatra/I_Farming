## Which kind of land a plot occupies -- determines which crops can go in it.
## Port of GameModels.kt's `PlotKind` enum. Plain enum, no per-case data (unlike
## CropType/HostType/DecorationType -- see crop_type.gd's header comment for why
## those need the separate "enum + def table" pattern and this one doesn't).
class_name PlotKind
extends RefCounted

enum Kind {
	OPEN_FIELD,
	POLYHOUSE,
	AGROFORESTRY,
	AQUACULTURE,
	VERTICAL_FARM,
}
