import java.util.Properties
import java.io.FileInputStream

apply(plugin = "com.google.gms.google-services")

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// 👇 ЗАГРУЖАЕМ KEY.PROPERTIES
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.hashtagg"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "ru.hashtagg.app.test"
        minSdk = 26
        targetSdk = 36
        versionCode = 2     
        versionName = "1.0.2"        
        multiDexEnabled = true

        manifestPlaceholders += mapOf(
            "yandexMapkitApiKey" to "56984492-3dbc-4c22-8b0f-03790464b774"
        )
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
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
    implementation("com.yandex.android:maps.mobile:4.22.0-lite")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}