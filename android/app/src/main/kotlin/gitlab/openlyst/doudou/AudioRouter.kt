package gitlab.openlyst.doudou

import android.content.Context
import android.media.MediaRouter
import android.os.Build
import androidx.annotation.Keep
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Lists and switches media output routes through the framework MediaRouter.
 * Live audio routes cover the phone speaker route plus connected Bluetooth
 * and cast targets. Deprecated on API 34 but still functional and it needs
 * no extra dependencies.
 */
@Keep
@Suppress("DEPRECATION")
object AudioRouter {
    private const val CHANNEL = "gitlab.openlyst.doudou/audio_output"

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDevices" -> result.success(listDevices(context))
                "selectDevice" -> result.success(
                    selectDevice(context, call.argument<String>("id"))
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun liveAudioRoutes(
        context: Context
    ): Pair<MediaRouter, List<MediaRouter.RouteInfo>> {
        val router = MediaRouter.getInstance(context)
        val routes = (0 until router.routeCount)
            .map { router.getRouteAt(it) }
            .filter {
                it.supportedTypes and MediaRouter.ROUTE_TYPE_LIVE_AUDIO != 0
            }
        return router to routes
    }

    private fun routeId(
        route: MediaRouter.RouteInfo,
        context: Context,
        index: Int
    ): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            route.id
        } else {
            "${route.getName(context)}#$index"
        }
    }

    private fun routeKind(route: MediaRouter.RouteInfo): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            when (route.deviceType) {
                MediaRouter.RouteInfo.DEVICE_TYPE_BLUETOOTH -> return "bluetooth"
                MediaRouter.RouteInfo.DEVICE_TYPE_TV -> return "cast"
                MediaRouter.RouteInfo.DEVICE_TYPE_SPEAKER -> return "speaker"
            }
        }
        return if (route.playbackType == MediaRouter.RouteInfo.PLAYBACK_TYPE_REMOTE) {
            "other"
        } else {
            "speaker"
        }
    }

    private fun listDevices(context: Context): List<Map<String, Any>> {
        val (router, routes) = liveAudioRoutes(context)
        val selected = router.getSelectedRoute(MediaRouter.ROUTE_TYPE_LIVE_AUDIO)
        return routes.mapIndexed { index, route ->
            mapOf(
                "id" to routeId(route, context, index),
                "name" to (route.getName(context)?.toString() ?: ""),
                "kind" to routeKind(route),
                "selected" to (route == selected),
                "selectable" to true,
            )
        }
    }

    private fun selectDevice(context: Context, id: String?): Boolean {
        if (id == null) return false
        val (router, routes) = liveAudioRoutes(context)
        val route = routes.withIndex()
            .firstOrNull { routeId(it.value, context, it.index) == id }
            ?.value ?: return false
        router.selectRoute(MediaRouter.ROUTE_TYPE_LIVE_AUDIO, route)
        return true
    }
}
