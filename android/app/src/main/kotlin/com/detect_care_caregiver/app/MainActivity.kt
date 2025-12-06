package com.detect_care_caregiver.app

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import software.solid.fluttervlcplayer.FlutterVlcPlayerPlugin
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    private val CHANNEL = "detect_care_caregiver/direct_call"
    private val TAG = "MainActivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.i(TAG, "🚀 configureFlutterEngine called - engine hash: ${flutterEngine.hashCode()}")
        
        // Ensure Vlc plugin is registered – in some edge cases generated
        // registration fails when engines are created/used in atypical ways.
        try {
            // Guard: attempt to add plugin; if it's already registered the
            // plugin registry will throw or ignore duplicates.
            flutterEngine.plugins.add(FlutterVlcPlayerPlugin())
            Log.i(TAG, "✅ FlutterVlcPlayerPlugin registered manually")
        } catch (e: Exception) {
            Log.i(TAG, "❌ FlutterVlcPlayerPlugin manual registration failed: ${e.message}")
        }

        // Verify registration by trying to get the plugin instance.
        try {
            val pluginInstance = flutterEngine.plugins.get(FlutterVlcPlayerPlugin::class.java)
            Log.i(TAG, "✅ FlutterVlcPlayerPlugin present: $pluginInstance")
        } catch (e: Exception) {
            Log.i(TAG, "❌ FlutterVlcPlayerPlugin presence check failed: ${e.message}")
        }

        // Also run the GeneratedPluginRegistrant explicitly for this engine
        // to ensure all plugins that the tooling expects are registered here.
        try {
            Log.i(TAG, "📋 Calling GeneratedPluginRegistrant.registerWith...")
            GeneratedPluginRegistrant.registerWith(flutterEngine)
            Log.i(TAG, "✅ GeneratedPluginRegistrant.registerWith succeeded")
        } catch (e: Exception) {
            Log.e(TAG, "❌ GeneratedPluginRegistrant.registerWith failed: ${e.message}", e)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "makeDirectCall") {
                    val number = call.argument<String>("number") ?: ""
                    val ok = PhoneCallHandler(this).makeDirectCall(number)
                    result.success(ok)
                } else {
                    result.notImplemented()
                }
            }
    }
}
