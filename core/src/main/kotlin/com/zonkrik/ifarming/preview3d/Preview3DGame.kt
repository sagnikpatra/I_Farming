package com.zonkrik.ifarming.preview3d

import com.badlogic.gdx.ApplicationAdapter
import com.badlogic.gdx.Gdx
import com.badlogic.gdx.graphics.GL20
import com.badlogic.gdx.graphics.PerspectiveCamera
import com.badlogic.gdx.graphics.g3d.Environment
import com.badlogic.gdx.graphics.g3d.Model
import com.badlogic.gdx.graphics.g3d.ModelBatch
import com.badlogic.gdx.graphics.g3d.ModelInstance
import com.badlogic.gdx.graphics.g3d.attributes.ColorAttribute
import com.badlogic.gdx.graphics.g3d.environment.DirectionalLight
import com.badlogic.gdx.graphics.g3d.loader.ObjLoader
import com.badlogic.gdx.graphics.g3d.utils.CameraInputController
import com.badlogic.gdx.math.Vector3
import com.badlogic.gdx.math.collision.BoundingBox

/**
 * Phase 1 proof-of-concept for the (separately scoped) "real 3D models" migration -- proves the
 * `ModelBatch`/`PerspectiveCamera`/`Environment` rendering pipeline actually works end-to-end on
 * device (loading a Kenney `.obj`+`.mtl` from Android assets, lighting it, rendering it) *before*
 * any investment in the much bigger interaction rewrite (ray-picking, drag/rotate against 3D
 * transforms) that real board integration would need. Deliberately isolated from the production
 * `VillageGame`/`VillageStage` (which still render the 2D board) -- this never touches that code.
 *
 * Ships loading `nature-kit`'s `statue_head.obj` (flat vertex-colored, single `g` group) since it
 * renders cleanly with zero caveats -- confirmed the whole pipeline correct end-to-end on-device.
 * Textured multi-material models (e.g. `city-kit-suburban`'s `planter.obj`) were also tested here
 * and their `map_Kd` texture *does* load and sample correctly; a couple of things worth knowing
 * before Part 3 proper picks specific models to integrate:
 *  - Kenney's OBJ export repeats identical `g <name>` lines within one logical object (once per
 *    material switch). LibGDX's `ObjLoader` treats a repeated group name as the *same* group
 *    (correct per the OBJ spec), so this isn't a bug -- but it does mean the whole group ends up as
 *    one `Node`/`NodePart`, all sharing whatever material was last assigned to it.
 *  - Some Kenney models genuinely sample into a solid-black region of their shared `colormap.png`
 *    atlas (verified by inspecting the PNG directly) -- a part rendering solid black is very
 *    plausibly correct/intentional, not a missing-texture bug.
 *  - One model (`fantasy-town-kit/windmill.obj`) rendered as an oddly cropped fragment in testing;
 *    unconfirmed whether that's a camera-framing edge case for that specific asset's geometry or
 *    something else -- worth re-checking whenever Part 3 actually reaches for it.
 *
 * Reachable from the "🧊 3D Preview" HUD button in `FarmScreen` via `Preview3DScreen`/
 * `Preview3DFragment`, the same `AndroidFragmentApplication` embedding pattern as the village
 * board itself.
 */
class Preview3DGame : ApplicationAdapter() {

    private lateinit var modelBatch: ModelBatch
    private lateinit var model: Model
    private lateinit var instance: ModelInstance
    private lateinit var camera: PerspectiveCamera
    private lateinit var environment: Environment
    private lateinit var cameraController: CameraInputController
    private var spinDegrees = 0f

    override fun create() {
        modelBatch = ModelBatch()

        environment = Environment()
        environment.set(ColorAttribute(ColorAttribute.AmbientLight, 0.55f, 0.55f, 0.6f, 1f))
        environment.add(DirectionalLight().set(0.8f, 0.8f, 0.75f, -0.6f, -1f, -0.4f))

        model = ObjLoader().loadModel(Gdx.files.internal("models3d/statue/statue_head.obj"))
        instance = ModelInstance(model)

        camera = PerspectiveCamera(52f, Gdx.graphics.width.toFloat(), Gdx.graphics.height.toFloat())
        camera.near = 0.1f
        camera.far = 100f
        frameCameraOnModel()

        // Lets a finger-drag orbit the camera too, on top of the automatic turntable spin below --
        // useful for eyeballing a model from every angle while proving out the pipeline.
        cameraController = CameraInputController(camera)
        Gdx.input.inputProcessor = cameraController
    }

    /**
     * Points the camera at the model's actual bounding-box center from a distance derived from its
     * radius, instead of a hardcoded position -- Kenney's kits span wildly different scales model to
     * model (a `statue_head` vs. a `windmill`), so this keeps whichever `.obj` this screen is
     * pointed at fully framed without per-model tuning.
     */
    private fun frameCameraOnModel() {
        val bounds = BoundingBox()
        instance.calculateBoundingBox(bounds)
        val center = Vector3()
        bounds.getCenter(center)
        val radius = bounds.getDimensions(Vector3()).len() / 2f

        camera.position.set(center).add(radius * 1.4f, radius * 1.2f, radius * 1.4f)
        camera.lookAt(center)
        camera.update()
    }

    override fun resize(width: Int, height: Int) {
        camera.viewportWidth = width.toFloat()
        camera.viewportHeight = height.toFloat()
        camera.update()
    }

    override fun render() {
        cameraController.update()

        // Slow automatic turntable so the model is visibly 3D (parallax/shading change) even
        // without touching the screen -- the point of this screen is "does this actually render",
        // not "is this the final interaction model".
        spinDegrees += Gdx.graphics.deltaTime * 20f
        instance.transform.setToRotation(0f, 1f, 0f, spinDegrees)

        Gdx.gl.glViewport(0, 0, Gdx.graphics.width, Gdx.graphics.height)
        Gdx.gl.glClearColor(0.15f, 0.17f, 0.2f, 1f)
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT or GL20.GL_DEPTH_BUFFER_BIT)
        Gdx.gl.glEnable(GL20.GL_DEPTH_TEST)

        modelBatch.begin(camera)
        modelBatch.render(instance, environment)
        modelBatch.end()
    }

    override fun dispose() {
        modelBatch.dispose()
        model.dispose()
    }
}
