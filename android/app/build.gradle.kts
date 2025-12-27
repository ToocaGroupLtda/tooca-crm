import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {

    // =====================================================
    // 📦 IDENTIDADE DO APP
    // =====================================================
    namespace = "com.toocagroup.crm.tooca"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.toocagroup.crm.tooca"
        minSdk = 29
        targetSdk = 35

        versionCode = 2
        versionName = flutter.versionName
    }

    // =====================================================
    // 🔐 SIGNING CONFIG (APENAS SE EXISTIR)
    // =====================================================
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            keystoreProperties.load(FileInputStream(keystorePropertiesFile))

            create("release") {
                storeFile = file(keystoreProperties["storeFile"].toString())
                storePassword = keystoreProperties["storePassword"].toString()
                keyAlias = keystoreProperties["keyAlias"].toString()
                keyPassword = keystoreProperties["keyPassword"].toString()
            }
        }
    }

    buildTypes {

        // ✅ DEBUG NUNCA ASSINADO COM RELEASE
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }

        // 🔒 RELEASE SÓ ASSINA SE TIVER KEYSTORE
        getByName("release") {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
