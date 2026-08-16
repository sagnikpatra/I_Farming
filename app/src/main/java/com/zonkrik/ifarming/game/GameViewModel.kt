package com.zonkrik.ifarming.game

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.math.exp
import kotlin.math.roundToLong
import kotlin.random.Random

/** One-off UI events the screen should show and then dismiss (snackbars, toasts). */
sealed class GameEvent {
    data class Info(val message: String) : GameEvent()
}

class GameViewModel(private val repository: GameRepository) : ViewModel() {

    private val _state = MutableStateFlow(repository.load())
    val state: StateFlow<GameState> = _state.asStateFlow()

    /** Ticks once a second so plot progress bars and countdowns stay live. */
    private val _nowMillis = MutableStateFlow(System.currentTimeMillis())
    val nowMillis: StateFlow<Long> = _nowMillis.asStateFlow()

    private val _events = MutableStateFlow<GameEvent?>(null)
    val events: StateFlow<GameEvent?> = _events.asStateFlow()

    init {
        viewModelScope.launch {
            while (true) {
                val now = System.currentTimeMillis()
                _nowMillis.value = now
                resolveGrowthCompletions(now)
                delay(1000)
            }
        }
    }

    fun consumeEvent() {
        _events.value = null
    }

    /** True while the Polyhouse's UV film is bought and not yet expired. */
    fun isFilmActive(current: GameState, now: Long): Boolean =
        current.hasPolyhouse && current.filmExpiresAtEpochMs != null && now < current.filmExpiresAtEpochMs

    private fun effectiveWeatherRiskPercent(current: GameState, plotKind: PlotKind, crop: CropType, now: Long): Int =
        when (plotKind) {
            PlotKind.OPEN_FIELD -> crop.weatherRiskPercent
            PlotKind.POLYHOUSE -> if (isFilmActive(current, now)) 0 else GameData.POLYHOUSE_UNPROTECTED_RISK_PERCENT
            // Sandalwood's risk is theft, handled separately in resolveGrowthCompletions -- no weather roll here.
            PlotKind.AGROFORESTRY -> 0
            // Managed ponds and indoor vertical racks are shielded from open-field weather entirely.
            PlotKind.AQUACULTURE, PlotKind.VERTICAL_FARM -> 0
        }

    /** True while the Saffron vertical farm's electricity credit is paid up. */
    fun isElectricityActive(current: GameState, now: Long): Boolean =
        current.hasVerticalFarm && current.electricityExpiresAtEpochMs != null && now < current.electricityExpiresAtEpochMs

    // --- LiveOps: Monsoon Season -----------------------------------------------------------

    /** A recurring window computed purely from device time -- no live backend required. */
    fun isMonsoonActive(now: Long): Boolean = now.mod(GameData.MONSOON_CYCLE_MS) < GameData.MONSOON_ACTIVE_DURATION_MS

    /** Ms remaining in the current phase (active-until, or until the next Monsoon begins). */
    fun monsoonPhaseRemainingMs(now: Long): Long {
        val phase = now.mod(GameData.MONSOON_CYCLE_MS)
        return if (phase < GameData.MONSOON_ACTIVE_DURATION_MS) {
            GameData.MONSOON_ACTIVE_DURATION_MS - phase
        } else {
            GameData.MONSOON_CYCLE_MS - phase
        }
    }

    // --- LiveOps: Festival Event Pass -------------------------------------------------------

    fun isFestivalActive(now: Long): Boolean = now.mod(GameData.FESTIVAL_CYCLE_MS) < GameData.FESTIVAL_ACTIVE_DURATION_MS

    fun currentFestival(now: Long): GameData.FestivalDef = GameData.festivalDef(now / GameData.FESTIVAL_CYCLE_MS)

    fun festivalPhaseRemainingMs(now: Long): Long {
        val phase = now.mod(GameData.FESTIVAL_CYCLE_MS)
        return if (phase < GameData.FESTIVAL_ACTIVE_DURATION_MS) {
            GameData.FESTIVAL_ACTIVE_DURATION_MS - phase
        } else {
            GameData.FESTIVAL_CYCLE_MS - phase
        }
    }

