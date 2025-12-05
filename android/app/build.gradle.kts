plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.toocagroup.crm"
    compileSdk = 36             // obrigatorio para Android 14
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.toocagroup.crm"
        minSdk = 29              // Android 10
        targetSdk = 35           // recomendado
        versionCode = 5
        versionName = flutter.versionName
    }

    // =====================================================
    // 🔐 ASSINATURA PARA PLAY STORE — RELEASE SIGNED
    // =====================================================
    signingConfigs {
        create("release") {
            storeFile = file("tooca.keystore")
            storePassword = "Vendas2025$$"
            keyAlias = "tooca"
            keyPassword = "Vendas2025$$"
        }
    }

    // =====================================================
    // 🏗️ TIPOS DE BUILD (DEBUG / RELEASE)
    // =====================================================
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
