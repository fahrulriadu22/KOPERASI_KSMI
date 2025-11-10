package com.ksmi.koperasi

import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class Application : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        // Tidak perlu register plugin manual lagi
        // WorkManager otomatis diinisialisasi
    }

    companion object {
        fun registerWith(flutterEngine: FlutterEngine) {
            GeneratedPluginRegistrant.registerWith(flutterEngine)
        }
    }
}
