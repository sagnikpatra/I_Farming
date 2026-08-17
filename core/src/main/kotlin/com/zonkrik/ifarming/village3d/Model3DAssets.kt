package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.graphics.Color
import com.zonkrik.ifarming.village.TileSnapshot
import com.zonkrik.ifarming.village.ZONE_ID_AGROFORESTRY
import com.zonkrik.ifarming.village.ZONE_ID_AQUACULTURE
import com.zonkrik.ifarming.village.ZONE_ID_FARMHOUSE
import com.zonkrik.ifarming.village.ZONE_ID_MANDI
import com.zonkrik.ifarming.village.ZONE_ID_POLYHOUSE
import com.zonkrik.ifarming.village.ZONE_ID_VERTICAL_FARM

/**
 * Maps each structure zone / decoration to a real, hand-picked CC0 `.obj` asset (see
 * `assets_3d/README.md` at the repo root for the full sourcing notes) bundled under
 * `app/src/main/assets/models3d/`. Anything not covered here (crop plots, the land-expansion
 * ghost tile, Agroforestry host plants) has no dedicated 3D model and falls back to a billboarded
 * emoji quad instead -- see [Village3DStage]'s `rebuild`.
 */
object Model3DAssets {
    private val structureAssets = mapOf(
        ZONE_ID_FARMHOUSE to "models3d/structures/farmhouse/building-type-a.obj",
        ZONE_ID_POLYHOUSE to "models3d/structures/polyhouse/building-type-b.obj",
        // hedge-large.obj and watermill.obj (both fantasy-town-kit) render as broken black
        // silhouettes on-device for reasons not fully root-caused -- swapped for nature-kit
        // single-group flat-colored models instead, which have been reliable throughout testing.
        ZONE_ID_AGROFORESTRY to "models3d/structures/agroforestry/tree_default.obj",
        ZONE_ID_AQUACULTURE to "models3d/structures/aquaculture/bridge_stone.obj",
        ZONE_ID_VERTICAL_FARM to "models3d/structures/verticalfarm/building-type-c.obj",
        // stall.obj (fantasy-town-kit) has the same broken-black-render issue as hedge-large.obj
        // and watermill.obj above -- another city-kit-suburban building stands in instead (also
        // keeps the six structures in one consistent art style, rather than visibly mismatched
        // kits sitting side by side).
        ZONE_ID_MANDI to "models3d/structures/mandi/building-type-d.obj",
    )

    /**
     * Multiplied into a structure's baked material colors on first load (see [Model3DCache.get])
     * -- pushes the generic city-kit-suburban palette toward whitewashed-plaster-and-terracotta
     * (Farmhouse, on its way to a Haveli look) or a warm marketplace ochre (Mandi) instead of
     * leaving every building in its stock Western-suburb colors. Zones not listed here render
     * with their asset's original, unmodified colors.
     */
    private val structureTints = mapOf(
        ZONE_ID_FARMHOUSE to Color(1f, 0.82f, 0.62f, 1f),
        ZONE_ID_MANDI to Color(1f, 0.78f, 0.5f, 1f),
    )

    /** Keyed by the decoration's emoji -- `TileSnapshot.spriteKey` for a decoration tile is always its `DecorationType.emoji`. */
    private val decorationAssets = mapOf(
        "🪴" to "models3d/decorations/potted_plant/planter.obj",
        "🏵️" to "models3d/decorations/sunflower/flower_yellowA.obj",
        "🎋" to "models3d/decorations/bamboo/crops_bambooStageB.obj",
        // lantern.obj (fantasy-town-kit) has the same broken-black-render issue noted above --
        // graveyard-kit's lantern-candle.obj instead.
        "🪔" to "models3d/decorations/lantern/lantern-candle.obj",
        "⛲" to "models3d/decorations/fountain/fountain-round.obj",
        "🛕" to "models3d/decorations/statue/statue_obelisk.obj",
    )

    fun assetFor(tile: TileSnapshot): String? {
        if (tile.decorationId != null) return decorationAssets[tile.spriteKey]
        return tile.zoneId?.let { structureAssets[it] }
    }

    /** See [structureTints]. Null for decorations and any zone without a deliberate tint. */
    fun tintFor(tile: TileSnapshot): Color? {
        if (tile.decorationId != null) return null
        return tile.zoneId?.let { structureTints[it] }
    }
}
