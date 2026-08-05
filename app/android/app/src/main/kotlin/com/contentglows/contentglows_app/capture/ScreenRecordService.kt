package com.contentglows.app.capture

import android.Manifest
import android.app.Notification
import android.app.Notification.Action
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.Notification.Builder
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.view.WindowManager
import com.contentglows.app.capture.pro.RecorderState
import com.contentglows.app.capture.pro.RecorderStatePayload
import java.io.File
import kotlin.math.max

class ScreenRecordService : Service() {
    interface Listener {
        fun onRecordingEvent(event: Map<String, Any?>)
    }

    private val handler = Handler(Looper.getMainLooper())
    private var projection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var recorder: MediaRecorder? = null
    private var outputFile: File? = null
    private var sessionStartAt = 0L
    private var activeSegmentStartAt = 0L
    private var recordedDurationMs = 0L
    private var width = 0
    private var height = 0
    private var microphoneEnabled = false
    private var stopping = false
    private var recordingConfig = CaptureRecordingConfig()
    private var state = RecorderState.IDLE

    private val progressRunnable = object : Runnable {
        override fun run() {
            when (state) {
                RecorderState.RECORDING -> {
                    val durationMs = elapsedDurationMs()
                    emitProgress(durationMs)
                    if (durationMs >= MAX_DURATION_MS) {
                        stopCapture(completed = true, reason = "duration_cap")
                    } else {
                        handler.postDelayed(this, 1_000)
                    }
                }
                RecorderState.PAUSED -> {
                    emitProgress(elapsedDurationMs())
                    handler.postDelayed(this, 1_000)
                }
                else -> Unit
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_PAUSE) {
            return if (pauseActiveRecording()) START_NOT_STICKY else START_NOT_STICKY
        }
        if (action == ACTION_RESUME) {
            return if (resumeActiveRecording()) START_NOT_STICKY else START_NOT_STICKY
        }
        if (action == ACTION_STOP) {
            stopCapture(completed = true, reason = "user_stop")
            return START_NOT_STICKY
        }

        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, 0) ?: 0
        @Suppress("DEPRECATION")
        val data = intent?.getParcelableExtra<Intent>(EXTRA_DATA)
        microphoneEnabled = intent?.getBooleanExtra(EXTRA_MICROPHONE, false) == true && hasRecordAudioPermission()
        recordingConfig = CaptureRecordingConfig(
            requestedAudioMode = intent?.getStringExtra(EXTRA_REQUESTED_AUDIO_MODE) ?: "screenOnly",
            effectiveAudioMode = intent?.getStringExtra(EXTRA_EFFECTIVE_AUDIO_MODE) ?: "screenOnly",
            requestedCameraMode = intent?.getStringExtra(EXTRA_REQUESTED_CAMERA_MODE) ?: "screenOnly",
            effectiveCameraMode = intent?.getStringExtra(EXTRA_EFFECTIVE_CAMERA_MODE) ?: "screenOnly",
            overlayConfig = CaptureOverlayConfig(
                shape = intent?.getStringExtra(EXTRA_OVERLAY_SHAPE) ?: "circle",
                size = intent?.getStringExtra(EXTRA_OVERLAY_SIZE) ?: "medium",
            ),
            degradationFlags = intent?.getStringArrayListExtra(EXTRA_DEGRADATION_FLAGS) ?: emptyList(),
            startedWithForegroundOverlay = intent?.getBooleanExtra(EXTRA_FOREGROUND_OVERLAY, false) == true,
        )
        activeService = this
        setState(RecorderState.STARTING)

        if (state != RecorderState.STARTING) {
            setState(RecorderState.FAILED, failureCode = "state_mismatch")
            emitFailed("Recorder failed to enter startup state.")
            return START_NOT_STICKY
        }

        try {
            startCaptureForeground(microphoneEnabled)
        } catch (error: Exception) {
            failStartup(error.message ?: "Screen recording foreground service could not start.")
            return START_NOT_STICKY
        }

        if (resultCode == 0 || data == null) {
            failStartup("Missing Android screen capture consent data.")
            return START_NOT_STICKY
        }

        try {
            startProjection(resultCode, data)
        } catch (error: Exception) {
            failStartup(error.message ?: "Screen recording failed to start.")
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        if (!stopping && state != RecorderState.IDLE && state != RecorderState.FAILED) {
            stopCapture(completed = true, reason = "service_destroyed")
        } else {
            if (activeService === this) {
                activeService = null
            }
        }
        super.onDestroy()
    }

    private fun startProjection(resultCode: Int, data: Intent) {
        val metrics = displayMetrics()
        width = even(metrics.widthPixels.coerceAtLeast(1))
        height = even(metrics.heightPixels.coerceAtLeast(1))
        val density = metrics.densityDpi
        outputFile = CaptureAssetMetadata.newRecordingFile(this)

        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val mediaProjection = projectionManager.getMediaProjection(resultCode, data)
            ?: throw IllegalStateException("Android did not return a MediaProjection session.")
        projection = mediaProjection
        mediaProjection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                stopCapture(completed = true, reason = "projection_stopped")
            }
        }, handler)

        val mediaRecorder = createRecorder(outputFile!!, width, height, microphoneEnabled)
        recorder = mediaRecorder
        virtualDisplay = mediaProjection.createVirtualDisplay(
            "ContentGlowsRecording",
            width,
            height,
            density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            mediaRecorder.surface,
            null,
            handler
        )

        mediaRecorder.start()
        sessionStartAt = System.currentTimeMillis()
        activeSegmentStartAt = sessionStartAt
        recordedDurationMs = 0L
        setState(RecorderState.RECORDING)
        emit(
            mapOf(
                "type" to "recording",
                "durationMs" to 0L,
                "maxDurationMs" to MAX_DURATION_MS,
                "microphoneEnabled" to microphoneEnabled,
                "isPaused" to false,
            )
                .plus(recordingConfig.toEventMap())
                .plus(RecorderStatePayload(state = state).toEventMap())
        )
        updateNotification()
        handler.postDelayed(progressRunnable, 1_000)
    }

    private fun createRecorder(file: File, videoWidth: Int, videoHeight: Int, includeMicrophone: Boolean): MediaRecorder {
        val mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        if (includeMicrophone) {
            mediaRecorder.setAudioSource(MediaRecorder.AudioSource.MIC)
        }
        mediaRecorder.setVideoSource(MediaRecorder.VideoSource.SURFACE)
        mediaRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        mediaRecorder.setOutputFile(file.absolutePath)
        mediaRecorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
        mediaRecorder.setVideoSize(videoWidth, videoHeight)
        mediaRecorder.setVideoFrameRate(30)
        mediaRecorder.setVideoEncodingBitRate((videoWidth * videoHeight * 4).coerceIn(4_000_000, 16_000_000))
        if (includeMicrophone) {
            mediaRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            mediaRecorder.setAudioEncodingBitRate(128_000)
            mediaRecorder.setAudioSamplingRate(44_100)
        }
        mediaRecorder.prepare()
        return mediaRecorder
    }

    private fun pauseActiveRecording(): Boolean {
        if (!supportsPauseResume()) {
            emit(
                mapOf(
                    "type" to "notice",
                    "recoverable" to true,
                    "failureCode" to "pause_resume_not_supported",
                    "message" to "This Android version does not support pause/resume in MediaRecorder.",
                    "degraded" to true,
                    "state" to state.eventValue(),
                ).plus(recordingConfig.toEventMap())
            )
            emitStateEvent(
                RecorderStatePayload(
                    type = "state",
                    state = state,
                    failureCode = "pause_resume_not_supported",
                )
            )
            return false
        }

        if (state != RecorderState.RECORDING) {
            emitStateEvent(
                RecorderStatePayload(
                    state = state,
                    previousState = state,
                    failureCode = "pause_invalid_state",
                )
            )
            return false
        }

        val now = System.currentTimeMillis()
        recordedDurationMs += max(0L, now - activeSegmentStartAt)
        activeSegmentStartAt = 0L
        try {
            recorder?.pause()
            setState(RecorderState.PAUSED)
            emitStateEvent(
                RecorderStatePayload(
                    state = state,
                    previousState = RecorderState.RECORDING,
                    failureCode = null,
                )
            )
            updateNotification()
            return true
        } catch (error: Exception) {
            setState(RecorderState.FAILED, failureCode = "recording_pause_failed")
            emitFailed(error.message ?: "Unable to pause recording.")
            return false
        }
    }

    private fun resumeActiveRecording(): Boolean {
        if (!supportsPauseResume()) {
            emit(
                mapOf(
                    "type" to "notice",
                    "recoverable" to true,
                    "failureCode" to "pause_resume_not_supported",
                    "message" to "This Android version does not support pause/resume in MediaRecorder.",
                    "degraded" to true,
                    "state" to state.eventValue(),
                ).plus(recordingConfig.toEventMap())
            )
            emitStateEvent(
                RecorderStatePayload(
                    type = "state",
                    state = state,
                    failureCode = "pause_resume_not_supported",
                )
            )
            return false
        }

        if (state != RecorderState.PAUSED) {
            emitStateEvent(
                RecorderStatePayload(
                    state = state,
                    previousState = state,
                    failureCode = "resume_invalid_state",
                )
            )
            return false
        }

        activeSegmentStartAt = System.currentTimeMillis()
        try {
            recorder?.resume()
            setState(RecorderState.RECORDING, failureCode = null)
            emitStateEvent(
                RecorderStatePayload(
                    state = state,
                    previousState = RecorderState.PAUSED,
                )
            )
            updateNotification()
            return true
        } catch (error: Exception) {
            setState(RecorderState.FAILED, failureCode = "recording_resume_failed")
            emitFailed(error.message ?: "Unable to resume recording.")
            return false
        }
    }

    private fun stopCapture(completed: Boolean, reason: String) {
        if (stopping) return
        val shouldCountSegment = state == RecorderState.RECORDING
        stopping = true
        handler.removeCallbacks(progressRunnable)
        setState(RecorderState.STOPPING, stopReason = reason)
        if (shouldCountSegment) {
            recordedDurationMs += max(0L, System.currentTimeMillis() - activeSegmentStartAt)
        }

        val duration = recordedDurationMs
        val file = outputFile
        var finalized = completed

        try {
            recorder?.stop()
        } catch (_: Exception) {
            finalized = false
        }

        releaseResources(deleteOutput = !finalized)

        if (finalized && file != null && file.exists() && file.length() > 0L) {
            emit(
                mapOf(
                    "type" to "completed",
                    "reason" to reason,
                    "microphoneEnabled" to microphoneEnabled,
                    "durationMs" to duration,
                    "asset" to CaptureAssetMetadata.mapForFile(
                        file = file,
                        kind = "recording",
                        mimeType = "video/mp4",
                        createdAt = sessionStartAt,
                        durationMs = duration,
                        width = width,
                        height = height,
                        microphoneEnabled = microphoneEnabled,
                        captureScopeLabel = "system-selected",
                    )
                        .plus(recordingConfig.toAssetMap())
                        .plus(
                            mapOf(
                                "stopReason" to reason,
                                "state" to state.eventValue(),
                                "metadata" to recordingRecoveryMetadata(
                                    file = file,
                                    durationMs = duration,
                                    completed = true,
                                    reason = reason,
                                ),
                            ),
                        ),
                )
                    .plus(recordingConfig.toEventMap())
                    .plus(RecorderStatePayload(state = state, stopReason = reason).toEventMap())
            )
        } else {
            emit(
                mapOf(
                    "type" to "canceled",
                    "reason" to reason,
                    "message" to "Screen recording stopped before a usable file was saved.",
                    "failureCode" to "recording_not_finalized",
                    "durationMs" to duration,
                    "microphoneEnabled" to microphoneEnabled,
                    "metadata" to recordingRecoveryMetadata(
                        file = file,
                        durationMs = duration,
                        completed = false,
                        reason = reason,
                        failureCode = "recording_not_finalized",
                    ),
                )
                    .plus(recordingConfig.toEventMap())
                    .plus(RecorderStatePayload(state = state, stopReason = reason, failureCode = "recording_not_finalized").toEventMap())
            )
        }

        emitStateEvent(RecorderStatePayload(state = RecorderState.IDLE, previousState = state, stopReason = reason))
        stopForegroundCompat()
        if (activeService === this) {
            activeService = null
        }
        stopSelf()
    }

    private fun emitFailed(message: String) {
        emit(
            mapOf(
                "type" to "failed",
                "message" to message,
            )
                .plus(recordingConfig.toEventMap())
                .plus(RecorderStatePayload(state = state).toEventMap())
        )
    }

    private fun failStartup(message: String) {
        if (stopping) return
        setState(RecorderState.FAILED)
        stopping = true
        handler.removeCallbacks(progressRunnable)
        emitFailed(message)
        releaseResources(deleteOutput = true)
        stopForegroundCompat()
        if (activeService === this) {
            emitStateEvent(
                RecorderStatePayload(
                    state = RecorderState.IDLE,
                    previousState = RecorderState.FAILED,
                )
            )
            activeService = null
        }
        stopSelf()
    }

    private fun releaseResources(deleteOutput: Boolean) {
        try {
            virtualDisplay?.release()
        } catch (_: Exception) {
        }
        virtualDisplay = null
        try {
            recorder?.reset()
            recorder?.release()
        } catch (_: Exception) {
        }
        recorder = null
        try {
            projection?.stop()
        } catch (_: Exception) {
        }
        projection = null
        if (deleteOutput) {
            try {
                outputFile?.delete()
            } catch (_: Exception) {
            }
        }
        outputFile = null
        state = RecorderState.IDLE
        sessionStartAt = 0L
        recordedDurationMs = 0L
        activeSegmentStartAt = 0L
        width = 0
        height = 0
        microphoneEnabled = false
        stopping = false
    }

    private fun supportsPauseResume(): Boolean {
        return Build.VERSION.SDK_INT >= BUILD_VERSION_FOR_PAUSE_RESUME
    }

    private fun startCaptureForeground(includeMicrophone: Boolean) {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val serviceType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                if (includeMicrophone) {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                } else {
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                }
            } else {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            }
            startForeground(NOTIFICATION_ID, notification, serviceType)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        if (!hasPostNotificationsPermission()) {
            emit(
                mapOf(
                    "type" to "notice",
                    "recoverable" to true,
                    "degraded" to true,
                    "failureCode" to "notification_permission_missing",
                    "message" to "Android notification permission is off. Android still shows system screen-recording indicators.",
                ).plus(recordingConfig.toEventMap())
            )
        }
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "ContentGlows capture", NotificationManager.IMPORTANCE_LOW)
            manager.createNotificationChannel(channel)
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Builder(this)
        }
        builder
            .setSmallIcon(android.R.drawable.presence_video_online)
            .setContentTitle("ContentGlows screen recording")
            .setContentText(notificationTextForState())
            .setOngoing(true)

        val stopIntent = pendingNotificationAction(ACTION_STOP, 3301)
        stopIntent?.let {
            builder.addAction(Action.Builder(0, "Stop", it).build())
        }

        if (supportsPauseResume()) {
            when (state) {
                RecorderState.RECORDING -> {
                    val pauseIntent = pendingNotificationAction(ACTION_PAUSE, 3302)
                    pauseIntent?.let {
                        builder.addAction(Action.Builder(0, "Pause", it).build())
                    }
                }
                RecorderState.PAUSED -> {
                    val resumeIntent = pendingNotificationAction(ACTION_RESUME, 3303)
                    resumeIntent?.let {
                        builder.addAction(Action.Builder(0, "Resume", it).build())
                    }
                }
                else -> Unit
            }
        }

        return builder.build()
    }

    private fun updateNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (state == RecorderState.IDLE) return
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun pendingNotificationAction(action: String, requestCode: Int): PendingIntent? {
        val intent = Intent(this, ScreenRecordService::class.java).setAction(action)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getService(this, requestCode, intent, flags)
    }

    private fun setState(next: RecorderState, stopReason: String? = null, failureCode: String? = null) {
        val previous = state
        if (previous == next && state != RecorderState.FAILED) {
            return
        }
        state = next
        emitStateEvent(RecorderStatePayload(type = "state", state = next, previousState = previous, stopReason = stopReason, failureCode = failureCode))
        updateNotification()
    }

    private fun emitStateEvent(payload: RecorderStatePayload) {
        emit(payload.toEventMap().plus(recordingConfig.toEventMap()))
    }

    private fun emitProgress(durationMs: Long) {
        emit(
            mapOf(
                "type" to "progress",
                "durationMs" to durationMs,
                "maxDurationMs" to MAX_DURATION_MS,
                "microphoneEnabled" to microphoneEnabled,
                "isPaused" to (state == RecorderState.PAUSED),
            )
                .plus(recordingConfig.toEventMap())
                .plus(RecorderStatePayload(state = state).toEventMap())
        )
    }

    private fun elapsedDurationMs(): Long {
        return when (state) {
            RecorderState.RECORDING -> recordedDurationMs + max(0L, System.currentTimeMillis() - activeSegmentStartAt)
            else -> recordedDurationMs
        }
    }

    private fun displayMetrics(): DisplayMetrics {
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        (getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay.getRealMetrics(metrics)
        return metrics
    }

    private fun even(value: Int): Int = if (value % 2 == 0) value else value - 1

    private fun recordingRecoveryMetadata(
        file: File?,
        durationMs: Long,
        completed: Boolean,
        reason: String,
        failureCode: String? = null,
    ): Map<String, Any?> = mapOf(
        "state" to state.eventValue(),
        "stopReason" to reason,
        "durationMs" to durationMs,
        "startedAt" to sessionStartAt,
        "supportsPauseResume" to supportsPauseResume(),
        "degradationFlags" to recordingConfig.degradationFlags,
        "width" to width,
        "height" to height,
        "microphoneEnabled" to microphoneEnabled,
        "outputPath" to file?.absolutePath,
        "outputExists" to (file?.exists() == true),
        "outputSize" to (file?.length() ?: 0L),
        "completed" to completed,
        "failureCode" to failureCode,
        "hasNotificationPermission" to hasPostNotificationsPermission(),
    )

    private fun hasRecordAudioPermission(): Boolean {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            true
        } else {
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun hasPostNotificationsPermission(): Boolean {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            true
        } else {
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun notificationTextForState(): String = when (state) {
        RecorderState.RECORDING -> "Screen recording is running."
        RecorderState.PAUSED -> "Screen recording is paused."
        RecorderState.STOPPING -> "Finalizing recording."
        RecorderState.STARTING -> "Starting screen recording."
        RecorderState.FAILED -> "Screen recording failed."
        RecorderState.IDLE -> "Screen recording is idle."
    }

    private fun emit(event: Map<String, Any?>) {
        listener?.onRecordingEvent(event)
    }

    private fun currentStatusEvent(): Map<String, Any?>? {
        if (state == RecorderState.IDLE) return null
        return mapOf(
            "type" to "state",
            "durationMs" to elapsedDurationMs(),
            "maxDurationMs" to MAX_DURATION_MS,
            "microphoneEnabled" to microphoneEnabled,
            "isPaused" to (state == RecorderState.PAUSED),
            "state" to state.eventValue(),
        )
            .plus(recordingConfig.toEventMap())
            .plus(RecorderStatePayload(state = state).toEventMap())
        }

    private fun stopForegroundCompat() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (_: Exception) {
        }
    }

    companion object {
        @Volatile
        var listener: Listener? = null

        @Volatile
        private var activeService: ScreenRecordService? = null

        private const val CHANNEL_ID = "contentglows_capture"
        private const val NOTIFICATION_ID = 4407
        private const val MAX_DURATION_MS = 300_000L
        private const val ACTION_STOP = "com.contentglows.app.capture.STOP"
        private const val ACTION_PAUSE = "com.contentglows.app.capture.PAUSE"
        private const val ACTION_RESUME = "com.contentglows.app.capture.RESUME"
        private const val EXTRA_RESULT_CODE = "resultCode"
        private const val EXTRA_DATA = "data"
        private const val EXTRA_MICROPHONE = "microphone"
        private const val EXTRA_REQUESTED_AUDIO_MODE = "requestedAudioMode"
        private const val EXTRA_EFFECTIVE_AUDIO_MODE = "effectiveAudioMode"
        private const val EXTRA_REQUESTED_CAMERA_MODE = "requestedCameraMode"
        private const val EXTRA_EFFECTIVE_CAMERA_MODE = "effectiveCameraMode"
        private const val EXTRA_OVERLAY_SHAPE = "overlayShape"
        private const val EXTRA_OVERLAY_SIZE = "overlaySize"
        private const val EXTRA_DEGRADATION_FLAGS = "degradationFlags"
        private const val EXTRA_FOREGROUND_OVERLAY = "foregroundOverlay"
        private const val BUILD_VERSION_FOR_PAUSE_RESUME = Build.VERSION_CODES.N

        fun start(
            context: Context,
            resultCode: Int,
            data: Intent,
            microphoneEnabled: Boolean,
            recordingConfig: CaptureRecordingConfig,
            eventListener: Listener
        ): Boolean {
            if (activeService != null) return false
            listener = eventListener
            val intent = Intent(context, ScreenRecordService::class.java).apply {
                putExtra(EXTRA_RESULT_CODE, resultCode)
                putExtra(EXTRA_DATA, data)
                putExtra(EXTRA_MICROPHONE, microphoneEnabled)
                putExtra(EXTRA_REQUESTED_AUDIO_MODE, recordingConfig.requestedAudioMode)
                putExtra(EXTRA_EFFECTIVE_AUDIO_MODE, recordingConfig.effectiveAudioMode)
                putExtra(EXTRA_REQUESTED_CAMERA_MODE, recordingConfig.requestedCameraMode)
                putExtra(EXTRA_EFFECTIVE_CAMERA_MODE, recordingConfig.effectiveCameraMode)
                putExtra(EXTRA_OVERLAY_SHAPE, recordingConfig.overlayConfig.shape)
                putExtra(EXTRA_OVERLAY_SIZE, recordingConfig.overlayConfig.size)
                putStringArrayListExtra(EXTRA_DEGRADATION_FLAGS, ArrayList(recordingConfig.degradationFlags))
                putExtra(EXTRA_FOREGROUND_OVERLAY, recordingConfig.startedWithForegroundOverlay)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            return true
        }

        fun stopActive(): Boolean {
            val service = activeService ?: return false
            service.stopCapture(completed = true, reason = "user_stop")
            return true
        }

        fun pauseActive(): Boolean {
            val service = activeService ?: return false
            return service.pauseActiveRecording()
        }

        fun resumeActive(): Boolean {
            val service = activeService ?: return false
            return service.resumeActiveRecording()
        }

        fun canPauseResume(): Boolean = Build.VERSION.SDK_INT >= BUILD_VERSION_FOR_PAUSE_RESUME

        fun currentStatusEvent(): Map<String, Any?>? {
            return activeService?.currentStatusEvent()
        }
    }
}
