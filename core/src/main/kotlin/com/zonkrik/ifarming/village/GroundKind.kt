package com.zonkrik.ifarming.village

import com.badlogic.gdx.graphics.Color

/**
 * Ground-tile color pairs, matching the same hex values as the Compose board's
 * `ui/theme/Color.kt` (SoilBrown/FieldGreen/RipeGold/WoodBrownLight) -- duplicated here
 * deliberately, same as `IsoMath`: `core` must not depend on the `app` module.
 */
enum class GroundKind(val top: Color, val bottom: Color) {
    SOIL(Color.valueOf("6B4226"), Color.valueOf("3E2412")),
    GROWING(Color.valueOf("2E7D32"), Color.valueOf("1B5E20")),
    READY(Color.valueOf("FFC107"), Color.valueOf("C56A00")),
    GHOST(Color.valueOf("6B422688"), Color.valueOf("3E241288")),
    FARMHOUSE(Color.valueOf("8A5A34"), Color.valueOf("3E2412")),
    /** Aquaculture pond tiles (Empty/Growing only -- ReadyToHarvest still uses READY everywhere). */
    WATER(Color.valueOf("4FA8D8"), Color.valueOf("1D5C82")),
    /** A built (unlocked) structure's footprint -- Polyhouse/Agroforestry/Aquaculture/Vertical Farm/Mandi, and Agroforestry host tiles. */
    UNLOCKED(Color.valueOf("66BB6A"), Color.valueOf("2E7D32")),
    /** A dirt path tile. */
    PATH(Color.valueOf("8D6E63"), Color.valueOf("5D4037")),
}
