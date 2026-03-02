package com.ahmedsleem.terminate_restart.example

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.ahmedsleem.terminate_restart.TerminateRestartPlugin

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TerminateRestartPlugin.registerWith(flutterEngine)
    }
}
