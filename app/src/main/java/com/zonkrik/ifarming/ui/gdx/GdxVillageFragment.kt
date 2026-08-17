package com.zonkrik.ifarming.ui.gdx

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import com.badlogic.gdx.backends.android.AndroidApplicationConfiguration
import com.badlogic.gdx.backends.android.AndroidFragmentApplication
import com.zonkrik.ifarming.village3d.Village3DGame

/**
 * Hosts the real-3D LibGDX GL view as a Fragment -- LibGDX's supported way to embed inside an
 * existing Activity/UI, unlike `AndroidApplication` which expects to own (and extend) the whole
 * Activity. `AndroidApplication` can't be used here because it extends plain `Activity`, and
 * `MainActivity` needs to stay a `FragmentActivity` (a `ComponentActivity`) for the rest of the
 * app's Compose UI (`setContent`, `by viewModels()`) to keep working.
 *
 * See [GdxVillageBoard], which embeds this Fragment inside the Compose tree via `AndroidView` and
 * keeps [tapListener]/[zoneMovedListener]/[decorationMovedListener]/[groundTappedListener]/
 * [villageGame] wired to the current GameState/callbacks every recomposition.
 */
class GdxVillageFragment : AndroidFragmentApplication() {

    /** Exposed once `onCreateView` has run, so the host Composable can push GameState snapshots into it. */
    var villageGame: Village3DGame? = null
        private set

    /**
     * Updated every recomposition by [GdxVillageBoard] so a tap always routes to the *current*
     * GameState/callbacks, not whichever were captured when the Fragment was first created.
     */
    var tapListener: ((Int) -> Unit)? = null

    /** Fires with (zoneId, newTileX, newTileY) after a long-press-drag drops a structure -- see `Entity3D`. */
    var zoneMovedListener: ((String, Float, Float) -> Unit)? = null

    /** Fires with (decorationId, newTileX, newTileY) after a long-press-drag drops a decoration -- see `Entity3D`. */
    var decorationMovedListener: ((Int, Float, Float) -> Unit)? = null

    /** Fires with a (possibly non-integer) world tile position whenever a tap ray-misses every entity -- used for decoration placement. */
    var groundTappedListener: ((Float, Float) -> Unit)? = null

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        val config = AndroidApplicationConfiguration().apply {
            useAccelerometer = false
            useCompass = false
            // Real 3D geometry needs a depth buffer for faces to occlude each other correctly,
            // unlike the old 2D board which never needed one.
            depth = 16
        }
        // All callbacks fire from the GestureDetector's input handling on the GL thread; hop back
        // to the main thread before touching the listeners, since they end up calling Compose
        // state setters / GameViewModel methods that expect to run there.
        val game = Village3DGame(
            onTap = { id -> activity?.runOnUiThread { tapListener?.invoke(id) } },
            onZoneMoved = { zoneId, tileX, tileY -> activity?.runOnUiThread { zoneMovedListener?.invoke(zoneId, tileX, tileY) } },
            onDecorationMoved = { decorationId, tileX, tileY ->
                activity?.runOnUiThread { decorationMovedListener?.invoke(decorationId, tileX, tileY) }
            },
            onGroundTapped = { tileX, tileY -> activity?.runOnUiThread { groundTappedListener?.invoke(tileX, tileY) } },
        )
        villageGame = game
        return initializeForView(game, config)
    }
}
