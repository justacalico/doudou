package gitlab.openlyst.doudou

import android.os.PowerManager
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.content.Context
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "app.channel/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestBatteryOptimizationExemption" -> {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(null)
                    }
                    "isBatteryOptimizationIgnored" -> {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
