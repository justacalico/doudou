package gitlab.openlyst.doudou

import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.android.FlutterActivity
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "gitlab.openlyst.doudou/battery_optimization"
    private var wakeLock: PowerManager.WakeLock? = null
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestBatteryOptimization" -> {
                    requestBatteryOptimization()
                    result.success(true)
                }
                "acquireWakeLock" -> {
                    acquireWakeLock()
                    result.success(true)
                }
                "releaseWakeLock" -> {
                    releaseWakeLock()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Create high priority notification channel for audio service
        createNotificationChannel()
        
        // Request battery optimization whitelist on app start
        requestBatteryOptimization()
        
        Log.d("MainActivity", "Audio app initialized with battery optimization handling")
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "gitlab.openlyst.doudou.channel.audio"
            val channelName = "Doudou Music"
            val channelDescription = "Music playback controls and status"
            val importance = NotificationManager.IMPORTANCE_HIGH
            
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = channelDescription
                setSound(null, null) // No sound for media controls
                enableVibration(false) // No vibration for media controls
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
            
            Log.d("MainActivity", "High priority notification channel created")
        }
    }
    
    private fun requestBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent()
            val packageName = packageName
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                intent.action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                intent.data = Uri.parse("package:$packageName")
                try {
                    startActivity(intent)
                    Log.d("MainActivity", "Requesting battery optimization whitelist")
                } catch (e: Exception) {
                    Log.e("MainActivity", "Failed to request battery optimization", e)
                }
            } else {
                Log.d("MainActivity", "App is already whitelisted from battery optimization")
            }
        }
    }
    
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "DoudouAudio::AudioPlaybackWakeLock"
            )
            wakeLock?.acquire(10*60*1000L /*10 minutes*/)
            Log.d("MainActivity", "Wake lock acquired for audio playback")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to acquire wake lock", e)
        }
    }
    
    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                    Log.d("MainActivity", "Wake lock released")
                }
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to release wake lock", e)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        releaseWakeLock()
    }
}
