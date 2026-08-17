package com.zonkrik.ifarming.game

import kotlin.math.pow
import kotlin.math.roundToLong

/** Tunable constants for the farm economy. */
object GameData {
    /** A poor farmer doesn't start with a sprawling holding -- just enough to get going, matching
     * the design doc's marginal-pricing land economy (see [landExpansionCost]): everything past
     * this has to be earned and paid for, at an increasing price as the farm's "valuation" grows. */
    const val STARTING_PLOTS = 3
    const val MAX_PLOTS = 16

    private const val BASE_LAND_COST = 150L
    private const val LAND_COST_MULTIPLIER = 1.55

    /**
     * Marginal pricing: each new plot costs more than the last, per the design
     * doc's requirement that late-game expansion still applies financial pressure.
     */
    fun landExpansionCost(currentPlotCount: Int): Long {
        val stepsBeyondStart = (currentPlotCount - STARTING_PLOTS).coerceAtLeast(0)
        return (BASE_LAND_COST * LAND_COST_MULTIPLIER.pow(stepsBeyondStart)).roundToLong()
    }

    /** Weather-damaged (or spoiled) crops still sell, but at a steep discount, not for zero. */
    const val WEATHER_DAMAGE_YIELD_MULTIPLIER = 0.5

    // --- Tier 2: Protected Cultivation / Polyhouse -------------------------------------

    const val POLYHOUSE_PLOT_COUNT = 4

    const val POLYHOUSE_BASE_COST = 35_000L
    const val POLYHOUSE_SUBSIDY_COST = 17_500L
    const val FAN_PAD_COST = 70_000L
    const val DRIP_IRRIGATION_COST = 5_000L
    const val UV_FILM_COST = 7_500L

    /** Doc calls for renewal "every three in-game weeks" -- compressed to 3 real days here. */
    const val UV_FILM_DURATION_MS = 3L * 24 * 60 * 60 * 1000

    /** Weather/pest risk for polyhouse crops when the UV film has lapsed (or was never bought). */
    const val POLYHOUSE_UNPROTECTED_RISK_PERCENT = 10

    /** Harvest this many crops (any type) to unlock the 50% government subsidy on the Polyhouse. */
    const val SUBSIDY_QUEST_TARGET = 25L

    /** How long a harvested-but-neglected Polyhouse crop can sit before it's treated as spoiled. */
    const val SPOILAGE_GRACE_MS_BASE = 4L * 60 * 60 * 1000
    const val SPOILAGE_GRACE_MS_WITH_DRIP = 24L * 60 * 60 * 1000

    fun polyhouseCost(subsidyUnlocked: Boolean): Long =
        if (subsidyUnlocked) POLYHOUSE_SUBSIDY_COST else POLYHOUSE_BASE_COST

    fun isSubsidyUnlocked(totalHarvests: Long): Boolean = totalHarvests >= SUBSIDY_QUEST_TARGET

    // --- Tier 3: Agroforestry / Sandalwood ----------------------------------------------

    /** Fixed NxN adjacency grid for host-plant/Sandalwood placement puzzles. */
    const val AGROFORESTRY_GRID_SIZE = 3
    const val AGROFORESTRY_UNLOCK_COST = 20_000L
    const val SECURITY_COST = 50_000L

    /** Doc: 12-15 real years to maturity, compressed to a real 14-30 day wait in-game. */
    const val SANDALWOOD_GROW_SECONDS_BASE = 21L * 24 * 60 * 60
    /** Acacia is the "optimized" host per the doc's soil/host-plant optimization note. */
    const val SANDALWOOD_GROW_SECONDS_ACACIA = 14L * 24 * 60 * 60

    /**
     * Sandalwood is only at risk of theft while still Growing (not yet harvested), checked
     * once per elapsed real hour so it plays out sensibly even across long offline gaps.
     * These are deliberately tiny per-hour probabilities: compounded over a multi-week grow,
     * unprotected trees have a real (~30%+) chance of being stolen; secured trees are safe.
     */
    const val THEFT_HOURLY_PROBABILITY_UNPROTECTED = 0.00085
    const val THEFT_HOURLY_PROBABILITY_PROTECTED = 0.00006

    // --- Tier 4: Niche Regional / Vertical Farming --------------------------------------

    /** Makhana ponds -- cheaper, lower-ceiling alternative to Polyhouse; encourages diversification. */
    const val AQUACULTURE_PLOT_COUNT = 5
    const val AQUACULTURE_UNLOCK_COST = 15_000L

    /** Saffron vertical racks -- very few tiles, very high cost, needs recurring power to keep planting. */
    const val VERTICAL_FARM_PLOT_COUNT = 2
    const val VERTICAL_FARM_UNLOCK_COST = 80_000L
    const val ELECTRICITY_COST = 8_000L
    const val ELECTRICITY_DURATION_MS = 2L * 24 * 60 * 60 * 1000

    // --- The Ancestral Farmhouse: core progression hub ----------------------------------