    /** Resets the event-pass fields if we've rolled into a new festival occurrence. Pure -- safe to call from Compose. */
    private fun withFreshEventOccurrence(state: GameState, now: Long): GameState {
        val cycleIndex = now / GameData.FESTIVAL_CYCLE_MS
        return if (state.eventOccurrenceIndex != cycleIndex) {
            state.copy(eventOccurrenceIndex = cycleIndex, eventPoints = 0, eventHasPremiumPass = false, eventClaimedTier = 0)
        } else {
            state
        }
    }

    /** What the UI should show for the event pass right now -- never mutates state. */
    fun eventStatePreview(now: Long): GameState = withFreshEventOccurrence(_state.value, now)

    fun buyPremiumPass() {
        val now = System.currentTimeMillis()
        if (!isFestivalActive(now)) {
            _events.value = GameEvent.Info("The Premium Pass can only be bought during an active festival.")
            return
        }
        val current = withFreshEventOccurrence(_state.value, now)
        if (current.eventHasPremiumPass) return
        if (current.coins < GameData.FESTIVAL_PREMIUM_PASS_COST) {
            _events.value = GameEvent.Info("Need ₹${GameData.FESTIVAL_PREMIUM_PASS_COST} for the Premium Pass.")
            return
        }
        _state.value = current.copy(
            coins = current.coins - GameData.FESTIVAL_PREMIUM_PASS_COST,
            eventHasPremiumPass = true,
        )
        _events.value = GameEvent.Info("🎫 Premium Pass activated for this festival!")
        persist()
    }

    /** Called after any sale completes; awards festival points/rewards if that crop is this festival's target. */
    private fun registerFestivalSale(crop: CropType, unitsSold: Int, now: Long) {
        if (unitsSold <= 0 || !isFestivalActive(now)) return
        val festival = currentFestival(now)
        if (crop != festival.targetCrop) return

        val current = withFreshEventOccurrence(_state.value, now)
        val newPoints = current.eventPoints + unitsSold * GameData.FESTIVAL_POINTS_PER_UNIT_SOLD

        var coinsGained = 0L
        var newTier = current.eventClaimedTier
        var lastMessage: String? = null
        GameData.FESTIVAL_TIER_THRESHOLDS.forEachIndexed { index, threshold ->
            val tierNumber = index + 1
            if (newPoints >= threshold && current.eventClaimedTier < tierNumber) {
                val freeReward = GameData.FESTIVAL_FREE_REWARDS[index]
                coinsGained += freeReward
                var msg = "${festival.emoji} ${festival.displayName} Tier $tierNumber reached! +₹$freeReward"
                if (current.eventHasPremiumPass) {
                    val premiumReward = GameData.FESTIVAL_PREMIUM_BONUS[index]
                    coinsGained += premiumReward
                    msg += " (+₹$premiumReward Premium bonus)"
                }
                lastMessage = msg
                newTier = tierNumber
            }
        }

        _state.value = current.copy(eventPoints = newPoints, eventClaimedTier = newTier, coins = current.coins + coinsGained)
        lastMessage?.let { _events.value = GameEvent.Info(it) }
        persist()
    }

    // --- The Ancestral Farmhouse: core progression hub ------------------------------------

    fun storageCapacity(current: GameState): Int =
        GameData.farmhouseLevelDef(current.farmhouseLevel).storageCapacity

    fun totalInventoryUnits(current: GameState): Int =
        current.inventory.values.sumOf { it.total }

    /** Farm-wide grow-time multiplier from the Farmhouse level (e.g. 0.85 = 15% faster). */
    private fun growthSpeedMultiplier(current: GameState): Double =
        1.0 - GameData.farmhouseLevelDef(current.farmhouseLevel).growthSpeedBonusPercent / 100.0

    /** Farm-wide sell-price multiplier from the Farmhouse level (e.g. 1.10 = 10% more). */
    private fun sellPriceMultiplier(current: GameState): Double =
        1.0 + GameData.farmhouseLevelDef(current.farmhouseLevel).sellPriceBonusPercent / 100.0

