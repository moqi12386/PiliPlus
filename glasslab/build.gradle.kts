plugins {
    // Same stack the Flutter app module already uses (see android/settings.gradle.kts),
    // so the lab builds against the Compose version the vendored code was written for.
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.0" apply false
}
