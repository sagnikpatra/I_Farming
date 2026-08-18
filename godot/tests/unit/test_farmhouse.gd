## Covers farmhouse-progression.md: the sequential upgrade path and the three
## systemic multipliers (storage/growth-speed/sell-price).
extends GutTest

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()


func test_upgrade_is_strictly_sequential() -> void:
	eco.state.coins = 100_000_000
	assert_eq(eco.state.farmhouse_level, 0)
	eco.buy_farmhouse_upgrade()
	assert_eq(eco.state.farmhouse_level, 1)
	eco.buy_farmhouse_upgrade()
	assert_eq(eco.state.farmhouse_level, 2)


func test_upgrade_blocked_at_max_level() -> void:
	eco.state.coins = 100_000_000
	eco.state.farmhouse_level = GameData.farmhouse_max_level()
	eco.buy_farmhouse_upgrade()
	assert_eq(eco.state.farmhouse_level, GameData.farmhouse_max_level())


func test_upgrade_blocked_on_insufficient_coins() -> void:
	eco.state.coins = 100  # Level 1 costs 2,000
	eco.pending_events.clear()
	eco.buy_farmhouse_upgrade()
	assert_eq(eco.state.farmhouse_level, 0)
	assert_eq(eco.state.coins, 100)
	assert_true(eco.has_events())


func test_upgrade_deducts_exact_cost() -> void:
	eco.state.coins = 2_000
	eco.buy_farmhouse_upgrade()
	assert_eq(eco.state.coins, 0)


func test_storage_capacity_reflects_current_level() -> void:
	assert_eq(eco.storage_capacity(), 50)  # Level 0
	eco.state.farmhouse_level = 7
	assert_eq(eco.storage_capacity(), 2_000)


func test_total_inventory_units_sums_normal_and_damaged_across_crops() -> void:
	eco.state.inventory[CropType.Kind.WHEAT] = CropStock.new(3, 2)
	eco.state.inventory[CropType.Kind.PADDY] = CropStock.new(1, 0)
	assert_eq(eco.total_inventory_units(), 6)
