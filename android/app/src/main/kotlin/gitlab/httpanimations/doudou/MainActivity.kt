package gitlab.openlyst.doudou

import android.app.SearchManager
import android.os.Bundle
import android.os.PowerManager
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.provider.MediaStore
import android.content.Context
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val BATTERY_CHANNEL = "app.channel/battery"
    private val VOICE_CHANNEL = "app.channel/voice_commands"
    
    private var voiceMethodChannel: MethodChannel? = null
    private var initialUri: String? = null
    private var pendingMediaPlayFromSearch: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Battery optimization channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BATTERY_CHANNEL)
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
        
        // Voice commands channel for Google Assistant
        voiceMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL)
        voiceMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialUri" -> {
                    result.success(initialUri)
                    initialUri = null // Clear after returning
                }
                else -> result.notImplemented()
            }
        }
        
        // Process initial intent if app was started from voice command
        handleIntent(intent)
        
        // Send any pending media play from search
        pendingMediaPlayFromSearch?.let { searchData ->
            voiceMethodChannel?.invokeMethod("onMediaPlayFromSearch", searchData)
            pendingMediaPlayFromSearch = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Handle the intent that started this activity
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        
        val action = intent.action
        val data = intent.data
        
        android.util.Log.d("Doudou", "handleIntent: action=$action, data=$data")
        
        when (action) {
            // Handle deep link from Google Assistant App Actions
            Intent.ACTION_VIEW -> {
                data?.let { uri ->
                    val uriString = uri.toString()
                    android.util.Log.d("Doudou", "Received deep link: $uriString")
                    
                    // Check if Flutter engine is ready
                    if (voiceMethodChannel != null) {
                        voiceMethodChannel?.invokeMethod("onVoiceCommand", uriString)
                    } else {
                        // Store for later when Flutter is ready
                        initialUri = uriString
                    }
                }
            }
            
            // Handle voice search / "Play X on Doudou" commands
            MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH -> {
                handleMediaPlayFromSearch(intent)
            }
            
            // Handle generic media search intent
            "android.media.action.MEDIA_PLAY_FROM_SEARCH" -> {
                handleMediaPlayFromSearch(intent)
            }
        }
    }

    private fun handleMediaPlayFromSearch(intent: Intent) {
        val extras = intent.extras ?: return
        
        val query = extras.getString(MediaStore.EXTRA_MEDIA_FOCUS)
            ?: extras.getString("query")
            ?: intent.getStringExtra(SearchManager.QUERY)
        
        val searchData = mutableMapOf<String, Any?>(
            "query" to (extras.getString("query") ?: intent.getStringExtra(SearchManager.QUERY)),
            "mediaFocus" to extras.getString(MediaStore.EXTRA_MEDIA_FOCUS),
            "artist" to extras.getString(MediaStore.EXTRA_MEDIA_ARTIST),
            "album" to extras.getString(MediaStore.EXTRA_MEDIA_ALBUM),
            "genre" to extras.getString("android.intent.extra.genre"),
            "playlist" to extras.getString("android.intent.extra.playlist"),
            "title" to extras.getString(MediaStore.EXTRA_MEDIA_TITLE)
        )
        
        android.util.Log.d("Doudou", "Media play from search: $searchData")
        
        // Check if Flutter engine is ready
        if (voiceMethodChannel != null) {
            voiceMethodChannel?.invokeMethod("onMediaPlayFromSearch", searchData)
        } else {
            // Store for later when Flutter is ready
            pendingMediaPlayFromSearch = searchData
        }
    }
}
