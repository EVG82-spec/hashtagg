apply(plugin = "com.google.gms.google-services")
plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
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

    // ✅ ГЛАВНОЕ: kotlinOptions — ОН РАБОТАЕТ В AGP 8.9.1
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "ru.hashtagg.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
        multiDexEnabled = true

        // 🔑 ЯВНО УКАЗЫВАЕМ КЛЮЧ
        manifestPlaceholders += mapOf(
            "yandexMapkitApiKey" to "56984492-3dbc-4c22-8b0f-03790464b774"
        )
    }

    buildTypes {
        release {
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