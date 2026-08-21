package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.graphics.GL20
import com.badlogic.gdx.graphics.Pixmap
import com.badlogic.gdx.graphics.Texture
import com.badlogic.gdx.graphics.VertexAttributes.Usage
import com.badlogic.gdx.graphics.g3d.Material
import com.badlogic.gdx.graphics.g3d.Model
import com.badlogic.gdx.graphics.g3d.attributes.BlendingAttribute
import com.badlogic.gdx.graphics.g3d.attributes.IntAttribute
import com.badlogic.gdx.graphics.g3d.attributes.TextureAttribute
import com.badlogic.gdx.graphics.g3d.utils.ModelBuilder
import com.badlogic.gdx.math.Vector3
import kotlin.math.PI
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sqrt

/**
 * A rangoli -- the painted/powdered floor pattern set outside Indian homes for festivals and daily
 * welcome -- rendered as a flat, alpha-blended decal lying directly on the grass, not a standing
 * billboard sprite. [DecorationType.RANGOLI][com.zonkrik.ifarming.game.DecorationType] previously
 * fell back to a floating lotus-emoji billboard like every other unmapped decoration -- a rangoli
 * is fundamentally a ground pattern, not an object standing *on* the ground, so it gets its own
 * flat decal instead (see [Village3DStage.rebuild]'s special case).
 */
object RangoliModelBuilder {
    private var cachedModel: Model? = null
    private const val TEXTURE_SIZE = 128
    private const val PETAL_COUNT = 8

    fun get(): Model = cachedModel ?: build().also { cachedModel = it }

    private fun build(): Model {
        val texture = buildTexture()
        val material = Material(
            TextureAttribute.createDiffuse(texture),
            BlendingAttribute(true, GL20.GL_SRC_ALPHA, GL20.GL_ONE_MINUS_SRC_ALPHA, 1f),
            IntAttribute.createCullFace(GL20.GL_NONE),
        )
        val attrs = (Usage.Position or Usage.Normal or Usage.TextureCoordinates).toLong()
        val builder = ModelBuilder()
        builder.begin()
        val part = builder.part("rangoli", GL20.GL_TRIANGLES, attrs, material)
        val half = TILE_SPACING / 2f * 0.85f
        // Sits a hair above the ground/path decals below it to avoid z-fighting.
        part.rect(
            Vector3(-half, 0.03f, half), Vector3(half, 0.03f, half),
            Vector3(half, 0.03f, -half), Vector3(-half, 0.03f, -half),
            Vector3(0f, 1f, 0f),
        )
        val model = builder.end()
        model.manageDisposable(texture)
        return model
    }

    private fun buildTexture(): Texture {
        val pixmap = Pixmap(TEXTURE_SIZE, TEXTURE_SIZE, Pixmap.Format.RGBA8888)
        val center = (TEXTURE_SIZE - 1) / 2.0
        val outerRadius = center * 0.92

        // Festive rangoli palette -- the colors traditionally used in kolam/rangoli powder.
        val petalA = doubleArrayOf(0.85, 0.15, 0.45) // magenta
        val petalB = doubleArrayOf(0.95, 0.65, 0.10) // saffron
        val centerColor = doubleArrayOf(0.80, 0.10, 0.15) // deep red bindu
        val outline = doubleArrayOf(1.0, 0.95, 0.85) // warm white

        val anglePerPetal = 2.0 * PI / PETAL_COUNT

        for (y in 0 until TEXTURE_SIZE) {
            for (x in 0 until TEXTURE_SIZE) {
                val dx = x - center
                val dy = y - center
                val dist = sqrt(dx * dx + dy * dy)
                if (dist > outerRadius) {
                    pixmap.setColor(0f, 0f, 0f, 0f)
                    pixmap.drawPixel(x, y)
                    continue
                }
                val normDist = dist / outerRadius
                val angle = atan2(dy, dx) + PI // 0..2*PI
                val sector = (angle / anglePerPetal).toInt()
                val localAngle = angle - (sector + 0.5) * anglePerPetal // -half..+half within the petal
                // cos maps the petal's angular center to a full bump (1.0) and its edges to 0 --
                // a smooth scalloped lobe rather than a plain disc or a hard pie-slice.
                val bump = cos((localAngle / (anglePerPetal / 2.0)) * (PI / 2.0)).coerceIn(0.0, 1.0)
                val lobeRadius = 0.40 + 0.42 * bump

                var r: Double
                var g: Double
                var b: Double
                var alpha = 1.0
                when {
                    normDist < 0.14 -> {
                        r = centerColor[0]; g = centerColor[1]; b = centerColor[2]
                    }
                    normDist < 0.20 -> {
                        r = outline[0]; g = outline[1]; b = outline[2]
                    }
                    normDist < lobeRadius -> {
                        // Alternate the two petal colors pinwheel-style, sector by sector.
                        val petal = if (sector % 2 == 0) petalA else petalB
                        r = petal[0]; g = petal[1]; b = petal[2]
                    }
                    normDist < lobeRadius + 0.035 -> {
                        r = outline[0]; g = outline[1]; b = outline[2]
                    }
                    else -> {
                        alpha = 0.0
                        r = 0.0; g = 0.0; b = 0.0
                    }
                }
                // Soft-fade the very outer edge so the decal blends into the grass instead of
                // ending in a hard silhouette.
                if (normDist > 0.85) alpha *= ((1.0 - normDist) / 0.15).coerceIn(0.0, 1.0)
                pixmap.setColor(r.toFloat(), g.toFloat(), b.toFloat(), alpha.toFloat())
                pixmap.drawPixel(x, y)
            }
        }
        val texture = Texture(pixmap)
        pixmap.dispose()
        return texture
    }

    fun dispose() {
        cachedModel?.dispose()
        cachedModel = null
    }
}
