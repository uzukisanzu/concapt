package dev.concapt.screen_capture

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.media.projection.MediaProjectionManager
import android.widget.Toast
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class ScreenCapturePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {

    companion object {
        private const val REQUEST_CONSENT = 4107
        private const val REQUEST_NOTIFICATIONS = 4108
    }

    private lateinit var context: Context
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingConsent: MethodChannel.Result? = null
    private var pendingNotifications: MethodChannel.Result? = null
    private var stopListener: (() -> Unit)? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "concapt/screen_capture")
        methods.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "concapt/screen_capture/events")
        events.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        onCancel(null)
        pendingConsent = null
        pendingNotifications = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestConsent" -> requestConsent(result)
            "requestNotifications" -> requestNotifications(result)
            "isRunning" -> result.success(CaptureSession.isRunning)
            "capture" -> CaptureSession.capture(context) { outcome ->
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { e ->
                        val code = if (e is NotRunningException) "not_running" else "capture_failed"
                        result.error(code, e.message, null)
                    },
                )
            }
            "stop" -> {
                CaptureSession.stop()
                result.success(null)
            }
            "moveToBack" -> {
                activityBinding?.activity?.moveTaskToBack(true)
                result.success(null)
            }
            "toast" -> {
                Toast.makeText(context, call.argument<String>("message") ?: "", Toast.LENGTH_SHORT).show()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestConsent(result: MethodChannel.Result) {
        if (CaptureSession.isRunning) {
            result.success(true)
            return
        }
        val activity = activityBinding?.activity
        if (activity == null) {
            result.error("no_activity", "Capture consent needs the app in the foreground", null)
            return
        }
        if (pendingConsent != null) {
            result.error("consent_pending", "The capture prompt is already showing", null)
            return
        }
        pendingConsent = result
        val manager = context.getSystemService(MediaProjectionManager::class.java)
        activity.startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_CONSENT)
    }

    private fun requestNotifications(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        val activity = activityBinding?.activity
        if (activity == null) {
            result.success(false)
            return
        }
        pendingNotifications = result
        activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_NOTIFICATIONS) return false
        pendingNotifications?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingNotifications = null
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CONSENT) return false
        val pending = pendingConsent ?: return true
        pendingConsent = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            pending.success(false)
            return true
        }
        CaptureSession.onStarted = { ok -> pending.success(ok) }
        val intent = Intent(context, CaptureService::class.java)
            .putExtra(CaptureService.EXTRA_RESULT_CODE, resultCode)
            .putExtra(CaptureService.EXTRA_DATA, data)
        context.startForegroundService(intent)
        return true
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        onCancel(null)
        val listener: () -> Unit = { sink.success("stopped") }
        stopListener = listener
        CaptureSession.addStopListener(listener)
    }

    override fun onCancel(arguments: Any?) {
        stopListener?.let { CaptureSession.removeStopListener(it) }
        stopListener = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
    }
}
