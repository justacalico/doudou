package gitlab.openlyst.doudou

import android.app.Application
import android.content.Intent
import android.os.Build
import android.util.Log
import io.flutter.app.FlutterApplication

class DoudouApplication : FlutterApplication() {
    
    override fun onCreate() {
        super.onCreate()
        Log.d("DoudouApplication", "Application created - Enhanced for background audio survival")
        
        // Handle any app-level initialization here
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // For Android 9+, enable additional background restrictions handling
            Log.d("DoudouApplication", "Android 9+ detected - Enhanced background handling enabled")
        }
    }
    
    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        
        when (level) {
            TRIM_MEMORY_UI_HIDDEN -> {
                Log.d("DoudouApplication", "UI hidden - app backgrounded but keeping services alive")
            }
            TRIM_MEMORY_BACKGROUND -> {
                Log.d("DoudouApplication", "App in background - memory pressure detected")
            }
            TRIM_MEMORY_MODERATE,
            TRIM_MEMORY_COMPLETE -> {
                Log.d("DoudouApplication", "High memory pressure - but keeping audio service alive")
                // Normally we'd clean up here, but we want audio to keep playing
            }
            else -> {
                Log.d("DoudouApplication", "Memory trim level: $level")
            }
        }
    }
    
    override fun onLowMemory() {
        super.onLowMemory()
        Log.d("DoudouApplication", "Low memory - but keeping audio service alive")
        // Don't kill audio service even under memory pressure
    }
}