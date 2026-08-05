package com.contentglows.app.capture

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class ScreenCaptureChannel(
    private val activity: Activity,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ScreenRecordService.Listener, ScreenShotService.Listener {
    private val methodChannel = MethodChannel(messenger, "contentglows/device_capture")
    private val eventChannel = EventChannel(messenger, "contentglows/device_capture_events")
    private val projectionManager =
        activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    private val capabilityResolver = CaptureCapabilityResolver(activity)
    private var eventSink: EventChannel.EventSink? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingScreenshotResult: MethodChannel.Result? = null
    private var pendingOperation: PendingOperation? = null
    private var pendingMicrophoneRequest = false
    private var pendingNotificationRequest = false
    private var microphoneEnabledForNextRecording = false
    private var recordingConfigForNextRecording = CaptureRecordingConfig()

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
        ScreenRecordService.listener = this
        ScreenShotService.listener = this
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
            "queryRecordingCapabilities" -> result.success(capabilityResolver.resolve())
            "takeScreenshot" -> requestProjection(PendingOperation.Screenshot, false, result)
            "startRecording" -> {
                val includeMicrophone = call.argument<Boolean>("includeMicrophone") == true
                requestRecording(includeMicrophone, CaptureRecordingConfig.fromMethodCall(call), result)
            }
            "stopRecording" -> {
                if (ScreenRecordService.stopActive()) {
                    result.success(mapOf("status" to "stopping"))
                } else {
                    result.success(mapOf("status" to "idle"))
                }
            }
            "pauseRecording" -> {
                val supported = capabilityResolver.supportsPauseResume
                if (!supported) {
                    emit(
                        mapOf(
                            "type" to "notice",
                            "recoverable" to true,
                            "degraded" to true,
                            "failureCode" to "pause_resume_not_supported",
                            "message" to "Pause/resume is not supported on this Android version.",
                        )
                    )
                    result.success(mapOf("status" to "unsupported", "failureCode" to "pause_resume_not_supported"))
                } else if (ScreenRecordService.pauseActive()) {
                    result.success(mapOf("status" to "paused"))
                } else {
                    result.success(mapOf("status" to "failed", "failureCode" to "pause_failed"))
                }
            }
            "resumeRecording" -> {
                val supported = capabilityResolver.supportsPauseResume
                if (!supported) {
                    emit(
                        mapOf(
                            "type" to "notice",
                            "recoverable" to true,
                            "degraded" to true,
                            "failureCode" to "pause_resume_not_supported",
                            "message" to "Pause/resume is not supported on this Android version.",
                        )
                    )
                    result.success(mapOf("status" to "unsupported", "failureCode" to "pause_resume_not_supported"))
                } else if (ScreenRecordService.resumeActive()) {
                    result.success(mapOf("status" to "recording"))
                } else {
                    result.success(mapOf("status" to "failed", "failureCode" to "resume_failed"))
                }
            }
            "shareAsset" -> {
                val path = call.argument<String>("path")
                val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                if (path.isNullOrBlank()) {
                    result.error("invalid_asset", "Missing capture asset path.", null)
                    return
                }
                shareFile(path, mimeType, result)
            }
            "deleteAsset" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("invalid_asset", "Missing capture asset path.", null)
                    return
                }
                result.success(deleteFile(path))
            }
            else -> result.notImplemented()
        }
    }

    private fun requestRecording(
        includeMicrophone: Boolean,
        requestedConfig: CaptureRecordingConfig,
        result: MethodChannel.Result
    ) {
        val permissions = mutableListOf<String>()
        if (includeMicrophone && !hasRecordAudioPermission()) {
            permissions.add(Manifest.permission.RECORD_AUDIO)
        }
        if (!hasPostNotificationsPermission()) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        if (permissions.isNotEmpty()) {
            if (pendingResult != null) {
                result.error("capture_busy", "Another capture request is already pending.", null)
                return
            }
            pendingResult = result
            pendingOperation = PendingOperation.Recording
            pendingMicrophoneRequest = permissions.contains(Manifest.permission.RECORD_AUDIO)
            pendingNotificationRequest = permissions.contains(Manifest.permission.POST_NOTIFICATIONS)
            microphoneEnabledForNextRecording = includeMicrophone
            recordingConfigForNextRecording = normalizeConfig(requestedConfig, includeMicrophone)
            activity.requestPermissions(permissions.toTypedArray(), REQUEST_RECORDING_PERMISSIONS)
            return
        }
        val normalizedConfig = normalizeConfig(requestedConfig, includeMicrophone && hasRecordAudioPermission())
        recordingConfigForNextRecording = normalizedConfig
        emitDegradationNotices(normalizedConfig)
        requestProjection(PendingOperation.Recording, includeMicrophone && hasRecordAudioPermission(), result)
    }

    private fun requestProjection(operation: PendingOperation, microphoneEnabled: Boolean, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("capture_busy", "Another capture request is already pending.", null)
            return
        }
        pendingResult = result
        pendingOperation = operation
        microphoneEnabledForNextRecording = microphoneEnabled
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            projectionManager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay())
        } else {
            projectionManager.createScreenCaptureIntent()
        }
        @Suppress("DEPRECATION")
        activity.startActivityForResult(intent, REQUEST_MEDIA_PROJECTION)
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_MEDIA_PROJECTION) return false
        val result = pendingResult ?: return true
        val operation = pendingOperation
        pendingResult = null
        pendingOperation = null

        if (resultCode != Activity.RESULT_OK || data == null || operation == null) {
            emit(mapOf("type" to "canceled", "message" to "Screen capture permission was declined."))
            result.error("capture_canceled", "Screen capture permission was declined.", null)
            return true
        }

        when (operation) {
            PendingOperation.Screenshot -> startScreenshot(resultCode, data, result)
            PendingOperation.Recording -> startRecording(resultCode, data, microphoneEnabledForNextRecording, result)
        }
        return true
    }

    fun handleRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != REQUEST_RECORDING_PERMISSIONS) return false
        if (!pendingMicrophoneRequest && !pendingNotificationRequest) return true
        val result = pendingResult ?: return true
        val grants = permissions.mapIndexed { index, permission ->
            permission to (grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED)
        }.toMap()
        val microphoneGranted = if (pendingMicrophoneRequest) {
            grants[Manifest.permission.RECORD_AUDIO] == true
        } else {
            hasRecordAudioPermission()
        }
        val notificationGranted = if (pendingNotificationRequest) {
            grants[Manifest.permission.POST_NOTIFICATIONS] == true
        } else {
            true
        }
        if (pendingMicrophoneRequest && !microphoneGranted) {
            emit(
                mapOf(
                    "type" to "notice",
                    "recoverable" to true,
                    "message" to "Microphone permission was denied. Recording will continue video-only."
                )
            )
        }
        if (pendingNotificationRequest && !notificationGranted) {
            emit(
                mapOf(
                    "type" to "notice",
                    "recoverable" to true,
                    "message" to "Android notification permission is off. Android still shows system screen-recording indicators."
                )
            )
        }
        val includeMicrophone = microphoneEnabledForNextRecording && microphoneGranted
        pendingMicrophoneRequest = false
        pendingNotificationRequest = false
        pendingResult = null
        pendingOperation = null
        recordingConfigForNextRecording = normalizeConfig(recordingConfigForNextRecording, includeMicrophone)
        emitDegradationNotices(recordingConfigForNextRecording)
        requestProjection(PendingOperation.Recording, includeMicrophone, result)
        return true
    }

    private fun startScreenshot(resultCode: Int, data: Intent, result: MethodChannel.Result) {
        if (pendingScreenshotResult != null) {
            result.error("capture_busy", "A screenshot capture is already active.", null)
            return
        }
        emit(mapOf("type" to "progress", "message" to "Saving screenshot."))
        pendingScreenshotResult = result
        val started = ScreenShotService.start(activity, resultCode, data, this)
        if (!started) {
            pendingScreenshotResult = null
            result.error("capture_busy", "A screenshot capture is already active.", null)
        }
    }

    private fun startRecording(
        resultCode: Int,
        data: Intent,
        microphoneEnabled: Boolean,
        result: MethodChannel.Result
    ) {
        val config = recordingConfigForNextRecording
        val started = ScreenRecordService.start(activity, resultCode, data, microphoneEnabled, config, this)
        if (!started) {
            result.error("capture_busy", "A screen recording is already active.", null)
            return
        }
        result.success(
            mapOf(
                "status" to "recording",
                "microphoneEnabled" to microphoneEnabled,
                "effectiveAudioMode" to config.effectiveAudioMode,
                "effectiveCameraMode" to config.effectiveCameraMode,
                "degraded" to config.degradationFlags.isNotEmpty(),
                "degradationFlags" to config.degradationFlags,
            )
        )
    }

    private fun normalizeConfig(
        requestedConfig: CaptureRecordingConfig,
        includeMicrophone: Boolean
    ): CaptureRecordingConfig {
        var effectiveAudioMode = requestedConfig.requestedAudioMode
        var effectiveCameraMode = requestedConfig.requestedCameraMode
        val degradationFlags = mutableListOf<String>()

        effectiveAudioMode = when (requestedConfig.requestedAudioMode) {
            "microphone" -> if (includeMicrophone) "microphone" else {
                degradationFlags.add("microphone_permission_required")
                "screenOnly"
            }
            "systemAudio" -> {
                degradationFlags.add("system_audio_not_supported")
                "screenOnly"
            }
            "microphoneAndSystemAudio" -> if (includeMicrophone) {
                degradationFlags.add("system_audio_not_supported")
                "microphone"
            } else {
                degradationFlags.add("microphone_permission_required")
                degradationFlags.add("system_audio_not_supported")
                "screenOnly"
            }
            else -> "screenOnly"
        }

        effectiveCameraMode = when (requestedConfig.requestedCameraMode) {
            "frontCamera", "rearCamera", "dualCamera" -> {
                degradationFlags.add("camera_overlay_not_supported")
                "screenOnly"
            }
            else -> "screenOnly"
        }

        return requestedConfig.copy(
            effectiveAudioMode = effectiveAudioMode,
            effectiveCameraMode = effectiveCameraMode,
            degradationFlags = degradationFlags.toList(),
        )
    }

    private fun emitDegradationNotices(config: CaptureRecordingConfig) {
        for (flag in config.degradationFlags) {
            when (flag) {
                "microphone_permission_required" -> emit(
                    mapOf(
                        "type" to "notice",
                        "recoverable" to true,
                        "degraded" to true,
                        "failureCode" to flag,
                        "message" to "Microphone access is unavailable. Recording will continue without microphone audio."
                    )
                )
                "system_audio_not_supported" -> emit(
                    mapOf(
                        "type" to "notice",
                        "recoverable" to true,
                        "degraded" to true,
                        "failureCode" to flag,
                        "message" to "System audio capture is not available in this recorder build yet."
                    )
                )
                "camera_overlay_not_supported" -> emit(
                    mapOf(
                        "type" to "notice",
                        "recoverable" to true,
                        "degraded" to true,
                        "failureCode" to flag,
                        "message" to "Camera overlay modes are not available in this recorder build yet."
                    )
                )
            }
        }
    }

    private fun shareFile(path: String, mimeType: String, result: MethodChannel.Result) {
        val file = File(path)
        if (!file.exists()) {
            result.error("missing_asset", "The local capture file no longer exists.", null)
            return
        }
        val uri = CaptureFileProvider.uriForFile(activity, file, mimeType)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(intent, "Share capture"))
        result.success(true)
    }

    private fun deleteFile(path: String): Boolean {
        val file = File(path).canonicalFile
        val roots = listOfNotNull(activity.filesDir, activity.getExternalFilesDir(null)).map { it.canonicalFile }
        if (roots.none { file.path == it.path || file.path.startsWith("${it.path}/") }) {
            throw SecurityException("Capture file is outside app storage.")
        }
        return !file.exists() || file.delete()
    }

    private fun hasRecordAudioPermission(): Boolean {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            true
        } else {
            activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun hasPostNotificationsPermission(): Boolean {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            true
        } else {
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun emit(event: Map<String, Any?>) {
        activity.runOnUiThread { eventSink?.success(event) }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        ScreenRecordService.currentStatusEvent()?.let { event ->
            activity.runOnUiThread { events?.success(event) }
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onRecordingEvent(event: Map<String, Any?>) {
        emit(event)
    }

    override fun onScreenshotCompleted(asset: Map<String, Any?>) {
        activity.runOnUiThread {
            emit(mapOf("type" to "completed", "asset" to asset))
            pendingScreenshotResult?.success(asset)
            pendingScreenshotResult = null
        }
    }

    override fun onScreenshotFailed(code: String, message: String) {
        activity.runOnUiThread {
            emit(mapOf("type" to if (code == "capture_canceled") "canceled" else "failed", "message" to message))
            pendingScreenshotResult?.error(code, message, null)
            pendingScreenshotResult = null
        }
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        if (ScreenRecordService.listener === this) {
            ScreenRecordService.listener = null
        }
        if (ScreenShotService.listener === this) {
            ScreenShotService.listener = null
        }
    }

    private enum class PendingOperation { Screenshot, Recording }

    companion object {
        private const val REQUEST_MEDIA_PROJECTION = 7301
        private const val REQUEST_RECORDING_PERMISSIONS = 7302
    }
}
