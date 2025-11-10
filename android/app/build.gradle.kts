import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    println("✅ Loaded keystore from ${keystorePropertiesFile.absolutePath}")
} else {
    println("⚠️ key.properties not found, using unsigned build")
}

android {
    namespace = "com.ksmi.koperasi"
    compileSdk = 34 // ✅ TURUNKAN DARI 36 KE 34
    ndkVersion = "26.1.10909125" // ✅ VERSI LEBIH STABIL

    val flutterVersionCode = project.findProperty("flutterVersionCode")?.toString()?.toIntOrNull() ?: 1
    val flutterVersionName = project.findProperty("flutterVersionName")?.toString() ?: "1.0.0"

    defaultConfig {
        applicationId = "com.ksmi.koperasi"
        minSdk = 23
        targetSdk = 34 // ✅ TURUNKAN DARI 36 KE 34
        versionCode = flutterVersionCode
        versionName = flutterVersionName
        multiDexEnabled = true
        
        // ✅ ADD DEX CONFIG
        multiDexEnabled = true
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.create("release") {
                    storeFile = file(keystoreProperties["storeFile"]?.toString())
                    storePassword = keystoreProperties["storePassword"]?.toString()
                    keyAlias = keystoreProperties["keyAlias"]?.toString()
                    keyPassword = keystoreProperties["keyPassword"]?.toString()
                }
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }

            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.24")
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-messaging")
    implementation("androidx.work:work-runtime-ktx:2.9.0") // ✅ WORKMANAGER
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
}