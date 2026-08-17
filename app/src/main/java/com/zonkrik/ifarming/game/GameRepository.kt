package com.zonkrik.ifarming.game

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Simple local save/load using SharedPreferences + JSON. No network, no
 * account system yet -- the game only needs to survive an app restart.
 */
class GameRepository(context: Context) {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun load(): GameState {
        val raw = prefs.getString(KEY_STATE, null) ?: return GameState()
        return runCatching { deserialize(raw) }.getOrDefault(GameState())
    }

    fun save(state: GameState) {
        prefs.edit().putString(KEY_STATE, serialize(state)).apply()
    }

    private fun serialize(state: GameState): String {
        val root = JSONObject()
        root.put("coins", state.coins)
        root.put("totalHarvests", state.totalHarvests)
        root.put("hasPolyhouse", state.hasPolyhouse)
        root.put("hasFanPad", state.hasFanPad)
        root.put("hasDripIrrigation", state.hasDripIrrigation)
        root.put("filmExpiresAt", state.filmExpiresAtEpochMs ?: -1L)
        root.put("hasAgroforestry", state.hasAgroforestry)
        root.put("hasSecurity", state.hasSecurity)
        root.put("hasAquaculture", state.hasAquaculture)
        root.put("hasVerticalFarm", state.hasVerticalFarm)
        root.put("electricityExpiresAt", state.electricityExpiresAtEpochMs ?: -1L)
        root.put("farmhouseLevel", state.farmhouseLevel)
        root.put("hasMandi", state.hasMandi)
        root.put("hasMandiTerminal", state.hasMandiTerminal)
        root.put("eventOccurrenceIndex", state.eventOccurrenceIndex)
        root.put("eventPoints", state.eventPoints)
        root.put("eventHasPremiumPass", state.eventHasPremiumPass)
        root.put("eventClaimedTier", state.eventClaimedTier)

        val glutObj = JSONObject()
        state.mandiGlut.forEach { (crop, glut) ->
            val glutEntry = JSONObject()
            glutEntry.put("value", glut.value)
            glutEntry.put("updatedAt", glut.updatedAtEpochMs)
            glutObj.put(crop.name, glutEntry)
        }
        root.put("mandiGlut", glutObj)

        val plotsArray = JSONArray()
        state.plots.forEach { plot ->
            val plotObj = JSONObject()
            plotObj.put("id", plot.id)
            plotObj.put("kind", plot.kind.name)
            plot.agroRow?.let { plotObj.put("agroRow", it) }
            plot.agroCol?.let { plotObj.put("agroCol", it) }
            plot.hostType?.let { plotObj.put("hostType", it.name) }
            when (val s = plot.state) {
                is PlotState.Empty -> plotObj.put("state", "EMPTY")
                is PlotState.Growing -> {
                    plotObj.put("state", "GROWING")
                    plotObj.put("crop", s.crop.name)
                    plotObj.put("plantedAt", s.plantedAtEpochMs)
                    plotObj.put("growSeconds", s.effectiveGrowSeconds)
                }
                is PlotState.ReadyToHarvest -> {
                    plotObj.put("state", "READY")
                    plotObj.put("crop", s.crop.name)
                    plotObj.put("damaged", s.weatherDamaged)
                    plotObj.put("readyAt", s.readyAtEpochMs)
                }
            }
            plotsArray.put(plotObj)
        }
        root.put("plots", plotsArray)

        val inventoryObj = JSONObject()
        state.inventory.forEach { (crop, stock) ->
            val stockObj = JSONObject()
            stockObj.put("normal", stock.normal)
            stockObj.put("damaged", stock.damaged)
            inventoryObj.put(crop.name, stockObj)
        }
        root.put("inventory", inventoryObj)

        val zoneLayoutObj = JSONObject()
        state.zoneLayout.forEach { (zoneId, anchor) ->
            val anchorObj = JSONObject()
            anchorObj.put("tileX", anchor.tileX)
            anchorObj.put("tileY", anchor.tileY)
            anchorObj.put("rotationDegrees", anchor.rotationDegrees)
            anchorObj.put("flippedX", anchor.flippedX)
            zoneLayoutObj.put(zoneId, anchorObj)
        }
        root.put("zoneLayout", zoneLayoutObj)

        val decorationsArray = JSONArray()
        state.decorations.forEach { decoration ->
            val decorationObj = JSONObject()
            decorationObj.put("id", decoration.id)
            decorationObj.put("type", decoration.type.name)
            decorationObj.put("tileX", decoration.tileX)
            decorationObj.put("tileY", decoration.tileY)
            decorationObj.put("rotationDegrees", decoration.rotationDegrees)
            decorationObj.put("flippedX", decoration.flippedX)
            decorationsArray.put(decorationObj)
        }
        root.put("decorations", decorationsArray)
        root.put("nextDecorationId", state.nextDecorationId)

        return root.toString()
    }

