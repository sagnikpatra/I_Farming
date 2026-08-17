package com.zonkrik.ifarming.village

import com.badlogic.gdx.graphics.g2d.TextureRegion
import com.badlogic.gdx.scenes.scene2d.Group
import com.badlogic.gdx.scenes.scene2d.InputEvent
import com.badlogic.gdx.scenes.scene2d.InputListener
import com.badlogic.gdx.scenes.scene2d.actions.Actions
import com.badlogic.gdx.scenes.scene2d.ui.Image
import com.badlogic.gdx.scenes.scene2d.ui.Label
import com.badlogic.gdx.utils.Align
import kotlin.math.abs
import kotlin.math.roundToInt

/** How long a press must be held before it "picks up" a draggable building, matching CoC's own pick-up feel. */
private const val LONG_PRESS_MS = 450L

/**
 * One tile on the village grid: a diamond ground image plus a standing sprite on top (the same
 * "billboarded sprite on an isometric ground tile" look as the Compose board's `IsoEntity`), with
 * a little ambient motion matching the earlier Compose board's "living world" touches:
 *  - [GroundKind.GROWING] tiles get a live countdown label + progress bar (updated locally every
 *    frame from [growthInfo]'s wall-clock timing -- no re-snapshot needed) and a gentle sway.
 *  - [GroundKind.READY] tiles bob up and down to catch the eye.
 *  - [GroundKind.WATER] tiles get an expanding/fading ripple ring.
 *
 * A `Group` so every child hit-tests/taps as one unit -- the tap/drag listener added to the group
 * still fires on taps that land on a child Image, since Scene2D bubbles touch events up the actor
 * tree.
 *
 * If [draggable] is true (only the six structure-zone building tiles are), a press held past
 * [LONG_PRESS_MS] "picks up" the tile -- it then follows the finger until release, snaps to the
 * nearest grid tile, and reports the drop via [onMoved]. A quick release still just taps, matching
 * CoC's own pick-up-vs-tap gesture split. See [DragCoordinator] for how this avoids fighting the
 * board's own camera-pan gesture.
 */
