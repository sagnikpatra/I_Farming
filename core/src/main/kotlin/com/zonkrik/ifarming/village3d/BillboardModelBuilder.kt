package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.graphics.GL20
import com.badlogic.gdx.graphics.VertexAttributes.Usage
import com.badlogic.gdx.graphics.g2d.TextureRegion
import com.badlogic.gdx.graphics.g3d.Material
import com.badlogic.gdx.graphics.g3d.Model
import com.badlogic.gdx.graphics.g3d.attributes.BlendingAttribute
import com.badlogic.gdx.graphics.g3d.attributes.IntAttribute
import com.badlogic.gdx.graphics.g3d.attributes.TextureAttribute
import com.badlogic.gdx.graphics.g3d.utils.ModelBuilder
import com.badlogic.gdx.math.Vector3

/**
 * Builds a small flat quad "billboard" [Model] textured with an emoji [TextureRegion], its corners
 * placed directly along [CameraRig]'s fixed right/up basis so it faces the board's camera without
 * needing per-frame rotation (the camera never free-rotates -- see [CameraRig]). Used for anything
 * without a hand-picked 3D model (crop plots, the land-expansion ghost tile, Agroforestry host
 * plants) -- a real 3D-rendered sprite standing on the tile, occluded by/occluding real geometry
 * correctly since it's genuinely part of the 3D scene now, not a 2D overlay.
 */
object BillboardModelBuilder {
    private val builder = ModelBuilder()

    fun build(region: TextureRegion, size: Float): Model {
        val material = Material(
            TextureAttribute.createDiffuse(region),
            BlendingAttribute(true, GL20.GL_SRC_ALPHA, GL20.GL_ONE_MINUS_SRC_ALPHA, 1f),
            IntAttribute.createCullFace(GL20.GL_NONE),
        )
        val attrs = (Usage.Position or Usage.Normal or Usage.TextureCoordinates).toLong()

        builder.begin()
        val part = builder.part("billboard", GL20.GL_TRIANGLES, attrs, material)
        val half = size / 2f
        val bottomLeft = Vector3(CameraRig.right).scl(-half)
        val bottomRight = Vector3(CameraRig.right).scl(half)
        val top = Vector3(CameraRig.up).scl(size)
        val topLeft = Vector3(bottomLeft).add(top)
        val topRight = Vector3(bottomRight).add(top)
        part.rect(bottomLeft, bottomRight, topRight, topLeft, CameraRig.towardCamera)
        return builder.end()
    }
}