    private fun deserialize(raw: String): GameState {
        val root = JSONObject(raw)
        val coins = root.optLong("coins", 300)

        val plotsArray = root.optJSONArray("plots") ?: JSONArray()
        val plots = (0 until plotsArray.length()).map { index ->
            val plotObj = plotsArray.getJSONObject(index)
            val id = plotObj.getInt("id")
            val kind = runCatching { PlotKind.valueOf(plotObj.optString("kind", "OPEN_FIELD")) }
                .getOrDefault(PlotKind.OPEN_FIELD)
            val state: PlotState = when (plotObj.getString("state")) {
                "GROWING" -> {
                    val crop = CropType.valueOf(plotObj.getString("crop"))
                    PlotState.Growing(
                        crop = crop,
                        plantedAtEpochMs = plotObj.getLong("plantedAt"),
                        effectiveGrowSeconds = plotObj.optLong("growSeconds", crop.growSeconds),
                    )
                }
                "READY" -> PlotState.ReadyToHarvest(
                    crop = CropType.valueOf(plotObj.getString("crop")),
                    weatherDamaged = plotObj.optBoolean("damaged", false),
                    readyAtEpochMs = plotObj.optLong("readyAt", System.currentTimeMillis()),
                )
                else -> PlotState.Empty
            }
            val agroRow = if (plotObj.has("agroRow")) plotObj.getInt("agroRow") else null
            val agroCol = if (plotObj.has("agroCol")) plotObj.getInt("agroCol") else null
            val hostType = if (plotObj.has("hostType")) {
                runCatching { HostType.valueOf(plotObj.getString("hostType")) }.getOrNull()
            } else {
                null
            }
            Plot(id = id, kind = kind, state = state, agroRow = agroRow, agroCol = agroCol, hostType = hostType)
        }

        val inventoryObj = root.optJSONObject("inventory") ?: JSONObject()
        val inventory = inventoryObj.keys().asSequence().associate { key ->
            val stockObj = inventoryObj.getJSONObject(key)
            CropType.valueOf(key) to CropStock(
                normal = stockObj.optInt("normal", 0),
                damaged = stockObj.optInt("damaged", 0),
            )
        }

        val zoneLayoutObj = root.optJSONObject("zoneLayout") ?: JSONObject()
        val zoneLayout = zoneLayoutObj.keys().asSequence().associateWith { key ->
            val anchorObj = zoneLayoutObj.getJSONObject(key)
            ZoneAnchor(
                tileX = anchorObj.optDouble("tileX", 0.0).toFloat(),
                tileY = anchorObj.optDouble("tileY", 0.0).toFloat(),
                rotationDegrees = anchorObj.optInt("rotationDegrees", 0),
                flippedX = anchorObj.optBoolean("flippedX", false),
            )
        }

        val decorationsArray = root.optJSONArray("decorations") ?: JSONArray()
        val decorations = (0 until decorationsArray.length()).mapNotNull { index ->
            val decorationObj = decorationsArray.getJSONObject(index)
            val type = runCatching { DecorationType.valueOf(decorationObj.getString("type")) }.getOrNull()
                ?: return@mapNotNull null
            Decoration(
                id = decorationObj.getInt("id"),
                type = type,
                tileX = decorationObj.optDouble("tileX", 0.0).toFloat(),
                tileY = decorationObj.optDouble("tileY", 0.0).toFloat(),
                rotationDegrees = decorationObj.optInt("rotationDegrees", 0),
                flippedX = decorationObj.optBoolean("flippedX", false),
            )
        }
        val nextDecorationId = root.optInt("nextDecorationId", 0)

        val filmExpiresAt = root.optLong("filmExpiresAt", -1L).takeIf { it >= 0 }
        val electricityExpiresAt = root.optLong("electricityExpiresAt", -1L).takeIf { it >= 0 }

        val glutObj = root.optJSONObject("mandiGlut") ?: JSONObject()
        val mandiGlut = glutObj.keys().asSequence().mapNotNull { key ->
            val cropOrNull = runCatching { CropType.valueOf(key) }.getOrNull() ?: return@mapNotNull null
            val glutEntry = glutObj.getJSONObject(key)
            cropOrNull to MandiGlut(
                value = glutEntry.optDouble("value", 0.0),
                updatedAtEpochMs = glutEntry.optLong("updatedAt", 0L),
            )
        }.toMap()

        return GameState(
            coins = coins,
            plots = plots.ifEmpty { GameState().plots },
            inventory = inventory,
            totalHarvests = root.optLong("totalHarvests", 0),
            hasPolyhouse = root.optBoolean("hasPolyhouse", false),
            hasFanPad = root.optBoolean("hasFanPad", false),
            hasDripIrrigation = root.optBoolean("hasDripIrrigation", false),
            filmExpiresAtEpochMs = filmExpiresAt,
            hasAgroforestry = root.optBoolean("hasAgroforestry", false),
            hasSecurity = root.optBoolean("hasSecurity", false),
            hasAquaculture = root.optBoolean("hasAquaculture", false),
            hasVerticalFarm = root.optBoolean("hasVerticalFarm", false),
            electricityExpiresAtEpochMs = electricityExpiresAt,
            farmhouseLevel = root.optInt("farmhouseLevel", 0),
            hasMandi = root.optBoolean("hasMandi", false),
            hasMandiTerminal = root.optBoolean("hasMandiTerminal", false),
            mandiGlut = mandiGlut,
            eventOccurrenceIndex = root.optLong("eventOccurrenceIndex", -1L),
            eventPoints = root.optInt("eventPoints", 0),
            eventHasPremiumPass = root.optBoolean("eventHasPremiumPass", false),
            eventClaimedTier = root.optInt("eventClaimedTier", 0),
            zoneLayout = zoneLayout,
            decorations = decorations,
            nextDecorationId = nextDecorationId,
        )
    }

    private companion object {
        const val PREFS_NAME = "kisan_khet_save"
        const val KEY_STATE = "state_json"
    }
}
