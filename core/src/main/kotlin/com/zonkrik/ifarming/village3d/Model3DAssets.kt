package com.zonkrik.ifarming.village3d

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
        ZONE_ID_AGROFORESTRY to "models3d/structures/agroforestry/hedge-large.obj",
        ZONE_ID_AQUACULTURE to "models3d/structures/aquaculture/watermill.obj",
        ZONE_ID_VERTICAL_FARM to "models3d/structures/verticalfarm/building-type-c.obj",
        ZONE_ID_MANDI to "models3d/structures/mandi/stall.obj",
    )

    /** Keyed by the decoration's emoji -- `TileSnapshot.spriteKey` for a decoration tile is always its `DecorationType.emoji`. */
    private val decorationAssets = mapOf(
        "🪴" to "models3d/decorations/potted_plant/planter.obj",
        "🌻" to "models3d/decorations/sunflower/flower_yellowA.obj",
        "🎋" to "models3d/decorations/bamboo/crops_bambooStageB.obj",
        "🏮" to "models3d/decorations/lantern/lantern.obj",
        "⛲" to "models3d/decorations/fountain/fountain-round.obj",
        "🗿" to "models3d/decorations/statue/statue_obelisk.obj",
    )

    fun assetFor(tile: TileSnapshot): String? {
        if (tile.decorationId != null) return decorationAssets[tile.spriteKey]
        return tile.zoneId?.let { structureAssets[it] }
    }
}