    fun buyFarmhouseUpgrade() {
        val current = _state.value
        if (current.farmhouseLevel >= GameData.FARMHOUSE_MAX_LEVEL) return
        val nextLevel = GameData.farmhouseLevelDef(current.farmhouseLevel + 1)
        if (current.coins < nextLevel.upgradeCost) {
            _events.value = GameEvent.Info("Need ₹${nextLevel.upgradeCost} to upgrade to ${nextLevel.displayName}.")
            return
        }
        _state.update { s ->
            s.copy(coins = s.coins - nextLevel.upgradeCost, farmhouseLevel = current.farmhouseLevel + 1)
        }
        _events.value = GameEvent.Info("${nextLevel.emoji} Welcome to your new ${nextLevel.displayName}!")
        persist()
    }

    /**
     * Deterministic, replayable theft check: same plot+hour always resolves the same way, so
     * re-evaluating after an offline gap (or after buying Security late) is consistent and
     * needs no extra persisted state beyond plantedAtEpochMs.
     */
    private fun wasSandalwoodStolen(plotId: Int, elapsedHours: Long, secured: Boolean): Boolean {
        val hourlyProbability = if (secured) {
            GameData.THEFT_HOURLY_PROBABILITY_PROTECTED
        } else {
            GameData.THEFT_HOURLY_PROBABILITY_UNPROTECTED
        }
        for (hour in 1..elapsedHours) {
            val seed = plotId * 1_000_003L + hour * 7_919L
            if (Random(seed).nextDouble() < hourlyProbability) return true
        }
        return false
    }

    private fun resolveGrowthCompletions(now: Long) {
        var weatherMessage: String? = null
        var theftMessage: String? = null
        var floodMessage: String? = null
        _state.update { current ->
            val updatedPlots = current.plots.map { plot ->
                val growing = plot.state as? PlotState.Growing ?: return@map plot

                if (growing.crop == CropType.SANDALWOOD) {
                    val elapsedHours = (now - growing.plantedAtEpochMs) / 3_600_000L
                    if (elapsedHours > 0 && wasSandalwoodStolen(plot.id, elapsedHours, current.hasSecurity)) {
                        if (theftMessage == null) {
                            theftMessage = "💀 Thieves made off with a Sandalwood tree before you could harvest it!"
                        }
                        return@map plot.copy(state = PlotState.Empty)
                    }
                }

                val elapsedMs = now - growing.plantedAtEpochMs
                if (elapsedMs < growing.effectiveGrowSeconds * 1000L) return@map plot

                // Monsoon Season: open-field crops risk total loss to flooding instead of the
                // usual weather-damage roll, unless the player has invested in a Polyhouse.
                if (plot.kind == PlotKind.OPEN_FIELD && isMonsoonActive(now) && !current.hasPolyhouse) {
                    val flooded = Random.nextInt(100) < GameData.MONSOON_FLOOD_CHANCE_PERCENT
                    if (flooded) {
                        if (floodMessage == null) {
                            floodMessage = "🌊 Monsoon floods wiped out your ${growing.crop.displayName}! " +
                                "Polyhouse owners are immune."
                        }
                        return@map plot.copy(state = PlotState.Empty)
                    }
                    return@map plot.copy(
                        state = PlotState.ReadyToHarvest(growing.crop, weatherDamaged = false, readyAtEpochMs = now),
                    )
                }

                val risk = effectiveWeatherRiskPercent(current, plot.kind, growing.crop, now)
                val damaged = Random.nextInt(100) < risk
                if (damaged && weatherMessage == null) {
                    weatherMessage = "⛈️ Unseasonal weather clipped your ${growing.crop.displayName}!"
                }
                plot.copy(
                    state = PlotState.ReadyToHarvest(growing.crop, weatherDamaged = damaged, readyAtEpochMs = now),
                )
            }
            current.copy(plots = updatedPlots)
        }
        weatherMessage?.let { _events.value = GameEvent.Info(it) }
        theftMessage?.let { _events.value = GameEvent.Info(it) }
        floodMessage?.let { _events.value = GameEvent.Info(it) }
        persist()
    }

