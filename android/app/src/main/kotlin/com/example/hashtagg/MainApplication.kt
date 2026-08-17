package com.example.hashtagg

import android.app.Application
import com.yandex.mapkit.MapKitFactory

class MainApplication : Application() {

    override fun onCreate() {
        // Ключ ДО super.onCreate() — это важно!
        MapKitFactory.setApiKey("4aab5e00-30ab-4a8a-b428-63d00203f440")

        super.onCreate()
    }
}