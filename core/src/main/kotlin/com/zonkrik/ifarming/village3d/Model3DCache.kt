package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.graphics.Color
import com.badlogic.gdx.graphics.g3d.Model
import com.badlogic.gdx.graphics.g3d.attributes.ColorAttribute
import com.badlogic.gdx.graphics.g3d.loader.ObjLoader

/** Loads and caches each hand-picked `.obj` exactly once, keyed by its internal asset path. Must be used from the GL thread. */
class Model3DCache {
    private val loader = ObjLoader()
    private val cache = mutableMapOf<String, Model>()

    /**
     * [tint], when given, is multiplied into every material's diffuse color the first time this
     * asset is loaded -- a cheap way to nudge a generic Kenney kit model's baked palette toward a
     * more Indian architectural one (whitewash, terracotta, ochre) without needing new textures.
     * Applied once per cached [Model], so every [com.badlogic.gdx.graphics.g3d.ModelInstance] built
     * from it (there's normally only one structure of a given type on the board at a time) shares it.
     */
    fun get(assetPath: String, tint: Color? = null): Model = cache.getOrPut(assetPath) {
        val model = loader.loadModel(Gdx.files.internal(assetPath))
        if (tint != null) applyTint(model, tint)
        model
    }

    private fun applyTint(model: Model, tint: Color) {
        model.materials.forEach { material ->
            val existing = material.get(ColorAttribute.Diffuse) as ColorAttribute?
            if (existing != null) {
                existing.color.mul(tint)
            } else {
                material.set(ColorAttribute.createDiffuse(tint))
            }
        }
    }

    fun dispose() {
        cache.values.forEach { it.dispose() }
        cache.clear()
    }
}
