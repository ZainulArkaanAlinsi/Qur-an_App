import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.quran_app_2025"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // Play Store ID; the Kotlin namespace above stays unchanged.
        applicationId = "com.zainularkaan.quran"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "Ruang Tilawah"

        // Satu APK dibagikan lewat GitHub Releases, jadi isinya memuat kode
        // mesin tiap arsitektur. x86_64 praktis hanya dipakai emulator dan
        // sebagian Chromebook; membuangnya memangkas ukuran unduhan pengguna.
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    // Release key lives outside the repo; android/key.properties (git-ignored)
    // points to it. Without that file, release builds fall back to the debug
    // key so `flutter run --release` still works, but such APKs must never be
    // distributed: users could not update them with the official build.
    val keyProperties = Properties().apply {
        val file = rootProject.file("key.properties")
        if (file.exists()) file.inputStream().use { load(it) }
    }
    val hasReleaseKey = keyProperties.getProperty("storeFile") != null

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // Build debug terpasang BERDAMPINGAN dengan aplikasi rilis di HP:
        // ID dan nama berbeda, jadi debug (kunci debug) tidak menimpa atau
        // memaksa mencopot aplikasi rilis beserta data lokalnya.
        debug {
            applicationIdSuffix = ".debug"
            manifestPlaceholders["appLabel"] = "Ruang Tilawah Debug"
        }
        release {
            if (!hasReleaseKey) {
                logger.warn(
                    "WARNING: android/key.properties not found; release build " +
                        "is signed with the DEBUG key and must not be distributed.",
                )
            }
            signingConfig = signingConfigs.getByName(
                if (hasReleaseKey) "release" else "debug",
            )
        }
    }
}

// google-services.json hanya mendaftarkan ID rilis. Build debug (.debug)
// melewati langkah ini; Firebase tetap diinisialisasi dari
// DefaultFirebaseOptions di Dart (gagalnya tidak menghentikan aplikasi).
tasks.configureEach {
    if (name == "processDebugGoogleServices") enabled = false
}

// Kotlin 2.3 removed kotlinOptions.jvmTarget; same JVM 11 target as Java.
kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // FileProvider untuk menyerahkan APK pembaruan ke pemasang sistem.
    implementation("androidx.core:core-ktx:1.13.1")
}

flutter {
    source = "../.."
}
