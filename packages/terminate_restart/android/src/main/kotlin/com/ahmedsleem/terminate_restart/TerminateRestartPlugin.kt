package com.ahmedsleem.terminate_restart

import android.app.Activity
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlin.system.exitProcess
import java.io.File

/** TerminateRestartPlugin */
class TerminateRestartPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private val TAG = "TerminateRestartPlugin"
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    companion object {
        private var instance: TerminateRestartPlugin? = null

        @JvmStatic
        fun registerWith(flutterEngine: FlutterEngine) {
            if (instance == null) {
                instance = TerminateRestartPlugin()
            }
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.ahmedsleem.terminate_restart/restart")
            channel.setMethodCallHandler(instance)
            Log.d("TerminateRestartPlugin", "Plugin registered with Flutter engine")
        }
    }

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "Plugin attached to engine")
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.ahmedsleem.terminate_restart/restart")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        this.flutterPluginBinding = flutterPluginBinding
        instance = this
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        Log.d(TAG, "Method call received: ${call.method}")
        when (call.method) {
            "restart" -> handleRestartApp(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleRestartApp(call: MethodCall, result: Result) {
        try {
            val options = call.arguments as? Map<String, Any>
            val terminate = options?.get("terminate") as? Boolean ?: false
            val clearData = options?.get("clearData") as? Boolean ?: false
            val preserveKeychain = options?.get("preserveKeychain") as? Boolean ?: false
            val preserveUserDefaults = options?.get("preserveUserDefaults") as? Boolean ?: false

            Log.d(TAG, "Handling restart with options: terminate=$terminate, clearData=$clearData")

            if (clearData) {
                Log.d(TAG, "Starting data clearing...")
                clearAppData(preserveKeychain, preserveUserDefaults) { success, error ->
                    if (error != null) {
                        Log.e(TAG, "Data clearing failed: $error")
                        result.error("DATA_CLEAR_ERROR", error.message, null)
                        return@clearAppData
                    }
                    Log.d(TAG, "Data clearing completed successfully")
                    Handler(Looper.getMainLooper()).post {
                        performRestart(terminate, result)
                    }
                }
            } else {
                performRestart(terminate, result)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error restarting app: $e")
            result.error("RESTART_ERROR", e.message, null)
        }
    }

    private fun clearAppData(preserveKeychain: Boolean, preserveUserDefaults: Boolean, callback: (Boolean, Throwable?) -> Unit) {
        try {
            val cacheDir = context.cacheDir
            val filesDir = context.filesDir
            val sharedPrefsDir = File(context.applicationInfo.dataDir, "shared_prefs")
            
            Log.d(TAG, "Clearing app data...")
            Log.d(TAG, "Cache dir: ${cacheDir.absolutePath}")
            Log.d(TAG, "Files dir: ${filesDir.absolutePath}")
            Log.d(TAG, "Shared prefs dir: ${sharedPrefsDir.absolutePath}")

            // Clear cache directory
            if (cacheDir.exists()) {
                deleteRecursive(cacheDir)
                Log.d(TAG, "Cache directory cleared")
            }

            // Clear files directory
            if (filesDir.exists() && !preserveUserDefaults) {
                deleteRecursive(filesDir)
                Log.d(TAG, "Files directory cleared")
            }

            // Clear shared preferences
            if (sharedPrefsDir.exists() && !preserveUserDefaults) {
                deleteRecursive(sharedPrefsDir)
                Log.d(TAG, "Shared preferences cleared")
            }

            // Clear databases
            val databaseList = context.databaseList()
            databaseList.forEach { dbName ->
                if (!preserveUserDefaults || !dbName.contains("keychain", ignoreCase = true)) {
                    context.deleteDatabase(dbName)
                    Log.d(TAG, "Database deleted: $dbName")
                }
            }

            callback(true, null)
        } catch (e: Exception) {
            Log.e(TAG, "Error clearing app data: $e")
            callback(false, e)
        }
    }

    private fun deleteRecursive(fileOrDirectory: File) {
        if (fileOrDirectory.isDirectory) {
            fileOrDirectory.listFiles()?.forEach { child ->
                deleteRecursive(child)
            }
        }
        val deleted = fileOrDirectory.delete()
        Log.d(TAG, "Deleted ${fileOrDirectory.path}: $deleted")
    }

    private fun performRestart(terminate: Boolean, result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            Log.e(TAG, "No activity found to restart")
            result.error("NO_ACTIVITY", "No activity found to restart", null)
            return
        }

        try {
            Log.d(TAG, "Performing ${if (terminate) "full" else "UI-only"} restart")
            
            if (terminate) {
                Log.d(TAG, "Performing full app termination")

                try {
                    Log.d(TAG, "Attempting to restart app")
                    
                    // Get package manager and create launch intent
                    val packageManager = context.packageManager
                    val packageName = context.packageName
                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                    
                    if (intent != null) {
                        Log.d(TAG, "Created restart intent with package: $packageName")
                        
                        // Create main intent that will restart the app
                        val mainIntent = Intent.makeRestartActivityTask(intent.component)
                        
                        // Return success before restarting
                        result.success(true)
                        
                        // Start new instance and exit
                        context.startActivity(mainIntent)
                        Runtime.getRuntime().exit(0)
                    } else {
                        Log.e(TAG, "Could not create launch intent")
                        result.error("INTENT_ERROR", "Could not create launch intent", null)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error restarting app", e)
                    result.error("RESTART_FAILED", e.message, null)
                }
            } else {
                Log.d(TAG, "Starting UI-only restart")
                // Get the activity's class name
                val activityClass = currentActivity.javaClass
                Log.d(TAG, "Current activity class: ${activityClass.name}")
                
                // Create a new intent for the same activity
                val intent = Intent(currentActivity, activityClass).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                            Intent.FLAG_ACTIVITY_CLEAR_TASK
                    putExtra("uiRestart", true)
                }

                // Return success before restarting
                result.success(true)

                // Start new activity
                currentActivity.startActivity(intent)
                currentActivity.finish()

                // Force recreate the Flutter engine
                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        // Get the Flutter activity
                        val flutterActivity = currentActivity as? io.flutter.embedding.android.FlutterActivity
                        
                        if (flutterActivity != null) {
                            // Create and configure the new engine
                            val newEngine = FlutterEngine(context)
                            newEngine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())

                            // Register plugins using FlutterPluginRegistrant
                            try {
                                val registrantClass = Class.forName("io.flutter.plugins.GeneratedPluginRegistrant")
                                val registerMethod = registrantClass.getMethod("registerWith", FlutterEngine::class.java)
                                registerMethod.invoke(null, newEngine)
                            } catch (e: Exception) {
                                Log.e(TAG, "Error registering plugins: $e")
                            }

                            // Register our plugin with the new engine
                            val channel = MethodChannel(newEngine.dartExecutor.binaryMessenger, "com.ahmedsleem.terminate_restart/restart")
                            val internalChannel = MethodChannel(newEngine.dartExecutor.binaryMessenger, "com.ahmedsleem.terminate_restart/internal")
                            
                            // Set the new engine using reflection since the property is protected
                            try {
                                val engineField = io.flutter.embedding.android.FlutterActivity::class.java.getDeclaredField("flutterEngine")
                                engineField.isAccessible = true
                                engineField.set(flutterActivity, newEngine)
                            } catch (e: Exception) {
                                Log.e(TAG, "Error setting new Flutter engine: $e")
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error during engine recreation: $e")
                    }
                }, 100)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error during restart: $e")
            result.error("RESTART_ERROR", e.message, null)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "Plugin detached from engine")
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "Plugin attached to activity: ${binding.activity.javaClass.name}")
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "Plugin detached from activity for config changes")
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "Plugin reattached to activity: ${binding.activity.javaClass.name}")
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "Plugin detached from activity")
        activity = null
    }
}
