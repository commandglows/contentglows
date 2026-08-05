package com.contentglows.app.capture

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder

class ScreenShotService : Service() {
    interface Listener {
        fun onScreenshotCompleted(asset: Map<String, Any?>)
        fun onScreenshotFailed(code: String, message: String)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        activeService = this
        try {
            startCaptureForeground()
        } catch (error: Exception) {
            listener?.onScreenshotFailed(
                "capture_failed",
                error.message ?: "Screenshot foreground service could not start."
            )
            if (activeService === this) {
                activeService = null
            }
            stopSelf()
            return START_NOT_STICKY
        }

        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, 0) ?: 0
        @Suppress("DEPRECATION")
        val data = intent?.getParcelableExtra<Intent>(EXTRA_DATA)
        if (resultCode == 0 || data == null) {
            finishWithFailure("capture_failed", "Missing Android screen capture consent data.")
            return START_NOT_STICKY
        }

        try {
            val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val projection = projectionManager.getMediaProjection(resultCode, data)
            if (projection == null) {
                finishWithFailure("capture_failed", "Android did not return a MediaProjection session.")
                return START_NOT_STICKY
            }
            ScreenShotCapture(this).capture(
                projection,
                onSuccess = { asset -> finishWithSuccess(asset) },
                onError = { code, message -> finishWithFailure(code, message) }
            )
        } catch (error: Exception) {
            finishWithFailure("capture_failed", error.message ?: "Screenshot capture failed to start.")
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        if (activeService === this) {
            activeService = null
        }
        super.onDestroy()
    }

    private fun finishWithSuccess(asset: Map<String, Any?>) {
        listener?.onScreenshotCompleted(asset)
        stopForegroundCompat()
        stopSelf()
    }

    private fun finishWithFailure(code: String, message: String) {
        listener?.onScreenshotFailed(code, message)
        stopForegroundCompat()
        stopSelf()
    }

    private fun startCaptureForeground() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "ContentGlows capture", NotificationManager.IMPORTANCE_LOW)
            )
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
            .setSmallIcon(android.R.drawable.presence_video_online)
            .setContentTitle("ContentGlows screenshot")
            .setContentText("Saving a screen capture.")
            .setOngoing(true)
            .build()
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    companion object {
        @Volatile
        var listener: Listener? = null

        @Volatile
        private var activeService: ScreenShotService? = null

        private const val CHANNEL_ID = "contentglows_capture"
        private const val NOTIFICATION_ID = 4408
        private const val EXTRA_RESULT_CODE = "resultCode"
        private const val EXTRA_DATA = "data"

        fun start(
            context: Context,
            resultCode: Int,
            data: Intent,
            eventListener: Listener
        ): Boolean {
            if (activeService != null) return false
            listener = eventListener
            val intent = Intent(context, ScreenShotService::class.java).apply {
                putExtra(EXTRA_RESULT_CODE, resultCode)
                putExtra(EXTRA_DATA, data)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            return true
        }
    }
}
