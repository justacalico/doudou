package gitlab.openlyst.doudou

import android.content.Intent
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class WearMessageListenerService : WearableListenerService() {
    
    private val WEAR_CHANNEL = "app.channel/wear"
    private var methodChannel: MethodChannel? = null
    
    override fun onCreate() {
        super.onCreate()
        
        // Initialize Flutter engine for communication with Flutter app
        val flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WEAR_CHANNEL)
    }
    
    override fun onMessageReceived(messageEvent: MessageEvent) {
        super.onMessageReceived(messageEvent)
        
        val command = String(messageEvent.data)
        
        when (messageEvent.path) {
            "/music/control" -> {
                // Handle music control commands from Wear OS
                handleMusicControl(command)
            }
            "/music/state" -> {
                // Handle requests for playback state
                handlePlaybackStateRequest()
            }
        }
    }
    
    private fun handleMusicControl(command: String) {
        // Send command to Flutter app
        methodChannel?.invokeMethod("handleWearCommand", mapOf(
            "command" to command
        ))
    }
    
    private fun handlePlaybackStateRequest() {
        // Request current playback state from Flutter app
        methodChannel?.invokeMethod("getPlaybackState", null)
    }
}