    fun plantSeed(plotId: Int, crop: CropType) {
        // Sandalwood has its own entry point (adjacency + host-dependent duration).
        if (crop == CropType.SANDALWOOD) return
        val current = _state.value
        val plot = current.plots.find { it.id == plotId } ?: return
        if (plot.state !is PlotState.Empty) return
        if (crop.requiredPlotKind != plot.kind) return
        val now = System.currentTimeMillis()
        if (crop == CropType.SAFFRON && !isElectricityActive(current, now)) {
            _events.value = GameEvent.Info("Renew the electricity credit to power the grow lights.")
            return
        }
        if (current.coins < crop.seedCost) {
            _events.value = GameEvent.Info("Not enough coins for ${crop.displayName} seeds.")
            return
        }

        val speedBoosted = crop.requiredPlotKind == PlotKind.POLYHOUSE &&
            current.hasFanPad && isFilmActive(current, now)
        val afterFanPad = if (speedBoosted) crop.growSeconds / 2.0 else crop.growSeconds.toDouble()
        val monsoonMultiplier = if (crop.requiredPlotKind == PlotKind.OPEN_FIELD && isMonsoonActive(now)) {
            GameData.MONSOON_SPEED_MULTIPLIER
        } else {
            1.0
        }
        val effectiveSeconds = (afterFanPad * growthSpeedMultiplier(current) * monsoonMultiplier)
            .roundToLong().coerceAtLeast(1)

        _state.update { s ->
            s.copy(
                coins = s.coins - crop.seedCost,
                plots = s.plots.map {
                    if (it.id == plotId) {
                        it.copy(state = PlotState.Growing(crop, now, effectiveSeconds))
                    } else it
                },
            )
        }
        persist()
    }

    fun harvestPlot(plotId: Int) {
        val current = _state.value
        val plot = current.plots.find { it.id == plotId } ?: return
        val ready = plot.state as? PlotState.ReadyToHarvest ?: return

        val capacity = storageCapacity(current)
        val currentTotal = totalInventoryUnits(current)
        if (currentTotal >= capacity) {
            _events.value = GameEvent.Info("📦 Storage full ($currentTotal/$capacity)! Sell crops or upgrade your Farmhouse.")
            return
        }

        val now = System.currentTimeMillis()
        val spoiled = plot.kind == PlotKind.POLYHOUSE && run {
            val grace = if (current.hasDripIrrigation) {
                GameData.SPOILAGE_GRACE_MS_WITH_DRIP
            } else {
                GameData.SPOILAGE_GRACE_MS_BASE
            }
            now - ready.readyAtEpochMs > grace
        }
        val damaged = ready.weatherDamaged || spoiled

        _state.update { s ->
            val existingStock = s.inventory[ready.crop] ?: CropStock()
            val newStock = if (damaged) {
                existingStock.copy(damaged = existingStock.damaged + 1)
            } else {
                existingStock.copy(normal = existingStock.normal + 1)
            }
            s.copy(
                plots = s.plots.map { if (it.id == plotId) it.copy(state = PlotState.Empty) else it },
                inventory = s.inventory + (ready.crop to newStock),
                totalHarvests = s.totalHarvests + 1,
            )
        }
        if (spoiled && !ready.weatherDamaged) {
            _events.value = GameEvent.Info("🥀 That ${ready.crop.displayName} sat too long and spoiled a little.")
        }
        persist()
    }

    fun sellCrop(crop: CropType) {
        val current = _state.value
        val stock = current.inventory[crop] ?: return
        if (stock.total == 0) return

        val sellMultiplier = sellPriceMultiplier(current)
        val normalValue = (stock.normal * crop.baseSellPrice * sellMultiplier).roundToLong()
        val damagedValue = (stock.damaged * crop.baseSellPrice * GameData.WEATHER_DAMAGE_YIELD_MULTIPLIER * sellMultiplier)
            .roundToLong()
        val totalValue = normalValue + damagedValue

        _state.update { s ->
            s.copy(
                coins = s.coins + totalValue,
                inventory = s.inventory - crop,
            )
        }
        _events.value = GameEvent.Info("Sold ${stock.total} ${crop.displayName} for ₹$totalValue")
        registerFestivalSale(crop, stock.total, System.currentTimeMillis())
        persist()
    }