    /**
     * One row per Farmhouse tier. [upgradeCost] is the price to reach that level from the
     * previous one (level 0 is the free starting hut). Each tier grants three systemic,
     * farm-wide bonuses rather than being purely cosmetic, per the design doc.
     */
    data class FarmhouseLevel(
        val level: Int,
        val displayName: String,
        val emoji: String,
        val upgradeCost: Long,
        /** Max total harvested-but-unsold crop units the player can hold at once. */
        val storageCapacity: Int,
        /** % reduction applied to every crop's effective grow time, farm-wide. */
        val growthSpeedBonusPercent: Int,
        /** % bonus applied to every sale, farm-wide. */
        val sellPriceBonusPercent: Int,
    )

    val FARMHOUSE_LEVELS = listOf(
        FarmhouseLevel(0, "Humble Hut", "🛖", 0, 50, 0, 0),
        FarmhouseLevel(1, "Kutcha House", "🏠", 2_000, 100, 3, 2),
        FarmhouseLevel(2, "Pucca House", "🏠", 8_000, 200, 6, 4),
        FarmhouseLevel(3, "Village Bungalow", "🏡", 25_000, 350, 9, 6),
        FarmhouseLevel(4, "Courtyard Haveli", "🏡", 75_000, 550, 12, 8),
        FarmhouseLevel(5, "Grand Haveli", "🏰", 200_000, 800, 15, 10),
        FarmhouseLevel(6, "Heritage Estate", "🏰", 500_000, 1_200, 18, 12),
        FarmhouseLevel(7, "Modern Agricultural Estate", "🏛️", 1_200_000, 2_000, 20, 15),
    )

    fun farmhouseLevelDef(level: Int): FarmhouseLevel =
        FARMHOUSE_LEVELS.getOrElse(level) { FARMHOUSE_LEVELS.last() }

    val FARMHOUSE_MAX_LEVEL = FARMHOUSE_LEVELS.lastIndex

    // --- Mandi / e-NAM trading -----------------------------------------------------------

    const val MANDI_UNLOCK_COST = 3_000L
    const val MANDI_TERMINAL_COST = 25_000L

    /** Produce from any protected/managed cultivation tier gets an automatic A-Grade bump. */
    const val MANDI_GRADE_A_BONUS_PERCENT = 12

    /** Developer-controlled price band so no crop can be pumped or dumped to absurd values. */
    const val MANDI_MIN_MULTIPLIER = 0.6
    const val MANDI_MAX_MULTIPLIER = 1.6

    /** Each unit sold through the Mandi adds this much oversupply pressure on that crop. */
    const val MANDI_GLUT_PER_UNIT = 0.02

    /** Continuous decay rate for glut; roughly halves every ~3 hours. */
    const val MANDI_GLUT_DECAY_PER_HOUR = 0.231

    /** How often the server-wide demand cycle rotates to a new crop-by-crop modifier. */
    const val MANDI_CYCLE_MS = 4L * 60 * 60 * 1000

    /**
     * Deterministic per-crop, per-cycle demand swing in percent (e.g. -15..20). Pure function of
     * (crop, cycleIndex) -- no state to persist, and the "tomorrow's forecast" feature just peeks
     * at cycleIndex + 1 ahead of time once the player has bought the auction terminal.
     */
    fun demandModifierPercent(crop: CropType, cycleIndex: Long): Int {
        val seed = crop.ordinal * 104_729L + cycleIndex * 7_919L
        return kotlin.random.Random(seed).nextInt(-15, 21)
    }

    // --- LiveOps: Monsoon Season ----------------------------------------------------------

    /** Recurring window, computed purely from device time -- no backend needed. */
    const val MONSOON_CYCLE_MS = 6L * 60 * 60 * 1000
    const val MONSOON_ACTIVE_DURATION_MS = 90L * 60 * 1000

    /** Open-field crops grow this much faster while the Monsoon is active. */
    const val MONSOON_SPEED_MULTIPLIER = 0.8

    /** Chance an un-protected open-field crop is wiped entirely by flooding when it matures. */
    const val MONSOON_FLOOD_CHANCE_PERCENT = 10

    // --- LiveOps: Festival Event Pass -------------------------------------------------------

    const val FESTIVAL_CYCLE_MS = 8L * 60 * 60 * 1000
    const val FESTIVAL_ACTIVE_DURATION_MS = 60L * 60 * 1000
    const val FESTIVAL_POINTS_PER_UNIT_SOLD = 2
    const val FESTIVAL_PREMIUM_PASS_COST = 5_000L

    data class FestivalDef(val displayName: String, val emoji: String, val targetCrop: CropType)

    val FESTIVALS = listOf(
        FestivalDef("Makar Sankranti", "🪁", CropType.PADDY),
        FestivalDef("Pongal", "🍚", CropType.PADDY),
        FestivalDef("Baisakhi", "🌾", CropType.WHEAT),
    )

    val FESTIVAL_TIER_THRESHOLDS = listOf(50, 150, 300)
    val FESTIVAL_FREE_REWARDS = listOf(500L, 1_500L, 4_000L)
    val FESTIVAL_PREMIUM_BONUS = listOf(500L, 1_500L, 4_000L)

    fun festivalDef(cycleIndex: Long): FestivalDef = FESTIVALS[(cycleIndex % FESTIVALS.size).toInt()]
}
