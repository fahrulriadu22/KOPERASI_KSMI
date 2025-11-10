package com.ksmi.koperasi

import io.flutter.app.FlutterApplication
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugins.GeneratedPluginRegistrant
import dev.fluttercommunity.workmanager.WorkmanagerPlugin

class Application : FlutterApplication(), PluginRegistry.PluginRegistrantCallback {
    override fun onCreate() {
        super.onCreate()
        WorkmanagerPlugin.setPluginRegistrantCallback(this)
    }

    override fun registerWith(registry: PluginRegistry?) {
        if (registry != null) {
            GeneratedPluginRegistrant.registerWith(registry)
        }
    }
}
