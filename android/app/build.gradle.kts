plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.ksmi.koperasi"
    compileSdk = 36

    // ✅ ambil versi dari local.properties (fix unresolved reference)
    val flutterVersionCode = project.findProperty("flutterVersionCode")?.toString()?.toIntOrNull() ?: 1
    val flutterVersionName = project.findProperty("flutterVersionName")?.toString() ?: "1.0.0"

    defaultConfig {
        applicationId = "com.ksmi.koperasi"
        minSdk = 21
        targetSdk = 36
        versionCode = flutterVersionCode
        versionName = flutterVersionName
        multiDexEnabled = true
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.24")

    // ✅ Gunakan Firebase BoM versi stabil yang cocok dengan firebase_messaging 16.x
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")

    // ✅ Desugar versi stabil (2.1.4 terbaru)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    implementation("androidx.multidex:multidex:2.0.1")
}
