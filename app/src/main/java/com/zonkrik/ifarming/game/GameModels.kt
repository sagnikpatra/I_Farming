package com.zonkrik.ifarming.game

/** Which kind of land a plot occupies -- determines which crops can go in it. */
enum class PlotKind {
    OPEN_FIELD,
    POLYHOUSE,
    AGROFORESTRY,
    AQUACULTURE,
    VERTICAL_FARM,
}

/**
 * Companion/host plants for Agroforestry tiles. These aren't grown through the
 * normal timer-based crop cycle -- they're placed instantly as permanent
 * infrastructure that a nearby Sandalwood tree can lean on, per the design
 * doc's semi-parasitic host requirement. Acacia is the "optimized" host: it
 * shortens the Sandalwood grow time (see GameData.SANDALWOOD_GROW_SECONDS_ACACIA).
 */
enum class HostType(
    val displayName: String,
    val emoji: String,
    val cost: Long,
) {
    PIGEON_PEA("Pigeon Pea", "🌿", 15),
    NEEM("Neem", "🌳", 200),
    ACACIA("Acacia", "🌲", 350),
}

/**
 * Crop catalogue. Tier 1 staples grow in open-field plots and are exposed to
 * weather/pest risk. Tier 2 exotics only grow in Polyhouse plots, where the
 * risk model instead depends on the player's protected-cultivation upgrades.
 * Sandalwood (Tier 3) only grows in Agroforestry plots next to a host plant,
 * and is threatened by theft rather than weather (see GameViewModel).
 */
enum class CropType(
    val displayName: String,
    val emoji: String,
    val seedCost: Long,
    val growSeconds: Long,
    val baseSellPrice: Long,
    /** % chance an open-field crop gets hit by weather/pests once it finishes growing. Unused outside open field. */
    val weatherRiskPercent: Int,
    val requiredPlotKind: PlotKind = PlotKind.OPEN_FIELD,
) {
    WHEAT(
        displayName = "Wheat",
        emoji = "🌾",
        seedCost = 10,
        growSeconds = 120,
        baseSellPrice = 20,
        weatherRiskPercent = 8,
    ),
    PADDY(
        displayName = "Paddy",
        emoji = "🌱",
        seedCost = 30,
        growSeconds = 20 * 60,
        baseSellPrice = 80,
        weatherRiskPercent = 12,
    ),
    TOMATO(
        displayName = "Tomato",
        emoji = "🍅",
        seedCost = 60,
        growSeconds = 2 * 60 * 60,
        baseSellPrice = 240,
        weatherRiskPercent = 15,
    ),
    CAPSICUM(
        displayName = "Colored Capsicum",
        emoji = "🫑",
        seedCost = 150,
        growSeconds = 40 * 60,
        baseSellPrice = 650,
        weatherRiskPercent = 0,
        requiredPlotKind = PlotKind.POLYHOUSE,
    ),
    DUTCH_ROSE(
        displayName = "Dutch Rose",
        emoji = "🌹",
        seedCost = 220,
        growSeconds = 60 * 60,
        baseSellPrice = 1100,
        weatherRiskPercent = 0,
        requiredPlotKind = PlotKind.POLYHOUSE,
    ),
    SANDALWOOD(
        displayName = "Sandalwood",
        emoji = "🪵",
        seedCost = 5_000,
        // Base (Neem/Pigeon Pea host) duration; Acacia hosts shorten this -- see GameData.
        growSeconds = GameData.SANDALWOOD_GROW_SECONDS_BASE,
        baseSellPrice = 500_000,
        weatherRiskPercent = 0,
        requiredPlotKind = PlotKind.AGROFORESTRY,
    ),
    MAKHANA(
        displayName = "Makhana (Fox Nut)",
        emoji = "🪷",
        seedCost = 400,
        growSeconds = 6 * 60 * 60,
        baseSellPrice = 1_800,
        weatherRiskPercent = 0,
        requiredPlotKind = PlotKind.AQUACULTURE,
    ),
    POND_FISH(
        displayName = "Pond Fish",
        emoji = "🐟",
        seedCost = 250,
        growSeconds = 3 * 60 * 60,
        baseSellPrice = 900,
        weatherRiskPercent = 0,
        requiredPlotKind = PlotKind.AQUACULTURE,
    ),
    SAFFRON(
        displayName = "Saffron",
        emoji = "🌸",
        seedCost = 800,
        growSeconds = 90 * 60,
        baseSellPrice = 3_500,
        weatherRiskPercent = 0,
        requiredPlotKind = PlotKind.VERTICAL_FARM,
    ),
}

/** A single plot of land on the player's farm. */
sealed class PlotState {
    data object Empty : PlotState()

    data class Growing(
        val crop: CropType,
        val plantedAtEpochMs: Long,
        /** Grow duration actually applied at planting time (captures any Fan & Pad speed bonus, or host choice, in effect then). */
        val effectiveGrowSeconds: Long,
    ) : PlotState()

