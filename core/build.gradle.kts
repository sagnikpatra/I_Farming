// Plain Kotlin/JVM module -- no Android, no Compose. This is where the actual LibGDX game/render
// logic lives, kept platform-independent per LibGDX convention (the `app` module supplies the
// Android glue: the GL view, emoji-rasterized textures, and the GameState/tap bridge).
plugins {
    alias(libs.plugins.kotlin.jvm)
}

kotlin {
    jvmToolchain(11)
}

dependencies {
    api(libs.gdx.core)
}
