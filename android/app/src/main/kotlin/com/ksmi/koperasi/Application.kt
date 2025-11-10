package com.ksmi.koperasi

import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugins.GeneratedPluginRegistrant
import be.tramckrijte.workmanager.WorkmanagerPlugin

class Application : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
    }

    companion object {
        fun registerWith(flutterEngine: FlutterEngine) {
            GeneratedPluginRegistrant.registerWith(flutterEngine)
            WorkmanagerPlugin.registerWith(flutterEngine)
        }
    }
}
