package com.zonkrik.ifarming.ui.gdx

import android.view.View
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentContainerView
import com.badlogic.gdx.Gdx
import com.badlogic.gdx.graphics.PerspectiveCamera
import com.zonkrik.ifarming.game.DecorationType
import com.zonkrik.ifarming.game.GameData
import com.zonkrik.ifarming.game.GameState
import com.zonkrik.ifarming.game.GameViewModel
import com.zonkrik.ifarming.game.PlotKind
import com.zonkrik.ifarming.game.PlotState
import com.zonkrik.ifarming.ui.ChunkyTile
import com.zonkrik.ifarming.ui.iso.IsoSheet
import com.zonkrik.ifarming.ui.theme.SaffronDark
import com.zonkrik.ifarming.ui.theme.WoodBrownLight
import com.zonkrik.ifarming.village.AGROFORESTRY_BUILDING_ID
import com.zonkrik.ifarming.village.AQUACULTURE_BUILDING_ID
import com.zonkrik.ifarming.village.DECORATION_ID_OFFSET
import com.zonkrik.ifarming.village.FARMHOUSE_TILE_ID
import com.zonkrik.ifarming.village.LAND_GHOST_TILE_ID
import com.zonkrik.ifarming.village.MANDI_BUILDING_ID
import com.zonkrik.ifarming.village.POLYHOUSE_BUILDING_ID
import com.zonkrik.ifarming.village.TileSnapshot
import com.zonkrik.ifarming.village.VERTICAL_FARM_BUILDING_ID
import com.zonkrik.ifarming.village.ZONE_ID_AGROFORESTRY
import com.zonkrik.ifarming.village.ZONE_ID_AQUACULTURE
import com.zonkrik.ifarming.village.ZONE_ID_FARMHOUSE
import com.zonkrik.ifarming.village.ZONE_ID_MANDI
import com.zonkrik.ifarming.village.ZONE_ID_POLYHOUSE
import com.zonkrik.ifarming.village.ZONE_ID_VERTICAL_FARM
import com.zonkrik.ifarming.village3d.Camera3DSnapshot
import com.zonkrik.ifarming.village3d.Grid3D
import kotlin.math.roundToInt

/** Reused across calls (rather than allocated per-frame) purely to run `project()` against -- see [screenPositionOf]. */
private val projectionCamera = PerspectiveCamera()

/** World (tileX,tileY) -> on-screen px, using the live [Camera3DSnapshot] -- see `GdxInfoCard`. */
private fun screenPositionOf(snapshot: Camera3DSnapshot, tileX: Float, tileY: Float): Offset {
    projectionCamera.viewportWidth = snapshot.viewportWidth.toFloat()
    projectionCamera.viewportHeight = snapshot.viewportHeight.toFloat()
    projectionCamera.fieldOfView = snapshot.fieldOfViewY
    projectionCamera.near = snapshot.near
    projectionCamera.far = snapshot.far
    projectionCamera.position.set(snapshot.position)
    projectionCamera.direction.set(snapshot.direction)
    projectionCamera.up.set(snapshot.up)
    projectionCamera.update()

    val world = Grid3D.tileToWorld(tileX, tileY)
    world.y = 0.9f // roughly a structure's/decoration's midheight, so the card anchors above it, not at ground level
    val projected = projectionCamera.project(world)
    // GL is Y-up (origin bottom-left), Compose is Y-down (origin top-left).
    return Offset(projected.x, snapshot.viewportHeight - projected.y)
}

/**
 * Embeds the LibGDX village view inside the existing Compose tree via [AndroidView], hosting
 * [GdxVillageFragment] in a plain [FragmentContainerView] managed through the Activity's
 * `supportFragmentManager` -- the standard, supported way to mix classic Android UI (Fragments,
 * SurfaceViews) into Compose.
 *
 * Phase 4: tapping a building or a growing crop shows a floating CoC-style [GdxInfoCard] instead
 * of jumping straight into a sheet -- its position is tracked live against the LibGDX camera every
 * frame (via [Camera3DSnapshot]), so it stays anchored to the tile through pan/pinch-zoom. Empty and
 * ready-to-harvest plots stay instant one-tap actions, matching the earlier Compose board's design
 * (and real CoC, which doesn't interpose a card on "tap to collect" either).
 */
