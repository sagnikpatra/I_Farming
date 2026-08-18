## Companion/host plant identifiers for Agroforestry tiles. Port of
## GameModels.kt's `HostType` enum class. See crop_type.gd's header for why
## this is split into an enum (identifiers) + a def table (host_type_def.gd,
## GameData.host_type_def()).
##
## `NONE` is a GDScript-side addition with no Kotlin equivalent: Kotlin models
## "no host planted" as a nullable `HostType?` on `Plot`. GDScript enums can't
## be null, so `Plot.host_type` uses this sentinel instead -- same pattern as
## the -1 sentinels used elsewhere in this port for other nullable Kotlin
## fields (see plot.gd, game_state.gd).
class_name HostType
extends RefCounted

const NONE: int = -1

enum Kind {
	PIGEON_PEA,
	NEEM,
	ACACIA,
}
