package com.candradigital.pos_resto

import android.os.Build
import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "pos/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Penyimpanan internal (bytes) untuk telemetri heartbeat.
                    "storage" -> {
                        try {
                            val stat = StatFs(Environment.getDataDirectory().path)
                            result.success(
                                mapOf("total" to stat.totalBytes, "free" to stat.availableBytes)
                            )
                        } catch (e: Exception) {
                            result.error("STORAGE_ERR", e.message, null)
                        }
                    }
                    // Identitas perangkat (model, manufaktur, versi Android).
                    "deviceInfo" -> {
                        result.success(
                            mapOf(
                                "manufacturer" to Build.MANUFACTURER,
                                "model" to Build.MODEL,
                                "android_release" to Build.VERSION.RELEASE,
                                "sdk_int" to Build.VERSION.SDK_INT
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
