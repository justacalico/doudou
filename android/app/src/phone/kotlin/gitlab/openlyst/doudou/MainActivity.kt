package gitlab.openlyst.doudou

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import com.oguzhnatly.flutter_android_auto.FAAConstants

class MainActivity : AudioServiceActivity() {
    private val wakeLockChannel = "gitlab.openlyst.doudou/wakelock"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        FlutterEngineCache.getInstance().put(FAAConstants.flutterEngineId, flutterEngine)
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, wakeLockChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        PlaybackWakeLock.acquire(applicationContext)
                        result.success(true)
                    }
                    "release" -> {
                        PlaybackWakeLock.release()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
