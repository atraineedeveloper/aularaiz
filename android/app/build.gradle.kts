import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties =
    Properties().apply {
        if (keystorePropertiesFile.exists()) {
            keystorePropertiesFile.inputStream().use { load(it) }
        }
    }

android {
    namespace = "com.mindtzijib.aularaiz"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mindtzijib.aularaiz"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                val storeFilePath =
                    requireNotNull(keystoreProperties.getProperty("storeFile")) {
                        "storeFile is missing from android/key.properties"
                    }
                storeFile = file(storeFilePath)
                storePassword =
                    requireNotNull(keystoreProperties.getProperty("storePassword")) {
                        "storePassword is missing from android/key.properties"
                    }
                keyAlias =
                    requireNotNull(keystoreProperties.getProperty("keyAlias")) {
                        "keyAlias is missing from android/key.properties"
                    }
                keyPassword =
                    requireNotNull(keystoreProperties.getProperty("keyPassword")) {
                        "keyPassword is missing from android/key.properties"
                    }
            }
        }
    }

    buildTypes {
        release {
            // Never fall back to the debug keystore for production builds.
            // Local unsigned release builds remain possible, while the release
            // workflow injects android/key.properties and the production key.
            signingConfigs.findByName("release")?.let { signingConfig = it }
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
