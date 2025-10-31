plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // ✅ correct plugin id
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.platovalabs.where_its_at"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
           sourceCompatibility = JavaVersion.VERSION_17
           targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true // ✅ needed with desugar dep below
    }

    kotlinOptions {
    jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.platovalabs.where_its_at"
        minSdk = flutter.minSdkVersion // ✅ we planned API 23+
        targetSdk = 34 // ✅ explicit; keep in sync with Flutter if it changes
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        release {
            storeFile = file("my-release-key.jks")
            storePassword = "mich@3l9"
            keyAlias = "my-key-alias"
            keyPassword = "mich@3l9"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            minifyEnabled = false
            shrinkResources = false
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
    }

    buildFeatures {
        viewBinding = true
    }
}

// ✅ dependencies must be top-level (not inside `android {}`)
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
