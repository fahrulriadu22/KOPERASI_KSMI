plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.ksmi.koperasi"
    compileSdk = 34  // ✅ Aman sampai Android 14

    val flutterVersionCode = project.findProperty("flutterVersionCode")?.toString()?.toIntOrNull() ?: 1
    val flutterVersionName = project.findProperty("flutterVersionName")?.toString() ?: "1.0.0"

    defaultConfig {
        applicationId = "com.ksmi.koperasi"
        minSdk = 23             // ✅ Android 6.0+ (wajib utk Firebase/Notif modern)
        targetSdk = 34          // ✅ Kompatibel dg Play Store
        versionCode = flutterVersionCode
        versionName = flutterVersionName
        multiDexEnabled = true
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    ndkVersion = "26.1.10909125"
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.24")
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
}
