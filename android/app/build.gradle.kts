import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "us.adavidson.checklist"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "us.adavidson.checklist"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildFeatures {
        resValues = true
    }

    buildTypes {
        debug {
            // Separate ID so debug builds install alongside the release app
            // instead of replacing it (and wiping its data).
            applicationIdSuffix = ".debug"
            resValue("string", "app_name", "checklist (debug)")
        }
        // Flutter's profile mode has no resValue of its own, so without this
        // the manifest's @string/app_name fails to resolve.
        maybeCreate("profile").apply {
            initWith(getByName("debug"))
            // Shares the debug app's ID (and data); both are dev builds.
            applicationIdSuffix = ".debug"
            resValue("string", "app_name", "checklist (profile)")
            matchingFallbacks += listOf("debug")
        }
        release {
            resValue("string", "app_name", "checklist")
            // Falls back to the debug key when android/key.properties is
            // missing, so release builds still work on a fresh checkout.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
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
