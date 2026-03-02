package com.ahmedsleem.terminate_restart

import android.app.Application
import android.content.Context
import android.util.Log

class TerminateRestartApplication : Application() {
    companion object {
        private const val PREF_NAME = "terminate_restart_prefs"
        private const val KEY_SHOULD_CLEAR = "should_clear_data"
        private const val KEY_PRESERVE_DEFAULTS = "preserve_user_defaults"
        private const val TAG = "TerminateRestartApp"
    }

    override fun onCreate() {
        super.onCreate()
        
        // Check if we need to clear data
        val prefs = getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
        if (prefs.getBoolean(KEY_SHOULD_CLEAR, false)) {
            val preserveUserDefaults = prefs.getBoolean(KEY_PRESERVE_DEFAULTS, false)
            clearAppData(preserveUserDefaults)
            // Clear the flags
            prefs.edit().clear().commit()
        }
    }

    private fun clearAppData(preserveUserDefaults: Boolean) {
        try {
            Log.d(TAG, "Clearing app data (preserveUserDefaults: $preserveUserDefaults)")
            
            // Clear app cache
            cacheDir.deleteRecursively()
            externalCacheDir?.deleteRecursively()
            
            // Clear app files except shared preferences if preserved
            filesDir.listFiles()?.forEach { file ->
                if (!preserveUserDefaults || !file.name.contains("shared_prefs")) {
                    file.deleteRecursively()
                }
            }
            
            // Clear shared preferences if not preserved
            if (!preserveUserDefaults) {
                // Clear default shared preferences
                getSharedPreferences(packageName + "_preferences", Context.MODE_PRIVATE)
                    .edit()
                    .clear()
                    .commit()

                // Clear all shared preferences files except our own preferences
                getDir("shared_prefs", Context.MODE_PRIVATE).listFiles()?.forEach { file ->
                    if (!file.name.startsWith(PREF_NAME)) {
                        file.delete()
                    }
                }
            }

            // Force a garbage collection to ensure cleared data is released
            System.gc()
            
            Log.d(TAG, "App data cleared successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing app data", e)
            throw e
        }
    }
}
