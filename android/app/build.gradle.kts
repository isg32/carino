plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: set by build_signed.sh (from .env) or the release
// workflow (from secrets), never committed. Without them, release builds
// fall back to the debug key, so `flutter build apk --release` still works
// with no setup.
val releaseStoreFile = System.getenv("CARINO_KEYSTORE_FILE")?.let { file(it) }
val releaseStorePassword = System.getenv("CARINO_KEYSTORE_PASSWORD")?.takeIf { it.isNotEmpty() }
val releaseKeyPassword =
    System.getenv("CARINO_KEY_PASSWORD")?.takeIf { it.isNotEmpty() } ?: releaseStorePassword
val releaseKeyAlias = System.getenv("CARINO_KEY_ALIAS")?.takeIf { it.isNotEmpty() } ?: "upload"
val canSignRelease = releaseStorePassword != null && releaseStoreFile?.exists() == true

android {
    namespace = "com.isg32.carino"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.isg32.carino"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
            storeFile = releaseStoreFile
            storePassword = releaseStorePassword
        }
    }

    buildTypes {
        release {
            signingConfig = if (canSignRelease) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
