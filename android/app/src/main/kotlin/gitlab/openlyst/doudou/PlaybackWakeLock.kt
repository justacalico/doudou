package gitlab.openlyst.doudou

import android.content.Context
import android.os.PowerManager
import androidx.annotation.Keep

@Keep
object PlaybackWakeLock {
    private const val TAG = "doudou:PlaybackWakeLock"
    private var wakeLock: PowerManager.WakeLock? = null

    @Synchronized
    fun acquire(context: Context) {
        if (wakeLock?.isHeld == true) return
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val lock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "doudou:playback_wakelock")
        lock.setReferenceCounted(false)
        lock.acquire()
        wakeLock = lock
    }

    @Synchronized
    fun release() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null
    }
}