    fun sellAll() {
        val current = _state.value
        if (current.inventory.isEmpty()) return
        val sellMultiplier = sellPriceMultiplier(current)
        var totalValue = 0L
        current.inventory.forEach { (crop, stock) ->
            totalValue += (stock.normal * crop.baseSellPrice * sellMultiplier).roundToLong()
            totalValue += (stock.damaged * crop.baseSellPrice * GameData.WEATHER_DAMAGE_YIELD_MULTIPLIER * sellMultiplier)
                .roundToLong()
        }
        val soldStock = current.inventory
        _state.update { s -> s.copy(coins = s.coins + totalValue, inventory = emptyMap()) }
        _events.value = GameEvent.Info("Sold everything for ₹$totalValue")
        val now = System.currentTimeMillis()
        soldStock.forEach { (crop, stock) -> registerFestivalSale(crop, stock.total, now) }
        persist()
    }

    fun buyLandExpansion() {
        val current = _state.value
        val openFieldCount = current.plots.count { it.kind == PlotKind.OPEN_FIELD }
        if (openFieldCount >= GameData.MAX_PLOTS) {
            _events.value = GameEvent.Info("Your farm has reached its maximum size for now.")
            return
        }
        val cost = GameData.landExpansionCost(openFieldCount)
        if (current.coins < cost) {
            _events.value = GameEvent.Info("Need ₹$cost to expand your land.")
            return
        }
        _state.update { s ->
            s.copy(
                coins = s.coins - cost,
                plots = s.plots + Plot(id = (s.plots.maxOfOrNull { it.id } ?: -1) + 1),
            )
        }
        persist()
    }

    fun buyPolyhouse() {
        val current = _state.value
        if (current.hasPolyhouse) return
        val cost = GameData.polyhouseCost(GameData.isSubsidyUnlocked(current.totalHarvests))
        if (current.coins < cost) {
            _events.value = GameEvent.Info("Need ₹$cost to build a Polyhouse.")
            return
        }
        _state.update { s ->
            val nextId = (s.plots.maxOfOrNull { it.id } ?: -1) + 1
            val newPlots = List(GameData.POLYHOUSE_PLOT_COUNT) { offset ->
                Plot(id = nextId + offset, kind = PlotKind.POLYHOUSE)
            }
            s.copy(coins = s.coins - cost, hasPolyhouse = true, plots = s.plots + newPlots)
        }
        _events.value = GameEvent.Info("🏠 Polyhouse built! Colored Capsicum and Dutch Rose are now available.")
        persist()
    }

    fun buyFanPad() {
        val current = _state.value
        if (!current.hasPolyhouse || current.hasFanPad) return
        if (current.coins < GameData.FAN_PAD_COST) {
            _events.value = GameEvent.Info("Need ₹${GameData.FAN_PAD_COST} for Fan & Pad Climate Control.")
            return
        }
        _state.update { s -> s.copy(coins = s.coins - GameData.FAN_PAD_COST, hasFanPad = true) }
        persist()
    }

    fun buyDripIrrigation() {
        val current = _state.value
        if (!current.hasPolyhouse || current.hasDripIrrigation) return
        if (current.coins < GameData.DRIP_IRRIGATION_COST) {
            _events.value = GameEvent.Info("Need ₹${GameData.DRIP_IRRIGATION_COST} for Drip Irrigation.")
            return
        }
        _state.update { s -> s.copy(coins = s.coins - GameData.DRIP_IRRIGATION_COST, hasDripIrrigation = true) }
        persist()
    }

    fun renewFilm() {
        val current = _state.value
        if (!current.hasPolyhouse) return
        if (current.coins < GameData.UV_FILM_COST) {
            _events.value = GameEvent.Info("Need ₹${GameData.UV_FILM_COST} to renew the UV-stabilized film.")
            return
        }
        val now = System.currentTimeMillis()
        _state.update { s ->
            s.copy(
                coins = s.coins - GameData.UV_FILM_COST,
                filmExpiresAtEpochMs = now + GameData.UV_FILM_DURATION_MS,
            )
        }
        _events.value = GameEvent.Info("UV-stabilized film renewed. Climate control active.")
        persist()
    }

