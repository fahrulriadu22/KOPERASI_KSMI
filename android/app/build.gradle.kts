plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.ksmi.koperasi"

    // ✅ Gunakan compileSdk eksplisit agar build lebih konsisten
    compileSdk = 33
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.ksmi.koperasi"
        minSdk = 23        // ✅ pastikan sama dengan minSdkVersion di pubspec
        targetSdk = 33
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // ⚠️ Gunakan keystore release sendiri nanti, bukan debug
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // ✅ Pastikan Flutter resource path tetap benar
    sourceSets["main"].java.srcDirs("src/main/kotlin")
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
