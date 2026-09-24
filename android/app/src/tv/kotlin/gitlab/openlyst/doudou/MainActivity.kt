package gitlab.openlyst.doudou

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AudioRouter.register(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
    }
}