    // --- Tier 3: Agroforestry / Sandalwood ----------------------------------------------

    private fun agroNeighbors(plots: List<Plot>, plot: Plot): List<Plot> {
        val row = plot.agroRow ?: return emptyList()
        val col = plot.agroCol ?: return emptyList()
        return plots.filter { other ->
            other.kind == PlotKind.AGROFORESTRY &&
                other.agroRow != null && other.agroCol != null &&
                (kotlin.math.abs(other.agroRow - row) + kotlin.math.abs(other.agroCol - col) == 1)
        }
    }

    /** True if this empty Agroforestry tile sits next to at least one placed host plant. */
    fun canPlantSandalwood(plotId: Int): Boolean {
        val current = _state.value
        val plot = current.plots.find { it.id == plotId } ?: return false
        if (plot.kind != PlotKind.AGROFORESTRY || plot.state !is PlotState.Empty || plot.hostType != null) return false
        return agroNeighbors(current.plots, plot).any { it.hostType != null }
    }

    fun buyAgroforestry() {
        val current = _state.value
        if (current.hasAgroforestry) return
        if (current.coins < GameData.AGROFORESTRY_UNLOCK_COST) {
            _events.value = GameEvent.Info("Need ₹${GameData.AGROFORESTRY_UNLOCK_COST} to clear land for Agroforestry.")
            return
        }
        _state.update { s ->
            val nextId = (s.plots.maxOfOrNull { it.id } ?: -1) + 1
            val size = GameData.AGROFORESTRY_GRID_SIZE
            val newPlots = List(size * size) { index ->
                Plot(
                    id = nextId + index,
                    kind = PlotKind.AGROFORESTRY,
                    agroRow = index / size,
                    agroCol = index % size,
                )
            }
            s.copy(coins = s.coins - GameData.AGROFORESTRY_UNLOCK_COST, hasAgroforestry = true, plots = s.plots + newPlots)
        }
        _events.value = GameEvent.Info("🌳 Agroforestry plots cleared. Plant a host, then Sandalwood beside it.")
        persist()
    }

    fun buySecurity() {
        val current = _state.value
        if (!current.hasAgroforestry || current.hasSecurity) return
        if (current.coins < GameData.SECURITY_COST) {
            _events.value = GameEvent.Info("Need ₹${GameData.SECURITY_COST} for fencing and security.")
            return
        }
        _state.update { s -> s.copy(coins = s.coins - GameData.SECURITY_COST, hasSecurity = true) }
        persist()
    }

    fun plantHost(plotId: Int, host: HostType) {
        val current = _state.value
        val plot = current.plots.find { it.id == plotId } ?: return
        if (plot.kind != PlotKind.AGROFORESTRY || plot.state !is PlotState.Empty || plot.hostType != null) return
        if (current.coins < host.cost) {
            _events.value = GameEvent.Info("Need ₹${host.cost} for ${host.displayName}.")
            return
        }
        _state.update { s ->
            s.copy(
                coins = s.coins - host.cost,
                plots = s.plots.map { if (it.id == plotId) it.copy(hostType = host) else it },
            )
        }
        persist()
    }

    fun removeHost(plotId: Int) {
        val current = _state.value
        val plot = current.plots.find { it.id == plotId } ?: return
        if (plot.hostType == null) return
        _state.update { s ->
            s.copy(plots = s.plots.map { if (it.id == plotId) it.copy(hostType = null) else it })
        }
        persist()
    }

