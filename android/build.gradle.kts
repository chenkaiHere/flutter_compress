group = "com.compress.all.flutter_compress"
version = "1.0-SNAPSHOT"

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.compress.all.flutter_compress"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
        // Ships our R8 keep rules to consuming apps. Without this line the
        // consumer-rules.pro file would be inert.
        consumerProguardFiles("consumer-rules.pro")
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Exact versions here are the *tested* ones, not a lock. Gradle treats a plain
// `group:name:version` as a preference and resolves conflicts upward, so an app
// that declares a newer Media3 still wins — the pin costs consumers nothing.
//
// A floating range (`1.4.+`) would be worse than useless here: Media3 changed
// `DefaultMuxer.Factory(long)` from a sample-interval timeout to a video
// duration inside the 1.x line, which silently truncated every output to 30s.
// That class of change compiles clean and passes unit tests, so builds must stay
// reproducible and upgrades must be deliberate (CLAUDE.md §12.3).
private val media3 = "1.4.1"

dependencies {
    // Google's official, hardware-accelerated transcoding pipeline. Media3
    // owns the device/codec compatibility matrix so we don't have to.
    implementation("androidx.media3:media3-transformer:$media3")
    implementation("androidx.media3:media3-effect:$media3")
    implementation("androidx.media3:media3-common:$media3")
    // Provides androidx.media3.muxer.* referenced by DefaultMuxer.
    implementation("androidx.media3:media3-muxer:$media3")

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    testImplementation("org.jetbrains.kotlin:kotlin-test-junit5")
    testImplementation("org.mockito:mockito-core:5.0.0")
    // testOptions uses useJUnitPlatform(), which needs a JUnit 5 engine present.
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine:5.10.2")
}
