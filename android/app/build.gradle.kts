import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // =====================================================
    // 📦 IDENTIDADE DO NOVO APP (OFICIAL)
    // =====================================================
    // Alterado para 'tooca_oficial' para criar um novo registro na Play Store
    namespace = "com.toocagroup.crm.tooca"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Alterado para criar uma nova identidade única
        applicationId = "com.toocagroup.crm.tooca"
        minSdk = 29
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    // =====================================================
    // 🔐 CONFIGURAÇÃO DE ASSINATURA
    // =====================================================
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            keystoreProperties.load(FileInputStream(keystorePropertiesFile))

            create("release") {
                val fileName = keystoreProperties["storeFile"].toString()
                // rootProject.file aponta para a pasta /android/
                storeFile = rootProject.file(fileName)

                storePassword = keystoreProperties["storePassword"].toString()
                keyAlias = keystoreProperties["keyAlias"].toString()
                keyPassword = keystoreProperties["keyPassword"].toString()
            }
        }
    }

    buildTypes {
        getByName("release") {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }

            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