class Building(
    val id: Int,
    val tileX: Float,
    val tileY: Float,
    diamond: TextureRegion,
    sprite: TextureRegion,
    private val isoMath: IsoMath,
    groundKind: GroundKind,
    private val growthInfo: GrowthInfo?,
    private val draggable: Boolean,
    private val dragCoordinator: DragCoordinator,
    rotationDegrees: Int,
    flippedX: Boolean,
    private val onTap: () -> Unit,
    private val onMoved: (Float, Float) -> Unit,
) : Group() {

    private val depthKeyValue = isoMath.depthKey(tileX, tileY)
    private var progressFill: Image? = null
    private var countdownLabel: Label? = null
    private var progressBarWidth = 0f

    init {
        val diamondImage = Image(diamond)
        diamondImage.setPosition(0f, 0f)
        addActor(diamondImage)

        if (groundKind == GroundKind.WATER) addRipple(diamondImage)

        val spriteImage = Image(sprite)
        val standHeight = spriteImage.height * 0.6f
        setSize(diamondImage.width, diamondImage.height + standHeight)
        spriteImage.setPosition((diamondImage.width - spriteImage.width) / 2f, diamondImage.height * 0.35f)
        spriteImage.setOrigin(Align.center)
        spriteImage.rotation = rotationDegrees.toFloat()
        spriteImage.scaleX = if (flippedX) -1f else 1f
        addActor(spriteImage)

        when {
            growthInfo != null -> {
                addGrowthUi(diamondImage)
                animateSway(spriteImage)
            }
            groundKind == GroundKind.READY -> animateBob(spriteImage)
        }

        val (screenX, screenY) = isoMath.gridToScreen(tileX, tileY)
        setPosition(screenX - width / 2f, screenY)

        addListener(
            object : InputListener() {
                private var downAtMs = 0L
                private var armed = false

                override fun touchDown(event: InputEvent?, x: Float, y: Float, pointer: Int, button: Int): Boolean {
                    if (pointer != 0) return false
                    downAtMs = System.currentTimeMillis()
                    armed = false
                    return true
                }

                override fun touchDragged(event: InputEvent?, x: Float, y: Float, pointer: Int) {
                    if (!draggable) return
                    if (!armed && System.currentTimeMillis() - downAtMs >= LONG_PRESS_MS) {
                        armed = true
                        dragCoordinator.isDraggingBuilding = true
                        clearActions()
                        addAction(Actions.scaleTo(1.12f, 1.12f, 0.1f))
                    }
                    if (armed) {
                        moveBy(x - width / 2f, y - height / 2f)
                    }
                }

                override fun touchUp(event: InputEvent?, x: Float, y: Float, pointer: Int, button: Int) {
                    if (armed) {
                        armed = false
                        dragCoordinator.isDraggingBuilding = false
                        clearActions()
                        addAction(Actions.scaleTo(1f, 1f, 0.1f))
                        // The tile's own diamond sits at local (0,0); its screen anchor for gridToScreen
                        // is (centerX, bottomY) -- see how `setPosition` placed it above.
                        val anchorScreenX = this@Building.x + width / 2f
                        val anchorScreenY = this@Building.y
                        val (rawTileX, rawTileY) = isoMath.screenToGrid(anchorScreenX, anchorScreenY)
                        onMoved(rawTileX.roundToInt().toFloat(), rawTileY.roundToInt().toFloat())
                        return
                    }
                    if (System.currentTimeMillis() - downAtMs < LONG_PRESS_MS) {
                        addAction(
                            Actions.sequence(
                                Actions.scaleTo(1.15f, 1.15f, 0.08f),
                                Actions.scaleTo(1f, 1f, 0.08f),
                            ),
                        )
                        onTap()
                    }
                }
            },
        )
    }

    private fun addRipple(diamondImage: Image) {
        val ripple = Image(SolidTextures.circle())
        val size = diamondImage.width * 0.5f
        ripple.setSize(size, size)
        ripple.setPosition((diamondImage.width - size) / 2f, (diamondImage.height - size) / 2f)
        ripple.setOrigin(Align.center)
        ripple.setScale(0.1f)
        ripple.color.a = 0.5f
        addActor(ripple)

        val phaseDelay = (abs(id) % 4) * 0.5f
        ripple.addAction(
            Actions.delay(
                phaseDelay,
                Actions.forever(
                    Actions.sequence(
                        Actions.parallel(Actions.scaleTo(1f, 1f, 2f), Actions.alpha(0f, 2f)),
                        Actions.run {
                            ripple.setScale(0.1f)
                            ripple.color.a = 0.5f
                        },
                    ),
                ),
            ),
        )
    }

    private fun addGrowthUi(diamondImage: Image) {
        progressBarWidth = diamondImage.width * 0.6f
        val barHeight = 6f
        val barX = (diamondImage.width - progressBarWidth) / 2f
        val barY = diamondImage.height * 0.22f

        val track = Image(SolidTextures.white())
        track.color.set(0f, 0f, 0f, 0.35f)
        track.setBounds(barX, barY, progressBarWidth, barHeight)
        addActor(track)

        val fill = Image(SolidTextures.white())
        fill.color.set(GroundKind.READY.top)
        fill.setBounds(barX, barY, 0f, barHeight)
        addActor(fill)
        progressFill = fill

        val label = Label("", Label.LabelStyle(VillageFonts.get(), com.badlogic.gdx.graphics.Color.WHITE))
        label.setFontScale(0.8f)
        label.setPosition(diamondImage.width / 2f, barY + barHeight + 2f, Align.bottom)
        addActor(label)
        countdownLabel = label

        updateGrowthUi()
    }

    /** Gentle +/-3 degree sway, phase-offset by [id] so a field doesn't sway in lockstep. */
    private fun animateSway(sprite: Image) {
        val phaseDelay = (abs(id) % 5) * 0.2f
        sprite.addAction(
            Actions.delay(
                phaseDelay,
                Actions.forever(Actions.sequence(Actions.rotateTo(-3f, 0.7f), Actions.rotateTo(3f, 0.7f))),
            ),
        )
    }

    /** Slow up/down bob to draw the eye to a ready-to-harvest tile. */
    private fun animateBob(sprite: Image) {
        sprite.addAction(
            Actions.forever(Actions.sequence(Actions.moveBy(0f, 6f, 0.35f), Actions.moveBy(0f, -6f, 0.35f))),
        )
    }

    private fun updateGrowthUi() {
        val info = growthInfo ?: return
        val elapsedMs = (System.currentTimeMillis() - info.startAtMs).coerceIn(0, info.durationMs)
        val progress = if (info.durationMs > 0) elapsedMs.toFloat() / info.durationMs.toFloat() else 1f
        progressFill?.width = progressBarWidth * progress
        val remainingSeconds = ((info.durationMs - elapsedMs) / 1000L).coerceAtLeast(0)
        countdownLabel?.setText(formatCountdown(remainingSeconds))
    }

    override fun act(delta: Float) {
        super.act(delta)
        if (growthInfo != null) updateGrowthUi()
    }

    /** Used by [VillageStage] for depth sorting each frame. */
    fun depthKey(): Float = depthKeyValue
}

private fun formatCountdown(totalSeconds: Long): String {
    val h = totalSeconds / 3600
    val m = (totalSeconds % 3600) / 60
    val s = totalSeconds % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
}