    data class ReadyToHarvest(
        val crop: CropType,
        /** True if a random weather/pest event clipped this yield. */
        val weatherDamaged: Boolean,
        val readyAtEpochMs: Long,
    ) : PlotState()
}

data class Plot(
    val id: Int,
    val kind: PlotKind = PlotKind.OPEN_FIELD,
    val state: PlotState = PlotState.Empty,
    /** Only meaningful for AGROFORESTRY plots -- position within the fixed adjacency grid. */
    val agroRow: Int? = null,
    val agroCol: Int? = null,
    /** A host plant occupies this tile permanently instead of going through the normal grow cycle. */
    val hostType: HostType? = null,
)

/** A structure zone's custom world position/orientation -- see `GameState.zoneLayout` and the village board's drag/rotate/flip features. */
data class ZoneAnchor(
    val tileX: Float,
    val tileY: Float,
    val rotationDegrees: Int = 0,
    val flippedX: Boolean = false,
)

/** A cosmetic, purely-decorative placeable item -- no gameplay effect. See `GameState.decorations`. */
enum class DecorationType(val displayName: String, val emoji: String, val cost: Long) {
    POTTED_PLANT("Potted Plant", "🪴", 50),
    SUNFLOWER("Sunflower", "🌻", 75),
    BAMBOO("Bamboo", "🎋", 100),
    LANTERN("Lantern", "🏮", 150),
    FOUNTAIN("Fountain", "⛲", 400),
    STATUE("Statue", "🗿", 600),
    DIRT_PATH("Dirt Path", "🟫", 10),
    RANGOLI("Rangoli", "🪷", 25),
}

/** One placed decoration on the village board. */
data class Decoration(
    val id: Int,
    val type: DecorationType,
    val tileX: Float,
    val tileY: Float,
    val rotationDegrees: Int = 0,
    val flippedX: Boolean = false,
)

/** Harvested-but-unsold stock for one crop type, split by yield quality. */
data class CropStock(
    val normal: Int = 0,
    val damaged: Int = 0,
) {
    val total: Int get() = normal + damaged
}

/**
 * Oversupply pressure for one crop on the Mandi market. [value] decays continuously toward
 * zero over real time from [updatedAtEpochMs] -- see GameViewModel.currentGlut. This is what
 * makes selling a lot of one crop through the Mandi temporarily depress its own price, per the
 * design doc's "flooding the market lowers the price" e-NAM behaviour.
 */
data class MandiGlut(
    val value: Double = 0.0,
    val updatedAtEpochMs: Long = 0L,
)

/** The full persisted game state. */
data class GameState(
    val coins: Long = 300,
    val plots: List<Plot> = List(GameData.STARTING_PLOTS) { Plot(id = it) },
    val inventory: Map<CropType, CropStock> = emptyMap(),
    val lastWeatherEvent: String? = null,
    /** Lifetime harvest count, used to unlock the government Polyhouse subsidy. */
    val totalHarvests: Long = 0,
    val hasPolyhouse: Boolean = false,
    val hasFanPad: Boolean = false,
    val hasDripIrrigation: Boolean = false,
    /** Null = no UV film ever bought. Once bought, protection only applies while now < this. */
    val filmExpiresAtEpochMs: Long? = null,
    val hasAgroforestry: Boolean = false,
    /** Fencing + guard posts / CCTV. Sharply cuts the odds of Sandalwood theft. */
    val hasSecurity: Boolean = false,
    val hasAquaculture: Boolean = false,
    val hasVerticalFarm: Boolean = false,
    /** Null = never paid. New Saffron cycles can only be started while now < this. */
    val electricityExpiresAtEpochMs: Long? = null,
    /** Index into GameData.FARMHOUSE_LEVELS. The central progression hub. */
    val farmhouseLevel: Int = 0,
    val hasMandi: Boolean = false,
    /** Digital auction terminal -- unlocks tomorrow's demand forecast. */
    val hasMandiTerminal: Boolean = false,
    val mandiGlut: Map<CropType, MandiGlut> = emptyMap(),
    // --- LiveOps: Festival Event Pass. Which recurring festival "occurrence" these fields
    // belong to -- see GameViewModel.withFreshEventOccurrence for how a new occurrence resets them.
    val eventOccurrenceIndex: Long = -1,
    val eventPoints: Int = 0,
    val eventHasPremiumPass: Boolean = false,
    /** Highest reward tier (0..GameData.FESTIVAL_TIER_THRESHOLDS.size) already granted this occurrence. */
    val eventClaimedTier: Int = 0,
    /** Custom drag-to-reposition positions for the village board's structure zones, keyed by zone id (see `village/TileSnapshot.kt`'s zone-id constants). Missing entries fall back to that zone's default anchor. */
    val zoneLayout: Map<String, ZoneAnchor> = emptyMap(),
    /** Purely cosmetic placed items -- see `DecorationType`/`Decoration`. */
    val decorations: List<Decoration> = emptyList(),
    /** Simple auto-incrementing id source for new decorations, mirrors how plot ids already work. */
    val nextDecorationId: Int = 0,
)
