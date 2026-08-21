## Which player verb a daily task tracks. Plain enum, no per-case data (same
## rationale as plot_kind.gd) -- per-kind display/target/reward data lives in
## DailyTaskDef instead. See design/gdd/gems-daily-tasks.md.
class_name DailyTaskKind
extends RefCounted

enum Kind {
	HARVEST,
	PLANT,
	SELL,
	WORKER,
	EARN,
}