    fun plantSandalwood(plotId: Int) {
        val current = _state.value
        val plot = current.plots.find { it.id == plotId } ?: return
        if (plot.kind != PlotKind.AGROFORESTRY || plot.state !is PlotState.Empty || plot.hostType != null) return
        val neighbors = agroNeighbors(current.plots, plot)
        val hasHost = neighbors.any { it.hostType != null }
        if (!hasHost) {
            _events.value = GameEvent.Info("Sandalwood needs a host plant (Pigeon Pea, Neem, or Acacia) next to it.")
            return
        }
        val crop = CropType.SANDALWOOD
        if (current.coins < crop.seedCost) {
            _events.value = GameEvent.Info("Not enough coins for a Sandalwood sapling.")
            return
        }
        val hasAcaciaHost = neighbors.any { it.hostType == HostType.ACACIA }
        val baseSeconds = if (hasAcaciaHost) {
            GameData.SANDALWOOD_GROW_SECONDS_ACACIA
        } else {
            GameData.SANDALWOOD_GROW_SECONDS_BASE
        }
        val effectiveSeconds = (baseSeconds * growthSpeedMultiplier(current)).roundToLong().coerceAtLeast(1)
        val now = System.currentTimeMillis()
        _state.update { s ->
            s.copy(
                coins = s.coins - crop.seedCost,
                plots = s.plots.map {
                    if (it.id == plotId) it.copy(state = PlotState.Growing(crop, now, effectiveSeconds)) else it
                },
            )
        }
        persist()
    }

    // --- Tier 4: Niche Regional / Vertical Farming ---------------------------------------

    fun buyAquaculture() {
        val current = _state.value
        if (current.hasAquaculture) return
        if (current.coins < GameData.AQUACULTURE_UNLOCK_COST) {
            _events.value = GameEvent.Info("Need ₹${GameData.AQUACULTURE_UNLOCK_COST} to excavate ponds.")
            return
        }
        _state.update { s ->
            val nextId = (s.plots.maxOfOrNull { it.id } ?: -1) + 1
            val newPlots = List(GameData.AQUACULTURE_PLOT_COUNT) { offset ->
                Plot(id = nextId + offset, kind = PlotKind.AQUACULTURE)
            }
            s.copy(coins = s.coins - GameData.AQUACULTURE_UNLOCK_COST, hasAquaculture = true, plots = s.plots + newPlots)
        }
        _events.value = GameEvent.Info("🪷 Ponds excavated! Makhana and Pond Fish are now available.")
        persist()
    }

    fun buyVerticalFarm() {
        val current = _state.value
        if (current.hasVerticalFarm) return
        if (current.coins < GameData.VERTICAL_FARM_UNLOCK_COST) {
            _events.value = GameEvent.Info("Need ₹${GameData.VERTICAL_FARM_UNLOCK_COST} to build the vertical farm.")
            return
        }
        _state.update { s ->
            val nextId = (s.plots.maxOfOrNull { it.id } ?: -1) + 1
            val newPlots = List(GameData.VERTICAL_FARM_PLOT_COUNT) { offset ->
                Plot(id = nextId + offset, kind = PlotKind.VERTICAL_FARM)
            }
            s.copy(coins = s.coins - GameData.VERTICAL_FARM_UNLOCK_COST, hasVerticalFarm = true, plots = s.plots + newPlots)
        }
        _events.value = GameEvent.Info("🌸 Saffron vertical farm built! Pay for electricity to start growing.")
        persist()
    }

    fun renewElectricity() {
        val current = _state.value
        if (!current.hasVerticalFarm) return
        if (current.coins < GameData.ELECTRICITY_COST) {
            _events.value = GameEvent.Info("Need ₹${GameData.ELECTRICITY_COST} for the electricity bill.")
            return
        }
        val now = System.currentTimeMillis()
        _state.update { s ->
            s.copy(
                coins = s.coins - GameData.ELECTRICITY_COST,
                electricityExpiresAtEpochMs = now + GameData.ELECTRICITY_DURATION_MS,
            )
        }
        _events.value = GameEvent.Info("Electricity bill paid. Grow lights powered.")
        persist()
    }

    // --- Mandi / e-NAM trading -------------------------------------------------------------

