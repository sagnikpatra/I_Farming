## Covers AgroforestryTab's pure logic -- build_view_data() (build-gate
## state, Security cost/active flag) -- extracted specifically so it's
## unit-testable independent of the scene tree (see agroforestry_tab.gd's
## header comment). Node construction/layout/styling is explicitly NOT
## covered here, per this project's testing standards
## (.claude/docs/coding-standards.md: "Visual/Feel" stories get screenshot
## evidence, not automated tests).
extends GutTest

var eco: GameEconomy


func before_each() -> void:
	eco = GameEconomy.new()
	eco.state.coins = 1_000_000


func test_view_data_before_built_reports_not_built() -> void:
	var data := AgroforestryTab.build_view_data(eco)
	assert_false(data["has_agroforestry"])
	assert_eq(data["cost"], GameData.AGROFORESTRY_UNLOCK_COST)


func test_view_data_after_built_reports_built_and_security_inactive() -> void:
	eco.buy_agroforestry()
	var data := AgroforestryTab.build_view_data(eco)
	assert_true(data["has_agroforestry"])
	assert_false(data["has_security"])
	assert_eq(data["security_cost"], GameData.SECURITY_COST)


func test_view_data_reflects_purchased_security() -> void:
	eco.buy_agroforestry()
	eco.buy_security()
	var data := AgroforestryTab.build_view_data(eco)
	assert_true(data["has_security"])
