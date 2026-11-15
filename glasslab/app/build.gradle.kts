plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.kyant.glasslab"
    compileSdk = 37

    defaultConfig {
        // Distinct id so it can sit next to PiliPlus 玻璃.
        applicationId = "com.moqi.piliplus.glasslab"
        minSdk = 26
        targetSdk = 37
        versionCode = 1
        versionName = "0.1"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    // The BOM pins the Compose version the vendored sources expect; declaring the
    // artifacts without versions keeps them consistent.
    implementation(platform("androidx.compose:compose-bom:2026.09.00"))
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.activity:activity-compose:1.11.0")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.foundation:foundation")

    // No io.github.kyant0:shapes and no material3/material-icons on purpose: the
    // former pins Compose in a way that fights the BOM, and the lab draws its own
    // glyphs, so the two inlined shapes (tool/vendor_glasslab.ps1) are enough.
}
