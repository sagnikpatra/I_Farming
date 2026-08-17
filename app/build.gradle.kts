plugins {
    alias(libs.plugins.android.application)
    // AGP 9's built-in Kotlin support replaces org.jetbrains.kotlin.android;
    // applying it explicitly conflicts with AGP's own "kotlin" extension.
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.zonkrik.ifarming"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "com.zonkrik.ifarming"
        minSdk = 24
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            optimization {
                enable = false
            }
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
    }

    sourceSets.getByName("main") {
        jniLibs.srcDir(layout.buildDirectory.dir("generated/gdxNatives").get().asFile)
    }
}

// LibGDX's `gdx-platform` natives artifacts are plain jars with .so files loose at the jar root --
// not proper AGP-recognized native-library artifacts -- so a normal `implementation` dependency
// silently drops them from the APK. This is the classic LibGDX Gradle "copy natives" task: pull
// each ABI-classified jar's .so files into build/generated/gdxNatives/<abi>/, which is registered
// above as a jniLibs source dir AGP *does* know how to package.
val gdxNatives: Configuration by configurations.creating

val extractGdxNatives by tasks.registering(Copy::class) {
    // Order matters: "natives-x86" is a substring of "natives-x86_64", so the longer/more
    // specific classifier must be checked first or the x86_64 jar's contents would also match it.
    val abiByClassifier = listOf(
        "natives-armeabi-v7a" to "armeabi-v7a",
        "natives-arm64-v8a" to "arm64-v8a",
        "natives-x86_64" to "x86_64",
        "natives-x86" to "x86",
    )
    gdxNatives.files.forEach { jarFile ->
        val abi = abiByClassifier.firstOrNull { jarFile.name.contains(it.first) }?.second
        if (abi != null) {
            from(zipTree(jarFile)) {
                include("*.so")
                into(abi)
            }
        }
    }
    into(layout.buildDirectory.dir("generated/gdxNatives"))
    duplicatesStrategy = DuplicatesStrategy.WARN
}

tasks.matching { it.name.contains("merge") && it.name.contains("JniLibFolders") }.configureEach {
    dependsOn(extractGdxNatives)
}

dependencies {
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.core.ktx)
    implementation(libs.material)

    // LibGDX village-view renderer (see core/ module + ui/gdx/).
    implementation(project(":core"))
    implementation(libs.gdx.backend.android)
    gdxNatives(variantOf(libs.gdx.platform) { classifier("natives-armeabi-v7a") })
    gdxNatives(variantOf(libs.gdx.platform) { classifier("natives-arm64-v8a") })
    gdxNatives(variantOf(libs.gdx.platform) { classifier("natives-x86") })
    gdxNatives(variantOf(libs.gdx.platform) { classifier("natives-x86_64") })

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    debugImplementation(libs.androidx.compose.ui.tooling)

    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(platform(libs.androidx.compose.bom))
}
