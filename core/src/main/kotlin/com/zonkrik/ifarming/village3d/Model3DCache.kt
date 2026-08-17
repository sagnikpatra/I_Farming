package com.zonkrik.ifarming.village3d

import com.badlogic.gdx.Gdx
import com.badlogic.gdx.graphics.g3d.Model
import com.badlogic.gdx.graphics.g3d.loader.ObjLoader

/** Loads and caches each hand-picked `.obj` exactly once, keyed by its internal asset path. Must be used from the GL thread. */
class Model3DCache {
    private val loader = ObjLoader()
    private val cache = mutableMapOf<String, Model>()

    fun get(assetPath: String): Model = cache.getOrPut(assetPath) {
        loader.loadModel(Gdx.files.internal(assetPath))
    }

    fun dispose() {
        cache.values.forEach { it.dispose() }
        cache.clear()
    }
}
