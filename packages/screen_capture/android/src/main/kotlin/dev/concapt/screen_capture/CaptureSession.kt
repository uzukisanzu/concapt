package dev.concapt.screen_capture

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.util.DisplayMetrics
import android.view.Display
import java.io.File
import java.io.FileOutputStream

class NotRunningException : Exception("Screen capture is not running")
class NoFrameException : Exception("No frame arrived from the screen")

/** Process-wide capture state shared by every engine's plugin instance. Main-thread only, except [lock]ed frame access. */
object CaptureSession {
    /** How long a capture waits for a frame newer than the request before using the latest one. */
    private const val FRESH_FRAME_WAIT_MS = 300L
    private const val POLL_MS = 20L

    private val main = Handler(Looper.getMainLooper())
    private val lock = Any()
    private val stopListeners = mutableSetOf<() -> Unit>()

    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var reader: ImageReader? = null
    private var thread: HandlerThread? = null
    private var worker: Handler? = null
    private var latest: Image? = null
    private var latestAt = 0L

    /** Set by the plugin before starting the service; called once with the start result. */
    var onStarted: ((Boolean) -> Unit)? = null

    val isRunning: Boolean get() = projection != null

    fun start(context: Context, mediaProjection: MediaProjection) {
        val metrics = DisplayMetrics()
        val screen = context.getSystemService(DisplayManager::class.java).getDisplay(Display.DEFAULT_DISPLAY)
        @Suppress("DEPRECATION")
        screen.getRealMetrics(metrics)

        val captureThread = HandlerThread("concapt-capture").apply { start() }
        val handler = Handler(captureThread.looper)
        val imageReader = ImageReader.newInstance(metrics.widthPixels, metrics.heightPixels, PixelFormat.RGBA_8888, 3)
        imageReader.setOnImageAvailableListener({ source ->
            val image = source.acquireLatestImage() ?: return@setOnImageAvailableListener
            synchronized(lock) {
                latest?.close()
                latest = image
                latestAt = SystemClock.uptimeMillis()
            }
        }, handler)

        // Android 14 requires the callback before createVirtualDisplay.
        mediaProjection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                main.post { release() }
            }
        }, main)

        projection = mediaProjection
        reader = imageReader
        thread = captureThread
        worker = handler
        display = mediaProjection.createVirtualDisplay(
            "concapt", metrics.widthPixels, metrics.heightPixels, metrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, imageReader.surface, null, handler,
        )
        reportStarted(true)
    }

    fun reportStarted(ok: Boolean) {
        onStarted?.invoke(ok)
        onStarted = null
    }

    /** Takes the first frame after this call, or the latest frame after [FRESH_FRAME_WAIT_MS]. */
    fun capture(context: Context, callback: (Result<String>) -> Unit) {
        val handler = worker
        if (projection == null || handler == null) {
            callback(Result.failure(NotRunningException()))
            return
        }
        val requestedAt = SystemClock.uptimeMillis()
        val deadline = requestedAt + FRESH_FRAME_WAIT_MS
        handler.post(object : Runnable {
            override fun run() {
                val fresh = synchronized(lock) { latestAt >= requestedAt }
                if (!fresh && SystemClock.uptimeMillis() < deadline) {
                    handler.postDelayed(this, POLL_MS)
                    return
                }
                val result = runCatching { writePng(context) }
                main.post { callback(result) }
            }
        })
    }

    fun stop() {
        val current = projection ?: return
        current.stop() // onStop releases
    }

    fun addStopListener(listener: () -> Unit) {
        stopListeners += listener
    }

    fun removeStopListener(listener: () -> Unit) {
        stopListeners -= listener
    }

    private fun release() {
        if (projection == null) return
        display?.release()
        display = null
        synchronized(lock) {
            latest?.close()
            latest = null
            latestAt = 0L
        }
        reader?.close()
        reader = null
        thread?.quitSafely()
        thread = null
        worker = null
        projection = null
        stopListeners.toList().forEach { it() }
    }

    private fun writePng(context: Context): String {
        val bitmap = synchronized(lock) {
            val image = latest ?: throw NoFrameException()
            toBitmap(image)
        }
        val file = File(context.cacheDir, "capture.png")
        FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
        return file.absolutePath
    }

    private fun toBitmap(image: Image): Bitmap {
        val plane = image.planes[0]
        val rowPixels = plane.rowStride / plane.pixelStride
        val padded = Bitmap.createBitmap(rowPixels, image.height, Bitmap.Config.ARGB_8888)
        plane.buffer.rewind()
        padded.copyPixelsFromBuffer(plane.buffer)
        if (rowPixels == image.width) return padded
        val cropped = Bitmap.createBitmap(padded, 0, 0, image.width, image.height)
        padded.recycle()
        return cropped
    }
}
