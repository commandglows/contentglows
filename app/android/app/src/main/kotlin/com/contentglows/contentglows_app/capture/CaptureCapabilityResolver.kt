package com.contentglows.app.capture

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings

class CaptureCapabilityResolver(private val activity: Activity) {
    val supportsPauseResume: Boolean
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N

    val supportsFloatingControls: Boolean
        get() = true

    fun resolve(): Map<String, Any> {
        val packageManager = activity.packageManager
        val hasFrontCamera = packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FRONT)
        val hasRearCamera = packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA)
        val dualCameraHardwareHint = hasFrontCamera && hasRearCamera && Build.VERSION.SDK_INT >= Build.VERSION_CODES.P
        return mapOf(
            "isSupported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP),
            "supportsScreenOnlyRecording" to true,
            "supportsMicrophoneAudio" to true,
            "supportsSystemAudio" to false,
            "supportsPauseResume" to supportsPauseResume,
            "supportsFloatingControls" to supportsFloatingControls,
            "supportsComposedCameraModes" to false,
            "hasFrontCamera" to hasFrontCamera,
            "hasRearCamera" to hasRearCamera,
            "supportsDualCamera" to false,
            "dualCameraHardwareHint" to dualCameraHardwareHint,
            "requiresFreshConsent" to true,
            "hasNotificationPermission" to hasPostNotificationsPermission(),
            "hasMicrophonePermission" to hasRecordAudioPermission(),
            "overlayPermissionGranted" to hasOverlayPermission(),
            "androidVersion" to Build.VERSION.SDK_INT,
            "projectionTokenModel" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                "single_use"
            } else {
                "legacy_session"
            },
        )
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

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            true
        } else {
            Settings.canDrawOverlays(activity)
        }
    }
}