    /** Decays the stored glut for [crop] forward to [now] without mutating state. */
    fun currentGlut(current: GameState, crop: CropType, now: Long): Double {
        val stored = current.mandiGlut[crop] ?: return 0.0
        val elapsedHours = (now - stored.updatedAtEpochMs).coerceAtLeast(0) / 3_600_000.0
        val decayed = stored.value * exp(-GameData.MANDI_GLUT_DECAY_PER_HOUR * elapsedHours)
        return if (decayed < 0.001) 0.0 else decayed
    }

    /**
     * Combines the server-wide demand cycle, this crop's automatic grade bonus (protected
     * cultivation only), and its current oversupply glut into one clamped price multiplier.
     */
    fun mandiPriceMultiplier(current: GameState, crop: CropType, now: Long): Double {
        val cycleIndex = now / GameData.MANDI_CYCLE_MS
        val demandPercent = GameData.demandModifierPercent(crop, cycleIndex)
        val gradeBonusPercent = if (crop.requiredPlotKind != PlotKind.OPEN_FIELD) {
            GameData.MANDI_GRADE_A_BONUS_PERCENT
        } else {
            0
        }
        val glut = currentGlut(current, crop, now)
        val raw = 1.0 + demandPercent / 100.0 + gradeBonusPercent / 100.0 - glut
        return raw.coerceIn(GameData.MANDI_MIN_MULTIPLIER, GameData.MANDI_MAX_MULTIPLIER)
    }

    /** Tomorrow's demand swing, only meaningful once the auction terminal is bought. */
    fun mandiForecastPercent(crop: CropType, now: Long): Int {
        val nextCycleIndex = now / GameData.MANDI_CYCLE_MS + 1
        return GameData.demandModifierPercent(crop, nextCycleIndex)
    }

    fun buyMandi() {
        val current = _state.value
        if (current.hasMandi) return
        if (current.coins < GameData.MANDI_UNLOCK_COST) {
            _events.value = GameEvent.Info("Need ₹${GameData.MANDI_UNLOCK_COST} to register at the Local Mandi.")
            return
        }
        _state.update { s -> s.copy(coins = s.coins - GameData.MANDI_UNLOCK_COST, hasMandi = true) }
        _events.value = GameEvent.Info("🏛️ Registered at the Local Mandi -- e-NAM auctions are now open to you.")
        persist()
    }

    fun buyMandiTerminal() {
        val current = _state.value
        if (!current.hasMandi || current.hasMandiTerminal) return
        if (current.coins < GameData.MANDI_TERMINAL_COST) {
            _events.value = GameEvent.Info("Need ₹${GameData.MANDI_TERMINAL_COST} for a digital auction terminal.")
            return
        }
        _state.update { s -> s.copy(coins = s.coins - GameData.MANDI_TERMINAL_COST, hasMandiTerminal = true) }
        persist()
    }

    fun sellToMandi(crop: CropType) {
        val current = _state.value
        if (!current.hasMandi) return
        val stock = current.inventory[crop] ?: return
        if (stock.total == 0) return

        val now = System.currentTimeMillis()
        val marketMultiplier = mandiPriceMultiplier(current, crop, now)
        val farmhouseMultiplier = sellPriceMultiplier(current)
        val combined = marketMultiplier * farmhouseMultiplier

        val normalValue = (stock.normal * crop.baseSellPrice * combined).roundToLong()
        val damagedValue = (stock.damaged * crop.baseSellPrice * GameData.WEATHER_DAMAGE_YIELD_MULTIPLIER * combined)
            .roundToLong()
        val totalValue = normalValue + damagedValue

        val decayedGlut = currentGlut(current, crop, now)
        val newGlut = decayedGlut + stock.total * GameData.MANDI_GLUT_PER_UNIT

        _state.update { s ->
            s.copy(
                coins = s.coins + totalValue,
                inventory = s.inventory - crop,
                mandiGlut = s.mandiGlut + (crop to MandiGlut(newGlut, now)),
            )
        }
        val pct = (marketMultiplier * 100).roundToLong()
        _events.value = GameEvent.Info(
            "🏛️ Mandi bought ${stock.total} ${crop.displayName} at $pct% market rate for ₹$totalValue",
        )
        registerFestivalSale(crop, stock.total, now)
        persist()
    }

    private fun persist() {
        repository.save(_state.value)
    }
}