@Composable
fun GdxVillageBoard(
    state: GameState,
    viewModel: GameViewModel,
    onEmptyTapped: (Int) -> Unit,
    onEmptyAgroTileTapped: (Int) -> Unit,
    onOpenSheet: (IsoSheet) -> Unit,
    /** Set (from `FarmScreen`'s decoration picker) to arm placement mode -- the next board tap places this type. */
    pendingDecorationType: DecorationType? = null,
    /** Called once a placement (or a cancel) consumes [pendingDecorationType], so the host can clear it. */
    onDecorationPlacementConsumed: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val activity = LocalContext.current as FragmentActivity
    var fragment by remember { mutableStateOf<GdxVillageFragment?>(null) }
    var selection by remember { mutableStateOf<GdxSelection?>(null) }
    var hasCenteredOnFarmhouse by remember { mutableStateOf(false) }

    // Recomputed only when GameState changes -- also doubles as the position lookup for the info
    // card, so a building/plot's world position is only ever defined once (in the mapper), not
    // duplicated here.
    val tiles = remember(state) { VillageSnapshotMapper.build(state) }
    fun positionOf(id: Int): Pair<Float, Float> = tiles.find { it.id == id }?.let { it.tileX to it.tileY } ?: (0f to 0f)
    // The Farmhouse can be dragged anywhere -- "Home" always means wherever it currently is, not a
    // fixed world origin (that assumption broke once dragging shipped).
    val farmhouseAnchor = positionOf(FARMHOUSE_TILE_ID)

    fun selectBuilding(id: Int, emoji: String, title: String, subtitle: String, actionLabel: String, sheet: IsoSheet, zoneId: String) {
        val (tileX, tileY) = positionOf(id)
        selection = GdxSelection(
            tileX = tileX, tileY = tileY, emoji = emoji, title = title, subtitle = subtitle,
            actionLabel = actionLabel,
            onAction = {
                selection = null
                onOpenSheet(sheet)
            },
            onRotate = { viewModel.rotateZone(zoneId, tileX to tileY) },
            onFlip = { viewModel.flipZone(zoneId, tileX to tileY) },
        )
    }

    Box(modifier = modifier.fillMaxSize()) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { context ->
                FragmentContainerView(context).apply { id = View.generateViewId() }
            },
            update = { container ->
                val fragmentManager = activity.supportFragmentManager
                val existing = fragmentManager.findFragmentById(container.id) as? GdxVillageFragment
                fragment = existing ?: GdxVillageFragment().also {
                    fragmentManager.beginTransaction().replace(container.id, it).commitNowAllowingStateLoss()
                }
            },
        )

        val currentFragment = fragment
        if (currentFragment != null) {
            // Kept up to date every recomposition so a drop always saves against the current ViewModel.
            currentFragment.zoneMovedListener = { zoneId, tileX, tileY -> viewModel.moveZone(zoneId, tileX, tileY) }
            currentFragment.decorationMovedListener = { decorationId, tileX, tileY -> viewModel.moveDecoration(decorationId, tileX, tileY) }
            // A tap that ray-misses every entity (bare ground) only does something while a
            // decoration is armed for placement -- see the picker flow in `FarmScreen`.
            currentFragment.groundTappedListener = { tileX, tileY ->
                pendingDecorationType?.let { type ->
                    viewModel.placeDecoration(type, tileX.roundToInt().toFloat(), tileY.roundToInt().toFloat())
                    onDecorationPlacementConsumed()
                }
            }

            // Kept up to date every recomposition so a tap always resolves against the current state.
            currentFragment.tapListener = tapListener@{ id ->
                if (id <= DECORATION_ID_OFFSET) {
                    val decorationId = DECORATION_ID_OFFSET - id
                    val decoration = state.decorations.find { it.id == decorationId } ?: return@tapListener
                    selection = GdxSelection(
                        tileX = decoration.tileX,
                        tileY = decoration.tileY,
                        emoji = decoration.type.emoji,
                        title = decoration.type.displayName,
                        subtitle = "Decoration",
                        onRotate = { viewModel.rotateDecoration(decorationId) },
                        onFlip = { viewModel.flipDecoration(decorationId) },
                        onRemove = {
                            viewModel.removeDecoration(decorationId)
                            selection = null
                        },
                    )
                    return@tapListener
                }
                // While placement mode is armed, the Compose overlay below intercepts the tap instead
                // (it needs the raw screen position, not a resolved tile id) -- ignore normal routing.
                if (pendingDecorationType != null) return@tapListener

                val farmhouseLevel = GameData.farmhouseLevelDef(state.farmhouseLevel)
                when (id) {
                    FARMHOUSE_TILE_ID -> selectBuilding(
                        id, farmhouseLevel.emoji, farmhouseLevel.displayName,
                        "Farmhouse · Level ${state.farmhouseLevel} of ${GameData.FARMHOUSE_MAX_LEVEL}",
                        "Manage", IsoSheet.Farmhouse, ZONE_ID_FARMHOUSE,
                    )
                    LAND_GHOST_TILE_ID -> viewModel.buyLandExpansion()
                    POLYHOUSE_BUILDING_ID -> {
                        val cost = GameData.polyhouseCost(GameData.isSubsidyUnlocked(state.totalHarvests))
                        selectBuilding(
                            id, "🏠", "Polyhouse",
                            if (state.hasPolyhouse) "${GameData.POLYHOUSE_PLOT_COUNT} protected plots" else "Protected cultivation -- Colored Capsicum & Dutch Rose",
                            if (state.hasPolyhouse) "Manage" else "Build ₹$cost",
                            IsoSheet.Polyhouse, ZONE_ID_POLYHOUSE,
                        )
                    }
                    AGROFORESTRY_BUILDING_ID -> selectBuilding(
                        id, if (state.hasSecurity) "🛡️" else "🌳", "Agroforestry",
                        if (state.hasAgroforestry) {
                            "${GameData.AGROFORESTRY_GRID_SIZE}x${GameData.AGROFORESTRY_GRID_SIZE} Sandalwood grid" + if (state.hasSecurity) " · secured" else ""
                        } else {
                            "Grow Sandalwood (Srigandham) -- a multi-week, high-value crop"
                        },
                        if (state.hasAgroforestry) "Manage" else "Clear ₹${GameData.AGROFORESTRY_UNLOCK_COST}",
                        IsoSheet.Agroforestry, ZONE_ID_AGROFORESTRY,
                    )
                    AQUACULTURE_BUILDING_ID -> selectBuilding(
                        id, "🪷", "Makhana Ponds",
                        if (state.hasAquaculture) "${GameData.AQUACULTURE_PLOT_COUNT} pond plots" else "Aquaculture -- Fox Nut & Pond Fish",
                        if (state.hasAquaculture) "Manage" else "Excavate ₹${GameData.AQUACULTURE_UNLOCK_COST}",
                        IsoSheet.Niche, ZONE_ID_AQUACULTURE,
                    )
                    VERTICAL_FARM_BUILDING_ID -> selectBuilding(
                        id, "🌸", "Saffron Vertical Farm",
                        if (state.hasVerticalFarm) "${GameData.VERTICAL_FARM_PLOT_COUNT} compact plots" else "Ultra-high-value, low-footprint -- needs electricity",
                        if (state.hasVerticalFarm) "Manage" else "Build ₹${GameData.VERTICAL_FARM_UNLOCK_COST}",
                        IsoSheet.Niche, ZONE_ID_VERTICAL_FARM,
                    )
                    MANDI_BUILDING_ID -> selectBuilding(
                        id, "🏛️", "Mandi",
                        if (state.hasMandi) "e-NAM trading post" else "e-NAM trading post -- not yet built",
                        if (state.hasMandi) "Manage" else "Build ₹${GameData.MANDI_UNLOCK_COST}",
                        IsoSheet.Mandi, ZONE_ID_MANDI,
                    )
                    else -> {
                        val plot = state.plots.find { it.id == id }
                        when {
                            plot == null -> Unit
                            plot.kind == PlotKind.AGROFORESTRY && plot.hostType != null -> viewModel.removeHost(id)
                            plot.kind == PlotKind.AGROFORESTRY && plot.state is PlotState.Empty -> onEmptyAgroTileTapped(id)
                            plot.state is PlotState.Empty -> onEmptyTapped(id)
                            plot.state is PlotState.ReadyToHarvest -> viewModel.harvestPlot(id)
                            plot.state is PlotState.Growing -> {
                                val growing = plot.state as PlotState.Growing
                                val (tileX, tileY) = positionOf(id)
                                selection = GdxSelection(
                                    tileX = tileX,
                                    tileY = tileY,
                                    emoji = growing.crop.emoji,
                                    title = growing.crop.displayName,
                                    subtitle = "sells ₹${growing.crop.baseSellPrice}",
                                )
                            }
                        }
                    }
                }
            }

            // Re-pushed whenever GameState changes (plant/harvest/expand-land/build/etc.) -- not on
            // every nowMillis tick, since Building animates its own countdown/progress bar locally
            // from wall-clock time (see core's GrowthInfo/Building.act) and GameViewModel already
            // emits a fresh `state` the moment a crop finishes growing.
            LaunchedEffect(tiles, currentFragment) {
                val villageGame = currentFragment.villageGame ?: return@LaunchedEffect
                val spriteKeys = tiles.map(TileSnapshot::spriteKey).toSet()
                EmojiTextureCache.ensurePixmaps(spriteKeys) // CPU-only, safe here on the main thread.
                val (homeX, homeY) = farmhouseAnchor
                val shouldCenter = !hasCenteredOnFarmhouse
                if (shouldCenter) hasCenteredOnFarmhouse = true
                Gdx.app?.postRunnable {
                    // GL-thread only from here: resolving/uploading textures and rebuilding the stage.
                    val sprites = EmojiTextureCache.resolveTextures(spriteKeys)
                    villageGame.applySnapshot(tiles, sprites)
                    // `core` doesn't know which tile is "home" -- center on
                    // the Farmhouse's real position exactly once, as soon as the first snapshot (and
                    // therefore its actual saved/default position) is known.
                    if (shouldCenter) villageGame.centerCameraOn(homeX, homeY)
                }
            }

            // Natural (unexpanded) size, bottom-aligned -- must NOT fillMaxSize here, or its empty
            // area would sit on top of (and steal touches from) the LibGDX view beneath it.
            GdxQuickNavBar(
                homeAnchor = farmhouseAnchor,
                onNavigate = { col, row -> Gdx.app?.postRunnable { currentFragment.villageGame?.centerCameraOn(col, row) } },
                modifier = Modifier.align(Alignment.BottomCenter),
            )

            // Placement mode: while a decoration type is armed, any tap on the board (including
            // bare ground) places it there -- ray-picked and reported directly by `Village3DStage`
            // via `groundTappedListener`/`tapListener` above, not by a Compose-level tap catcher
            // (a 3D scene has no 2D screen-space affine transform to invert the way the old
            // isometric board did). This banner is just a visible "you're in placement mode" hint
            // plus a cancel target.
            val armedDecoration = pendingDecorationType
            if (armedDecoration != null) {
                ChunkyTile(
                    modifier = Modifier.align(Alignment.TopCenter).padding(top = 12.dp),
                    topColor = WoodBrownLight,
                    bottomColor = SaffronDark,
                    cornerRadius = 12.dp,
                    elevation = 4.dp,
                    onClick = onDecorationPlacementConsumed,
                ) {
                    Box(modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)) {
                        Text(
                            "${armedDecoration.emoji} Tap anywhere to place · tap here to cancel",
                            color = Color.White,
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp,
                        )
                    }
                }
            }

            val currentSelection = selection
            if (currentSelection != null) {
                var screenPosition by remember(currentSelection) { mutableStateOf(Offset(-9999f, -9999f)) }
                LaunchedEffect(currentSelection) {
                    while (true) {
                        withFrameMillis { }
                        val snapshot = currentFragment.villageGame?.cameraSnapshot ?: continue
                        screenPosition = screenPositionOf(snapshot, currentSelection.tileX, currentSelection.tileY)
                    }
                }
                GdxInfoCard(selection = currentSelection, screenPosition = screenPosition, onDismiss = { selection = null })
            }
        }
    }
}
