package com.candradigital.pos_resto

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.RandomAccessFile

class MainActivity : FlutterActivity() {
    private val channel = "pos/device"

    // Snapshot /proc/stat terakhir untuk menghitung %CPU sebagai selisih antar
    // heartbeat (tanpa perlu sleep di main thread). 0 = belum ada baseline.
    private var lastCpuTotal = 0L
    private var lastCpuIdle = 0L

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
                    // Kondisi CPU & RAM untuk telemetri heartbeat.
                    // RAM selalu tersedia (ActivityManager). %CPU & load average
                    // best-effort — bila /proc/stat diblok SELinux, field-nya
                    // dilewati tapi cores + RAM tetap terkirim.
                    "resources" -> {
                        val map = HashMap<String, Any?>()
                        // — RAM —
                        try {
                            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                            val mi = ActivityManager.MemoryInfo()
                            am.getMemoryInfo(mi)
                            map["ram_total"] = mi.totalMem
                            map["ram_avail"] = mi.availMem
                            map["ram_low"] = mi.lowMemory
                        } catch (e: Exception) {
                            // abaikan — field RAM cukup dilewati
                        }
                        // — CPU cores —
                        map["cpu_cores"] = Runtime.getRuntime().availableProcessors()
                        // — %CPU sistem (selisih /proc/stat sejak panggilan lalu) —
                        try {
                            val reader = RandomAccessFile("/proc/stat", "r")
                            val line = reader.readLine()
                            reader.close()
                            val t = line.trim().split(Regex("\\s+"))
                            // t[0] = "cpu", sisanya: user nice system idle iowait irq softirq steal
                            val user = t.getOrNull(1)?.toLongOrNull() ?: 0L
                            val nice = t.getOrNull(2)?.toLongOrNull() ?: 0L
                            val system = t.getOrNull(3)?.toLongOrNull() ?: 0L
                            val idle = t.getOrNull(4)?.toLongOrNull() ?: 0L
                            val iowait = t.getOrNull(5)?.toLongOrNull() ?: 0L
                            val irq = t.getOrNull(6)?.toLongOrNull() ?: 0L
                            val softirq = t.getOrNull(7)?.toLongOrNull() ?: 0L
                            val steal = t.getOrNull(8)?.toLongOrNull() ?: 0L
                            val idleAll = idle + iowait
                            val total = user + nice + system + idleAll + irq + softirq + steal
                            if (lastCpuTotal > 0L) {
                                val dTotal = total - lastCpuTotal
                                val dIdle = idleAll - lastCpuIdle
                                if (dTotal > 0L) {
                                    val usage = (dTotal - dIdle).toDouble() / dTotal.toDouble() * 100.0
                                    val clamped = usage.coerceIn(0.0, 100.0)
                                    map["cpu_used_percent"] = Math.round(clamped * 10) / 10.0
                                }
                            }
                            lastCpuTotal = total
                            lastCpuIdle = idleAll
                        } catch (e: Exception) {
                            // /proc/stat tak terbaca (SELinux di Android 8+) → lewati
                        }
                        // — Load average (best-effort) —
                        try {
                            val la = RandomAccessFile("/proc/loadavg", "r")
                            val line = la.readLine()
                            la.close()
                            val p = line.trim().split(Regex("\\s+"))
                            p.getOrNull(0)?.toDoubleOrNull()?.let { map["load_1m"] = it }
                            p.getOrNull(1)?.toDoubleOrNull()?.let { map["load_5m"] = it }
                            p.getOrNull(2)?.toDoubleOrNull()?.let { map["load_15m"] = it }
                        } catch (e: Exception) {
                            // lewati
                        }
                        result.success(map)
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
